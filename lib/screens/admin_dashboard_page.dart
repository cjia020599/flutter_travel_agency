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

enum _ReportRange { daily, weekly, monthly, yearly, custom }

enum _RevenueRange { overall, daily, weekly, monthly, yearly, custom }

typedef _ReportLine = ({
  String serviceName,
  String status,
  int pax,
  double price,
  double salePrice,
  double total,
  double tax,
  DateTime? bookedAt,
});

typedef _ReportSnapshot = ({
  _ReportRange range,
  String rangeLabel,
  String periodLabel,
  List<_ReportLine> lines,
  ({double amount, double tax, double total}) totals,
  double taxRate,
});

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
  String _currentUserDisplayName = 'Admin';
  bool _loading = true;
  bool _loadingUsers = false;
  String? _usersError;
  Map<String, dynamic> _reportsData = {};
  bool _loadingReports = false;
  Map<String, dynamic> _dashboardData = {};
  bool _loadingDashboard = false;
  Map<String, dynamic> _revenuesData = {};
  bool _loadingRevenues = false;
  _RevenueRange _selectedRevenueRange = _RevenueRange.overall;
  DateTimeRange? _customRevenueDateRange;
  List<dynamic> _chatQuestions = [];
  bool _loadingChatQuestions = false;
  String? _chatError;
  String _chatSearchQuery = '';
  _ChatbotFilter _chatFilter = _ChatbotFilter.all;
  List<dynamic> _ratings = [];
  bool _loadingRatings = false;
  List<dynamic> _bookingHistoryRows = [];
  bool _loadingBookingHistory = false;
  String _bookingHistorySearch = '';
  String _bookingTypeFilter = 'all';
  String _bookingStatusFilter = 'all';
  _ReportRange _selectedReportRange = _ReportRange.daily;
  DateTimeRange? _customReportDateRange;
  String _toursSearchQuery = '';
  String _carsSearchQuery = '';
  final TextEditingController _usersSearchController = TextEditingController();
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
    String displayName = 'Admin';
    try {
      final profile = await UserApi.getProfile();
      final firstName = (profile['firstName'] ?? '').toString().trim();
      final username = (profile['userName'] ?? profile['username'] ?? '')
          .toString()
          .trim();
      if (firstName.isNotEmpty) {
        displayName = firstName;
      } else if (username.isNotEmpty) {
        displayName = username;
      }
    } catch (_) {
      // Keep default display name if profile fetch fails.
    }
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
      _currentUserDisplayName = displayName;
    });
    await Future.wait([_loadData(), _loadDashboard()]);
    if (!mounted) return;
    if (_current != AdminSection.dashboard) {
      _loadForSection(_current);
    }
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
    if (section == AdminSection.dashboard) {
      _loadDashboard();
    } else if (section == AdminSection.users) {
      _loadUsers();
    } else if (section == AdminSection.revenues) {
      _loadRevenues();
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
            icon: Icons.payments_outlined,
            label: 'Revenues',
            isActive: _current == AdminSection.revenues,
            onTap: () {
              setState(() => _current = AdminSection.revenues);
              _loadRevenues();
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
      case AdminSection.revenues:
        return 'Revenues';
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
      case AdminSection.revenues:
        return _buildRevenuesContent();
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
    final report = _buildActiveReportSnapshot(bookingsData);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 760;
    final isDesktop = width >= 1180;
    final isWideDesktop = width >= 1320;
    final chips = _ReportRange.values.map((range) {
      return ChoiceChip(
        label: Text(_reportRangeLabel(range)),
        selected: _selectedReportRange == range,
        onSelected: (_) async {
          if (range == _ReportRange.custom) {
            final picked = await _pickCustomReportDateRange();
            if (!mounted || picked == null) return;
            setState(() {
              _customReportDateRange = picked;
              _selectedReportRange = _ReportRange.custom;
            });
            return;
          }
          setState(() => _selectedReportRange = range);
        },
        selectedColor: _sidebarBg.withOpacity(0.16),
        labelStyle: TextStyle(
          color: _selectedReportRange == range ? _sidebarBg : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
      );
    }).toList();

    String count(dynamic v) {
      if (v == null) return '0';
      if (v is Map && v['items'] is List) {
        return (v['items'] as List).length.toString();
      }
      if (v is List) return v.length.toString();
      if (v is Map) return v.length.toString();
      return v.toString();
    }

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Travelista Adventures Sales Report',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                '${_reportRangeLabel(_selectedReportRange)} view',
                style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 4),
              Text(
                report.periodLabel,
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
              if (_selectedReportRange == _ReportRange.custom) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pickCustomReportDateRange();
                    if (!mounted || picked == null) return;
                    setState(() => _customReportDateRange = picked);
                  },
                  icon: const Icon(Icons.date_range),
                  label: const Text('Change custom date span'),
                ),
              ],
              const SizedBox(height: 16),
              if (isDesktop)
                Row(
                  children: [
                    Expanded(
                      child: _statCard('Tours', count(toursData), Icons.tour),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        'Cars',
                        count(carsData),
                        Icons.directions_car,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        'Bookings',
                        count(bookingsData),
                        Icons.book_online,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _statCard(
                        'Locations',
                        count(locationsData),
                        Icons.location_on,
                      ),
                    ),
                  ],
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = isMobile
                        ? constraints.maxWidth
                        : ((constraints.maxWidth - 12) / 2).clamp(220.0, 520.0);
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: _statCard(
                            'Tours',
                            count(toursData),
                            Icons.tour,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _statCard(
                            'Cars',
                            count(carsData),
                            Icons.directions_car,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _statCard(
                            'Bookings',
                            count(bookingsData),
                            Icons.book_online,
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: _statCard(
                            'Locations',
                            count(locationsData),
                            Icons.location_on,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 18),
              if (isWideDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 400,
                      child: _buildReportsSummaryPanel(report, desktop: true),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _buildReportsDetailsTable(report)),
                  ],
                )
              else ...[
                _buildReportsSummaryPanel(report, desktop: !isMobile),
                const SizedBox(height: 12),
                _buildReportsDetailsTable(report),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(
                    'Generate ${_reportRangeLabel(_selectedReportRange)} PDF Report',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _sidebarBg,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _loadingReports || _reportsData.isEmpty
                      ? null
                      : () => _generatePdfReport(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (_loadingDashboard && _dashboardData.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final metrics =
        (_dashboardData['metrics'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final chart =
        (_dashboardData['chart'] as List?)?.cast<dynamic>() ?? const [];
    final recentBookings =
        (_dashboardData['recentBookings'] as List?)?.cast<dynamic>() ??
        const [];
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 1100;
    final isMobile = width < 700;
    final cards = [
      _dashboardMetricCard(
        label: 'Revenue',
        value: _formatPeso((metrics['revenue'] as num?)?.toDouble() ?? 0),
        subtitle: 'Total revenue',
        icon: Icons.shopping_cart_checkout,
        color: const Color(0xFF7C8CE6),
      ),
      _dashboardMetricCard(
        label: 'Earning',
        value: _formatPeso((metrics['earning'] as num?)?.toDouble() ?? 0),
        subtitle: 'Total earning',
        icon: Icons.card_giftcard,
        color: const Color(0xFFEC6BA7),
      ),
      _dashboardMetricCard(
        label: 'Bookings',
        value: '${metrics['bookings'] ?? 0}',
        subtitle: 'Total bookings',
        icon: Icons.book_online,
        color: const Color(0xFF44C0E8),
      ),
      _dashboardMetricCard(
        label: 'Services',
        value: '${metrics['services'] ?? 0}',
        subtitle: 'Total bookable services',
        icon: Icons.bolt,
        color: const Color(0xFF73CB5C),
      ),
    ];

    return Container(
      width: double.infinity,
      color: const Color(0xFFF3F4F8),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome $_currentUserDisplayName',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          if (isNarrow)
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = isMobile
                    ? constraints.maxWidth
                    : ((constraints.maxWidth - 12) / 2).clamp(220.0, 420.0);
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards
                      .map((card) => SizedBox(width: cardWidth, child: card))
                      .toList(),
                );
              },
            )
          else
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
                const SizedBox(width: 12),
                Expanded(child: cards[2]),
                const SizedBox(width: 12),
                Expanded(child: cards[3]),
              ],
            ),
          const SizedBox(height: 14),
          if (isNarrow) ...[
            _dashboardChartCard(chart),
            const SizedBox(height: 14),
            _dashboardRecentBookingsCard(recentBookings),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _dashboardChartCard(chart, panelHeight: 360)),
                const SizedBox(width: 14),
                Expanded(
                  child: _dashboardRecentBookingsCard(
                    recentBookings,
                    panelHeight: 360,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _revenueRangeLabel(_RevenueRange range) {
    switch (range) {
      case _RevenueRange.overall:
        return 'Overall';
      case _RevenueRange.daily:
        return 'Daily';
      case _RevenueRange.weekly:
        return 'Weekly';
      case _RevenueRange.monthly:
        return 'Monthly';
      case _RevenueRange.yearly:
        return 'Yearly';
      case _RevenueRange.custom:
        return 'Custom';
    }
  }

  Future<DateTimeRange?> _pickCustomRevenueDateRange() async {
    final now = DateTime.now();
    final initial =
        _customRevenueDateRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);
    DateTime start = initial.start;
    DateTime end = initial.end;

    return showDialog<DateTimeRange>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          Future<void> pickStart() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: start,
              firstDate: DateTime(2020),
              lastDate: DateTime(now.year + 1, 12, 31),
            );
            if (picked == null) return;
            setLocalState(() {
              start = DateTime(picked.year, picked.month, picked.day);
              if (end.isBefore(start)) end = start;
            });
          }

          Future<void> pickEnd() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: end,
              firstDate: DateTime(2020),
              lastDate: DateTime(now.year + 1, 12, 31),
            );
            if (picked == null) return;
            setLocalState(() {
              end = DateTime(picked.year, picked.month, picked.day);
              if (end.isBefore(start)) start = end;
            });
          }

          return AlertDialog(
            title: const Text('Select custom revenue date span'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: pickStart,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    'Start: ${DateFormat('MMM dd, yyyy').format(start)}',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: pickEnd,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('End: ${DateFormat('MMM dd, yyyy').format(end)}'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(DateTimeRange(start: start, end: end));
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  ({DateTime start, DateTime end}) _revenueRangeBounds(
    _RevenueRange range,
    DateTime now,
  ) {
    final localNow = now.toLocal();
    switch (range) {
      case _RevenueRange.daily:
        final start = DateTime(localNow.year, localNow.month, localNow.day);
        return (start: start, end: start.add(const Duration(days: 1)));
      case _RevenueRange.weekly:
        final start = DateTime(
          localNow.year,
          localNow.month,
          localNow.day,
        ).subtract(Duration(days: localNow.weekday - 1));
        return (start: start, end: start.add(const Duration(days: 7)));
      case _RevenueRange.monthly:
        final start = DateTime(localNow.year, localNow.month);
        return (start: start, end: DateTime(localNow.year, localNow.month + 1));
      case _RevenueRange.yearly:
        final start = DateTime(localNow.year);
        return (start: start, end: DateTime(localNow.year + 1));
      case _RevenueRange.custom:
        final selected = _customRevenueDateRange;
        if (selected != null) {
          final start = DateTime(
            selected.start.year,
            selected.start.month,
            selected.start.day,
          );
          final end = DateTime(
            selected.end.year,
            selected.end.month,
            selected.end.day,
          ).add(const Duration(days: 1));
          return (start: start, end: end);
        }
        final fallbackEnd = DateTime(
          localNow.year,
          localNow.month,
          localNow.day,
        ).add(const Duration(days: 1));
        return (
          start: fallbackEnd.subtract(const Duration(days: 7)),
          end: fallbackEnd,
        );
      case _RevenueRange.overall:
        final start = DateTime(2000);
        return (start: start, end: DateTime(localNow.year + 50));
    }
  }

  String _revenuePeriodLabel(_RevenueRange range, DateTime now) {
    if (range == _RevenueRange.overall) return 'All time';
    final bounds = _revenueRangeBounds(range, now);
    final endInclusive = bounds.end.subtract(const Duration(days: 1));
    switch (range) {
      case _RevenueRange.daily:
        return DateFormat('MMMM dd, yyyy').format(bounds.start);
      case _RevenueRange.weekly:
        return '${DateFormat('MMM dd').format(bounds.start)} - ${DateFormat('MMM dd, yyyy').format(endInclusive)}';
      case _RevenueRange.monthly:
        return DateFormat('MMMM yyyy').format(bounds.start);
      case _RevenueRange.yearly:
        return DateFormat('yyyy').format(bounds.start);
      case _RevenueRange.custom:
        return '${DateFormat('MMM dd, yyyy').format(bounds.start)} - ${DateFormat('MMM dd, yyyy').format(endInclusive)}';
      case _RevenueRange.overall:
        return 'All time';
    }
  }

  Future<void> _loadRevenues() async {
    if (_loadingRevenues) return;
    setState(() {
      _loadingRevenues = true;
    });
    try {
      // Use the same sales source as Reports to keep both pages consistent.
      final bookingReport = await ReportsApi.bookings();
      final lines = _extractBookingSalesLines(bookingReport);
      final now = DateTime.now();
      final inRange = _selectedRevenueRange == _RevenueRange.overall
          ? lines
          : lines.where((line) {
              final date = line.bookedAt;
              if (date == null) return false;
              final bounds = _revenueRangeBounds(_selectedRevenueRange, now);
              return !date.isBefore(bounds.start) && date.isBefore(bounds.end);
            }).toList();

      final billable = inRange.where((line) {
        final raw = line.status.toLowerCase();
        return raw == 'confirmed' || raw == 'completed';
      }).toList();

      final pending = inRange.where((line) {
        final raw = line.status.toLowerCase();
        return raw == 'pending';
      }).length;

      final earnings = billable.fold<double>(
        0,
        (sum, line) => sum + line.salePrice,
      );
      final tax = billable.fold<double>(0, (sum, line) => sum + line.tax);
      final revenue = billable.fold<double>(0, (sum, line) => sum + line.total);
      final services = billable
          .map((line) => line.serviceName.trim().toLowerCase())
          .where((name) => name.isNotEmpty)
          .toSet()
          .length;

      final byDay = <String, ({double earning, double revenue})>{};
      for (final line in billable) {
        final bookedAt = line.bookedAt;
        if (bookedAt == null) continue;
        final key = DateFormat('yyyy-MM-dd').format(bookedAt);
        final current = byDay[key] ?? (earning: 0.0, revenue: 0.0);
        byDay[key] = (
          earning: current.earning + line.salePrice,
          revenue: current.revenue + line.total,
        );
      }

      final chartKeys = byDay.keys.toList()..sort();
      final chart = chartKeys
          .map(
            (key) => {
              'date': key,
              'earning': byDay[key]!.earning,
              'revenue': byDay[key]!.revenue,
            },
          )
          .toList();

      final data = <String, dynamic>{
        'metrics': {
          'pending': pending,
          'earnings': earnings,
          'bookings': billable.length,
          'services': services,
          'revenue': revenue,
          'tax': tax,
        },
        'chart': chart,
      };
      if (!mounted) return;
      setState(() => _revenuesData = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load revenues: $e')));
    } finally {
      if (mounted) {
        setState(() => _loadingRevenues = false);
      }
    }
  }

  Widget _buildRevenuesContent() {
    if (_loadingRevenues && _revenuesData.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final metrics =
        (_revenuesData['metrics'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final chart =
        (_revenuesData['chart'] as List?)?.cast<dynamic>() ?? const [];
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 1100;
    final isMobile = width < 700;
    final now = DateTime.now();
    final revenueChips = _RevenueRange.values
        .map(
          (range) => ChoiceChip(
            label: Text(_revenueRangeLabel(range)),
            selected: _selectedRevenueRange == range,
            onSelected: (_) async {
              if (range == _RevenueRange.custom) {
                final picked = await _pickCustomRevenueDateRange();
                if (!mounted || picked == null) return;
                setState(() {
                  _customRevenueDateRange = picked;
                  _selectedRevenueRange = _RevenueRange.custom;
                });
                _loadRevenues();
                return;
              }
              setState(() => _selectedRevenueRange = range);
              _loadRevenues();
            },
            selectedColor: _sidebarBg.withOpacity(0.16),
            labelStyle: TextStyle(
              color: _selectedRevenueRange == range
                  ? _sidebarBg
                  : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        )
        .toList();

    final cards = [
      _dashboardMetricCard(
        label: 'Pending',
        value: '${metrics['pending'] ?? 0}',
        subtitle: 'Total pending',
        icon: Icons.timelapse,
        color: const Color(0xFF7C8CE6),
      ),
      _dashboardMetricCard(
        label: 'Earnings',
        value: _formatPeso((metrics['earnings'] as num?)?.toDouble() ?? 0),
        subtitle: 'Total earnings',
        icon: Icons.attach_money,
        color: const Color(0xFFEC6BA7),
      ),
      _dashboardMetricCard(
        label: 'Bookings',
        value: '${metrics['bookings'] ?? 0}',
        subtitle: 'Total bookings',
        icon: Icons.book_online,
        color: const Color(0xFF44C0E8),
      ),
      _dashboardMetricCard(
        label: 'Services',
        value: '${metrics['services'] ?? 0}',
        subtitle: 'Total bookable services',
        icon: Icons.bolt,
        color: const Color(0xFF73CB5C),
      ),
    ];

    return Container(
      width: double.infinity,
      color: const Color(0xFFF3F4F8),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenue Dashboard',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _revenuePeriodLabel(_selectedRevenueRange, now),
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: revenueChips),
          const SizedBox(height: 14),
          if (_selectedRevenueRange == _RevenueRange.custom) ...[
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await _pickCustomRevenueDateRange();
                if (!mounted || picked == null) return;
                setState(() => _customRevenueDateRange = picked);
                _loadRevenues();
              },
              icon: const Icon(Icons.date_range),
              label: const Text('Change custom date span'),
            ),
            const SizedBox(height: 14),
          ],
          if (isNarrow)
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = isMobile
                    ? constraints.maxWidth
                    : ((constraints.maxWidth - 12) / 2).clamp(220.0, 420.0);
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards
                      .map((card) => SizedBox(width: cardWidth, child: card))
                      .toList(),
                );
              },
            )
          else
            Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 12),
                Expanded(child: cards[1]),
                const SizedBox(width: 12),
                Expanded(child: cards[2]),
                const SizedBox(width: 12),
                Expanded(child: cards[3]),
              ],
            ),
          const SizedBox(height: 14),
          _dashboardChartCard(
            chart,
            panelHeight: isNarrow ? null : 360,
            rangeLabel: _revenuePeriodLabel(_selectedRevenueRange, now),
          ),
        ],
      ),
    );
  }

  Future<void> _loadBookingHistory() async {
    if (_loadingBookingHistory) return;
    setState(() => _loadingBookingHistory = true);
    try {
      final data = await ReportsApi.bookings();
      final items = (data['items'] as List?)?.cast<dynamic>() ?? const [];
      if (!mounted) return;
      setState(() => _bookingHistoryRows = items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load booking history: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingBookingHistory = false);
    }
  }

  Widget _buildBookingHistoryPage() {
    if (_loadingBookingHistory && _bookingHistoryRows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final query = _bookingHistorySearch.trim().toLowerCase();
    final rows = _bookingHistoryRows.where((item) {
      final m = item is Map<String, dynamic>
          ? item
          : Map<String, dynamic>.from(item as Map);
      final status = (m['status'] ?? '').toString().toLowerCase();
      final type = (m['moduleType'] ?? '').toString().toLowerCase();
      final hay =
          '${m['bookingId'] ?? ''} ${m['serviceName'] ?? ''} ${m['bookedBy'] ?? ''} ${m['creator'] ?? ''} $status $type'
              .toLowerCase();
      final typeOk = _bookingTypeFilter == 'all' || type == _bookingTypeFilter;
      final statusOk =
          _bookingStatusFilter == 'all' || status == _bookingStatusFilter;
      return (query.isEmpty || hay.contains(query)) && typeOk && statusOk;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (value) =>
                    setState(() => _bookingHistorySearch = value),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search by service, booker, creator...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: _bookingTypeFilter,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Type',
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
            const SizedBox(width: 10),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: _bookingStatusFilter,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Status',
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
                ],
                onChanged: (value) =>
                    setState(() => _bookingStatusFilter = value ?? 'all'),
              ),
            ),
            const SizedBox(width: 10),
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
              ],
              rows: rows.map<DataRow>((item) {
                final m = item is Map<String, dynamic>
                    ? item
                    : Map<String, dynamic>.from(item as Map);
                final status = (m['status'] ?? '').toString();
                final dateRaw = (m['bookingDate'] ?? '').toString();
                String dateText = '-';
                if (dateRaw.isNotEmpty) {
                  try {
                    dateText = DateFormat(
                      'MM/dd/yyyy',
                    ).format(DateTime.parse(dateRaw));
                  } catch (_) {}
                }
                final price = (m['price'] as num?)?.toDouble() ?? 0;
                final salePrice = (m['salePrice'] as num?)?.toDouble() ?? 0;
                final total = (m['total'] as num?)?.toDouble() ?? 0;
                return DataRow(
                  cells: [
                    DataCell(Text('#${m['bookingId'] ?? '-'}')),
                    DataCell(
                      SizedBox(
                        width: 180,
                        child: Text(
                          (m['serviceName'] ?? '-').toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text((m['moduleType'] ?? '-').toString().toUpperCase()),
                    ),
                    DataCell(
                      SizedBox(
                        width: 160,
                        child: Text(
                          (m['bookedBy'] ?? '-').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 160,
                        child: Text(
                          (m['creator'] ?? '-').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text(_formatPeso(price))),
                    DataCell(Text(_formatPeso(salePrice))),
                    DataCell(Text(_formatPeso(total))),
                    DataCell(Text(dateText)),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: status.toLowerCase() == 'cancelled'
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          status.isEmpty ? 'unknown' : status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: status.toLowerCase() == 'cancelled'
                                ? const Color(0xFF991B1B)
                                : const Color(0xFF166534),
                          ),
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
        Text('Showing ${rows.length} booking(s)'),
      ],
    );
  }

  Future<void> _loadDashboard() async {
    if (_loadingDashboard) return;
    setState(() => _loadingDashboard = true);
    try {
      final data = await ReportsApi.dashboard();
      if (!mounted) return;
      setState(() => _dashboardData = data);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load dashboard: $e')));
    } finally {
      if (mounted) setState(() => _loadingDashboard = false);
    }
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

  Widget _dashboardMetricCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      height: 112,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          CircleAvatar(
            backgroundColor: Colors.white24,
            child: Icon(icon, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _dashboardChartCard(
    List<dynamic> chartData, {
    double? panelHeight,
    String rangeLabel = 'Last 7 days',
    VoidCallback? onRangeTap,
  }) {
    final hasBoundedHeight = panelHeight != null;
    final values = chartData
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final maxRevenue = values.fold<double>(
      0,
      (max, row) => ((row['revenue'] as num?)?.toDouble() ?? 0) > max
          ? ((row['revenue'] as num?)?.toDouble() ?? 0)
          : max,
    );
    final maxEarning = values.fold<double>(
      0,
      (max, row) => ((row['earning'] as num?)?.toDouble() ?? 0) > max
          ? ((row['earning'] as num?)?.toDouble() ?? 0)
          : max,
    );
    final maxValue = [
      maxRevenue,
      maxEarning,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: panelHeight,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Earning statistics',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                InkWell(
                  onTap: onRangeTap,
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          size: 14,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Text(rangeLabel, style: const TextStyle(fontSize: 12)),
                        if (onRangeTap != null) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down,
                            size: 16,
                            color: Colors.black54,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (values.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No chart data yet'),
              )
            else if (hasBoundedHeight)
              Expanded(
                child: SizedBox(
                  height: 250,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: values.map((row) {
                      final revenue = (row['revenue'] as num?)?.toDouble() ?? 0;
                      final earning = (row['earning'] as num?)?.toDouble() ?? 0;
                      final dateRaw = row['date']?.toString() ?? '';
                      final dateLabel = dateRaw.length >= 10
                          ? dateRaw.substring(5)
                          : dateRaw;
                      final revenueHeight = (revenue / maxValue) * 160;
                      final earningHeight = (earning / maxValue) * 160;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        width: 10,
                                        height: revenueHeight.clamp(2, 180),
                                        color: const Color(0xFF7C8CE6),
                                      ),
                                      const SizedBox(width: 4),
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 220,
                                        ),
                                        width: 10,
                                        height: earningHeight.clamp(2, 180),
                                        color: const Color(0xFFEC6BA7),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                dateLabel,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              )
            else
              SizedBox(
                height: 250,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: values.map((row) {
                    final revenue = (row['revenue'] as num?)?.toDouble() ?? 0;
                    final earning = (row['earning'] as num?)?.toDouble() ?? 0;
                    final dateRaw = row['date']?.toString() ?? '';
                    final dateLabel = dateRaw.length >= 10
                        ? dateRaw.substring(5)
                        : dateRaw;
                    final revenueHeight = (revenue / maxValue) * 160;
                    final earningHeight = (earning / maxValue) * 160;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      width: 10,
                                      height: revenueHeight.clamp(2, 180),
                                      color: const Color(0xFF7C8CE6),
                                    ),
                                    const SizedBox(width: 4),
                                    AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      width: 10,
                                      height: earningHeight.clamp(2, 180),
                                      color: const Color(0xFFEC6BA7),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              dateLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 10),
            const Row(
              children: [
                _LegendDot(color: Color(0xFF7C8CE6), label: 'Total Revenue'),
                SizedBox(width: 16),
                _LegendDot(color: Color(0xFFEC6BA7), label: 'Total Earning'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardRecentBookingsCard(
    List<dynamic> recentBookings, {
    double? panelHeight,
  }) {
    final hasBoundedHeight = panelHeight != null;
    final rows = recentBookings
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    return SizedBox(
      height: panelHeight,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Bookings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                TextButton(
                  onPressed: () => setSection(AdminSection.reports),
                  child: const Text('More'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No recent bookings'),
              )
            else if (hasBoundedHeight)
              Expanded(
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('Item')),
                        DataColumn(label: Text('Total')),
                        DataColumn(label: Text('Paid')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Created At')),
                      ],
                      rows: rows.map((row) {
                        final status = (row['status'] ?? '').toString();
                        final createdAt = row['createdAt']?.toString() ?? '';
                        final date = createdAt.isEmpty
                            ? '-'
                            : DateFormat(
                                'MM/dd/yyyy',
                              ).format(DateTime.parse(createdAt));
                        return DataRow(
                          cells: [
                            DataCell(Text('#${row['id'] ?? '-'}')),
                            DataCell(
                              SizedBox(
                                width: 180,
                                child: Text(
                                  (row['item'] ?? '-').toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _formatPeso(
                                  (row['total'] as num?)?.toDouble() ?? 0,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _formatPeso(
                                  (row['paid'] as num?)?.toDouble() ?? 0,
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: status.toLowerCase() == 'cancelled'
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  status.isEmpty ? 'unknown' : status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: status.toLowerCase() == 'cancelled'
                                        ? const Color(0xFF991B1B)
                                        : const Color(0xFF0C4A6E),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(date)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 280,
                child: SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('#')),
                        DataColumn(label: Text('Item')),
                        DataColumn(label: Text('Total')),
                        DataColumn(label: Text('Paid')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Created At')),
                      ],
                      rows: rows.map((row) {
                        final status = (row['status'] ?? '').toString();
                        final createdAt = row['createdAt']?.toString() ?? '';
                        final date = createdAt.isEmpty
                            ? '-'
                            : DateFormat(
                                'MM/dd/yyyy',
                              ).format(DateTime.parse(createdAt));
                        return DataRow(
                          cells: [
                            DataCell(Text('#${row['id'] ?? '-'}')),
                            DataCell(
                              SizedBox(
                                width: 180,
                                child: Text(
                                  (row['item'] ?? '-').toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _formatPeso(
                                  (row['total'] as num?)?.toDouble() ?? 0,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                _formatPeso(
                                  (row['paid'] as num?)?.toDouble() ?? 0,
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: status.toLowerCase() == 'cancelled'
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  status.isEmpty ? 'unknown' : status,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: status.toLowerCase() == 'cancelled'
                                        ? const Color(0xFF991B1B)
                                        : const Color(0xFF0C4A6E),
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(date)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatPeso(double amount) => '₱${amount.toStringAsFixed(2)}';

  String _reportRangeLabel(_ReportRange range) {
    switch (range) {
      case _ReportRange.daily:
        return 'Daily';
      case _ReportRange.weekly:
        return 'Weekly';
      case _ReportRange.monthly:
        return 'Monthly';
      case _ReportRange.yearly:
        return 'Yearly';
      case _ReportRange.custom:
        return 'Custom';
    }
  }

  ({DateTime start, DateTime end}) _reportRangeBounds(
    _ReportRange range,
    DateTime now,
  ) {
    final localNow = now.toLocal();
    switch (range) {
      case _ReportRange.daily:
        final start = DateTime(localNow.year, localNow.month, localNow.day);
        return (start: start, end: start.add(const Duration(days: 1)));
      case _ReportRange.weekly:
        final start = DateTime(
          localNow.year,
          localNow.month,
          localNow.day,
        ).subtract(Duration(days: localNow.weekday - 1));
        return (start: start, end: start.add(const Duration(days: 7)));
      case _ReportRange.monthly:
        final start = DateTime(localNow.year, localNow.month);
        return (start: start, end: DateTime(localNow.year, localNow.month + 1));
      case _ReportRange.yearly:
        final start = DateTime(localNow.year);
        return (start: start, end: DateTime(localNow.year + 1));
      case _ReportRange.custom:
        final selected = _customReportDateRange;
        if (selected != null) {
          final start = DateTime(
            selected.start.year,
            selected.start.month,
            selected.start.day,
          );
          final end = DateTime(
            selected.end.year,
            selected.end.month,
            selected.end.day,
          ).add(const Duration(days: 1));
          return (start: start, end: end);
        }
        final start = DateTime(localNow.year, localNow.month, localNow.day);
        return (start: start, end: start.add(const Duration(days: 1)));
    }
  }

  String _reportPeriodLabel(_ReportRange range, DateTime now) {
    final bounds = _reportRangeBounds(range, now);
    final endInclusive = bounds.end.subtract(const Duration(days: 1));
    switch (range) {
      case _ReportRange.daily:
        return DateFormat('MMMM dd, yyyy').format(bounds.start);
      case _ReportRange.weekly:
        return '${DateFormat('MMM dd').format(bounds.start)} - ${DateFormat('MMM dd, yyyy').format(endInclusive)}';
      case _ReportRange.monthly:
        return DateFormat('MMMM yyyy').format(bounds.start);
      case _ReportRange.yearly:
        return DateFormat('yyyy').format(bounds.start);
      case _ReportRange.custom:
        return '${DateFormat('MMM dd, yyyy').format(bounds.start)} - ${DateFormat('MMM dd, yyyy').format(endInclusive)}';
    }
  }

  _ReportSnapshot _buildActiveReportSnapshot(dynamic bookingReport) {
    final now = DateTime.now();
    final lines = _filterSalesLinesByRange(
      _extractBookingSalesLines(bookingReport),
      _selectedReportRange,
      now,
    );
    return (
      range: _selectedReportRange,
      rangeLabel: _reportRangeLabel(_selectedReportRange),
      periodLabel: _reportPeriodLabel(_selectedReportRange, now),
      lines: lines,
      totals: _bookingTotals(lines),
      taxRate: _extractBookingTaxRate(bookingReport),
    );
  }

  Future<DateTimeRange?> _pickCustomReportDateRange() async {
    final now = DateTime.now();
    final initial =
        _customReportDateRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);

    DateTime start = initial.start;
    DateTime end = initial.end;

    final result = await showDialog<DateTimeRange>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          Future<void> pickStart() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: start,
              firstDate: DateTime(2020),
              lastDate: DateTime(now.year + 1, 12, 31),
            );
            if (picked == null) return;
            setLocalState(() {
              start = DateTime(picked.year, picked.month, picked.day);
              if (end.isBefore(start)) end = start;
            });
          }

          Future<void> pickEnd() async {
            final picked = await showDatePicker(
              context: context,
              initialDate: end,
              firstDate: DateTime(2020),
              lastDate: DateTime(now.year + 1, 12, 31),
            );
            if (picked == null) return;
            setLocalState(() {
              end = DateTime(picked.year, picked.month, picked.day);
              if (end.isBefore(start)) start = end;
            });
          }

          return AlertDialog(
            title: const Text('Custom report date span'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: pickStart,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    'Start: ${DateFormat('MMM dd, yyyy').format(start)}',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: pickEnd,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text('End: ${DateFormat('MMM dd, yyyy').format(end)}'),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(
                    dialogContext,
                  ).pop(DateTimeRange(start: start, end: end));
                },
                child: const Text('Apply'),
              ),
            ],
          );
        },
      ),
    );

    return result;
  }

  DateTime? _parseReportDate(Map<String, dynamic> map) {
    final raw =
        map['bookingDate'] ??
        map['createdAt'] ??
        map['date'] ??
        map['updatedAt'];
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  List<
    ({
      String serviceName,
      String status,
      int pax,
      double price,
      double salePrice,
      double total,
      double tax,
      DateTime? bookedAt,
    })
  >
  _filterSalesLinesByRange(
    List<
      ({
        String serviceName,
        String status,
        int pax,
        double price,
        double salePrice,
        double total,
        double tax,
        DateTime? bookedAt,
      })
    >
    lines,
    _ReportRange range,
    DateTime now,
  ) {
    final bounds = _reportRangeBounds(range, now);
    return lines.where((line) {
      final d = line.bookedAt;
      if (d == null) return range == _ReportRange.daily;
      return !d.isBefore(bounds.start) && d.isBefore(bounds.end);
    }).toList();
  }

  Widget _reportSummaryRow(
    String label,
    String value, {
    bool emphasize = false,
  }) {
    final textStyle = TextStyle(
      fontSize: emphasize ? 16 : 14,
      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
      color: const Color(0xFF0F172A),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textStyle),
        Text(value, style: textStyle),
      ],
    );
  }

  Widget _buildReportsSummaryPanel(
    _ReportSnapshot report, {
    bool desktop = false,
  }) {
    final spacing = desktop ? 12.0 : 6.0;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(desktop ? 18 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sales Summary',
            style: TextStyle(
              fontSize: desktop ? 16 : 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          SizedBox(height: spacing),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: desktop ? 8 : 0),
            child: _reportSummaryRow(
              'Sales Amount',
              _formatPeso(report.totals.amount),
            ),
          ),
          SizedBox(height: spacing),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: desktop ? 8 : 0),
            child: _reportSummaryRow(
              'Sales Tax',
              _formatPeso(report.totals.tax),
            ),
          ),
          const Divider(height: 24),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: desktop ? 8 : 0),
            child: _reportSummaryRow(
              'Sales Total',
              _formatPeso(report.totals.total),
              emphasize: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsDetailsTable(_ReportSnapshot report) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              'Sales Details',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 28,
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFDCE6F4),
                    ),
                    columns: const [
                      DataColumn(label: Text('Service Name')),
                      DataColumn(label: Text('Pax')),
                      DataColumn(label: Text('Price')),
                      DataColumn(label: Text('Sale Price')),
                      DataColumn(label: Text('Total')),
                    ],
                    rows: [
                      ...report.lines.map(
                        (line) => DataRow(
                          cells: [
                            DataCell(Text(line.serviceName)),
                            DataCell(Text(line.pax.toString())),
                            DataCell(Text(_formatPeso(line.price))),
                            DataCell(Text(_formatPeso(line.salePrice))),
                            DataCell(Text(_formatPeso(line.total))),
                          ],
                        ),
                      ),
                      DataRow(
                        color: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                        cells: [
                          DataCell(
                            Text(
                              'Tax (${(report.taxRate * 100).toStringAsFixed(0)}%)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          const DataCell(Text('')),
                          DataCell(
                            Text(
                              _formatPeso(
                                report.lines.fold(0, (sum, l) => sum + l.tax),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (report.lines.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Text(
                'No sales found for this range.',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    if (_loadingUsers) return const Center(child: CircularProgressIndicator());
    if (_usersError != null) return Center(child: Text(_usersError!));
    if (_users.isEmpty) return const Center(child: Text('No users found.'));
    final query = _usersSearchController.text.trim().toLowerCase();
    final users = _users.where((u) {
      final m = u as Map<String, dynamic>;
      final id = (m['id'] ?? '').toString().toLowerCase();
      final name =
          '${m['firstName'] ?? ''} ${m['lastName'] ?? ''} ${m['userName'] ?? m['username'] ?? ''}'
              .toLowerCase();
      final email = (m['email'] ?? '').toString().toLowerCase();
      final role = (m['roleName'] ?? m['roleCode'] ?? m['roleId'] ?? '')
          .toString()
          .toLowerCase();
      return query.isEmpty ||
          id.contains(query) ||
          name.contains(query) ||
          email.contains(query) ||
          role.contains(query);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _usersSearchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search users...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
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
              rows: users.map<DataRow>((u) {
                final m = u as Map<String, dynamic>;
                final id = m['id']?.toString() ?? '';
                final firstName = (m['firstName'] ?? '').toString();
                final lastName = (m['lastName'] ?? '').toString();
                final userName = (m['userName'] ?? m['username'] ?? '')
                    .toString();
                final name = ('$firstName $lastName').trim().isEmpty
                    ? userName
                    : ('$firstName $lastName').trim();
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
                    DataCell(SizedBox(width: 70, child: Text(id))),
                    DataCell(
                      SizedBox(
                        width: 170,
                        child: Text(name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 220,
                        child: Text(
                          email?.toString() ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: role == 'Administrator'
                              ? const Color(0xFFDBEAFE)
                              : role == 'Vendor'
                              ? const Color(0xFFFFEDD5)
                              : const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          role,
                          style: TextStyle(
                            color: role == 'Administrator'
                                ? const Color(0xFF1E3A8A)
                                : role == 'Vendor'
                                ? const Color(0xFF9A3412)
                                : const Color(0xFF166534),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 180,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              icon: const Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: Color(0xFF1D4ED8),
                              ),
                              label: const Text(
                                'Edit',
                                style: TextStyle(color: Color(0xFF1D4ED8)),
                              ),
                              onPressed: () => _showEditUserDialog(m),
                            ),
                            TextButton.icon(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: Color(0xFFDC2626),
                              ),
                              label: const Text(
                                'Delete',
                                style: TextStyle(color: Color(0xFFDC2626)),
                              ),
                              onPressed: isSelf ? null : () => _deleteUser(id),
                            ),
                          ],
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
        Text('Showing ${users.length} of ${_users.length} users'),
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
                      m['userName']?.toString() ??
                      m['username']?.toString() ??
                      '';
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
      onAuthorFilterChanged: (value) =>
          setState(() => _toursAuthorFilter = value),
      onStatusFilterChanged: (value) =>
          setState(() => _toursStatusFilter = value),
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
      onToggleAdvancedFilters: () =>
          setState(() => _showCarsAdvancedFilters = !_showCarsAdvancedFilters),
      onBulkActionChanged: (value) => setState(() => _carsBulkAction = value),
      onAuthorFilterChanged: (value) =>
          setState(() => _carsAuthorFilter = value),
      onStatusFilterChanged: (value) =>
          setState(() => _carsStatusFilter = value),
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
      final bookingReport = _reportsData['bookings'];
      final report = _buildActiveReportSnapshot(bookingReport);
      final now = DateTime.now();
      final reportRangeTitle = report.rangeLabel.toUpperCase();
      final pdfBaseFont = await PdfGoogleFonts.notoSansRegular();
      final pdfBoldFont = await PdfGoogleFonts.notoSansBold();
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            theme: pw.ThemeData.withFont(base: pdfBaseFont, bold: pdfBoldFont),
          ),
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'TRAVELISTA ADVENTURES',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'BASIC $reportRangeTitle SALES REPORT',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _pdfLabelValue('Sales Person', userName.toString()),
                      pw.SizedBox(height: 6),
                      _pdfLabelValue('Period', report.periodLabel),
                    ],
                  ),
                  pw.Container(
                    width: 210,
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                      children: [
                        _pdfSummaryLine('Sales Amount', report.totals.amount),
                        pw.SizedBox(height: 4),
                        _pdfSummaryLine('Sales Tax', report.totals.tax),
                        pw.Divider(color: PdfColors.grey500),
                        _pdfSummaryLine(
                          'Sales Total',
                          report.totals.total,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              _buildBookingSalesPdfTable(report.lines, report.taxRate),
              pw.Spacer(),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Generated ${DateFormat('yyyy-MM-dd HH:mm').format(now)}',
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
            'travelista-adventures-sales-report-${DateFormat('yyyy-MM-dd-HHmmss').format(now)}.pdf',
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

  pw.Widget _pdfLabelValue(String label, String value) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 90,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ),
        pw.Text(value, style: pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  pw.Widget _pdfSummaryLine(String label, double amount, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 11,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(_pdfMoney(amount), style: style),
      ],
    );
  }

  pw.Widget _buildBookingSalesPdfTable(
    List<
      ({
        String serviceName,
        String status,
        int pax,
        double price,
        double salePrice,
        double total,
        double tax,
        DateTime? bookedAt,
      })
    >
    lines,
    double taxRate,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      columnWidths: {
        0: const pw.FlexColumnWidth(2.8),
        1: const pw.FlexColumnWidth(0.8),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColor.fromHex('#DCE6F4')),
          children: [
            _pdfHeaderCell('Service Name'),
            _pdfHeaderCell('Pax'),
            _pdfHeaderCell('Price'),
            _pdfHeaderCell('Sale Price'),
            _pdfHeaderCell('Total'),
          ],
        ),
        ...lines.map((line) {
          return pw.TableRow(
            children: [
              _pdfCell(line.serviceName),
              _pdfCell(line.pax.toString(), alignRight: true),
              _pdfCell(_pdfMoney(line.price), alignRight: true),
              _pdfCell(_pdfMoney(line.salePrice), alignRight: true),
              _pdfCell(_pdfMoney(line.total), alignRight: true),
            ],
          );
        }),
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey100),
          children: [
            _pdfCell(
              'Tax (${(taxRate * 100).toStringAsFixed(0)}%)',
              bold: true,
            ),
            _pdfCell(''),
            _pdfCell(''),
            _pdfCell(''),
            _pdfCell(
              _pdfMoney(lines.fold(0, (sum, l) => sum + l.tax)),
              alignRight: true,
              bold: true,
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _pdfCell(
    String text, {
    bool alignRight = false,
    bool bold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  String _pdfMoney(double value) => '\u20B1${value.toStringAsFixed(2)}';

  List<
    ({
      String serviceName,
      String status,
      int pax,
      double price,
      double salePrice,
      double total,
      double tax,
      DateTime? bookedAt,
    })
  >
  _extractBookingSalesLines(dynamic data) {
    final items = data is Map<String, dynamic> ? data['items'] : null;
    if (items is! List) return [];
    return items.whereType<Map>().map((item) {
      final map = Map<String, dynamic>.from(item);
      final pax = (map['pax'] as num?)?.toInt() ?? 1;
      final price = (map['price'] as num?)?.toDouble() ?? 0;
      final salePrice = (map['salePrice'] as num?)?.toDouble() ?? price;
      final total = (map['total'] as num?)?.toDouble() ?? (salePrice * pax);
      final tax =
          (map['tax'] as num?)?.toDouble() ?? (total - (salePrice * pax));
      return (
        serviceName: (map['serviceName'] ?? map['title'] ?? 'Service')
            .toString(),
        status: (map['status'] ?? '').toString(),
        pax: pax,
        price: price,
        salePrice: salePrice,
        total: total,
        tax: tax,
        bookedAt: _parseReportDate(map),
      );
    }).toList();
  }

  ({double amount, double tax, double total}) _bookingTotals(
    List<
      ({
        String serviceName,
        String status,
        int pax,
        double price,
        double salePrice,
        double total,
        double tax,
        DateTime? bookedAt,
      })
    >
    lines,
  ) {
    if (lines.isEmpty) return (amount: 0, tax: 0, total: 0);
    final amount = lines.fold<double>(
      0,
      (sum, line) => sum + (line.salePrice * line.pax),
    );
    final tax = lines.fold<double>(0, (sum, line) => sum + line.tax);
    return (amount: amount, tax: tax, total: amount + tax);
  }

  double _extractBookingTaxRate(dynamic data) {
    if (data is Map<String, dynamic>) {
      final raw = data['taxRate'];
      if (raw is num) return raw.toDouble();
    }
    return 0.12;
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
    _usersSearchController.dispose();
    _adminFirstNameController.dispose();
    _adminLastNameController.dispose();
    _adminUsernameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }
}

// --- FORM WIDGETS ---

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _ContentTextEditor extends StatefulWidget {
  const _ContentTextEditor({required this.controller, required this.label});

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
