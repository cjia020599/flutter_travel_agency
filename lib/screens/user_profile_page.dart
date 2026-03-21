import 'package:flutter/material.dart';
import '../api/user_api.dart';
import '../api/auth_api.dart';
import '../api/api_client.dart';
import 'login_page.dart';
import 'home_page.dart';
import 'admin_dashboard_page.dart';
import '../api/car_rentals_api.dart';
import '../api/tour_bookings_api.dart';
import '../models/car_rental.dart';
import '../models/tour_booking.dart';
import 'package:intl/intl.dart';

const _navBlue = Color(0xFF1E3A5F);
const _primaryBlue = Color(0xFF2563EB);
const _sidebarBg = Color(0xFF1E3A5F);

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
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
      final results = await Future.wait([UserApi.getProfile(), UserApi.isAdmin()]);
      if (!mounted) return;
      _profile = results[0] as Map<String, dynamic>;
      _isAdmin = results[1] as bool;
      _fillFromProfile(_profile!);
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
      await UserApi.updateProfile({
        'businessName': _businessName.text.trim(),
        'userName': _username.text.trim(),
        'email': _email.text.trim(),
        'firstName': _firstName.text.trim(),
        'lastName': _lastName.text.trim(),
        'phoneNumber': _phone.text.trim(),
        'birthday': _birthday.text.trim(),
        'bio': _about.text.trim(),
        'address': _address1.text.trim(),
        'address2': _address2.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'country': _country ?? '',
        'zipCode': _zipCode.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _loadBookings() async {
    try {
      _rentals = await CarRentalsApi.getCarRentals();
      _tourBookings = await TourBookingsApi.getMyBookings();
      setState(() {});
    } catch (e) {
      print('Error loading bookings: $e');
    }
  }

  Future<void> _showBookingsHistory() async {
    await _loadBookings();
    final allBookings = [..._rentals, ..._tourBookings];
    if (allBookings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No bookings found')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Booking History'),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: ListView.builder(
            itemCount: allBookings.length,
            itemBuilder: (context, index) {
              final booking = allBookings[index];
              if (booking is CarRental) {
                return Card(
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        booking.carImageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, size: 60),
                      ),
                    ),
                    title: Text(booking.carTitle),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${DateFormat('MMM dd, yyyy').format(booking.startDate)} - ${DateFormat('MMM dd, yyyy').format(booking.endDate)}'),
                        Text('Car Rental', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                    trailing: booking.status != 'cancelled'
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
                                final success = await CarRentalsApi.cancelRental(booking.id);
                                if (success && mounted) {
                                  Navigator.pop(context);
                                  _showBookingsHistory();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Car rental cancelled')),
                                  );
                                }
                              }
                            },
                          )
                        : const Text('Cancelled', style: TextStyle(color: Colors.grey)),
                  ),
                );
              } else if (booking is TourBooking) {
                return Card(
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        booking.tourImageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.card_travel, size: 60),
                      ),
                    ),
                    title: Text(booking.tourTitle),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${DateFormat('MMM dd, yyyy').format(booking.startDate)} - ${DateFormat('MMM dd, yyyy').format(booking.endDate)}'),
                        Text('Tour Booking', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      ],
                    ),
                    trailing: booking.status != 'cancelled'
                        ? IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirm Cancel'),
                                  content: const Text('Are you sure you want to cancel this tour booking? This action cannot be undone.'),
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
                                final success = await TourBookingsApi.cancelBooking(booking.id);
                                if (success && mounted) {
                                  Navigator.pop(context);
                                  _showBookingsHistory();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Tour booking cancelled')),
                                  );
                                }
                              }
                            },
                          )
                        : const Text('Cancelled', style: TextStyle(color: Colors.grey)),
                  ),
                );
              }
              return const SizedBox.shrink();
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

  Future<void> _logout() async {
    await AuthApi.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const TravelHomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _navBlue)),
                              Row(
                                children: [
                                  if (_isAdmin)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: ElevatedButton.icon(
                                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminDashboardPage())),
                                        icon: const Icon(Icons.admin_panel_settings),
                                        label: const Text('Admin Dashboard'),
                                        style: ElevatedButton.styleFrom(backgroundColor: _sidebarBg, foregroundColor: Colors.white),
                                      ),
                                    ),
                                  TextButton.icon(
                                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TravelHomePage())),
                                    icon: const Icon(Icons.home),
                                    label: const Text('Back to Home'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Text(_error!, style: TextStyle(color: Colors.red.shade800)),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _section(
                                  'Personal Information',
                                  [
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
                                      decoration: const InputDecoration(labelText: 'About Yourself', border: OutlineInputBorder(), alignLabelWithHint: true),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                child: _section(
                                  'Location Information',
                                  [
                                    _field(_address1, 'Address Line 1', Icons.location_on),
                                    _field(_address2, 'Address Line 2', Icons.location_on),
                                    _field(_city, 'City', Icons.location_city),
                                    _field(_state, 'State', Icons.flag),
                                    DropdownButtonFormField<String>(
                                      value: _country,
                                      decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
                                      items: ['Philippines', 'United States', 'United Kingdom', 'Japan', 'France'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                      onChanged: (v) => setState(() => _country = v),
                                    ),
                                    _field(_zipCode, 'Zip Code', Icons.pin_drop),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14)),
                            child: const Text('Save Changes'),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _navBlue)),
        const SizedBox(height: 16),
        ...children.map((c) => Padding(padding: const EdgeInsets.only(bottom: 16), child: c)),
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
                CircleAvatar(backgroundColor: Colors.white24, child: Text((_profile?['firstName'] ?? 'U')[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_str(_profile?['businessName'] ?? _profile?['firstName'] ?? 'User'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(_str(_profile?['role'] ?? 'Member'), style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _sideItem(Icons.dashboard, 'Dashboard', () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const TravelHomePage()), (r) => false)),
          _sideItem(Icons.person, 'My Profile', () {}),
          _sideItem(Icons.history, 'Booking History', _showBookingsHistory),
          const Spacer(),
          _sideItem(Icons.logout, 'Log Out', _logout),
        ],
      ),
    );
  }

  Widget _sideItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 20),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      onTap: onTap,
    );
  }
}
