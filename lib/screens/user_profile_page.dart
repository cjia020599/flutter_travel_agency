import 'package:flutter/material.dart';
import '../api/user_api.dart';
import '../api/auth_api.dart';
import '../api/api_client.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'admin_dashboard_page.dart';
import 'package:flutter_travel_agency/features/admin/dashboard/admin_section.dart';
import '../api/car_rentals_api.dart';
import '../api/tour_bookings_api.dart';
import '../api/reports_api.dart';
import '../models/car_rental.dart';
import '../models/tour_booking.dart';
import 'package:intl/intl.dart';

const _navBlue = Color(0xFF1E3A5F);
const _primaryBlue = Color(0xFF2563EB);
const _sidebarBg = Color(0xFF1E3A5F);

enum _ProfileSection { profile, bookingHistory, admin }

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final GlobalKey<AdminDashboardPageState> _adminKey =
      GlobalKey<AdminDashboardPageState>();
  Map<String, dynamic>? _profile;
  bool _loading = true;
  bool _isAdmin = false;
  String? _error;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _businessName;
  late TextEditingController _username;
  late TextEditingController _email;
  late TextEditingController _firstName;
  late TextEditingController _lastName;
  late TextEditingController _phone;
  late TextEditingController _birthday;
  late TextEditingController _about;
  late TextEditingController _address1;
  late TextEditingController _address2;
  late TextEditingController _city;
  late TextEditingController _state;
  late TextEditingController _zipCode;
  String? _country;
  late List<CarRental> _rentals = [];
  late List<TourBooking> _tourBookings = [];
  List<Map<String, dynamic>> _bookingHistoryRows = [];
  bool _loadingBookingHistory = false;
  String _bookingHistorySearch = '';
  String _bookingTypeFilter = 'all';
  String _bookingStatusFilter = 'all';
  String _bookingBookedByFilter = '';
  String _bookingCreatorFilter = '';
  _ProfileSection _activeSection = _ProfileSection.profile;
  AdminSection _adminSection = AdminSection.dashboard;
  bool _adminToursExpanded = true;
  bool _adminCarsExpanded = false;

  @override
  void initState() {
    super.initState();
    _businessName = TextEditingController();
    _username = TextEditingController();
    _email = TextEditingController();
    _firstName = TextEditingController();
    _lastName = TextEditingController();
    _phone = TextEditingController();
    _birthday = TextEditingController();
    _about = TextEditingController();
    _address1 = TextEditingController();
    _address2 = TextEditingController();
    _city = TextEditingController();
    _state = TextEditingController();
    _zipCode = TextEditingController();
    _loadProfile();
    _loadBookings();
  }

  @override
  void dispose() {
    _businessName.dispose();
    _username.dispose();
    _email.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _birthday.dispose();
    _about.dispose();
    _address1.dispose();
    _address2.dispose();
    _city.dispose();
    _state.dispose();
    _zipCode.dispose();
    super.dispose();
  }

  void _fillFromProfile(Map<String, dynamic> p) {
    _businessName.text = _str(p['businessName']);
    _username.text = _str(p['userName'] ?? p['username']);
    _email.text = _str(p['email']);
    _firstName.text = _str(p['firstName']);
    _lastName.text = _str(p['lastName']);
    _phone.text = _str(p['phoneNumber'] ?? p['phone']);
    _birthday.text = _str(p['birthday']);
    _about.text = _str(p['bio'] ?? p['aboutYourself'] ?? p['about']);
    _address1.text = _str(p['address'] ?? p['address1']);
    _address2.text = _str(p['address2']);
    _city.text = _str(p['city']);
    _state.text = _str(p['state']);
    _zipCode.text = _str(p['zipCode'] ?? p['zip']);
    _country = _str(p['country']);
    if (_country?.isEmpty ?? true) _country = null;
  }

  String _str(dynamic v) => v?.toString() ?? '';

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        UserApi.getProfile(),
        UserApi.isAdmin(),
      ]);
      if (!mounted) return;
      final rawProfile = results[0] as Map<String, dynamic>;
      final resolvedProfile = _coerceProfile(rawProfile) ?? rawProfile;
      if (resolvedProfile.isNotEmpty && _looksLikeProfile(resolvedProfile)) {
        _profile = resolvedProfile;
        _fillFromProfile(resolvedProfile);
      }
      _isAdmin = results[1] as bool;
      if (_isAdmin) {
        _activeSection = _ProfileSection.admin;
        _adminSection = AdminSection.dashboard;
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await AuthApi.logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginDialogContent()),
          (route) => false,
        );
        return;
      }
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _error = null);
    try {
      final payload = {
        'businessName': _businessName.text.trim(),
        'userName': _username.text.trim(),
        'username': _username.text.trim(),
        'email': _email.text.trim(),
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'phoneNumber': _phone.text.trim(),
        'phone': _phone.text.trim(),
        'birthday': _birthday.text.trim(),
        'bio': _about.text.trim(),
        'about': _about.text.trim(),
        'aboutYourself': _about.text.trim(),
        'address': _address1.text.trim(),
        'address1': _address1.text.trim(),
        'address2': _address2.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'country': _country ?? '',
        'zipCode': _zipCode.text.trim(),
        'zip': _zipCode.text.trim(),
      };
      final updated = await UserApi.updateProfile(payload);
      if (!mounted) return;
      final resolved = _coerceProfile(updated);
      if (resolved != null &&
          resolved.isNotEmpty &&
          _looksLikeProfile(resolved)) {
        _profile = resolved;
        _fillFromProfile(resolved);
      } else {
        await _loadProfile();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Map<String, dynamic>? _coerceProfile(Map<String, dynamic> raw) {
    if (raw.isEmpty) return null;
    final data = raw['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return raw;
  }

  bool _looksLikeProfile(Map<String, dynamic> profile) {
    return profile.containsKey('email') ||
        profile.containsKey('firstName') ||
        profile.containsKey('userName') ||
        profile.containsKey('username') ||
        profile.containsKey('businessName');
  }

  Future<void> _loadBookings() async {
    try {
      final currentUserIdRaw = await ApiClient.instance.currentUserId;
      final currentUserId = int.tryParse(currentUserIdRaw ?? '');
      _rentals = await CarRentalsApi.getCarRentals(userId: currentUserId);
      _tourBookings = await TourBookingsApi.getMyBookings(
        userId: currentUserId,
      );
      setState(() {});
    } catch (e) {
      print('Error loading bookings: $e');
    }
  }

  Future<void> _showBookingsHistory() async {
    setState(() => _activeSection = _ProfileSection.bookingHistory);
    await _loadBookingHistory();
  }

  Future<void> _loadBookingHistory() async {
    if (_loadingBookingHistory) return;
    setState(() => _loadingBookingHistory = true);
    try {
      await _loadBookings();
      final myRows = <Map<String, dynamic>>[];
      for (final rental in _rentals) {
        final row = {
          'bookingId': rental.id,
          'serviceName': rental.carTitle,
          'moduleType': 'car',
          'bookedBy': rental.bookedBy?.trim().isNotEmpty == true
              ? rental.bookedBy
              : (rental.buyerName?.trim().isNotEmpty == true
                    ? rental.buyerName
                    : 'You'),
          'creator': rental.creator?.trim().isNotEmpty == true
              ? rental.creator
              : 'Unknown',
          'price': rental.carPrice,
          'salePrice': rental.carPrice,
          'total': rental.carPrice,
          'bookingDate': rental.startDate.toIso8601String(),
          'status': rental.status,
          'actionEnabled': true,
        };
        myRows.add(row);
      }
      for (final booking in _tourBookings) {
        final row = {
          'bookingId': booking.id,
          'serviceName': booking.tourTitle,
          'moduleType': 'tour',
          'bookedBy': booking.bookedBy?.trim().isNotEmpty == true
              ? booking.bookedBy
              : (booking.buyerName?.trim().isNotEmpty == true
                    ? booking.buyerName
                    : 'You'),
          'creator': booking.creator?.trim().isNotEmpty == true
              ? booking.creator
              : 'Unknown',
          'price': booking.tourPrice,
          'salePrice': booking.tourPrice,
          'total': booking.tourPrice,
          'bookingDate': booking.startDate.toIso8601String(),
          'status': booking.status,
          'actionEnabled': true,
        };
        myRows.add(row);
      }

      if (_isAdmin) {
        final myRowsByKey = {
          for (final row in myRows)
            '${(row['moduleType'] ?? '').toString().toLowerCase()}_${row['bookingId']}':
                _normalizeBookingHistoryRow(row),
        };
        final myKeySet = myRowsByKey.keys.toSet();
        final data = await ReportsApi.bookings();
        final items = (data['items'] as List?)?.cast<dynamic>() ?? const [];
        final allRows = items
            .map(
              (item) => item is Map<String, dynamic>
                  ? item
                  : Map<String, dynamic>.from(item as Map),
            )
            .map(_normalizeBookingHistoryRow)
            .toList();
        _bookingHistoryRows = allRows.map((row) {
          final key =
              '${(row['moduleType'] ?? '').toString().toLowerCase()}_${row['bookingId']}';
          final isOwnBooking = myKeySet.contains(key);
          if (!isOwnBooking) {
            return {...row, 'actionEnabled': false};
          }
          final ownRow = myRowsByKey[key] ?? const <String, dynamic>{};
          return {
            ...row,
            // Prefer own booking source for identity fields so admin sees
            // reliable "booked by" on records they personally created.
            'bookedBy': ownRow['bookedBy'] ?? row['bookedBy'] ?? 'You',
            'creator': ownRow['creator'] ?? row['creator'] ?? 'Unknown',
            'actionEnabled': true,
          };
        }).toList();
      } else {
        _bookingHistoryRows = myRows.map(_normalizeBookingHistoryRow).toList();
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load booking history: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingBookingHistory = false);
    }
  }

  Future<void> _cancelBookingFromHistory(Map<String, dynamic> row) async {
    final bookingId = int.tryParse((row['bookingId'] ?? '').toString());
    final moduleType = (row['moduleType'] ?? '').toString().toLowerCase();
    if (bookingId == null || (moduleType != 'car' && moduleType != 'tour')) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid booking record.')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Cancel Booking'),
        content: Text(
          'Are you sure you want to cancel this ${moduleType == 'car' ? 'car rental' : 'tour'} booking?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = moduleType == 'car'
        ? await CarRentalsApi.cancelRental(bookingId)
        : await TourBookingsApi.cancelBooking(bookingId);

    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to cancel booking. Please try again.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking cancelled successfully.')),
    );
    await _loadBookingHistory();
  }

  Map<String, dynamic> _normalizeBookingHistoryRow(Map<String, dynamic> input) {
    final row = Map<String, dynamic>.from(input);
    String pickText(List<dynamic> values, {String fallback = '-'}) {
      for (final value in values) {
        final text = (value ?? '').toString().trim();
        if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
      }
      return fallback;
    }

    row['bookedBy'] = pickText([
      row['bookedBy'],
      row['buyerName'],
      row['buyer_name'],
      row['booked_by'],
      row['bookerName'],
      row['booker_name'],
      row['bookerEmail'],
      row['booker_email'],
    ], fallback: 'Unknown');

    row['creator'] = pickText([
      row['creator'],
      row['createdBy'],
      row['creatorName'],
      row['creator_name'],
      row['ownerName'],
      row['owner_name'],
    ], fallback: 'Unknown');

    row['serviceName'] = pickText([
      row['serviceName'],
      row['service_name'],
      row['item'],
      row['title'],
    ], fallback: 'N/A');

    row['moduleType'] = pickText([
      row['moduleType'],
      row['module_type'],
      row['type'],
    ], fallback: 'unknown').toLowerCase();

    row['status'] = pickText([
      row['status'],
      row['bookingStatus'],
      row['booking_status'],
    ], fallback: 'unknown').toLowerCase();

    return row;
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await AuthApi.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TravelHomePage()),
      (route) => false,
    );
  }

  void _openAdminSection(AdminSection section) {
    setState(() {
      _activeSection = _ProfileSection.admin;
      _adminSection = section;
    });
    _adminKey.currentState?.setSection(section);
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 980;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTopBar(isMobile: isMobile),
        Expanded(
          child: _activeSection == _ProfileSection.admin
              ? _buildAdminContent()
              : _activeSection == _ProfileSection.bookingHistory
              ? _buildBookingHistoryContent()
              : _buildProfileContent(),
        ),
      ],
    );

    return Scaffold(
      drawer: isMobile ? Drawer(child: SafeArea(child: _buildSidebar())) : null,
      body: isMobile
          ? content
          : Row(
              children: [
                _buildSidebar(),
                Expanded(child: content),
              ],
            ),
    );
  }

  String _pageTitle() {
    if (_activeSection == _ProfileSection.profile) return 'Settings';
    if (_activeSection == _ProfileSection.bookingHistory) {
      return 'Booking History';
    }
    switch (_adminSection) {
      case AdminSection.dashboard:
        return 'Dashboard';
      case AdminSection.users:
        return 'Users';
      case AdminSection.toursAll:
        return 'All Tours';
      case AdminSection.toursAdd:
        return 'Add Tour';
      case AdminSection.tourCategories:
        return 'Tour Categories';
      case AdminSection.tourAttributes:
        return 'Tour Attributes';
      case AdminSection.tourAvailability:
        return 'Tours Availability Calendar';
      case AdminSection.tourBookingCalendar:
        return 'Tour Booking Calendar';
      case AdminSection.tourRecovery:
        return 'Tour Recovery';
      case AdminSection.carsAll:
        return 'All Cars';
      case AdminSection.carsAdd:
        return 'Add new car';
      case AdminSection.chatbot:
        return 'Chatbot Q&A';
      case AdminSection.revenues:
        return 'Revenues';
      case AdminSection.reports:
        return 'Reports';
      case AdminSection.settings:
        return 'Settings';
      case AdminSection.ratings:
        return 'Ratings';
    }
  }

  Widget _buildTopBar({bool isMobile = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 12,
      ),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMobile)
                Builder(
                  builder: (drawerContext) => IconButton(
                    onPressed: () => Scaffold.of(drawerContext).openDrawer(),
                    icon: const Icon(Icons.menu),
                  ),
                ),
              Text(
                _pageTitle(),
                style: TextStyle(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (!isMobile)
            TextButton.icon(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const TravelHomePage())),
              icon: const Icon(Icons.home),
              label: const Text('Back to Home'),
            )
          else
            IconButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const TravelHomePage())),
              icon: const Icon(Icons.home),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 1100;
    return SingleChildScrollView(
      padding: EdgeInsets.all(isNarrow ? 16 : 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (isNarrow) ...[
              _section('Personal Information', [
                _field(_businessName, 'Business name', Icons.business),
                _field(_username, 'User name *', Icons.person),
                _field(_email, 'E-mail', Icons.email),
                _field(_firstName, 'First name', Icons.person_outline),
                _field(_lastName, 'Last name', Icons.person_outline),
                _field(_phone, 'Phone Number', Icons.phone),
                _field(_birthday, 'Birthday', Icons.calendar_today),
                TextFormField(
                  controller: _about,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'About Yourself',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              _section('Location Information', [
                _field(_address1, 'Address Line 1', Icons.location_on),
                _field(_address2, 'Address Line 2', Icons.location_on),
                _field(_city, 'City', Icons.location_city),
                _field(_state, 'State', Icons.flag),
                DropdownButtonFormField<String>(
                  initialValue: _country,
                  decoration: const InputDecoration(
                    labelText: 'Country',
                    border: OutlineInputBorder(),
                  ),
                  items:
                      [
                            'Philippines',
                            'United States',
                            'United Kingdom',
                            'Japan',
                            'France',
                          ]
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _country = v),
                ),
                _field(_zipCode, 'Zip Code', Icons.pin_drop),
              ]),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _section('Personal Information', [
                      _field(_businessName, 'Business name', Icons.business),
                      _field(_username, 'User name *', Icons.person),
                      _field(_email, 'E-mail', Icons.email),
                      _field(_firstName, 'First name', Icons.person_outline),
                      _field(_lastName, 'Last name', Icons.person_outline),
                      _field(_phone, 'Phone Number', Icons.phone),
                      _field(_birthday, 'Birthday', Icons.calendar_today),
                      TextFormField(
                        controller: _about,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'About Yourself',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _section('Location Information', [
                      _field(_address1, 'Address Line 1', Icons.location_on),
                      _field(_address2, 'Address Line 2', Icons.location_on),
                      _field(_city, 'City', Icons.location_city),
                      _field(_state, 'State', Icons.flag),
                      DropdownButtonFormField<String>(
                        initialValue: _country,
                        decoration: const InputDecoration(
                          labelText: 'Country',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            [
                                  'Philippines',
                                  'United States',
                                  'United Kingdom',
                                  'Japan',
                                  'France',
                                ]
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => _country = v),
                      ),
                      _field(_zipCode, 'Zip Code', Icons.pin_drop),
                    ]),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminContent() {
    if (!_isAdmin) {
      return const Center(child: Text('Admin access required'));
    }

    return AdminDashboardPage(
      key: _adminKey,
      showSidebar: false,
      showBackButton: false,
      showHeader: false,
      initialSection: _adminSection,
    );
  }

  Widget _buildBookingHistoryContent() {
    if (_loadingBookingHistory && _bookingHistoryRows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final query = _bookingHistorySearch.trim().toLowerCase();
    final bookedByQuery = _bookingBookedByFilter.trim().toLowerCase();
    final creatorQuery = _bookingCreatorFilter.trim().toLowerCase();
    final filteredRows = _bookingHistoryRows.where((row) {
      final type = (row['moduleType'] ?? '').toString().toLowerCase();
      final status = (row['status'] ?? '').toString().toLowerCase();
      final bookedBy = (row['bookedBy'] ?? '').toString().toLowerCase();
      final creator = (row['creator'] ?? '').toString().toLowerCase();
      final searchable =
          '${row['bookingId'] ?? ''} ${row['serviceName'] ?? ''} ${row['bookedBy'] ?? ''} ${row['creator'] ?? ''} $type $status'
              .toLowerCase();
      final typeOk = _bookingTypeFilter == 'all' || type == _bookingTypeFilter;
      final statusOk =
          _bookingStatusFilter == 'all' || status == _bookingStatusFilter;
      final bookedByOk =
          bookedByQuery.isEmpty || bookedBy.contains(bookedByQuery);
      final creatorOk = creatorQuery.isEmpty || creator.contains(creatorQuery);
      return (query.isEmpty || searchable.contains(query)) &&
          typeOk &&
          statusOk &&
          bookedByOk &&
          creatorOk;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 340,
                child: TextField(
                  onChanged: (value) =>
                      setState(() => _bookingHistorySearch = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search booking history...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  initialValue: _bookingTypeFilter,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'tour', child: Text('Tour')),
                    DropdownMenuItem(value: 'car', child: Text('Car')),
                  ],
                  onChanged: (value) =>
                      setState(() => _bookingTypeFilter = value ?? 'all'),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: _bookingStatusFilter,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(
                      value: 'confirmed',
                      child: Text('Confirmed'),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text('Cancelled'),
                    ),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  ],
                  onChanged: (value) =>
                      setState(() => _bookingStatusFilter = value ?? 'all'),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  onChanged: (value) =>
                      setState(() => _bookingBookedByFilter = value),
                  decoration: const InputDecoration(
                    labelText: 'Booked By',
                    hintText: 'Filter by booked by...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  onChanged: (value) =>
                      setState(() => _bookingCreatorFilter = value),
                  decoration: const InputDecoration(
                    labelText: 'Creator',
                    hintText: 'Filter by creator...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: _loadBookingHistory,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('#')),
                  DataColumn(label: Text('Service')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Booked By')),
                  DataColumn(label: Text('Creator')),
                  DataColumn(label: Text('Price')),
                  DataColumn(label: Text('Sale Price')),
                  DataColumn(label: Text('Total')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Action')),
                ],
                rows: filteredRows.map((row) {
                  final status = (row['status'] ?? '').toString().toLowerCase();
                  final actionEnabled = row['actionEnabled'] == true;
                  final dateValue = (row['bookingDate'] ?? '').toString();
                  String dateText = '-';
                  if (dateValue.isNotEmpty) {
                    try {
                      dateText = DateFormat(
                        'MMM dd, yyyy',
                      ).format(DateTime.parse(dateValue));
                    } catch (_) {}
                  }
                  final price = (row['price'] as num?)?.toDouble() ?? 0;
                  final salePrice = (row['salePrice'] as num?)?.toDouble() ?? 0;
                  final total = (row['total'] as num?)?.toDouble() ?? 0;

                  return DataRow(
                    cells: [
                      DataCell(Text('#${row['bookingId'] ?? '-'}')),
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Text(
                            (row['serviceName'] ?? '-').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          (row['moduleType'] ?? '-').toString().toUpperCase(),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Text(
                            (row['bookedBy'] ?? '-').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 140,
                          child: Text(
                            (row['creator'] ?? '-').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text('₱${price.toStringAsFixed(2)}')),
                      DataCell(Text('₱${salePrice.toStringAsFixed(2)}')),
                      DataCell(Text('₱${total.toStringAsFixed(2)}')),
                      DataCell(Text(dateText)),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'cancelled'
                                ? const Color(0xFFFEE2E2)
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            status.isEmpty ? 'unknown' : status,
                            style: TextStyle(
                              color: status == 'cancelled'
                                  ? const Color(0xFF991B1B)
                                  : const Color(0xFF166534),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        status == 'cancelled'
                            ? const Text(
                                'Cancelled',
                                style: TextStyle(color: Colors.grey),
                              )
                            : Tooltip(
                                message: actionEnabled
                                    ? 'Cancel this booking'
                                    : 'You can only cancel your own bookings',
                                child: TextButton(
                                  onPressed: actionEnabled
                                      ? () => _cancelBookingFromHistory(row)
                                      : null,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                  child: const Text('Cancel Booking'),
                                ),
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Showing ${filteredRows.length} booking(s)'),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _navBlue,
          ),
        ),
        const SizedBox(height: 16),
        ...children.map(
          (c) => Padding(padding: const EdgeInsets.only(bottom: 16), child: c),
        ),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon) {
    return TextFormField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 240,
      color: _sidebarBg,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Text(
                    (_profile?['firstName'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _str(
                          _profile?['businessName'] ??
                              _profile?['firstName'] ??
                              'User',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _str(_profile?['role'] ?? 'Member'),
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _sideItem(
            Icons.person,
            'My Profile',
            () => setState(() => _activeSection = _ProfileSection.profile),
            isActive: _activeSection == _ProfileSection.profile,
          ),
          _sideItem(
            Icons.history,
            'Booking History',
            _showBookingsHistory,
            isActive: _activeSection == _ProfileSection.bookingHistory,
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 12),
            _sideHeader('Admin'),
            _sideItem(
              Icons.dashboard_outlined,
              'Dashboard',
              () => _openAdminSection(AdminSection.dashboard),
              isActive:
                  _activeSection == _ProfileSection.admin &&
                  _adminSection == AdminSection.dashboard,
            ),
            _sideItem(
              Icons.people_outline,
              'Users',
              () => _openAdminSection(AdminSection.users),
              isActive:
                  _activeSection == _ProfileSection.admin &&
                  _adminSection == AdminSection.users,
            ),
            _sideItem(
              Icons.tour,
              'Tours',
              () => setState(() => _adminToursExpanded = !_adminToursExpanded),
              isActive: _adminToursExpanded,
            ),
            if (_adminToursExpanded) ...[
              _sideItem(
                Icons.list_alt,
                'All Tours',
                () => _openAdminSection(AdminSection.toursAll),
                isActive:
                    _activeSection == _ProfileSection.admin &&
                    _adminSection == AdminSection.toursAll,
                isSubItem: true,
              ),
              _sideItem(
                Icons.add_box_outlined,
                'Add Tour',
                () => _openAdminSection(AdminSection.toursAdd),
                isActive:
                    _activeSection == _ProfileSection.admin &&
                    _adminSection == AdminSection.toursAdd,
                isSubItem: true,
              ),
              _sideItem(
                Icons.category_outlined,
                'Categories',
                () => _openAdminSection(AdminSection.tourCategories),
                isActive:
                    _activeSection == _ProfileSection.admin &&
                    _adminSection == AdminSection.tourCategories,
                isSubItem: true,
              ),
              _sideItem(
                Icons.tune_outlined,
                'Attributes',
                () => _openAdminSection(AdminSection.tourAttributes),
                isActive:
                    _activeSection == _ProfileSection.admin &&
                    _adminSection == AdminSection.tourAttributes,
                isSubItem: true,
              ),
              _sideItem(
                Icons.event_available_outlined,
                'Availability',
                () => _openAdminSection(AdminSection.tourAvailability),
                isActive:
                    _activeSection == _ProfileSection.admin &&
                    _adminSection == AdminSection.tourAvailability,
                isSubItem: true,
              ),
              _sideItem(
                Icons.calendar_month_outlined,
                'Booking Calendar',
                () => _openAdminSection(AdminSection.tourBookingCalendar),
                isActive:
                    _activeSection == _ProfileSection.admin &&
                    _adminSection == AdminSection.tourBookingCalendar,
                isSubItem: true,
              ),
              _sideItem(
                Icons.restore_from_trash_outlined,
                'Recovery',
                () => _openAdminSection(AdminSection.tourRecovery),
                isActive:
                    _activeSection == _ProfileSection.admin &&
                    _adminSection == AdminSection.tourRecovery,
                isSubItem: true,
              ),
            ],
            _sideItem(
              Icons.directions_car_outlined,
              'Car Rental',
              () => setState(() => _adminCarsExpanded = !_adminCarsExpanded),
              isActive: _adminCarsExpanded,
            ),
            if (_adminCarsExpanded) ...[
              _sideItem(
                Icons.list_alt,
                'All Cars',
                () => _openAdminSection(AdminSection.carsAll),
                isActive:
                    _activeSection == _ProfileSection.admin &&
                    _adminSection == AdminSection.carsAll,
                isSubItem: true,
              ),
              _sideItem(
                Icons.add_box_outlined,
                'Add new car',
                () => _openAdminSection(AdminSection.carsAdd),
                isActive:
                    _activeSection == _ProfileSection.admin &&
                    _adminSection == AdminSection.carsAdd,
                isSubItem: true,
              ),
            ],
            _sideItem(
              Icons.chat_bubble_outline,
              'Chatbot Q&A',
              () => _openAdminSection(AdminSection.chatbot),
              isActive:
                  _activeSection == _ProfileSection.admin &&
                  _adminSection == AdminSection.chatbot,
            ),
            _sideItem(
              Icons.payments_outlined,
              'Revenues',
              () => _openAdminSection(AdminSection.revenues),
              isActive:
                  _activeSection == _ProfileSection.admin &&
                  _adminSection == AdminSection.revenues,
            ),
            _sideItem(
              Icons.assessment_outlined,
              'Reports',
              () => _openAdminSection(AdminSection.reports),
              isActive:
                  _activeSection == _ProfileSection.admin &&
                  _adminSection == AdminSection.reports,
            ),
            _sideItem(
              Icons.settings_outlined,
              'Settings',
              () => _openAdminSection(AdminSection.settings),
              isActive:
                  _activeSection == _ProfileSection.admin &&
                  _adminSection == AdminSection.settings,
            ),
          ],
          const Spacer(),
          _sideItem(Icons.logout, 'Log Out', _logout),
        ],
      ),
    );
  }

  Widget _sideHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _sideItem(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isActive = false,
    bool isSubItem = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: isSubItem ? 18 : 20),
      title: Text(
        label,
        style: TextStyle(color: Colors.white, fontSize: isSubItem ? 13 : 14),
      ),
      tileColor: isActive ? Colors.white.withOpacity(0.12) : Colors.transparent,
      dense: isSubItem,
      contentPadding: EdgeInsets.only(left: isSubItem ? 40 : 16, right: 16),
      onTap: onTap,
    );
  }
}
