import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_travel_agency/api/chatbot_api.dart';

import '../api/tours_api.dart';
import '../api/cars_api.dart';
import '../api/auth_api.dart';
import '../api/admin_api.dart';
import '../api/user_api.dart';
import '../api/api_client.dart';
import '../api/ratings_api.dart';
import '../api/reports_api.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter_travel_agency/features/admin/dashboard/admin_dashboard_shell.dart';
import 'package:flutter_travel_agency/features/admin/dashboard/admin_section.dart';
import 'package:flutter_travel_agency/features/admin/car_management/pages/car_form_page.dart';
import 'package:flutter_travel_agency/features/admin/car_management/pages/car_list_page.dart';
import 'package:flutter_travel_agency/features/admin/tour_management/pages/tour_admin_extra_pages.dart';
import 'package:flutter_travel_agency/features/admin/tour_management/pages/tour_form_page.dart';
import 'package:flutter_travel_agency/features/admin/tour_management/pages/tour_list_page.dart';

// ignore_for_file: unused_element

// Minimal admin dashboard with dark sidebar (Booking Core–style)
const _sidebarBg = Color(0xFF1E3A5F);
const _sidebarActive = Color(0xFF2C5282);
const _sidebarText = Colors.white;
const _sidebarTextMuted = Color(0xFFB0BEC5);

enum _ChatbotFilter { all, unanswered }

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    this.showSidebar = true,
    this.showHeader = true,
    this.showBackButton = true,
    this.initialSection,
  });

  final bool showSidebar;
  final bool showHeader;
  final bool showBackButton;
  final AdminSection? initialSection;

  @override
  State<AdminDashboardPage> createState() => AdminDashboardPageState();
}

class AdminDashboardPageState extends State<AdminDashboardPage> {
  AdminSection _current = AdminSection.dashboard;
  bool _toursExpanded = true;
  bool _carsExpanded = false;
  bool _isAdmin = false;
  bool _checkingAdmin = true;
  List<dynamic> _tours = [];
  List<dynamic> _cars = [];
  List<dynamic> _users = [];
  String? _currentUserId;
  bool _loading = true;
  bool _loadingUsers = false;
  String? _usersError;
  Map<String, dynamic> _reportsData = {};
  bool _loadingReports = false;
  List<dynamic> _chatQuestions = [];
  bool _loadingChatQuestions = false;
  String? _chatError;
  String _chatSearchQuery = '';
  _ChatbotFilter _chatFilter = _ChatbotFilter.all;
  List<dynamic> _ratings = [];
  bool _loadingRatings = false;
  String _toursSearchQuery = '';
  String _carsSearchQuery = '';
  bool _showToursAdvancedFilters = false;
  bool _showCarsAdvancedFilters = false;
  String _toursBulkAction = 'delete';
  String _carsBulkAction = 'delete';
  String _toursStatusFilter = 'all';
  String _carsStatusFilter = 'all';
  String _toursAuthorFilter = 'all';
  String _carsAuthorFilter = 'all';
  final Set<String> _selectedTourIds = {};
  final Set<String> _selectedCarIds = {};

  final GlobalKey<FormState> _settingsFormKey = GlobalKey<FormState>();
  final _adminFirstNameController = TextEditingController();
  final _adminLastNameController = TextEditingController();
  final _adminUsernameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  bool _creatingAdmin = false;
  String? _adminCreationError;

  @override
  void initState() {
    super.initState();
    if (widget.initialSection != null) {
      _current = widget.initialSection!;
      _expandForSection(_current);
    }
    _init();
  }

  Future<void> _init() async {
    final isAdmin = await UserApi.isAdmin();
    final userId = await ApiClient.instance.currentUserId;
    if (!mounted) return;

    if (!isAdmin) {
      setState(() {
        _isAdmin = false;
        _checkingAdmin = false;
        _loading = false;
      });
      return;
    }

    setState(() {
      _isAdmin = true;
      _checkingAdmin = false;
      _currentUserId = userId;
    });
    await _loadData();
  }

  List<dynamic> _getFilteredTours() {
    final query = _toursSearchQuery.toLowerCase().trim();
    return _tours.where((tour) {
      final m = tour as Map<String, dynamic>;
      final title = (m['title'] ?? m['name'] ?? '').toString().toLowerCase();
      final location =
          (m['realTourAddress'] ??
                  m['location'] ??
                  m['address'] ??
                  m['city'] ??
                  '')
              .toString()
              .toLowerCase();
      final author = (m['author'] ?? m['userName'] ?? m['username'] ?? '')
          .toString()
          .toLowerCase();
      if (query.isNotEmpty &&
          !(title.contains(query) ||
              location.contains(query) ||
              author.contains(query))) {
        return false;
      }
      if (_toursStatusFilter != 'all') {
        final status = (m['status'] ?? '').toString().toLowerCase();
        if (_toursStatusFilter == 'publish' && status == 'draft') return false;
        if (_toursStatusFilter == 'draft' && status != 'draft') return false;
      }
      if (_toursAuthorFilter != 'all') {
        final vendorValue = (m['vendor'] ?? '').toString().toLowerCase();
        final authorValue =
            (m['author'] ?? m['userName'] ?? m['username'] ?? '')
                .toString()
                .toLowerCase();
        final isVendor =
            vendorValue.isNotEmpty || authorValue.contains('vendor');
        final isAdmin =
            authorValue == 'admin' ||
            authorValue == 'administrator' ||
            authorValue.contains('admin');

        if (_toursAuthorFilter == 'vendor' && !isVendor) return false;
        if (_toursAuthorFilter == 'administrator' && !isAdmin) return false;
      }
      return true;
    }).toList();
  }

  List<dynamic> _getFilteredCars() {
    final query = _carsSearchQuery.toLowerCase().trim();
    return _cars.where((car) {
      final m = car as Map<String, dynamic>;
      final title = (m['title'] ?? m['name'] ?? '').toString().toLowerCase();
      final location =
          (m['realTourAddress'] ??
                  m['location'] ??
                  m['address'] ??
                  m['city'] ??
                  '')
              .toString()
              .toLowerCase();
      final author = (m['author'] ?? m['userName'] ?? '')
          .toString()
          .toLowerCase();
      if (query.isNotEmpty &&
          !(title.contains(query) ||
              location.contains(query) ||
              author.contains(query))) {
        return false;
      }
      if (_carsStatusFilter != 'all') {
        final status = (m['status'] ?? '').toString().toLowerCase();
        if (_carsStatusFilter == 'publish' && status == 'draft') return false;
        if (_carsStatusFilter == 'draft' && status != 'draft') return false;
      }
      if (_carsAuthorFilter != 'all') {
        final vendorValue = (m['vendor'] ?? '').toString().toLowerCase();
        final authorValue = (m['author'] ?? m['userName'] ?? '')
            .toString()
            .toLowerCase();
        final isVendor =
            vendorValue.isNotEmpty || authorValue.contains('vendor');
        final isAdmin =
            authorValue == 'admin' ||
            authorValue == 'administrator' ||
            authorValue.contains('admin');

        if (_carsAuthorFilter == 'vendor' && !isVendor) return false;
        if (_carsAuthorFilter == 'administrator' && !isAdmin) return false;
      }
      return true;
    }).toList();
  }

  void _toggleTourSelection(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedTourIds.add(id);
      } else {
        _selectedTourIds.remove(id);
      }
    });
  }

  void _toggleCarSelection(String id, bool selected) {
    setState(() {
      if (selected) {
        _selectedCarIds.add(id);
      } else {
        _selectedCarIds.remove(id);
      }
    });
  }

  void _selectAllTours(bool selected) {
    final ids = _getFilteredTours()
        .map((tour) => (tour['id']?.toString() ?? ''))
        .where((id) => id.isNotEmpty);
    setState(() {
      if (selected) {
        _selectedTourIds.addAll(ids);
      } else {
        _selectedTourIds.removeAll(ids);
      }
    });
  }

  void _selectAllCars(bool selected) {
    final ids = _getFilteredCars()
        .map((car) => (car['id']?.toString() ?? ''))
        .where((id) => id.isNotEmpty);
    setState(() {
      if (selected) {
        _selectedCarIds.addAll(ids);
      } else {
        _selectedCarIds.removeAll(ids);
      }
    });
  }

  void _removeToursByIds(Set<String> ids) {
    setState(() {
      _tours.removeWhere((tour) {
        final id = (tour['id']?.toString() ?? '');
        return ids.contains(id);
      });
      _selectedTourIds.removeAll(ids);
    });
  }

  void _removeCarsByIds(Set<String> ids) {
    setState(() {
      _cars.removeWhere((car) {
        final id = (car['id']?.toString() ?? '');
        return ids.contains(id);
      });
      _selectedCarIds.removeAll(ids);
    });
  }

  Future<void> _deleteSelectedTours() async {
    if (_selectedTourIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete selected tours'),
        content: Text(
          'Delete ${_selectedTourIds.length} selected tour(s) from the list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final removed = Set<String>.from(_selectedTourIds);
      _removeToursByIds(removed);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${removed.length} tour(s) removed.')),
      );
    }
  }

  Future<void> _deleteSelectedCars() async {
    if (_selectedCarIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete selected cars'),
        content: Text(
          'Delete ${_selectedCarIds.length} selected car(s) from the list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final removed = Set<String>.from(_selectedCarIds);
      _removeCarsByIds(removed);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${removed.length} car(s) removed.')),
      );
    }
  }

  Future<void> _confirmDeleteTour(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete tour'),
        content: const Text(
          'Are you sure you want to delete this tour? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _deleteTourFromList(id);
    }
  }

  void _deleteTourFromList(String id) {
    setState(() {
      _tours.removeWhere((tour) => (tour['id']?.toString() ?? '') == id);
      _selectedTourIds.remove(id);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Tour removed from list.')));
  }

  Future<void> _confirmDeleteCar(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete car'),
        content: const Text(
          'Are you sure you want to delete this car? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _deleteCarFromList(id);
    }
  }

  void _deleteCarFromList(String id) {
    setState(() {
      _cars.removeWhere((car) => (car['id']?.toString() ?? '') == id);
      _selectedCarIds.remove(id);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Car removed from list.')));
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
    });
    final tours = await ToursApi.list();
    final cars = await CarsApi.list();
    if (!mounted) return;
    setState(() {
      _tours = tours;
      _cars = cars;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AdminDashboardShell(
        showSidebar: widget.showSidebar,
        showHeader: widget.showHeader,
        showBackButton: widget.showBackButton,
        current: _current,
        toursExpanded: _toursExpanded,
        carsExpanded: _carsExpanded,
        sectionTitle: _sectionTitle(),
        onBack: () => Navigator.of(context).pop(),
        onSectionSelected: setSection,
        onToursToggle: () => setState(() => _toursExpanded = !_toursExpanded),
        onCarsToggle: () => setState(() => _carsExpanded = !_carsExpanded),
        child: _buildSectionContent(),
      ),
    );
  }

  void setSection(AdminSection section) {
    setState(() {
      _current = section;
      _expandForSection(section);
    });
    _loadForSection(section);
  }

  void _expandForSection(AdminSection section) {
    if (section == AdminSection.toursAll ||
        section == AdminSection.toursAdd ||
        section == AdminSection.tourCategories ||
        section == AdminSection.tourAttributes ||
        section == AdminSection.tourAvailability ||
        section == AdminSection.tourBookingCalendar ||
        section == AdminSection.tourRecovery) {
      _toursExpanded = true;
    }
    if (section == AdminSection.carsAll || section == AdminSection.carsAdd) {
      _carsExpanded = true;
    }
  }

  void _loadForSection(AdminSection section) {
    if (section == AdminSection.users) {
      _loadUsers();
    } else if (section == AdminSection.reports) {
      _loadReports();
    } else if (section == AdminSection.chatbot) {
      _loadChatQuestions();
    } else if (section == AdminSection.ratings) {
      _loadRatings();
    }
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: _sidebarBg,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Row(
              children: [
                Icon(Icons.dashboard, color: _sidebarText, size: 22),
                const SizedBox(width: 10),
                const Text(
                  'Admin',
                  style: TextStyle(
                    color: _sidebarText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          _sideItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            isActive: _current == AdminSection.dashboard,
            onTap: () => setState(() => _current = AdminSection.dashboard),
          ),
          _sideItem(
            icon: Icons.people_outline,
            label: 'Users',
            isActive: _current == AdminSection.users,
            onTap: () {
              setState(() => _current = AdminSection.users);
              _loadUsers();
            },
          ),
          const SizedBox(height: 8),
          _sideGroup(
            icon: Icons.tour,
            label: 'Tours',
            expanded: _toursExpanded,
            onToggle: () => setState(() => _toursExpanded = !_toursExpanded),
            children: [
              _sideSubItem(
                'All Tours',
                _current == AdminSection.toursAll,
                () => setState(() => _current = AdminSection.toursAll),
              ),
              _sideSubItem(
                'Add Tour',
                _current == AdminSection.toursAdd,
                () => setState(() => _current = AdminSection.toursAdd),
              ),
            ],
          ),
          _sideGroup(
            icon: Icons.directions_car_outlined,
            label: 'Car Rental',
            expanded: _carsExpanded,
            onToggle: () => setState(() => _carsExpanded = !_carsExpanded),
            children: [
              _sideSubItem(
                'All Cars',
                _current == AdminSection.carsAll,
                () => setState(() => _current = AdminSection.carsAll),
              ),
              _sideSubItem(
                'Add new car',
                _current == AdminSection.carsAdd,
                () => setState(() => _current = AdminSection.carsAdd),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _sideItem(
            icon: Icons.star_outline,
            label: 'Ratings',
            isActive: _current == AdminSection.ratings,
            onTap: () {
              setState(() => _current = AdminSection.ratings);
              _loadRatings();
            },
          ),
          _sideItem(
            icon: Icons.assessment_outlined,
            label: 'Reports',
            isActive: _current == AdminSection.reports,
            onTap: () {
              setState(() => _current = AdminSection.reports);
              _loadReports();
            },
          ),
          _sideItem(
            icon: Icons.chat_bubble_outline,
            label: 'Chatbot Q&A',
            isActive: _current == AdminSection.chatbot,
            onTap: () {
              setState(() => _current = AdminSection.chatbot);
              _loadChatQuestions();
            },
          ),
          _sideItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isActive: _current == AdminSection.settings,
            onTap: () => setState(() => _current = AdminSection.settings),
          ),
        ],
      ),
    );
  }

  Widget _sideItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isActive ? _sidebarActive : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: _sidebarText, size: 20),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: _sidebarText,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sideGroup({
    required IconData icon,
    required String label,
    required bool expanded,
    required VoidCallback onToggle,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: _sidebarText, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(color: _sidebarText, fontSize: 14),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    color: _sidebarTextMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded) ...children,
      ],
    );
  }

  Widget _sideSubItem(String label, bool isActive, VoidCallback onTap) {
    return Material(
      color: isActive ? _sidebarActive : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(52, 10, 20, 10),
          child: Row(
            children: [
              if (isActive)
                Container(
                  width: 3,
                  height: 16,
                  color: Colors.white,
                  margin: const EdgeInsets.only(right: 12),
                ),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? _sidebarText : _sidebarTextMuted,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _buildSectionContent(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (widget.showBackButton)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            )
          else
            const SizedBox(width: 40),
          const SizedBox(width: 8),
          Text(
            _sectionTitle(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _sectionTitle() {
    switch (_current) {
      case AdminSection.dashboard:
        return 'Dashboard';
      case AdminSection.users:
        return 'Users';
      case AdminSection.toursAll:
        return 'All Tours';
      case AdminSection.toursAdd:
        return 'Add new tour';
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
      case AdminSection.ratings:
        return 'Ratings';
      case AdminSection.chatbot:
        return 'Chatbot Q&A';
      case AdminSection.reports:
        return 'Reports';
      case AdminSection.settings:
        return 'Settings';
    }
  }

  Widget _buildSectionContent() {
    if (_checkingAdmin) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_isAdmin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Unauthorized',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('You do not have permission to view this page.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go back'),
            ),
          ],
        ),
      );
    }

    switch (_current) {
      case AdminSection.dashboard:
        return _buildDashboardContent();
      case AdminSection.users:
        return _buildUsersList();
      case AdminSection.toursAll:
        return _buildToursList();
      case AdminSection.toursAdd:
        return _buildTourForm();
      case AdminSection.tourCategories:
        return TourCategoriesPage(tours: _tours);
      case AdminSection.tourAttributes:
        return const TourAttributesPage();
      case AdminSection.tourAvailability:
        return TourAvailabilityCalendarPage(tours: _tours);
      case AdminSection.tourBookingCalendar:
        return const TourBookingCalendarPage();
      case AdminSection.tourRecovery:
        return const TourRecoveryPage();
      case AdminSection.carsAll:
        return _buildCarsList();
      case AdminSection.carsAdd:
        return _buildCarForm();
      case AdminSection.ratings:
        return _buildRatingsList();
      case AdminSection.chatbot:
        return _buildChatbotManager();
      case AdminSection.reports:
        return _buildReportsDashboard();
      case AdminSection.settings:
        return _buildSettingsContent();
    }
  }

  Widget _buildReportsDashboard() {
    if (_loadingReports) {
      return const Center(child: CircularProgressIndicator());
    }

    final toursData = _reportsData['tours'];
    final carsData = _reportsData['cars'];
    final bookingsData = _reportsData['bookings'];
    final locationsData = _reportsData['locations'];

    String count(dynamic v) {
      if (v == null) return '0';
      if (v is List) return v.length.toString();
      if (v is Map) return v.length.toString();
      return v.toString();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reports Overview',
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _statCard('Tours', count(toursData), Icons.tour),
            const SizedBox(width: 16),
            _statCard('Cars', count(carsData), Icons.directions_car),
            const SizedBox(width: 16),
            _statCard('Bookings', count(bookingsData), Icons.book_online),
            const SizedBox(width: 16),
            _statCard('Locations', count(locationsData), Icons.location_on),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Raw report data',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              _reportsData.entries
                  .map((e) {
                    final v = e.value;
                    if (v is List) return '${e.key}: ${v.length} items';
                    return '${e.key}: ${v ?? 'null'}';
                  })
                  .join('  •  '),
              style: TextStyle(color: Colors.grey[800]),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf, size: 24),
              label: const Text(
                'Generate PDF Report',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _sidebarBg,
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              onPressed: _loadingReports || _reportsData.isEmpty
                  ? null
                  : () => _generatePdfReport(context),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welcome to the admin dashboard.',
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _statCard('Tours', '${_tours.length}', Icons.tour),
            const SizedBox(width: 16),
            _statCard('Cars', '${_cars.length}', Icons.directions_car),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: _sidebarBg),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    if (_loadingUsers) return const Center(child: CircularProgressIndicator());
    if (_usersError != null) return Center(child: Text(_usersError!));
    if (_users.isEmpty) return const Center(child: Text('No users found.'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Role')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _users.map<DataRow>((u) {
            final m = u as Map<String, dynamic>;
            final id = m['id']?.toString() ?? '';
            final name = m['userName'] ?? m['username'] ?? '';
            final email = m['email'] ?? '';

            String role = '';
            final roleCandidates = [
              m['role'],
              m['roles'],
              m['roleName'],
              m['userType'],
              m['type'],
              m['role_id'],
              m['roleId'],
            ];
            for (final candidate in roleCandidates) {
              if (candidate == null) continue;
              if (candidate is String && candidate.isNotEmpty) {
                role = candidate;
                break;
              }
              if (candidate is List && candidate.isNotEmpty) {
                role = candidate.first.toString();
                break;
              }
            }

            role = role.toString().toLowerCase();
            if (role == 'customer') role = 'Customer';
            if (role == 'vendor') role = 'Vendor';
            if (role == 'administrator' || role == 'admin') {
              role = 'Administrator';
            }
            if (role.isEmpty) role = 'Unknown';

            final isSelf = id == _currentUserId;
                return DataRow(
                  cells: [
                    DataCell(Text(id)),
                    DataCell(Text(name?.toString() ?? '')),
                    DataCell(Text(email?.toString() ?? '')),
                    DataCell(Text(role)),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditUserDialog(m),
                            tooltip: 'Edit User',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: isSelf ? null : () => _deleteUser(id),
                            tooltip: isSelf
                                ? 'Cannot delete yourself'
                                : 'Delete User',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRatingsList() {
    if (_loadingRatings) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_ratings.isEmpty) return const Center(child: Text('No ratings yet.'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Module')),
                DataColumn(label: Text('Module ID')),
                DataColumn(label: Text('User')),
                DataColumn(label: Text('Stars')),
                DataColumn(label: Text('Comment')),
                DataColumn(label: Text('Actions')),
              ],
              rows: _ratings.map<DataRow>((r) {
                final m = r as Map<String, dynamic>;
                final id = m['id']?.toString() ?? '';
                final moduleType = m['moduleType']?.toString() ?? '';
                final moduleId = m['moduleId']?.toString() ?? '';
                final stars = m['stars']?.toString() ?? '';
                final comment = m['comment']?.toString() ?? '';

                String userName = '';
                final user = m['user'];
                if (user is Map<String, dynamic>) {
                  userName =
                      user['name']?.toString() ??
                      user['username']?.toString() ??
                      user['email']?.toString() ??
                      '';
                } else {
                  userName =
                      m['userName']?.toString() ?? m['username']?.toString() ?? '';
                }
                if (userName.isEmpty) userName = 'Unknown';
                return DataRow(
                  cells: [
                    DataCell(Text(id)),
                    DataCell(Text(moduleType)),
                    DataCell(Text(moduleId)),
                    DataCell(Text(userName)),
                    DataCell(Text(stars)),
                    DataCell(Text(comment.isEmpty ? 'No comment' : comment)),
                    DataCell(
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditRatingDialog(m),
                            tooltip: 'Edit Rating',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteRating(id),
                            tooltip: 'Delete Rating',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToursList() {
    final filteredTours = _getFilteredTours();
    return TourListPage(
      loading: _loading,
      tours: filteredTours,
      selectedIds: _selectedTourIds,
      showAdvancedFilters: _showToursAdvancedFilters,
      bulkAction: _toursBulkAction,
      authorFilter: _toursAuthorFilter,
      statusFilter: _toursStatusFilter,
      onSearchChanged: (value) => setState(() => _toursSearchQuery = value),
      onToggleAdvancedFilters: () => setState(
        () => _showToursAdvancedFilters = !_showToursAdvancedFilters,
      ),
      onBulkActionChanged: (value) => setState(() => _toursBulkAction = value),
      onAuthorFilterChanged: (value) => setState(() => _toursAuthorFilter = value),
      onStatusFilterChanged: (value) => setState(() => _toursStatusFilter = value),
      onApplyBulkAction: _deleteSelectedTours,
      onSelectAll: _selectAllTours,
      onToggleSelection: _toggleTourSelection,
      onClearSelection: () => setState(() => _selectedTourIds.clear()),
      onDeleteSelected: _deleteSelectedTours,
      onEdit: _showEditTourDialog,
      onDelete: _confirmDeleteTour,
    );
  }

  Widget _buildTourForm() {
    return TourFormPage(
      onCreated: () {
        setState(() => _current = AdminSection.toursAll);
        _loadData();
      },
    );
  }

  Widget _buildCarForm() {
    return CarFormPage(
      onCreated: () {
        setState(() => _current = AdminSection.carsAll);
        _loadData();
      },
      itemToEdit: null,
    );
  }

  Widget _buildCarsList() {
    final filteredCars = _getFilteredCars();
    return CarListPage(
      loading: _loading,
      cars: filteredCars,
      selectedIds: _selectedCarIds,
      showAdvancedFilters: _showCarsAdvancedFilters,
      bulkAction: _carsBulkAction,
      authorFilter: _carsAuthorFilter,
      statusFilter: _carsStatusFilter,
      onSearchChanged: (value) => setState(() => _carsSearchQuery = value),
      onToggleAdvancedFilters: () => setState(
        () => _showCarsAdvancedFilters = !_showCarsAdvancedFilters,
      ),
      onBulkActionChanged: (value) => setState(() => _carsBulkAction = value),
      onAuthorFilterChanged: (value) => setState(() => _carsAuthorFilter = value),
      onStatusFilterChanged: (value) => setState(() => _carsStatusFilter = value),
      onApplyBulkAction: _deleteSelectedCars,
      onSelectAll: _selectAllCars,
      onToggleSelection: _toggleCarSelection,
      onClearSelection: () => setState(() => _selectedCarIds.clear()),
      onDeleteSelected: _deleteSelectedCars,
      onEdit: _showEditCarDialog,
      onDelete: _confirmDeleteCar,
    );
  }

  Future<void> _showEditTourDialog(Map<String, dynamic> tour) async {
    final id = tour['id'];
    if (id == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading tour details...'),
          ],
        ),
      ),
    );
    try {
      final freshTour = await ToursApi.get(id);
      if (!mounted) return;
      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (context) {
          final size = MediaQuery.of(context).size;
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: size.width * 0.9,
                maxHeight: size.height * 0.9,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Edit Tour',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: TourFormPage(
                        onCreated: () async {
                          Navigator.of(context).pop();
                          await _loadData();
                        },
                        itemToEdit: freshTour,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load tour: $e')));
    }
  }

  Future<void> _showEditCarDialog(Map<String, dynamic> car) async {
    final id = car['id'];
    if (id == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Loading car details...'),
          ],
        ),
      ),
    );
    try {
      final freshCar = await CarsApi.get(id);
      if (!mounted) return;
      Navigator.of(context).pop();

      showDialog(
        context: context,
        builder: (context) {
          final size = MediaQuery.of(context).size;
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: size.width * 0.9,
                maxHeight: size.height * 0.9,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Edit Car',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: CarFormPage(
                        onCreated: () async {
                          Navigator.of(context).pop();
                          await _loadData();
                        },
                        itemToEdit: freshCar,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load car: $e')));
    }
  }

  Future<void> _loadReports() async {
    if (_loadingReports) return;
    setState(() {
      _loadingReports = true;
    });
    try {
      final results = await Future.wait([
        ReportsApi.tours(),
        ReportsApi.cars(),
        ReportsApi.bookings(),
        ReportsApi.locations(),
      ]);
      if (!mounted) return;
      setState(() {
        _reportsData = {
          'tours': results[0],
          'cars': results[1],
          'bookings': results[2],
          'locations': results[3],
        };
        _loadingReports = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingReports = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load reports: $e')));
      }
    }
  }

  Future<void> _loadChatQuestions() async {
    if (_loadingChatQuestions) return;
    setState(() {
      _loadingChatQuestions = true;
      _chatError = null;
    });
    try {
      final questions = await ChatbotApi.listQuestions();
      if (!mounted) return;
      setState(() {
        _chatQuestions = questions;
        _loadingChatQuestions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingChatQuestions = false;
        _chatError = e.toString();
      });
    }
  }

  Future<void> _openChatQuestionDialog({Map<String, dynamic>? existing}) async {
    final questionController = TextEditingController(
      text: existing?['question']?.toString() ?? '',
    );
    final answerController = TextEditingController(
      text: existing?['answer']?.toString() ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Add Q&A' : 'Edit Q&A'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: questionController,
                decoration: const InputDecoration(
                  labelText: 'Question',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: answerController,
                decoration: const InputDecoration(
                  labelText: 'Answer',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
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
    final question = questionController.text.trim();
    final answer = answerController.text.trim();
    if (question.isEmpty || answer.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question and answer are required.')),
      );
      return;
    }

    try {
      if (existing == null) {
        await ChatbotApi.createQuestion(question: question, answer: answer);
      } else {
        final id = existing['id']?.toString() ?? '';
        if (id.isEmpty) {
          throw Exception('Invalid question id');
        }
        await ChatbotApi.updateQuestion(id, question: question, answer: answer);
      }
      await _loadChatQuestions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existing == null ? 'Q&A added' : 'Q&A updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Widget _buildChatbotManager() {
    if (_loadingChatQuestions) {
      return const Center(child: CircularProgressIndicator());
    }

    final query = _chatSearchQuery.trim().toLowerCase();
    final filtered = _chatQuestions.where((item) {
      final map = item is Map
          ? Map<String, dynamic>.from(item)
          : <String, dynamic>{};
      final question = map['question']?.toString().toLowerCase() ?? '';
      final answer = map['answer']?.toString().toLowerCase() ?? '';
      if (_chatFilter == _ChatbotFilter.unanswered && answer.isNotEmpty) {
        return false;
      }
      if (query.isEmpty) return true;
      return question.contains(query) || answer.contains(query);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Chatbot Questions & Answers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              onPressed: _loadChatQuestions,
              tooltip: 'Refresh',
              icon: const Icon(Icons.refresh),
            ),
            ElevatedButton.icon(
              onPressed: () => _openChatQuestionDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Q&A'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => _chatSearchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search questions or answers',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _chatSearchQuery.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () =>
                              setState(() => _chatSearchQuery = ''),
                        ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<_ChatbotFilter>(
                initialValue: _chatFilter,
                decoration: const InputDecoration(
                  labelText: 'Filter',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(
                    value: _ChatbotFilter.all,
                    child: Text('All'),
                  ),
                  DropdownMenuItem(
                    value: _ChatbotFilter.unanswered,
                    child: Text('Unanswered'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _chatFilter = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_chatError != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              border: Border.all(color: const Color(0xFFFED7AA)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Failed to load Q&A: $_chatError'),
          ),
        if (filtered.isEmpty && _chatError == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _chatQuestions.isEmpty
                  ? 'No questions yet. Click "Add Q&A" to create the first one.'
                  : 'No results match your search.',
            ),
          )
        else
          ...filtered.map((item) {
            final map = item is Map
                ? Map<String, dynamic>.from(item)
                : <String, dynamic>{};
            final question = map['question']?.toString() ?? 'Untitled question';
            final answer = map['answer']?.toString() ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      question,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(answer.isEmpty ? 'No answer yet.' : answer),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              _openChatQuestionDialog(existing: map),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit'),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () => _deleteChatQuestion(map),
                          icon: const Icon(Icons.delete_outline, size: 16),
                          label: const Text('Delete'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _deleteChatQuestion(Map<String, dynamic> item) async {
    final id = item['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Q&A'),
        content: const Text('Are you sure you want to delete this question?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ChatbotApi.deleteQuestion(id);
      await _loadChatQuestions();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Q&A deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _generatePdfReport(BuildContext context) async {
    setState(() => _loadingReports = true);
    try {
      final profile = await UserApi.getProfile();
      final userName =
          profile['userName'] ??
          profile['username'] ??
          profile['firstName'] ??
          'Admin';
      final userEmail = profile['email'] ?? 'admin@example.com';
      final now = DateTime.now();
      final formatter = DateFormat('MMMM dd, yyyy \'at\' h:mm a');
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1E3A5F'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'Travelista Adventures Reports',
                      style: pw.TextStyle(
                        fontSize: 28,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'Comprehensive Dashboard Summary',
                      style: pw.TextStyle(
                        fontSize: 16,
                        color: PdfColors.grey200,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Container(
                margin: const pw.EdgeInsets.symmetric(horizontal: 40),
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Text(
                          'Printed by: $userName',
                          style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          userEmail,
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Generated: ${formatter.format(now)}',
                          style: pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: _buildPdfStatCards(_reportsData),
              ),
              pw.SizedBox(height: 30),
              ..._buildPdfDataTables(_reportsData),
              pw.Spacer(),
              pw.Container(
                alignment: pw.Alignment.center,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border(
                    top: pw.BorderSide(color: PdfColors.grey300),
                  ),
                ),
                child: pw.Text(
                  'Page ${context.pageNumber} | Travel Agency Admin System v1.0',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                ),
              ),
            ],
          ),
        ),
      );
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'travel-agency-reports-${DateFormat('yyyy-MM-dd-HHmmss').format(now)}.pdf',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF report generated and shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _loadingReports = false);
      }
    }
  }

  List<pw.Widget> _buildPdfStatCards(Map<String, dynamic> data) {
    final stats = {
      'Tours': data['tours'],
      'Cars': data['cars'],
      'Bookings': data['bookings'],
      'Locations': data['locations'],
    };
    return stats.entries.map((e) {
      final count = _pdfCount(e.value);
      return pw.Container(
        width: 120,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#3B82F6'),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              e.key,
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.white),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '$count',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  List<pw.Widget> _buildPdfDataTables(Map<String, dynamic> data) {
    final sections = ['tours', 'cars', 'bookings', 'locations'];
    return sections
        .map((key) {
          final items = data[key];
          final rows = _extractTableRows(items ?? []);
          if (rows.isEmpty) return pw.SizedBox.shrink();

          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '${key.toUpperCase()} (${rows.length})',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400),
                  defaultColumnWidth: const pw.FlexColumnWidth(),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromHex('#1E3A5F'),
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'ID',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Title/Name',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Price',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                            'Status',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...rows.asMap().entries.take(20).map((entry) {
                      final row = rows[entry.key];
                      return pw.TableRow(
                        decoration: pw.BoxDecoration(
                          color: entry.key % 2 == 0
                              ? PdfColors.white
                              : PdfColors.grey50,
                        ),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              row.id.toString(),
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              row.title ?? '',
                              style: const pw.TextStyle(fontSize: 11),
                              maxLines: 2,
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              row.price ?? '-',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text(
                              row.status ?? '-',
                              style: const pw.TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ),
          );
        })
        .where((w) => w != pw.SizedBox.shrink())
        .toList();
  }

  int _pdfCount(dynamic data) {
    if (data == null) return 0;
    if (data is List) return data.length;
    if (data is Map) return data.length;
    return 1;
  }

  List<({int id, String? title, String? price, String? status})>
  _extractTableRows(dynamic data) {
    final List<({int id, String? title, String? price, String? status})> rows =
        [];
    if (data is List) {
      for (int i = 0; i < data.length; i++) {
        final item = data[i];
        if (item is Map<String, dynamic>) {
          final id = item['id'] ?? i;
          rows.add((
            id: id is int ? id : (id?.hashCode ?? i),
            title: item['title'] ?? item['name'] ?? item['userName'] ?? '-',
            price: '\u20B1${item['price'] ?? item['salePrice'] ?? '-'}',
            status: item['status']?.toString() ?? '-',
          ));
        }
      }
    }
    return rows;
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loadingUsers = true;
      _usersError = null;
    });
    try {
      final users = await AdminApi.listUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _usersError = e is ApiException
            ? 'Error ${e.statusCode}: ${e.message}'
            : e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingUsers = false;
        });
      }
    }
  }

  Future<void> _loadRatings() async {
    if (_loadingRatings) return;
    setState(() {
      _loadingRatings = true;
    });
    try {
      final ratings = await RatingsApi.list();
      if (!mounted) return;
      setState(() {
        _ratings = ratings;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load ratings: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingRatings = false;
        });
      }
    }
  }

  Future<void> _deleteUser(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return AlertDialog(
          title: const Text('Delete User'),
          content: const Text('Are you sure you want to delete this user?'),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => navigator.pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
    if (confirm != true) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await AdminApi.deleteUser(id);
      _loadUsers();
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('User deleted')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Error deleting user: $e')),
      );
    }
  }

  Future<void> _deleteRating(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rating'),
        content: const Text('Are you sure you want to delete this rating?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await RatingsApi.delete(int.parse(id));
      _loadRatings();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Rating deleted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting rating: $e')));
    }
  }

  String _normalizeRoleForDropdown(String? role) {
    if (role == null) return '';
    switch (role.toLowerCase()) {
      case 'user':
      case 'customer':
        return 'customer';
      case 'admin':
      case 'administrator':
        return 'administrator';
      case 'vendor':
        return 'vendor';
      default:
        return 'customer';
    }
  }

  void _showEditUserDialog(Map<String, dynamic> user) {
    final firstName = TextEditingController(
      text: user['firstName']?.toString() ?? '',
    );
    final lastName = TextEditingController(
      text: user['lastName']?.toString() ?? '',
    );
    final email = TextEditingController(text: user['email']?.toString() ?? '');
    final username = TextEditingController(
      text: user['userName']?.toString() ?? user['username']?.toString() ?? '',
    );
    String rawRole = '';
    final roleCandidates = [
      user['role'],
      user['roles'],
      user['roleName'],
      user['userType'],
      user['type'],
      user['role_id'],
      user['roleId'],
    ];
    for (final candidate in roleCandidates) {
      if (candidate == null) continue;
      if (candidate is String && candidate.isNotEmpty) {
        rawRole = candidate;
        break;
      }
      if (candidate is List && candidate.isNotEmpty) {
        rawRole = candidate.first.toString();
        break;
      }
    }

    String role = _normalizeRoleForDropdown(rawRole);
    showDialog<void>(
      context: context,
      builder: (context) {
        final dialogNavigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);

        return AlertDialog(
          title: const Text('Edit User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: firstName,
                  decoration: const InputDecoration(labelText: 'First name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lastName,
                  decoration: const InputDecoration(labelText: 'Last name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: username,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role.isEmpty ? null : role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(
                      value: 'customer',
                      child: Text('Customer'),
                    ),
                    DropdownMenuItem(value: 'vendor', child: Text('Vendor')),
                    DropdownMenuItem(
                      value: 'administrator',
                      child: Text('Administrator'),
                    ),
                  ],
                  onChanged: (v) => role = v ?? role,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => dialogNavigator.pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final body = {
                    'firstName': firstName.text.trim(),
                    'lastName': lastName.text.trim(),
                    'username': username.text.trim(),
                    'email': email.text.trim(),
                    if (role.isNotEmpty) 'role': role,
                  };
                  await AdminApi.updateUser(user['id'].toString(), body);
                  if (!mounted) return;
                  dialogNavigator.pop();
                  _loadUsers();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('User updated')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error updating user: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditRatingDialog(Map<String, dynamic> rating) {
    final starsController = TextEditingController(
      text: rating['stars']?.toString() ?? '5',
    );
    final commentController = TextEditingController(
      text: rating['comment']?.toString() ?? '',
    );
    showDialog<void>(
      context: context,
      builder: (context) {
        final dialogNavigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);

        return AlertDialog(
          title: const Text('Edit Rating'),
          content: SingleChildScrollView(
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
              onPressed: () => dialogNavigator.pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final stars = int.tryParse(starsController.text.trim());
                if (stars == null || stars < 1 || stars > 5) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text('Stars must be an integer from 1 to 5'),
                    ),
                  );
                  return;
                }

                try {
                  await RatingsApi.update(
                    int.parse(rating['id'].toString()),
                    stars: stars,
                    comment: commentController.text.trim(),
                  );
                  if (!mounted) return;
                  dialogNavigator.pop();
                  _loadRatings();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Rating updated')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error updating rating: $e')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsContent() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 24),
          child: Text(
            'Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildSettingsMenuItem(
              icon: Icons.person_add,
              title: 'Create Administrator Account',
              description: 'Add a new administrator user to the system',
              onTap: _showCreateAdminDialog,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsMenuItem({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 24, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  void _showCreateAdminDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Administrator Account'),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Form(
              key: _settingsFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 16),
                  if (_adminCreationError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        _adminCreationError!,
                        style: TextStyle(color: Colors.red.shade800),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _adminFirstNameController,
                          decoration: const InputDecoration(
                            labelText: 'First name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _adminLastNameController,
                          decoration: const InputDecoration(
                            labelText: 'Last name *',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Required'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _adminUsernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _adminEmailController,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _adminPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Password *',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) => value == null || value.length < 6
                        ? 'At least 6 characters'
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _creatingAdmin
                ? null
                : () {
                    _settingsFormKey.currentState?.reset();
                    _adminFirstNameController.clear();
                    _adminLastNameController.clear();
                    _adminUsernameController.clear();
                    _adminEmailController.clear();
                    _adminPasswordController.clear();
                    setState(() => _adminCreationError = null);
                    Navigator.of(context).pop();
                  },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _creatingAdmin
                ? null
                : () => _submitCreateAdministrator(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: _creatingAdmin
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitCreateAdministrator(BuildContext dialogContext) async {
    if (!_settingsFormKey.currentState!.validate()) {
      setState(() {
        _adminCreationError = 'Please fill in all required fields correctly.';
      });
      return;
    }
    setState(() {
      _adminCreationError = null;
      _creatingAdmin = true;
    });
    try {
      await AuthApi.register(
        firstName: _adminFirstNameController.text.trim(),
        lastName: _adminLastNameController.text.trim(),
        username: _adminUsernameController.text.trim(),
        email: _adminEmailController.text.trim(),
        password: _adminPasswordController.text,
        role: 'administrator',
      );

      if (!mounted) return;

      _adminFirstNameController.clear();
      _adminLastNameController.clear();
      _adminUsernameController.clear();
      _adminEmailController.clear();
      _adminPasswordController.clear();

      Navigator.of(dialogContext).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Administrator account created successfully.'),
          backgroundColor: Colors.green,
        ),
      );
      _loadUsers();

      setState(() {
        _creatingAdmin = false;
        _adminCreationError = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _adminCreationError = 'Error ${e.statusCode}: ${e.message}';
          _creatingAdmin = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _adminCreationError = 'Failed to create admin: $e';
          _creatingAdmin = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _adminFirstNameController.dispose();
    _adminLastNameController.dispose();
    _adminUsernameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }
}

// --- FORM WIDGETS ---

class _ContentTextEditor extends StatefulWidget {
  const _ContentTextEditor({
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  State<_ContentTextEditor> createState() => _ContentTextEditorState();
}

class _ContentTextEditorState extends State<_ContentTextEditor> {
  late QuillController _quillController;

  @override
  void initState() {
    super.initState();
    final document = Document.fromJson(
      _parseJsonFromText(widget.controller.text),
    );
    _quillController = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    // Sync Quill to TextEditingController
    _quillController.document.changes.listen((event) {
      final delta = _quillController.document.toDelta();
      widget.controller.text = jsonEncode(delta.toJson());
    });
  }

  List<dynamic> _parseJsonFromText(String text) {
    if (text.isEmpty)
      return [
        {"insert": "\n"},
      ];
    try {
      final parsed = jsonDecode(text);
      if (parsed is List) return parsed;
    } catch (e) {
      // Ignore parse errors
    }
    return [
      {"insert": text},
      {"insert": "\n"},
    ];
  }

  @override
  void dispose() {
    _quillController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  border: Border(
                    bottom: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: QuillSimpleToolbar(controller: _quillController),
              ),
              SizedBox(
                height: 300,
                child: QuillEditor.basic(controller: _quillController),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

