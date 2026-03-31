import 'package:flutter/material.dart';

import '../api/tours_api.dart';
import '../api/cars_api.dart';
import '../api/admin_api.dart';
import '../api/user_api.dart';
import '../api/api_client.dart';
import '../widgets/image_upload_widget.dart';
import '../api/reports_api.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

// Minimal admin dashboard with dark sidebar (Booking Core–style)
const _sidebarBg = Color(0xFF1E3A5F);
const _sidebarActive = Color(0xFF2C5282);
const _sidebarText = Colors.white;
const _sidebarTextMuted = Color(0xFFB0BEC5);

enum AdminSection {
  dashboard,
  users,
  toursAll,
  toursAdd,
  carsAll,
  carsAdd,
  reports,
  settings,
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
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
  Map<String, dynamic?> _reportsData = {};
  bool _loadingReports = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final isAdmin = await UserApi.isAdmin();
    final userId = await ApiClient.instance.currentUserId;
    if (!mounted) return;

    if (!isAdmin) {
      // If a non-admin somehow navigates here, show an unauthorized message.
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
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildContent()),
        ],
      ),
    );
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
                Text(
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
              _sideSubItem('All Tours', _current == AdminSection.toursAll, () => setState(() => _current = AdminSection.toursAll)),
              _sideSubItem('Add Tour', _current == AdminSection.toursAdd, () => setState(() => _current = AdminSection.toursAdd)),
            ],
          ),
          _sideGroup(
            icon: Icons.directions_car_outlined,
            label: 'Cars',
            expanded: _carsExpanded,
            onToggle: () => setState(() => _carsExpanded = !_carsExpanded),
            children: [
              _sideSubItem('All Cars', _current == AdminSection.carsAll, () => setState(() => _current = AdminSection.carsAll)),
              _sideSubItem('Add Car', _current == AdminSection.carsAdd, () => setState(() => _current = AdminSection.carsAdd)),
            ],
          ),
          const SizedBox(height: 8),
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
                      style: const TextStyle(
                        color: _sidebarText,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
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
        _buildHeader(),
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
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
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
        return 'Add Tour';
      case AdminSection.carsAll:
        return 'All Cars';
      case AdminSection.carsAdd:
        return 'Add Car';
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
            const Text('Unauthorized', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
      case AdminSection.carsAll:
        return _buildCarsList();
      case AdminSection.carsAdd:
        return _buildCarForm();
      case AdminSection.reports:
        return _buildReportsDashboard();
      case AdminSection.settings:
        return _buildPlaceholder('Settings', Icons.settings);
    }
  }

  Widget _buildReportsDashboard() {
    // Simple reports dashboard showing counts and raw data summaries.
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
        const Text('Raw report data', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              // Show a compact string representation of the reports map
              _reportsData.entries.map((e) {
                final v = e.value;
                if (v is List) return '${e.key}: ${v.length} items';
                return '${e.key}: ${v ?? 'null'}';
              }).join('  •  '),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 32, color: _sidebarBg),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
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
        DataTable(
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

            // Role is often stored in different fields depending on backend.
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

            // Normalize role display
            role = role.toString().toLowerCase();
            if (role == 'customer') role = 'Customer';
            if (role == 'vendor') role = 'Vendor';
            if (role == 'administrator' || role == 'admin') role = 'Administrator';
            if (role.isEmpty) role = 'Unknown';

            final isSelf = id == _currentUserId;
            return DataRow(cells: [
              DataCell(Text(id)),
              DataCell(Text(name?.toString() ?? '')),
              DataCell(Text(email?.toString() ?? '')),
              DataCell(Text(role)),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditUserDialog(m),
                    tooltip: 'Edit User',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: isSelf ? null : () => _deleteUser(id),
                    tooltip: isSelf ? 'Cannot delete yourself' : 'Delete User',
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildToursList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_tours.isEmpty) return const Center(child: Text('No tours yet.'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Price')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _tours.map<DataRow>((t) {
            final m = t as Map<String, dynamic>;
            return DataRow(cells: [
              DataCell(Text('${m['id']}')),
              DataCell(Text(m['title']?.toString() ?? '')),
              DataCell(Text('\$${m['salePrice'] ?? m['price'] ?? '-'}')),
              DataCell(Text(m['status']?.toString() ?? '')),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditTourDialog(m),
                    tooltip: 'Edit Tour',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteTour(m['id']),
                    tooltip: 'Delete Tour',
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCarsList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_cars.isEmpty) return const Center(child: Text('No cars yet.'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Price')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _cars.map<DataRow>((c) {
            final m = c as Map<String, dynamic>;
            return DataRow(cells: [
              DataCell(Text('${m['id']}')),
              DataCell(Text(m['title']?.toString() ?? '')),
              DataCell(Text('\$${m['salePrice'] ?? m['price'] ?? '-'}')),
              DataCell(Text(m['status']?.toString() ?? '')),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _showEditCarDialog(m),
                    tooltip: 'Edit Car',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _deleteCar(m['id']),
                    tooltip: 'Delete Car',
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ],
    );
  }

  void _showEditTourDialog(Map<String, dynamic> tour) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Tour'),
        content: SizedBox(
          width: 550,
          height: 500,
          child: SingleChildScrollView(
            child: _AddTourForm(
              onCreated: () {
                Navigator.of(context).pop();
                _loadData();
              },
              itemToEdit: tour,
            ),
          ),
        ),
      ),
    );
  }

  void _showEditCarDialog(Map<String, dynamic> car) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Car'),
        content: SizedBox(
          width: 600,
          height: 550,
          child: SingleChildScrollView(
            child: _AddCarForm(
              onCreated: () {
                Navigator.of(context).pop();
                _loadData();
              },
              itemToEdit: car,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTour(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tour'),
        content: const Text('Are you sure you want to delete this tour?'),
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
    if (confirm == true) {
      try {
        await ToursApi.delete(id);
        _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tour deleted')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting tour: $e')));
      }
    }
  }

  Future<void> _deleteCar(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Car'),
        content: const Text('Are you sure you want to delete this car?'),
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
    if (confirm == true) {
      try {
        await CarsApi.delete(id);
        _loadData();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Car deleted')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting car: $e')));
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load reports: $e')),
      );
    }
  }
}

Future<void> _generatePdfReport(BuildContext context) async {
  setState(() => _loadingReports = true); // Reuse loading for button
  try {
    // Get current user profile for header
    final profile = await UserApi.getProfile();
    final userName = profile['userName'] ?? profile['username'] ?? profile['firstName'] ?? 'Admin';
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
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1E3A5F'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'Travel Agency Reports',
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Comprehensive Dashboard Summary',
                    style: pw.TextStyle(fontSize: 16, color: PdfColors.grey200),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Account Details Card - Center Top
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
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        userEmail,
                        style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Generated: ${formatter.format(now)}',
                        style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Stats Row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: _buildPdfStatCards(_reportsData),
            ),
            pw.SizedBox(height: 30),

            // Data Tables
            ..._buildPdfDataTables(_reportsData),

            // Footer
            pw.Spacer(),
            pw.Container(
              alignment: pw.Alignment.center,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
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

    // Share/print PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'travel-agency-reports-${DateFormat('yyyy-MM-dd-HHmmss').format(now)}.pdf',
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _loadingReports = false);
    }
  }
}

List<pw.Widget> _buildPdfStatCards(Map<String, dynamic?> data) {
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
          pw.Text(e.key, style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
          pw.SizedBox(height: 4),
          pw.Text('$count', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
        ],
      ),
    );
  }).toList();
}

List<pw.Widget> _buildPdfDataTables(Map<String, dynamic?> data) {
  final sections = ['tours', 'cars', 'bookings', 'locations'];
  return sections.map((key) {
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
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            defaultColumnWidth: const pw.FlexColumnWidth(),
            children: [
              // Header
              pw.TableRow(
                decoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E3A5F')),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('ID', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Title/Name', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Price', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Text('Status', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                  ),
                ],
              ),
              // Data rows
              ...rows.asMap().entries.take(20).map((entry) {
                final row = rows[entry.key];
                return pw.TableRow( // Limit to 20 rows per table
                  decoration: pw.BoxDecoration(color: entry.key % 2 == 0 ? PdfColors.white : PdfColors.grey50),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(row.id.toString(), style: const pw.TextStyle(fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(row.title ?? '', style: const pw.TextStyle(fontSize: 11), maxLines: 2)),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(row.price ?? '-', style: const pw.TextStyle(fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(row.status ?? '-', style: const pw.TextStyle(fontSize: 11))),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }).where((w) => w != pw.SizedBox.shrink()).toList();
}

int _pdfCount(dynamic data) {
  if (data == null) return 0;
  if (data is List) return data.length;
  if (data is Map) return data.length;
  return 1;
}

List<({int id, String? title, String? price, String? status})> _extractTableRows(dynamic data) {
  final List<({int id, String? title, String? price, String? status})> rows = [];
  if (data is List) {
    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      if (item is Map<String, dynamic>) {
        final id = item['id'] ?? i;
        rows.add((
          id: id is int ? id : (id?.hashCode ?? i),
          title: item['title'] ?? item['name'] ?? item['userName'] ?? '-',
          price: '\$${item['price'] ?? item['salePrice'] ?? '-'}',
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
        _usersError = e is ApiException ? 'Error ${e.statusCode}: ${e.message}' : e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingUsers = false;
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
      messenger.showSnackBar(SnackBar(content: Text('Error deleting user: $e')));
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
    final firstName = TextEditingController(text: user['firstName']?.toString() ?? '');
    final lastName = TextEditingController(text: user['lastName']?.toString() ?? '');
    final email = TextEditingController(text: user['email']?.toString() ?? '');
    final username = TextEditingController(text: user['userName']?.toString() ?? user['username']?.toString() ?? '');

    // Extract role using same logic as in _buildUsersList
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
                TextField(controller: firstName, decoration: const InputDecoration(labelText: 'First name')),
                const SizedBox(height: 12),
                TextField(controller: lastName, decoration: const InputDecoration(labelText: 'Last name')),
                const SizedBox(height: 12),
                TextField(controller: username, decoration: const InputDecoration(labelText: 'Username')),
                const SizedBox(height: 12),
                TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role.isEmpty ? null : role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: [
                    DropdownMenuItem(value: 'customer', child: const Text('Customer')),
                    DropdownMenuItem(value: 'vendor', child: const Text('Vendor')),
                    DropdownMenuItem(value: 'administrator', child: const Text('Administrator')),
                  ],
                  onChanged: (v) => role = v ?? role,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => dialogNavigator.pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final body = {
                    'firstName': firstName.text.trim(),
                    'lastName': lastName.text.trim(),
                    'userName': username.text.trim(),
                    'email': email.text.trim(),
                    if (role.isNotEmpty) 'role': role,
                  };
                  await AdminApi.updateUser(user['id'].toString(), body);
                  if (!mounted) return;
                  dialogNavigator.pop();
                  _loadUsers();
                  messenger.showSnackBar(const SnackBar(content: Text('User updated')));
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(SnackBar(content: Text('Error updating user: $e')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTourForm() {
    return _AddTourForm(onCreated: _loadData);
  }

  Widget _buildCarForm() {
    return _AddCarForm(onCreated: _loadData);
  }

  Widget _buildPlaceholder(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}

class _AddTourForm extends StatefulWidget {
  const _AddTourForm({required this.onCreated, this.itemToEdit});

  final VoidCallback onCreated;
  final Map<String, dynamic>? itemToEdit;

  @override
  State<_AddTourForm> createState() => _AddTourFormState();
}

class _AddTourFormState extends State<_AddTourForm> {
  final _title = TextEditingController();
  final _slug = TextEditingController();
  final _price = TextEditingController();
  final _salePrice = TextEditingController();
  String? _imageUrl;
  String? _imagePublicId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.itemToEdit != null) {
      final item = widget.itemToEdit!;
      _title.text = item['title']?.toString() ?? '';
      _slug.text = item['slug']?.toString() ?? '';
      _price.text = item['price']?.toString() ?? '';
      _salePrice.text = item['salePrice']?.toString() ?? '';
      _imageUrl = item['imageUrl']?.toString();
      _imagePublicId = item['imagePublicId']?.toString();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _price.dispose();
    _salePrice.dispose();
    super.dispose();
  }

  void _generateSlug() {
    final title = _title.text.trim();
    if (title.isNotEmpty) {
      _slug.text = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    }
  }

  void _onImageSelected(String? url, String? publicId) {
    setState(() {
      _imageUrl = url;
      _imagePublicId = publicId;
    });
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final body = {
        'title': _title.text.trim(),
        'slug': _slug.text.trim(),
        'price': _price.text.isEmpty ? "0" : _price.text.trim(),
        'salePrice': _salePrice.text.isEmpty ? "" : _salePrice.text.trim(),
        'imageUrl': _imageUrl,
        'imagePublicId': _imagePublicId,
        'status': 'publish',
      };
      if (widget.itemToEdit != null) {
        await ToursApi.update(widget.itemToEdit!['id'], body);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tour updated')));
      } else {
        await ToursApi.create(body);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tour created')));
      }
      if (!mounted) return;
      _title.clear();
      _slug.clear();
      _price.clear();
      _salePrice.clear();
      _imageUrl = null;
      _imagePublicId = null;
      widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      String errorMsg = 'Unknown error';
      if (e is ApiException) {
        errorMsg = 'Error ${e.statusCode}: ${e.message}';
        if (e.body is Map<String, dynamic>) {
          final body = e.body as Map<String, dynamic>;
          final details = body.entries.map((entry) => '${entry.key}: ${entry.value}').join(', ');
          if (details.length < 200) {
            errorMsg += ' ($details)';
          }
        }
      } else {
        errorMsg = 'Error: $e';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()), onChanged: (_) => _generateSlug()),
          const SizedBox(height: 16),
          TextField(controller: _slug, decoration: const InputDecoration(labelText: 'Slug', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _price, decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          TextField(controller: _salePrice, decoration: const InputDecoration(labelText: 'Sale Price (optional)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          const Text('Tour Image', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ImageUploadWidget(
            initialImageUrl: _imageUrl,
            initialImagePublicId: _imagePublicId,
            onImageSelected: _onImageSelected,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.itemToEdit != null ? 'Update Tour' : 'Add Tour')),
        ],
      ),
    );
  }
}

class _AddCarForm extends StatefulWidget {
  const _AddCarForm({required this.onCreated, this.itemToEdit});

  final VoidCallback onCreated;
  final Map<String, dynamic>? itemToEdit;

  @override
  State<_AddCarForm> createState() => _AddCarFormState();
}

class _AddCarFormState extends State<_AddCarForm> {
  final _title = TextEditingController();
  final _slug = TextEditingController();
  final _price = TextEditingController();
  final _salePrice = TextEditingController();
  final _passenger = TextEditingController(text: '4');
  final _gearShift = TextEditingController(text: 'Auto');
  final _baggage = TextEditingController(text: '2');
  final _door = TextEditingController(text: '4');
  final _mapLat = TextEditingController();
  final _mapLng = TextEditingController();
  String? _imageUrl;
  String? _imagePublicId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.itemToEdit != null) {
      final item = widget.itemToEdit!;
      _title.text = item['title']?.toString() ?? '';
      _slug.text = item['slug']?.toString() ?? '';
      _price.text = item['price']?.toString() ?? '';
      _salePrice.text = item['salePrice']?.toString() ?? '';
      _passenger.text = item['passenger']?.toString() ?? '4';
      _gearShift.text = item['gearShift']?.toString() ?? 'Auto';
      _baggage.text = item['baggage']?.toString() ?? '2';
      _door.text = item['door']?.toString() ?? '4';
      _mapLat.text = item['mapLat']?.toString() ?? '';
      _mapLng.text = item['mapLng']?.toString() ?? '';
      _imageUrl = item['imageUrl']?.toString();
      _imagePublicId = item['imagePublicId']?.toString();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _price.dispose();
    _salePrice.dispose();
    _passenger.dispose();
    _gearShift.dispose();
    _baggage.dispose();
    _door.dispose();
    _mapLat.dispose();
    _mapLng.dispose();
    super.dispose();
  }

  void _generateSlug() {
    final title = _title.text.trim();
    if (title.isNotEmpty) {
      _slug.text = title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    }
  }

  void _onImageSelected(String? url, String? publicId) {
    setState(() {
      _imageUrl = url;
      _imagePublicId = publicId;
    });
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      final body = {
        'title': _title.text.trim(),
        'slug': _slug.text.trim(),
        'price': _price.text.isEmpty ? "0" : _price.text.trim(),
        'salePrice': _salePrice.text.isEmpty ? "" : _salePrice.text.trim(),
'passenger': int.parse(_passenger.text.isEmpty ? "4" : _passenger.text.trim()),
        'gearShift': _gearShift.text.isEmpty ? "Auto" : _gearShift.text.trim(),
        'baggage': int.parse(_baggage.text.isEmpty ? "2" : _baggage.text.trim()),
        'door': int.parse(_door.text.isEmpty ? "4" : _door.text.trim()),
        'mapLat': _mapLat.text.isEmpty ? "" : _mapLat.text.trim(),
        'mapLng': _mapLng.text.isEmpty ? "" : _mapLng.text.trim(),
        'imageUrl': _imageUrl,
        'imagePublicId': _imagePublicId,
        'status': 'publish',
      };
      if (widget.itemToEdit != null) {
        await CarsApi.update(widget.itemToEdit!['id'], body);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Car updated')));
      } else {
        await CarsApi.create(body);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Car created')));
      }
      _title.clear();
      _slug.clear();
      _price.clear();
      _salePrice.clear();
      _imageUrl = null;
      _imagePublicId = null;
      widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      String errorMsg = 'Unknown error';
      if (e is ApiException) {
        errorMsg = 'Error ${e.statusCode}: ${e.message}';
        if (e.body is Map<String, dynamic>) {
          final body = e.body as Map<String, dynamic>;
          final details = body.entries.map((entry) => '${entry.key}: ${entry.value}').join(', ');
          if (details.length < 200) {
            errorMsg += ' ($details)';
          }
        }
      } else {
        errorMsg = 'Error: $e';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()), onChanged: (_) => _generateSlug()),
          const SizedBox(height: 16),
          TextField(controller: _slug, decoration: const InputDecoration(labelText: 'Slug', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _price, decoration: const InputDecoration(labelText: 'Price', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          TextField(controller: _salePrice, decoration: const InputDecoration(labelText: 'Sale Price (optional)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          TextField(controller: _passenger, decoration: const InputDecoration(labelText: 'Passenger', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          TextField(controller: _gearShift, decoration: const InputDecoration(labelText: 'Gear Shift', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          TextField(controller: _baggage, decoration: const InputDecoration(labelText: 'Baggage', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          TextField(controller: _door, decoration: const InputDecoration(labelText: 'Door', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          TextField(controller: _mapLat, decoration: const InputDecoration(labelText: 'Map Latitude (optional)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          TextField(controller: _mapLng, decoration: const InputDecoration(labelText: 'Map Longitude (optional)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          const Text('Car Image', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ImageUploadWidget(
            initialImageUrl: _imageUrl,
            initialImagePublicId: _imagePublicId,
            onImageSelected: _onImageSelected,
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.itemToEdit != null ? 'Update Car' : 'Add Car')),
        ],
      ),
    );
  }
}
