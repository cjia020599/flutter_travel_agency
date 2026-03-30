import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../api/tours_api.dart';
import '../api/cars_api.dart';
import '../api/lookups_api.dart';
import '../api/auth_api.dart';
import '../api/user_api.dart';
import 'admin_dashboard_page.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'user_profile_page.dart';
import '../models/car_rental.dart';
import '../api/car_rentals_api.dart';
import '../api/tour_bookings_api.dart';
import '../api/ratings_api.dart';
import 'package:intl/intl.dart';

// Design colors
const _navBlue = Color(0xFF1E3A5F);
const _topBarGrey = Color(0xFF2C3E50);
const _primaryBlue = Color(0xFF2563EB);
const _accentOrange = Color(0xFFEAB308);
const _saleRed = Color(0xFFDC2626);
const _hotPurple = Color(0xFF7C3AED);

enum _NavItem { home, tours, hotels, cars, news, contact }

class TravelHomePage extends StatefulWidget {
  const TravelHomePage({super.key});

  @override
  State<TravelHomePage> createState() => _TravelHomePageState();
}

class _TravelHomePageState extends State<TravelHomePage> {
  int _searchTabIndex = 0;
  final _searchTabs = ['Tours', 'Cars'];

  _NavItem _current = _NavItem.home;
  RangeValues _priceRange = const RangeValues(50, 300);

  bool _isLoggedIn = false;
  bool _isAdmin = false;
  List<dynamic> _tours = [];
  List<dynamic> _cars = [];
  List<dynamic> _locations = [];
  List<CarRental> _rentals = [];
  final Map<String, List<dynamic>> _ratingsByKey = {};
  final Map<String, bool> _ratingsLoadingByKey = {};
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().add(const Duration(days: 1)),
    end: DateTime.now().add(const Duration(days: 5)),
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final loggedIn = await ApiClient.instance.isLoggedIn;
    final isAdmin = await UserApi.isAdmin();
    final tours = await ToursApi.list();
    final cars = await CarsApi.list();
    final locations = await LookupsApi.locations();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _isAdmin = isAdmin;
      _tours = tours is List ? tours : [];
      _cars = cars is List ? cars : [];
      _locations = locations is List ? locations : [];
    });
    await _loadRentals();
  }

  Future<void> _loadRentals() async {
    if (!_isLoggedIn) {
      if (mounted) setState(() => _rentals = []);
      return;
    }
    try {
      final rentals = await CarRentalsApi.getCarRentals();
      if (mounted) setState(() => _rentals = rentals);
    } catch (e) {
      if (mounted) setState(() => _rentals = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load rentals: $e')),
      );
    }
  }

  String _ratingsKey(String moduleType, int moduleId) => '$moduleType:$moduleId';

  Future<List<dynamic>> _loadRatingsFor(String moduleType, int moduleId) async {
    final key = _ratingsKey(moduleType, moduleId);
    if (mounted) {
      setState(() {
        _ratingsLoadingByKey[key] = true;
      });
    }
    try {
      final ratings = await RatingsApi.list(moduleType: moduleType, moduleId: moduleId);
      if (mounted) {
        setState(() {
          _ratingsByKey[key] = ratings;
          _ratingsLoadingByKey[key] = false;
        });
      }
      return ratings;
    } catch (e) {
      if (mounted) {
        setState(() {
          _ratingsByKey[key] = [];
          _ratingsLoadingByKey[key] = false;
        });
      }
      return [];
    }
  }

  Future<void> _promptLoginIfNeeded() async {
    if (_isLoggedIn) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        title: const Text('Sign In'),
        content: LoginDialogContent(onSuccess: _loadData),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    await _loadData();
  }

  int? _extractUserId(dynamic rating) {
    if (rating is! Map) return null;
    final user = rating['user'];
    if (user is Map && user['id'] != null) {
      return int.tryParse(user['id'].toString());
    }
    if (rating['userId'] != null) {
      return int.tryParse(rating['userId'].toString());
    }
    return null;
  }

  Future<void> _upsertRating({
    required String moduleType,
    required int moduleId,
    Map<String, dynamic>? existing,
  }) async {
    if (!_isLoggedIn) {
      await _promptLoginIfNeeded();
      if (!_isLoggedIn) return;
    }

    final starsController = TextEditingController(
      text: (existing?['stars']?.toString() ?? '5'),
    );
    final commentController = TextEditingController(
      text: existing?['comment']?.toString() ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Rating' : 'Edit Rating'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: starsController,
                decoration: const InputDecoration(
                  labelText: 'Stars (1-5)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  labelText: 'Comment (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final stars = int.tryParse(starsController.text.trim());
    if (stars == null || stars < 1 || stars > 5) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stars must be an integer from 1 to 5')),
        );
      }
      return;
    }

    try {
      if (existing == null) {
        await RatingsApi.create(
          moduleType: moduleType,
          moduleId: moduleId,
          stars: stars,
          comment: commentController.text.trim(),
        );
      } else {
        final ratingId = int.tryParse(existing['id'].toString());
        if (ratingId == null) {
          throw Exception('Invalid rating ID');
        }
        await RatingsApi.update(
          ratingId,
          stars: stars,
          comment: commentController.text.trim(),
        );
      }

      await _loadRatingsFor(moduleType, moduleId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(existing == null ? 'Rating added' : 'Rating updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rating save failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteRating({
    required String moduleType,
    required int moduleId,
    required int ratingId,
  }) async {
    if (!_isLoggedIn) {
      await _promptLoginIfNeeded();
      if (!_isLoggedIn) return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rating'),
        content: const Text('Are you sure you want to delete this rating?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await RatingsApi.delete(ratingId);
      await _loadRatingsFor(moduleType, moduleId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Widget _buildRatingsSection({
    required String moduleType,
    required int moduleId,
  }) {
    final key = _ratingsKey(moduleType, moduleId);
    final ratings = _ratingsByKey[key] ?? const [];
    final isLoading = _ratingsLoadingByKey[key] == true;
    final avg = ratings.isEmpty
        ? 0.0
        : ratings
                .map((r) => double.tryParse((r['stars'] ?? 0).toString()) ?? 0.0)
                .reduce((a, b) => a + b) /
            ratings.length;
    final currentUserId = int.tryParse((_clientCurrentUserIdCached ?? '').toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Ratings', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(width: 8),
            if (ratings.isNotEmpty)
              Text(
                '${avg.toStringAsFixed(1)} / 5 (${ratings.length})',
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _upsertRating(moduleType: moduleType, moduleId: moduleId),
              icon: const Icon(Icons.rate_review, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(),
          )
        else if (ratings.isEmpty)
          Text('No ratings yet.', style: TextStyle(color: Colors.grey[600]))
        else
          ...ratings.map((r) {
            final ratingId = int.tryParse((r['id'] ?? '').toString());
            final stars = (r['stars'] ?? '').toString();
            final comment = (r['comment'] ?? '').toString();
            final userName = (r['username'] ?? r['userName'] ?? (
                    (r['user'] is Map && r['user']['name'] != null)
                        ? r['user']['name']
                        : ((r['user'] is Map && r['user']['email'] != null)
                            ? r['user']['email']
                            : 'User')))
                .toString();
            final ownerId = _extractUserId(r);
            final isOwner = currentUserId != null && ownerId != null && ownerId == currentUserId;

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('$stars ★  •  $userName'),
                subtitle: Text(comment.isEmpty ? 'No comment' : comment),
                trailing: isOwner && ratingId != null
                    ? Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _upsertRating(
                              moduleType: moduleType,
                              moduleId: moduleId,
                              existing: Map<String, dynamic>.from(r),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () => _deleteRating(
                              moduleType: moduleType,
                              moduleId: moduleId,
                              ratingId: ratingId,
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            );
          }),
      ],
    );
  }

  String? _clientCurrentUserIdCached;

  Future<void> _cacheCurrentUserId() async {
    _clientCurrentUserIdCached = await ApiClient.instance.currentUserId;
    if (mounted) setState(() {});
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text('$label: ', style: TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Future<void> _showCarDetailsDialog(Map<String, dynamic> car) async {
    final carId = car['id'] as int? ?? 0;
    if (carId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid car ID')),
      );
      return;
    }

    final title = car['title']?.toString() ?? 'Car';
    final price = car['salePrice'] ?? car['price'];
    final priceStr = price != null ? '\$${price.toString()} / day' : '';
    final imageUrl = car['imageUrl'] ?? '';
    final passengers = car['passenger']?.toString() ?? '-';
    final gear = car['gearShift']?.toString() ?? '-';

    final startController = TextEditingController(text: DateFormat('MMM dd, yyyy').format(DateTime.now().add(const Duration(days: 1))));
    final endController = TextEditingController(text: DateFormat('MMM dd, yyyy').format(DateTime.now().add(const Duration(days: 5))));
    final buyerNameController = TextEditingController();
    final buyerEmailController = TextEditingController(text: 'test@example.com');
    final buyerPhoneController = TextEditingController(text: '+1234567890');

    await _loadRatingsFor('car', carId);
    await _cacheCurrentUserId();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            height: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Car Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Icon(Icons.directions_car, size: 80, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Price
                  Text(
                    priceStr,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryBlue),
                  ),
                  const SizedBox(height: 12),
                  // Details
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(Icons.people, 'Passengers', passengers),
                          const SizedBox(height: 8),
                          _infoRow(Icons.speed, 'Gear Shift', gear),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date Pickers (compact style)
                  Text('Rental Dates:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startController,
                          decoration: InputDecoration(
                            labelText: 'Start Date',
                            hintText: 'Select start date',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today, size: 20),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(const Duration(days: 1)),
                                  firstDate: DateTime.now().add(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  startController.text = DateFormat('MMM dd, yyyy').format(picked);
                                  setDialogState(() {});
                                }
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: endController,
                          decoration: InputDecoration(
                            labelText: 'End Date',
                            hintText: 'Select end date',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today, size: 20),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(const Duration(days: 5)),
                                  firstDate: DateTime.now().add(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  endController.text = DateFormat('MMM dd, yyyy').format(picked);
                                  setDialogState(() {});
                                }
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRatingsSection(moduleType: 'car', moduleId: carId),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final startDate = DateFormat('MMM dd, yyyy').parse(startController.text);
                  final endDate = DateFormat('MMM dd, yyyy').parse(endController.text);
                  
                  final CreateRentalRequest request = CreateRentalRequest(
                    carId: carId,
                    startDate: startDate,
                    endDate: endDate,
                    buyerName: buyerNameController.text.trim(),
                    buyerEmail: buyerEmailController.text.trim(),
                    buyerPhone: buyerPhoneController.text.trim(),
                  );

                  final success = await CarRentalsApi.rentCar(request);
                  Navigator.pop(context);
                  
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$title rented successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    await _loadRentals();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to rent car')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
              ),
              child: const Text('Rent Now'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMyRentals() async {
    if (_rentals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rentals found')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('My Car Rentals'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: _rentals.length,
            itemBuilder: (context, index) {
              final rental = _rentals[index];
              return Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      rental.carImageUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, size: 60),
                    ),
                  ),
                  title: Text(rental.carTitle),
                  subtitle: Text('${DateFormat('MMM dd, yyyy').format(rental.startDate)} - ${DateFormat('MMM dd, yyyy').format(rental.endDate)}'),
                  trailing: rental.status != 'cancelled'
                      ? IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Confirm Cancel'),
                                content: const Text('Are you sure you want to cancel this car rental booking? This action cannot be undone.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text('Cancel Booking'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              final success = await CarRentalsApi.cancelRental(rental.id);
                              if (success && mounted) {
                                Navigator.pop(context);
                                await _loadRentals();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Rental cancelled')),
                                );
                              }
                            }
                          },
                        )
                      : const Text('Cancelled', style: TextStyle(color: Colors.grey)),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _showTourDetailsDialog(Map<String, dynamic> tour) async {
    final tourId = tour['id'] as int? ?? 0;
    if (tourId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid tour ID')),
      );
      return;
    }

    final title = tour['title']?.toString() ?? 'Tour';
    final price = tour['salePrice'] ?? tour['price'];
    final priceStr = price != null ? '\$${price.toString()} / person' : '';
    final imageUrl = tour['imageUrl'] ?? '';

    final startController = TextEditingController(text: DateFormat('MMM dd, yyyy').format(DateTime.now().add(const Duration(days: 1))));
    final endController = TextEditingController(text: DateFormat('MMM dd, yyyy').format(DateTime.now().add(const Duration(days: 5))));
    final buyerNameController = TextEditingController(text: 'John Doe');
    final buyerEmailController = TextEditingController(text: 'test@example.com');
    final buyerPhoneController = TextEditingController(text: '+1234567890');

    await _loadRatingsFor('tour', tourId);
    await _cacheCurrentUserId();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            height: 550,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        height: 180,
                        color: Colors.grey[300],
                        child: const Icon(Icons.travel_explore, size: 80, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    priceStr,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryBlue),
                  ),
                  const SizedBox(height: 16),
                  Text('Tour Dates:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startController,
                          decoration: InputDecoration(
                            labelText: 'Start Date',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(const Duration(days: 1)),
                                  firstDate: DateTime.now().add(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) startController.text = DateFormat('MMM dd, yyyy').format(picked);
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          readOnly: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: endController,
                          decoration: InputDecoration(
                            labelText: 'End Date',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.calendar_today),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now().add(const Duration(days: 5)),
                                  firstDate: DateTime.now().add(const Duration(days: 1)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) endController.text = DateFormat('MMM dd, yyyy').format(picked);
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRatingsSection(moduleType: 'tour', moduleId: tourId),
                  const SizedBox(height: 24),
                  Text('Buyer Information:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: buyerNameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: buyerEmailController,
                    decoration:  InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
    TextField(
                    controller: buyerPhoneController,
                    decoration: InputDecoration(
                      labelText: 'Phone',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final startDate = DateFormat('MMM dd, yyyy').parse(startController.text);
                  final endDate = DateFormat('MMM dd, yyyy').parse(endController.text);
                  final request = CreateTourBookingRequest(
                    tourId: tourId,
                    startDate: startDate,
                    endDate: endDate,
                    buyerName: buyerNameController.text.trim(),
                    buyerEmail: buyerEmailController.text.trim(),
                    buyerPhone: buyerPhoneController.text.trim(),
                  );
                  final success = await TourBookingsApi.buyTour(request);
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
SnackBar(content: Text('$title booked!'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Booking failed')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, foregroundColor: Colors.white),
              child: const Text('Book Now'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildTopBar(),
          _buildNavBar(),
          ..._buildPageSlivers(),
        ],
      ),
      floatingActionButton: _isLoggedIn
          ? FloatingActionButton(
              onPressed: _showMyRentals,
              backgroundColor: _primaryBlue,
              child: const Icon(Icons.directions_car, color: Colors.white),
              tooltip: 'My Rentals',
            )
          : null,
    );
  }

  List<Widget> _buildPageSlivers() {
    switch (_current) {
      case _NavItem.home:
        return [
          SliverToBoxAdapter(child: _buildHero()),
          SliverToBoxAdapter(child: _buildCategories()),
          SliverToBoxAdapter(child: _buildSectionTitle('Trending Places', "The world's best luxury travel tours.")),
          SliverToBoxAdapter(child: _buildTrendingPlaces()),
          SliverToBoxAdapter(child: _buildSectionTitle('Top Destinations', 'Explore our destinations.')),
          SliverToBoxAdapter(child: _buildTopDestinations()),
          SliverToBoxAdapter(child: _buildSectionTitle('Our Tour Packages', 'Browse available tours.')),
          SliverToBoxAdapter(child: _buildTourPackages()),
          SliverToBoxAdapter(child: _buildSectionTitle('Our Cars', 'Browse available cars.')),
          SliverToBoxAdapter(child: _buildCarPackages()),
          SliverToBoxAdapter(child: _buildKnowYourCityBanner()),
          SliverToBoxAdapter(child: _buildNewsletter()),
          SliverToBoxAdapter(child: _buildFooter()),
        ];
      case _NavItem.tours:
        return [
          SliverToBoxAdapter(child: _buildSearchListPage(title: 'Search for tour', itemLabel: 'tours', items: _tours, isTour: true)),
          SliverToBoxAdapter(child: _buildFooter()),
        ];
      case _NavItem.hotels:
        return [
          SliverToBoxAdapter(child: _buildSearchListPage(title: 'Search for tour', itemLabel: 'tours', items: _tours, isTour: true)),
          SliverToBoxAdapter(child: _buildFooter()),
        ];
      case _NavItem.cars:
        return [
          SliverToBoxAdapter(child: _buildSearchListPage(title: 'Search for car', itemLabel: 'cars', items: _cars, isTour: false)),
          SliverToBoxAdapter(child: _buildFooter()),
        ];
      case _NavItem.news:
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 40, 48, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('News', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _navBlue)),
                  const SizedBox(height: 8),
                  Text('Latest stories and travel advice.', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 24),
                  Center(child: Text('No news available.', style: TextStyle(color: Colors.grey[600]))),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildFooter()),
        ];
      case _NavItem.contact:
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(48, 80, 48, 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Contact us', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _navBlue)),
                  const SizedBox(height: 8),
                  Text('We would love to hear from you.', style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(decoration: InputDecoration(labelText: 'Your name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                            const SizedBox(height: 16),
                            TextField(decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                            const SizedBox(height: 16),
                            TextField(
                              maxLines: 4,
                              decoration: InputDecoration(labelText: 'Message', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {},
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                              ),
                              child: const Text('Send message'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildFooter()),
        ];
    }
  }

  Widget _buildTopBar() {
    return SliverToBoxAdapter(
      child: Container(
        color: _topBarGrey,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone, size: 16, color: Colors.grey[300]),
                    const SizedBox(width: 8),
                    Text('+1 (800) 283 0000', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                    const SizedBox(width: 24),
                    Icon(Icons.email_outlined, size: 16, color: Colors.grey[300]),
                    const SizedBox(width: 8),
                    Text('info@domain.com', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                  ],
                ),
                Row(
                  children: [
                    if (_isAdmin)
                      TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminDashboardPage())),
                        child: Text('Admin', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                      ),
                    if (_isLoggedIn) ...[
                      TextButton(
                        onPressed: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UserProfilePage()));
                          _loadData();
                        },
                        child: Text('My Profile', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                      ),
                      TextButton(
                        onPressed: () async {
                          await AuthApi.logout();
                          _loadData();
                        },
                        child: Text('Logout', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                      ),
                    ] else ...[
                      TextButton(
                        onPressed: () async {
showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                              title: const Text('Sign In'),
                              content: LoginDialogContent(onSuccess: _loadData),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Text('Sign In', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                      ),
                      TextButton(
                        onPressed: () async {
await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                              title: const Text('Register'),
                              content: const RegisterDialogContent(),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          );
                          _loadData();
                        },
                        child: Text('Register', style: TextStyle(color: Colors.grey[300], fontSize: 13)),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dropdown(String value, List<String> options) {
    return DropdownButton<String>(
      value: value,
      dropdownColor: _topBarGrey,
      underline: const SizedBox(),
      style: TextStyle(color: Colors.grey[300], fontSize: 13),
      items: options.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: (_) {},
    );
  }

  Widget _buildNavBar() {
    return SliverToBoxAdapter(
      child: Container(
        color: _navBlue,
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
        child: Row(
          children: [
            _buildLogo(),
            const SizedBox(width: 48),
            _NavLink(
              label: 'Home',
              isActive: _current == _NavItem.home,
              onTap: () => setState(() => _current = _NavItem.home),
            ),
            _NavLink(
              label: 'Tours',
              isActive: _current == _NavItem.tours,
              onTap: () => setState(() => _current = _NavItem.tours),
            ),
            // _NavLink(
            //   label: 'Hotel',
            //   isActive: _current == _NavItem.hotels,
            //   onTap: () => setState(() => _current = _NavItem.hotels),
            // ),
            _NavLink(
              label: 'Cars',
              isActive: _current == _NavItem.cars,
              onTap: () => setState(() => _current = _NavItem.cars),
            ),
            _NavLink(
              label: 'News',
              isActive: _current == _NavItem.news,
              onTap: () => setState(() => _current = _NavItem.news),
            ),
            _NavLink(
              label: 'Contact',
              isActive: _current == _NavItem.contact,
              onTap: () => setState(() => _current = _NavItem.contact),
            ),
            const Spacer(),
            // Stack(
            //   clipBehavior: Clip.none,
            //   children: [
            //     IconButton(icon: const Icon(Icons.notification_important_outlined, color: Colors.white), onPressed: () {}),
            //     Positioned(
            //       right: 4,
            //       top: 4,
            //       child: Container(
            //         padding: const EdgeInsets.all(4),
            //         decoration: const BoxDecoration(color: _saleRed, shape: BoxShape.circle),
            //         child: const Text('0', style: TextStyle(color: Colors.white, fontSize: 10)),
            //       ),
            //     ),
            //   ],
            // ),
            // IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      width: 125,
      height: 125,
      child:  Center(child: ClipOval(child: Image.network('https://res.cloudinary.com/das4hjjvf/image/upload/v1773481328/logo_transparent_bg_dfoqlw.webp', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[400]))),
                  ),
    );
  }

  Widget _buildHero() {
    return Stack(
      children: [
        Container(
          height: 520,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1E3A5F).withOpacity(0.7),
                const Color(0xFF0F172A),
              ],
            ),
          ),
          child: Image.network(
            'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=1200',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
        ),
        Container(
          height: 520,
          width: double.infinity,
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54])),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 100, 48, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Hi there!', style: TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w300)),
              const SizedBox(height: 8),
              const Text("Let's explore the world together!", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w500)),
              const SizedBox(height: 75),
              _buildSearchWidget(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchWidget() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(_searchTabs.length, (i) {
                  final isActive = i == _searchTabIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _searchTabIndex = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        color: isActive ? _primaryBlue : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _searchTabs[i],
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.grey[700],
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),
              if (isWide)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Where are you going?',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Check In',
                          suffixIcon: const Icon(Icons.calendar_today, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Check Out',
                          suffixIcon: const Icon(Icons.calendar_today, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<String>(
                        value: '2',
                        decoration: InputDecoration(
                          hintText: 'Guest',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        items: const [
                          DropdownMenuItem(value: '2', child: Text('2 Guest')),
                        ],
                        onChanged: (_) {},
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.search, size: 20),
                      label: const Text('Search'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Where are you going?',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Check In',
                              suffixIcon: const Icon(Icons.calendar_today, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Check Out',
                              suffixIcon: const Icon(Icons.calendar_today, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: '2',
                            decoration: InputDecoration(
                              hintText: 'Guest',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            ),
                            items: const [
                              DropdownMenuItem(value: '2', child: Text('2 Guest')),
                            ],
                            onChanged: (_) {},
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.search, size: 20),
                          label: const Text('Search'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 20, 48, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _navBlue)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    final items = [
      (_navBlue, 'NEW', 'Creative Hotels', 'Our Hotels are all about the experience.', Icons.hotel),
      (Colors.grey[700]!, 'SALE', 'Best Travel', 'Our trips are all about the experience.', Icons.travel_explore),
      (_navBlue, null, 'Holiday Planning', 'Our Cars are all about the experience.', Icons.flight),
      (Colors.orange[700]!, null, 'Amazing Cars', 'Our Cars are all about the experience.', Icons.directions_car),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(48,40,48,20),
      child: Row(
        children: items.map((e) {
          final (color, tag, title, desc, icon) = e;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
              child: Stack(
                children: [
                  // if (tag != null) Positioned(top: 0, left: 0, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _saleRed, borderRadius: BorderRadius.circular(4)), child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)))),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(height: 8), Text(desc, style: TextStyle(color: Colors.white70, fontSize: 13)), const SizedBox(height: 16), Icon(icon, color: Colors.white54, size: 40)]),
                  Positioned(bottom: 0, right: 0, child: Icon(Icons.arrow_forward, color: Colors.white54)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrendingPlaces() {
    if (_tours.isEmpty) {
      return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
    }
    return SizedBox(
      height: 320,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 48),
        itemCount: _tours.length,
        itemBuilder: (context, i) {
          final t = _tours[i] as Map<String, dynamic>;
          final title = t['title']?.toString() ?? 'Tour';
          final price = t['salePrice'] ?? t['price'];
          final priceStr = price != null ? '\$$price / person' : '';
          final featured = t['isFeatured'] == true;
          return Container(
            width: 280,
            margin: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(12)), child: Image.network('https://images.unsplash.com/photo-1552832230-c0197dd311b5?w=400', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[400]))),
                      if (featured) Positioned(top: 12, left: 12, child: _tag('FEATURED', _saleRed)),
                      Positioned(bottom: 12, left: 12, right: 12, child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]))),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(priceStr, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tag(String label, Color color) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)), child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)));
  }

  Widget _buildTopDestinations() {
    if (_locations.isEmpty) return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.8,
        children: _locations.map<Widget>((loc) {
          final name = (loc is Map ? loc['name'] : loc.toString()) ?? 'Destination';
          return Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2))]),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network('https://images.unsplash.com/photo-1496442226666-8d4d0e62e6e9?w=400', fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[400])),
                  Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54]))),
                  Positioned(bottom: 16, left: 16, right: 16, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)), Text('Explore', style: TextStyle(color: Colors.white70, fontSize: 12))]), const Icon(Icons.arrow_forward, color: Colors.white)])),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCard({String? saleTag, String title = 'Travel with us', String desc = 'Lorem ipsum dolor sit amet.', String price = '\$150 / person', double stars = 4.5, String? buttonLabel}) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black, blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Container(height: 160, width: double.infinity, color: Colors.grey[300], child: Image.network('https://images.unsplash.com/photo-1488646953014-85cb44e25828?w=400', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
              ),
              if (saleTag != null) Positioned(top: 12, left: 12, child: _tag(saleTag, saleTag == 'HOT' ? _hotPurple : _saleRed)),
              Positioned(bottom: 12, right: 12, child: CircleAvatar(backgroundColor: _primaryBlue, child: const Icon(Icons.check, color: Colors.white, size: 20))),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 6),
              Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [Icon(Icons.star, size: 16, color: Colors.amber[700]), const SizedBox(width: 4), Text('$stars', style: const TextStyle(fontSize: 13)), const SizedBox(width: 12), Text(price, style: const TextStyle(fontWeight: FontWeight.bold))]),
              ]),
              if (buttonLabel != null) ...[
                const SizedBox(height: 12), 
                SizedBox(
                  width: double.infinity, 
                  child: OutlinedButton(
                    onPressed: () {}, 
                    child: Text(buttonLabel)))],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildTourPackages() {
    if (_tours.isEmpty) return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.3,
        children: _tours.map<Widget>((t) {
          final m = t as Map<String, dynamic>;
          final title = m['title']?.toString() ?? 'Tour';
          final price = m['salePrice'] ?? m['price'];
          final priceStr = price != null ? '\$$price / person' : '';
          return _buildCard(title: title, price: priceStr, buttonLabel: 'View Details');
        }).toList(),
      ),
    );
  }

  Widget _buildCarPackages() {
    if (_cars.isEmpty) return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.3,
        children: _cars.map<Widget>((c) {
          final m = c as Map<String, dynamic>;
          final title = m['title']?.toString() ?? 'Car';
          final price = m['salePrice'] ?? m['price'];
          final priceStr = price != null ? '\$$price / day' : '';
          return _buildCard(title: title, price: priceStr, desc: '${m['passenger'] ?? '-'} passengers · ${m['gearShift'] ?? '-'}', buttonLabel: 'View Details');
        }).toList(),
      ),
    );
  }

  Widget _buildPopularPackages() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1,
        children: List.generate(8, (i) {
          return _buildCard(title: '${7 - (i % 3)} Days In Switzerland', price: '\$70 / person', buttonLabel: null);
        }),
      ),
    );
  }

  Widget _buildBankEvents() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.4,
        children: List.generate(6, (i) {
          return _buildCard(saleTag: 'HOT', title: 'Amazing Event in Paris', desc: 'Lorem ipsum dolor sit amet.', price: '\$120', buttonLabel: null);
        }),
      ),
    );
  }

  Widget _buildNews() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.2,
        children: List.generate(6, (_) {
          return Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black, blurRadius: 10, offset: const Offset(0, 2))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Container(height: 180, width: double.infinity, color: Colors.grey[300], child: Image.network('https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?w=400', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox())),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Adventure Trip (Tour)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(height: 8),
                    Text('22 March 2026', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    const SizedBox(height: 8),
                    TextButton(onPressed: () {}, child: const Text('Read More')),
                  ]),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSearchListPage({required String title, required String itemLabel, required List<dynamic> items, required bool isTour}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero banner with title
        Stack(
          children: [
            SizedBox(
              height: 260,
              width: double.infinity,
              child: Image.network(
                'https://images.unsplash.com/photo-1519710164239-da123dc03ef4?w=1200',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.green[200]),
              ),
            ),
            Container(
              height: 260,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 48,
              bottom: 40,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find the best $itemLabel for your next trip.',
                    style: TextStyle(color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Search row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(48, 24, 48, 24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final fields = [
                Expanded(
                  flex: 3,
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Location',
                      hintText: 'Where are you going?',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: 'Check-in – Check-out',
                      hintText: 'DD/MM/YYYY – DD/MM/YYYY',
                      suffixIcon: const Icon(Icons.calendar_today, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: '1 Adult · 0 Child',
                    decoration: InputDecoration(
                      labelText: 'Guests',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: const [
                      DropdownMenuItem(value: '1 Adult · 0 Child', child: Text('1 Adult · 0 Child')),
                      DropdownMenuItem(value: '2 Adults · 0 Child', child: Text('2 Adults · 0 Child')),
                    ],
                    onChanged: (_) {},
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                    ),
                    child: const Text('Search'),
                  ),
                ),
              ];

              if (isWide) {
                return Row(children: fields);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  fields[0],
                  const SizedBox(height: 12),
                  fields[2],
                  const SizedBox(height: 12),
                  fields[4],
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: fields[6]),
                ],
              );
            },
          ),
        ),
        // Filter + results
        Padding(
          padding: const EdgeInsets.fromLTRB(48, 16, 48, 48),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 260, child: _buildHotelFilterCard()),
              const SizedBox(width: 24),
              Expanded(child: _buildResultList(itemLabel: itemLabel, items: items, isTour: isTour)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHotelFilterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter by', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _navBlue)),
          const SizedBox(height: 16),
          const Text('Filter Price', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 500,
            divisions: 10,
            labels: RangeLabels('\$${_priceRange.start.round()}', '\$${_priceRange.end.round()}'),
            activeColor: _primaryBlue,
            onChanged: (values) {
              setState(() => _priceRange = values);
            },
          ),
          const SizedBox(height: 4),
          Text('Price: \$${_priceRange.start.round()} - \$${_priceRange.end.round()}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          const Divider(height: 32),
          const Text('Hotel Star', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _staticCheckbox('5 star'),
          _staticCheckbox('4 star'),
          _staticCheckbox('3 star'),
          const Divider(height: 32),
          const Text('Review Score', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _staticCheckbox('Wonderful 9+'),
          _staticCheckbox('Very good 8+'),
          _staticCheckbox('Good 7+'),
          const Divider(height: 32),
          const Text('Property type', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _staticCheckbox('Apartments'),
          _staticCheckbox('Hostels'),
          _staticCheckbox('Hotels'),
        ],
      ),
    );
  }

  Widget _staticCheckbox(String label) {
    return Row(
      children: [
        Checkbox(value: false, onChanged: null),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 13))),
      ],
    );
  }

  Widget _buildResultList({required String itemLabel, required List<dynamic> items, required bool isTour}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${items.length} $itemLabel found',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _navBlue),
            ),
          ],
        ),
        const SizedBox(height: 12),
        items.isEmpty
            ? const Padding(padding: EdgeInsets.all(48), child: Center(child: Text('No items found.')))
            : GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.9,
                children: List.generate(items.length, (index) => InkWell(
                  onTap: () => isTour ? _showTourDetailsDialog(items[index] as Map<String, dynamic>) : _showCarDetailsDialog(items[index] as Map<String, dynamic>),
                  child: _buildResultCard(items[index] as Map<String, dynamic>, isTour),
                )),
              ),
      ],
    );
  }

  Widget _buildResultCard(Map<String, dynamic> item, bool isTour) {
    final title = item['title']?.toString() ?? 'Item';
    final price = item['salePrice'] ?? item['price'];
    final priceStr = price != null ? '\$$price${isTour ? ' / person' : ' / day'}' : '';
    final featured = item['isFeatured'] == true;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: Image.network(
                    item['imageUrl'] ?? 'https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=600',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
                  ),
                ),
              ),
              if (featured)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: _saleRed, borderRadius: BorderRadius.circular(4)),
                    child: const Text('Featured', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  if (isTour)
                    Text('Tour', style: TextStyle(color: Colors.grey[600], fontSize: 12))
                  else
                    Text('${item['passenger'] ?? '-'} passengers · ${item['gearShift'] ?? '-'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('from $priceStr', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildKnowYourCityBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(48, 48, 48, 0),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      decoration: BoxDecoration(color: _accentOrange.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Know your city?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)), const SizedBox(height: 8), Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut elit tellus', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14))]),
          ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _navBlue, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Learn More')),
        ],
      ),
    );
  }

  Widget _buildRatings() {
    final guides = [('Irvin Deo', 'Sample Rating'), ('Jane Smith', 'Sample Rating'), ('John Doe', 'Sample Rating')];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        children: guides.map((e) {
          final (name, role) = e;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black, blurRadius: 10, offset: const Offset(0, 2))]),
              child: Column(children: [
                CircleAvatar(radius: 48, backgroundColor: Colors.grey[300], child: Text(name[0], style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold))),
                const SizedBox(height: 16),
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(role, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                const SizedBox(height: 8),
                Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit.', style: TextStyle(color: Colors.grey[500], fontSize: 12), textAlign: TextAlign.center),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNewsletter() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 48, 0, 0),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      color: Colors.grey[200],
      child: Row(
        children: [
          Icon(Icons.mail_outline, size: 32, color: _navBlue),
          const SizedBox(width: 16),
          const Text('Join Our Newsletter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _navBlue)),
          const SizedBox(width: 32),
          Expanded(child: TextField(decoration: InputDecoration(hintText: 'Enter your email', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)))),
          const SizedBox(width: 12),
          ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: _navBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Subscribe')),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      color: _navBlue,
      padding: const EdgeInsets.fromLTRB(48, 48, 48, 24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: 16),
                    Text('Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut elit tellus, luctus nec ullamcorper mattis.', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                    const SizedBox(height: 16),
                    Text('Copyright © 2026 Company Name, All Rights Reserved.', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Quick Links', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _footerLink('About us'),
                  _footerLink('Contact us'),
                  _footerLink('Privacy Policy'),
                  _footerLink('Terms & Conditions'),
                ]),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Categories', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _footerLink('Adventure'),
                  _footerLink('Culture'),
                  _footerLink('Relaxation'),
                  _footerLink('Family'),
                ]),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Contact Information', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Text('+1 (800) 283 0000', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                  Text('info@domain.com', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                  Text('123 Street, City, Country', style: TextStyle(color: Colors.grey[300], fontSize: 14)),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              IconButton(icon: const Icon(Icons.facebook, color: Colors.white), onPressed: () {}),
              IconButton(icon: const Icon(Icons.camera_alt, color: Colors.white), onPressed: () {}),
              IconButton(icon: const Icon(Icons.camera, color: Colors.white), onPressed: () {}),
              IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.white), onPressed: () {}),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white12),
        ],
      ),
    );
  }

  Widget _footerLink(String label) {
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: TextButton(onPressed: () {}, style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap), child: Text(label, style: TextStyle(color: Colors.grey[300], fontSize: 14))));
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? _accentOrange : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
