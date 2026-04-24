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
import '../models/car_rental.dart';
import '../models/tour_booking.dart';
import 'package:intl/intl.dart';

const _navBlue = Color(0xFF1E3A5F);
const _primaryBlue = Color(0xFF2563EB);
const _sidebarBg = Color(0xFF1E3A5F);

enum _ProfileSection { profile, admin }

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final GlobalKey<AdminDashboardPageState> _adminKey = GlobalKey<AdminDashboardPageState>();
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
  _ProfileSection _activeSection = _ProfileSection.profile;
  AdminSection _adminSection = AdminSection.users;
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
      final results = await Future.wait([UserApi.getProfile(), UserApi.isAdmin()]);
      if (!mounted) return;
      final rawProfile = results[0] as Map<String, dynamic>;
      final resolvedProfile = _coerceProfile(rawProfile) ?? rawProfile;
      if (resolvedProfile.isNotEmpty && _looksLikeProfile(resolvedProfile)) {
        _profile = resolvedProfile;
        _fillFromProfile(resolvedProfile);
      }
      _isAdmin = results[1] as bool;
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
      if (resolved != null && resolved.isNotEmpty && _looksLikeProfile(resolved)) {
        _profile = resolved;
        _fillFromProfile(resolved);
      } else {
        await _loadProfile();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
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
                        errorBuilder: (_, _, _) => const Icon(Icons.directions_car, size: 60),
                      ),
                    ),
                    title: Text(booking.carTitle),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormat('MMM dd, yyyy').format(booking.startDate)} - ${DateFormat('MMM dd, yyyy').format(booking.endDate)}',
                        ),
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
                        errorBuilder: (_, _, _) => const Icon(Icons.card_travel, size: 60),
                      ),
                    ),
                    title: Text(booking.tourTitle),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormat('MMM dd, yyyy').format(booking.startDate)} - ${DateFormat('MMM dd, yyyy').format(booking.endDate)}',
                        ),
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

  void _openAdminSection(AdminSection section) {
    setState(() {
      _activeSection = _ProfileSection.admin;
      _adminSection = section;
    });
    _adminKey.currentState?.setSection(section);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                Expanded(
                  child: IndexedStack(
                    index: _activeSection == _ProfileSection.admin ? 1 : 0,
                    children: [
                      _buildProfileContent(),
                      _buildAdminContent(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _pageTitle() {
    if (_activeSection == _ProfileSection.profile) return 'Settings';
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
      case AdminSection.reports:
        return 'Reports';
      case AdminSection.settings:
        return 'Settings';
      case AdminSection.ratings:
        return 'Ratings';
    }
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(_pageTitle(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TravelHomePage())),
            icon: const Icon(Icons.home),
            label: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        initialValue: _country,
                        decoration: const InputDecoration(labelText: 'Country', border: OutlineInputBorder()),
                        items: ['Philippines', 'United States', 'United Kingdom', 'Japan', 'France']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
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
                        _str(_profile?['businessName'] ?? _profile?['firstName'] ?? 'User'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      Text(_str(_profile?['role'] ?? 'Member'), style: TextStyle(color: Colors.white70, fontSize: 12)),
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
          _sideItem(Icons.history, 'Booking History', _showBookingsHistory),
          if (_isAdmin) ...[
            const SizedBox(height: 12),
            _sideHeader('Admin'),
            _sideItem(
              Icons.people_outline,
              'Users',
              () => _openAdminSection(AdminSection.users),
              isActive: _activeSection == _ProfileSection.admin && _adminSection == AdminSection.users,
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
                isActive: _activeSection == _ProfileSection.admin && _adminSection == AdminSection.toursAll,
                isSubItem: true,
              ),
              _sideItem(
                Icons.add_box_outlined,
                'Add Tour',
                () => _openAdminSection(AdminSection.toursAdd),
                isActive: _activeSection == _ProfileSection.admin && _adminSection == AdminSection.toursAdd,
                isSubItem: true,
              ),
              _sideItem(
                Icons.category_outlined,
                'Categories',
                () => _openAdminSection(AdminSection.tourCategories),
                isActive: _activeSection == _ProfileSection.admin && _adminSection == AdminSection.tourCategories,
                isSubItem: true,
              ),
              _sideItem(
                Icons.tune_outlined,
                'Attributes',
                () => _openAdminSection(AdminSection.tourAttributes),
                isActive: _activeSection == _ProfileSection.admin && _adminSection == AdminSection.tourAttributes,
                isSubItem: true,
              ),
              _sideItem(
                Icons.event_available_outlined,
                'Availability',
                () => _openAdminSection(AdminSection.tourAvailability),
                isActive: _activeSection == _ProfileSection.admin && _adminSection == AdminSection.tourAvailability,
                isSubItem: true,
              ),
              _sideItem(
                Icons.calendar_month_outlined,
                'Booking Calendar',
                () => _openAdminSection(AdminSection.tourBookingCalendar),
                isActive: _activeSection == _ProfileSection.admin && _adminSection == AdminSection.tourBookingCalendar,
                isSubItem: true,
              ),
              _sideItem(
                Icons.restore_from_trash_outlined,
                'Recovery',
                () => _openAdminSection(AdminSection.tourRecovery),
                isActive: _activeSection == _ProfileSection.admin && _adminSection == AdminSection.tourRecovery,
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
                isActive: _activeSection == _ProfileSection.admin && _adminSection == AdminSection.carsAll,
                isSubItem: true,
              ),
              _sideItem(
                Icons.add_box_outlined,
                'Add new car',
                () => _openAdminSection(AdminSection.carsAdd),
                isActive: _activeSection == _ProfileSection.admin && _adminSection == AdminSection.carsAdd,
                isSubItem: true,
              ),
            ],
            _sideItem(
              Icons.chat_bubble_outline,
              'Chatbot Q&A',
              () => _openAdminSection(AdminSection.chatbot),
              isActive: _activeSection == _ProfileSection.admin && _adminSection == AdminSection.chatbot,
            ),
            _sideItem(
              Icons.assessment_outlined,
              'Reports',
              () => _openAdminSection(AdminSection.reports),
              isActive: _activeSection == _ProfileSection.admin && _adminSection == AdminSection.reports,
            ),
            _sideItem(
              Icons.settings_outlined,
              'Settings',
              () => _openAdminSection(AdminSection.settings),
              isActive: _activeSection == _ProfileSection.admin && _adminSection == AdminSection.settings,
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
        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
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
      title: Text(label, style: TextStyle(color: Colors.white, fontSize: isSubItem ? 13 : 14)),
      tileColor: isActive ? Colors.white.withOpacity(0.12) : Colors.transparent,
      dense: isSubItem,
      contentPadding: EdgeInsets.only(left: isSubItem ? 40 : 16, right: 16),
      onTap: onTap,
    );
  }
}
