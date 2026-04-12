import 'package:flutter/material.dart';
import 'package:flutter_travel_agency/api/chatbot_api.dart';

import '../api/tours_api.dart';
import '../api/cars_api.dart';
import '../api/lookups_api.dart';
import '../api/auth_api.dart';
import '../api/admin_api.dart';
import '../api/user_api.dart';
import '../api/api_client.dart';
import '../api/ratings_api.dart';
import '../widgets/image_upload_widget.dart';
import '../widgets/car_location_map_picker.dart';
import 'package:latlong2/latlong.dart';
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
  ratings,
  chatbot,
  reports,
  settings,
}

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

  List<dynamic> _getFilteredTours() {
    final query = _toursSearchQuery.toLowerCase().trim();
    if (query.isEmpty) return _tours;
    return _tours.where((tour) {
      final m = tour as Map<String, dynamic>;
      final title = (m['title'] ?? m['name'] ?? '').toString().toLowerCase();
      final location = (m['realTourAddress'] ?? m['location'] ?? m['address'] ?? m['city'] ?? '').toString().toLowerCase();
      final author = (m['author'] ?? m['userName'] ?? m['username'] ?? '').toString().toLowerCase();
      return title.contains(query) || location.contains(query) || author.contains(query);
    }).toList();
  }

  List<dynamic> _getFilteredCars() {
    final query = _carsSearchQuery.toLowerCase().trim();
    if (query.isEmpty) return _cars;
    return _cars.where((car) {
      final m = car as Map<String, dynamic>;
      final title = (m['title'] ?? m['name'] ?? '').toString().toLowerCase();
      final location = (m['realTourAddress'] ?? m['location'] ?? m['address'] ?? m['city'] ?? '').toString().toLowerCase();
      final author = (m['author'] ?? m['userName'] ?? m['username'] ?? '').toString().toLowerCase();
      return title.contains(query) || location.contains(query) || author.contains(query);
    }).toList();
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
    final body = widget.showSidebar
        ? Row(
            children: [
              _buildSidebar(),
              Expanded(child: _buildContent()),
            ],
          )
        : _buildContent();
    return Scaffold(body: body);
  }

  void setSection(AdminSection section) {
    setState(() {
      _current = section;
      _expandForSection(section);
    });
    _loadForSection(section);
  }

  void _expandForSection(AdminSection section) {
    if (section == AdminSection.toursAll || section == AdminSection.toursAdd) {
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
        return 'Add Tour';
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
              // Show a compact string representation of the reports map
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
            if (role == 'administrator' || role == 'admin')
              role = 'Administrator';
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
      ],
    );
  }

  Widget _buildRatingsList() {
    if (_loadingRatings)
      return const Center(child: CircularProgressIndicator());
    if (_ratings.isEmpty) return const Center(child: Text('No ratings yet.'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DataTable(
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

            // Extract user name
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
      ],
    );
  }

  Widget _buildToursList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_tours.isEmpty) return const Center(child: Text('No tours yet.'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Padding(
        //   padding: const EdgeInsets.only(bottom: 24),
        //   child: Row(
        //     children: [
        //       Container(
        //         padding: const EdgeInsets.symmetric(
        //           horizontal: 16,
        //           vertical: 6,
        //         ),
        //         decoration: BoxDecoration(
        //           color: Colors.grey[100],
        //           borderRadius: BorderRadius.circular(8),
        //           border: Border.all(color: const Color(0xFFE0E0E0)),
        //         ),
        //         child: DropdownButtonHideUnderline(
        //           child: DropdownButton<String>(
        //             value: 'Bulk Actions',
        //             items: const [
        //               DropdownMenuItem(
        //                 value: 'Bulk Actions',
        //                 child: Text('Bulk Actions'),
        //               ),
        //             ],
        //             onChanged: (_) {},
        //           ),
        //         ),
        //       ),
        //       const SizedBox(width: 12),
        //       SizedBox(
        //         height: 44,
        //         child: ElevatedButton(
        //           onPressed: () {},
        //           style: ElevatedButton.styleFrom(
        //             backgroundColor: const Color(0xFF06A5BF),
        //             foregroundColor: Colors.white,
        //             padding: const EdgeInsets.symmetric(horizontal: 24),
        //           ),
        //           child: const Text('Apply'),
        //         ),
        //       ),
        //       const Spacer(),
        //       SizedBox(
        //         width: 250,
        //         height: 44,
        //         child: TextField(
        //           decoration: InputDecoration(
        //             hintText: 'Search by name',
        //             border: OutlineInputBorder(
        //               borderRadius: BorderRadius.circular(8),
        //             ),
        //             contentPadding: const EdgeInsets.symmetric(
        //               horizontal: 16,
        //               vertical: 12,
        //             ),
        //             suffixIcon: const Padding(
        //               padding: EdgeInsets.all(8.0),
        //               child: Icon(Icons.search, size: 20),
        //             ),
        //           ),
        //         ),
        //       ),
        //       const SizedBox(width: 12),
        //       SizedBox(
        //         height: 44,
        //         child: OutlinedButton(
        //           onPressed: () {},
        //           style: OutlinedButton.styleFrom(
        //             padding: const EdgeInsets.symmetric(horizontal: 16),
        //             side: const BorderSide(color: Color(0xFF5B667A)),
        //           ),
        //           child: const Text(
        //             'Advanced',
        //             style: TextStyle(color: Colors.black87),
        //           ),
        //         ),
        //       ),
        //       const SizedBox(width: 12),
        //       SizedBox(
        //         height: 44,
        //         child: ElevatedButton(
        //           onPressed: () {},
        //           style: ElevatedButton.styleFrom(
        //             backgroundColor: const Color(0xFF2563EB),
        //             foregroundColor: Colors.white,
        //             padding: const EdgeInsets.symmetric(horizontal: 24),
        //           ),
        //           child: const Text('Search'),
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            children: [
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: (value) => setState(() => _toursSearchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search tours by name, location or author...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _toursSearchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _toursSearchQuery = ''),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Found ${_getFilteredTours().length} items',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        Theme(
          data: Theme.of(context).copyWith(
            dataTableTheme: DataTableThemeData(
              headingRowColor: MaterialStateProperty.all(
                const Color(0xFFFAFAFC),
              ),
              headingRowHeight: 56,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 72,
              dividerThickness: 1,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(
                  label: Text(
                    'Name',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Location',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Author',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Reviews',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              rows: _getFilteredTours().map<DataRow>((t) {
                final m = t as Map<String, dynamic>;
                final title = m['title']?.toString() ?? 'Tour';
                final isFeatured =
                    m['featured'] == true || m['isFeatured'] == true;
                final location = m['realTourAddress']?.toString().trim() ?? 
                    m['location']?.toString().trim() ?? 
                    m['address']?.toString().trim() ?? 
                    m['city']?.toString().trim() ?? 'N/A';
                final author =
                    m['author']?.toString() ??
                    m['userName']?.toString() ??
                    m['username']?.toString() ??
                    'Admin';
                final status = m['status']?.toString().toLowerCase() ?? 'draft';
                final createdAt =
                    m['createdAt'] ?? m['dateCreated'] ?? DateTime.now();
                final reviewCount =
                    m['reviewCount'] ?? m['reviews'] ?? m['ratingCount'] ?? 0;

                String dateStr = '';
                try {
                  final date = createdAt is String
                      ? DateTime.parse(createdAt)
                      : createdAt as DateTime;
                  dateStr = DateFormat('MM/dd/yyyy').format(date);
                } catch (_) {
                  dateStr = 'N/A';
                }

                return DataRow(
                  cells: [
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            if (isFeatured)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFBBF24),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Featured',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            Flexible(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFF2563EB),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        location,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(author, style: const TextStyle(fontSize: 13)),
                    ),
                    DataCell(_carStatusChip(status)),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          reviewCount.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    DataCell(
                      ElevatedButton.icon(
                        onPressed: () => _showEditTourDialog(m),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
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

  Widget _carStatusChip(String? status) {
    final isPublish = (status ?? 'publish').toString().toLowerCase() != 'draft';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPublish ? Colors.green.shade50 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isPublish ? 'Publish' : 'Draft',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isPublish ? Colors.green.shade800 : Colors.grey.shade800,
        ),
      ),
    );
  }

  Widget _buildTourForm() {
    return Center(
      child: Container(
        width: 920,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: _AddTourForm(
            onCreated: () {
              setState(() => _current = AdminSection.toursAll);
              _loadData();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCarForm() {
    return Center(
      child: Container(
        width: 720,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: _AddCarForm(
            onCreated: () {
              setState(() => _current = AdminSection.carsAll);
              _loadData();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCarsList() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_cars.isEmpty) return const Center(child: Text('No cars yet.'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Padding(
        //   padding: const EdgeInsets.only(bottom: 24),
        //   child: Row(
        //     children: [
        //       Container(
        //         padding: const EdgeInsets.symmetric(
        //           horizontal: 16,
        //           vertical: 6,
        //         ),
        //         decoration: BoxDecoration(
        //           color: Colors.grey[100],
        //           borderRadius: BorderRadius.circular(8),
        //           border: Border.all(color: const Color(0xFFE0E0E0)),
        //         ),
        //         child: DropdownButtonHideUnderline(
        //           child: DropdownButton<String>(
        //             value: 'Bulk Actions',
        //             items: const [
        //               DropdownMenuItem(
        //                 value: 'Bulk Actions',
        //                 child: Text('Bulk Actions'),
        //               ),
        //             ],
        //             onChanged: (_) {},
        //           ),
        //         ),
        //       ),
        //       const SizedBox(width: 12),
        //       SizedBox(
        //         height: 44,
        //         child: ElevatedButton(
        //           onPressed: () {},
        //           style: ElevatedButton.styleFrom(
        //             backgroundColor: const Color(0xFF06A5BF),
        //             foregroundColor: Colors.white,
        //             padding: const EdgeInsets.symmetric(horizontal: 24),
        //           ),
        //           child: const Text('Apply'),
        //         ),
        //       ),
        //       const Spacer(),
        //       SizedBox(
        //         width: 250,
        //         height: 44,
        //         child: TextField(
        //           decoration: InputDecoration(
        //             hintText: 'Search by name',
        //             border: OutlineInputBorder(
        //               borderRadius: BorderRadius.circular(8),
        //             ),
        //             contentPadding: const EdgeInsets.symmetric(
        //               horizontal: 16,
        //               vertical: 12,
        //             ),
        //             suffixIcon: const Padding(
        //               padding: EdgeInsets.all(8.0),
        //               child: Icon(Icons.search, size: 20),
        //             ),
        //           ),
        //         ),
        //       ),
        //       const SizedBox(width: 12),
        //       SizedBox(
        //         height: 44,
        //         child: OutlinedButton(
        //           onPressed: () {},
        //           style: OutlinedButton.styleFrom(
        //             padding: const EdgeInsets.symmetric(horizontal: 16),
        //             side: const BorderSide(color: Color(0xFF5B667A)),
        //           ),
        //           child: const Text(
        //             'Advanced',
        //             style: TextStyle(color: Colors.black87),
        //           ),
        //         ),
        //       ),
        //       const SizedBox(width: 12),
        //       SizedBox(
        //         height: 44,
        //         child: ElevatedButton(
        //           onPressed: () {},
        //           style: ElevatedButton.styleFrom(
        //             backgroundColor: const Color(0xFF2563EB),
        //             foregroundColor: Colors.white,
        //             padding: const EdgeInsets.symmetric(horizontal: 24),
        //           ),
        //           child: const Text('Search'),
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            children: [
              const Spacer(),
              SizedBox(
                width: 300,
                child: TextField(
                  onChanged: (value) => setState(() => _carsSearchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Search cars by name, location or author...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _carsSearchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _carsSearchQuery = ''),
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Found ${_getFilteredCars().length} items',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),

        // Cars Table
        Theme(
          data: Theme.of(context).copyWith(
            dataTableTheme: DataTableThemeData(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFFAFAFC)),
              headingRowHeight: 56,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 72,
              dividerThickness: 1,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(
                  label: Text(
                    'Name',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Location',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Author',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Reviews',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Date',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
              rows: _cars.map<DataRow>((c) {
                final m = c as Map<String, dynamic>;
                final title = m['title']?.toString() ?? 'Car';
                final isFeatured =
                    m['featured'] == true || m['isFeatured'] == true;
                final location = m['realTourAddress']?.toString().trim() ?? 
                    m['location']?.toString().trim() ?? 
                    m['address']?.toString().trim() ?? 
                    m['city']?.toString().trim() ?? 'N/A';
                final author =
                    m['author']?.toString() ??
                    m['userName']?.toString() ??
                    'Admin';
                final status = m['status']?.toString().toLowerCase() ?? 'draft';
                final createdAt =
                    m['createdAt'] ?? m['dateCreated'] ?? DateTime.now();

                String dateStr = '';
                try {
                  final date = createdAt is String
                      ? DateTime.parse(createdAt)
                      : createdAt as DateTime;
                  dateStr = DateFormat('MM/dd/yyyy').format(date);
                } catch (_) {
                  dateStr = 'N/A';
                }

                return DataRow(
                  cells: [
                    // Name with Featured badge
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                if (isFeatured)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFBBF24),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Featured',
                                      style: TextStyle(
                                        color: Colors.black87,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                Flexible(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: Color(0xFF3B82F6),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Location
                    DataCell(
                      Text(
                        location,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                    // Author
                    DataCell(
                      Text(author, style: const TextStyle(fontSize: 13)),
                    ),

                    // Status
                    DataCell(_carStatusChip(status)),

                    // Reviews
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '0',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                    // Date
                    DataCell(
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ),

                    // Edit button
                    DataCell(
                      ElevatedButton.icon(
                        onPressed: () => _showEditCarDialog(m),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
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

  Future<void> _showEditTourDialog(Map<String, dynamic> tour) async {
    final id = tour['id'];
    if (id == null) return;

    // Show loading
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
      Navigator.of(context).pop(); // Close loading

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit Tour'),
          content: SizedBox(
            width: 920,
            height: 720,
            child: SingleChildScrollView(
              child: _AddTourForm(
                onCreated: () async {
                  Navigator.of(context).pop();
                  await _loadData();
                },
                itemToEdit: freshTour,
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load tour: $e')));
    }
  }

  Future<void> _showEditCarDialog(Map<String, dynamic> car) async {
    final id = car['id'];
    if (id == null) return;

    // Show loading
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
      Navigator.of(context).pop(); // Close loading

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit Car'),
          content: SizedBox(
            width: 720,
            height: 640,
            child: SingleChildScrollView(
              child: _AddCarForm(
                onCreated: () async {
                  Navigator.of(context).pop();
                  await _loadData();
                },
                itemToEdit: freshCar,
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load car: $e')));
    }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tour deleted')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting tour: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Car deleted')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting car: $e')));
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
    setState(() => _loadingReports = true); // Reuse loading for button
    try {
      // Get current user profile for header
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

      // Share/print PDF
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
                    // Header
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
                    // Data rows
                    ...rows.asMap().entries.take(20).map((entry) {
                      final row = rows[entry.key];
                      return pw.TableRow(
                        // Limit to 20 rows per table
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
                  items: [
                    DropdownMenuItem(
                      value: 'customer',
                      child: const Text('Customer'),
                    ),
                    DropdownMenuItem(
                      value: 'vendor',
                      child: const Text('Vendor'),
                    ),
                    DropdownMenuItem(
                      value: 'administrator',
                      child: const Text('Administrator'),
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
                    'userName': username.text.trim(),
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
    print('Admin create button clicked');
    if (!_settingsFormKey.currentState!.validate()) {
      print('Admin form validation failed');
      setState(() {
        _adminCreationError = 'Please fill in all required fields correctly.';
      });
      return;
    }
    print('Admin form valid - calling API');
    
    setState(() {
      _adminCreationError = null;
      _creatingAdmin = true;
    });
    
    try {
      print('Calling AuthApi.register for admin...');
      await AuthApi.register(
        firstName: _adminFirstNameController.text.trim(),
        lastName: _adminLastNameController.text.trim(),
        username: _adminUsernameController.text.trim(),  // Consistent with backend
        email: _adminEmailController.text.trim(),
        password: _adminPasswordController.text,
        role: 'administrator',
      );
      print('Admin creation API success');
      
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
      print('Admin API Exception: ${e.statusCode} - ${e.message}');
      if (mounted) {
        setState(() {
          _adminCreationError = 'Error ${e.statusCode}: ${e.message}';
          _creatingAdmin = false;
        });
      }
    } catch (e) {
      print('Admin creation error: $e');
      if (mounted) {
        setState(() {
          _adminCreationError = 'Failed to create admin: $e';
          _creatingAdmin = false;
        });
      }
    }
    print('Admin create complete');
  }

  Widget _buildPlaceholder(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 18, color: Colors.grey[700])),
        ],
      ),
    );
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

class _AddTourForm extends StatefulWidget {
  const _AddTourForm({required this.onCreated, this.itemToEdit});

  final VoidCallback onCreated;
  final Map<String, dynamic>? itemToEdit;

  @override
  State<_AddTourForm> createState() => _AddTourFormState();
}

class _AddTourFormState extends State<_AddTourForm> {
  final _formKey = GlobalKey<FormState>();
  static const _availabilityOptions = <MapEntry<String, String>>[
    MapEntry('always', 'Always available'),
    MapEntry('fixed', 'Fixed dates'),
    MapEntry('open_hours', 'Open hours'),
  ];

  final _title = TextEditingController();
  final _slug = TextEditingController();
  final _price = TextEditingController();
  final _salePrice = TextEditingController();
  final _realTourAddress = TextEditingController();
  String? _imageUrl;
  String? _imagePublicId;
  bool _loading = false;
  String _status = 'publish';
  String _availability = 'always';
  bool _isFeatured = false;
  double? _mapLat;
  double? _mapLng;
  String? _locationId;
  List<Map<String, dynamic>> _locationRows = [];
  bool _locationsLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.itemToEdit != null) {
      final item = widget.itemToEdit!;
      _title.text = item['title']?.toString() ?? '';
      _slug.text = item['slug']?.toString() ?? '';
      _price.text = item['price']?.toString() ?? '';
      _salePrice.text = item['salePrice']?.toString() ?? '';
      _realTourAddress.text =
          item['realTourAddress']?.toString() ??
          item['address']?.toString() ??
          '';
      _imageUrl = item['imageUrl']?.toString();
      _imagePublicId = item['imagePublicId']?.toString();
      _mapLat = double.tryParse(item['mapLat']?.toString() ?? '');
      _mapLng = double.tryParse(item['mapLng']?.toString() ?? '');
      final st = item['status']?.toString().toLowerCase() ?? 'publish';
      _status = st == 'draft' ? 'draft' : 'publish';
      _isFeatured = item['isFeatured'] == true || item['featured'] == true;
      final av = item['availability']?.toString() ?? '';
      if (_availabilityOptions.any((e) => e.key == av)) {
        _availability = av;
      }
      final loc = item['location'];
      final lid = item['locationId'] ?? (loc is Map ? loc['id'] : loc);
      _locationId = lid?.toString();
    }
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final list = await LookupsApi.locations();
      if (!mounted) return;
      final rows = <Map<String, dynamic>>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          rows.add(e);
        } else if (e is Map) {
          rows.add(Map<String, dynamic>.from(e));
        }
      }
      setState(() {
        _locationRows = rows;
        _locationsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _locationsLoading = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _price.dispose();
    _salePrice.dispose();
    _realTourAddress.dispose();
    super.dispose();
  }

  void _generateSlug() {
    final title = _title.text.trim();
    if (title.isNotEmpty) {
      _slug.text = title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
    }
  }

  void _onImageSelected(String? url, String? publicId) {
    setState(() {
      _imageUrl = url;
      _imagePublicId = publicId;
    });
  }

Widget _formCard(String heading, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(heading, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ...children,
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _loading = false);
      return;
    }
    if (_mapLat == null || _mapLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a location on the map (latitude and longitude are required)',
          ),
        ),
      );
      return;
    }
    if (_slug.text.trim().isEmpty && _title.text.trim().isNotEmpty) {
      _generateSlug();
    }
    setState(() => _loading = true);
    try {
      final body = <String, dynamic>{
        'title': _title.text.trim(),
        'name': _title.text.trim(),
        'slug': _slug.text.trim(),
        'price': _price.text.isEmpty ? '0' : _price.text.trim(),
        'salePrice': _salePrice.text.isEmpty ? '0' : _salePrice.text.trim(),
        'realTourAddress': _realTourAddress.text.trim(),
        'address': _realTourAddress.text.trim(),
        'mapLat': _mapLat != null ? _mapLat!.toString() : '',
        'mapLng': _mapLng != null ? _mapLng!.toString() : '',
        'imageUrl': _imageUrl ?? '',
        'imagePublicId': _imagePublicId ?? '',
        'status': _status,
        'published': _status == 'publish',
        'availability': _availability,
        'isFeatured': _isFeatured,
      };
      if (_locationId != null && _locationId!.isNotEmpty) {
        final n = int.tryParse(_locationId!);
        body['locationId'] = n ?? _locationId;
      }
      if (widget.itemToEdit != null) {
        await ToursApi.update(widget.itemToEdit!['id'], body);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tour updated')));
      } else {
        await ToursApi.create(body);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Tour created')));
      }
      if (!mounted) return;
      _title.clear();
      _slug.clear();
      _price.clear();
      _salePrice.clear();
      _realTourAddress.clear();
      _imageUrl = null;
      _imagePublicId = null;
      _status = 'publish';
      _availability = 'always';
      _isFeatured = false;
      _mapLat = null;
      _mapLng = null;
      _locationId = null;
      widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      String errorMsg = 'Unknown error';
      if (e is ApiException) {
        errorMsg = 'Error ${e.statusCode}: ${e.message}';
        if (e.body is Map<String, dynamic>) {
          final errBody = e.body as Map<String, dynamic>;
          final details = errBody.entries
              .map((entry) => '${entry.key}: ${entry.value}')
              .join(', ');
          if (details.length < 200) {
            errorMsg += ' ($details)';
          }
        }
      } else {
        errorMsg = 'Error: $e';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMsg)));
    }
    if (mounted) setState(() => _loading = false);
  }

  Widget _publishSidebar() {
    return _formCard('Publish', [
      RadioListTile<String>(
        title: const Text('Publish'),
        value: 'publish',
        groupValue: _status,
        onChanged: _loading ? null : (v) => setState(() => _status = v ?? 'publish'),
        dense: true,
      ),
      RadioListTile<String>(
        title: const Text('Draft'),
        value: 'draft',
        groupValue: _status,
        onChanged: _loading ? null : (v) => setState(() => _status = v ?? 'draft'),
        dense: true,
      ),
      const Divider(),
      DropdownButtonFormField<String>(
        initialValue: _availability,
        decoration: const InputDecoration(labelText: 'Availability', border: OutlineInputBorder(), isDense: true),
        items: const [
          DropdownMenuItem(value: 'always', child: Text('Always Available')),
        ],
        onChanged: _loading ? null : (v) => setState(() => _availability = v ?? 'always'),
      ),
      CheckboxListTile(
        value: _isFeatured,
        onChanged: _loading ? null : (v) => setState(() => _isFeatured = v ?? false),
        title: const Text('Enable featured'),
        dense: true,
      ),
      FilledButton.icon(
        onPressed: _loading ? null : _submit,
        icon: _loading ? const CircularProgressIndicator() : const Icon(Icons.save_outlined),
        label: Text(widget.itemToEdit != null ? 'Save changes' : 'Add tour'),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    const pageBg = Color(0xFFF0F2F5);
    final mapInitial = (_mapLat != null && _mapLng != null)
        ? LatLng(_mapLat!, _mapLng!)
        : null;

    final locationItems = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text('-- Please Select --'),
      ),
      ..._locationRows.map((loc) {
        final id = loc['id']?.toString();
        final name = loc['name']?.toString() ?? id ?? 'Location';
        return DropdownMenuItem<String?>(value: id, child: Text(name));
      }),
    ];

    final locationDropdown = _locationsLoading
        ? const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        : DropdownButtonFormField<String?>(
            initialValue: _locationId,
            decoration: const InputDecoration(
              labelText: 'Location',
              border: OutlineInputBorder(),
            ),
            items: locationItems,
            onChanged: _loading ? null : (v) => setState(() => _locationId = v),
          );

    Widget mainColumn() {
      return Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
_formCard('Tour content', [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Title is required' : null,
              onChanged: (_) { if (widget.itemToEdit == null) _generateSlug(); },
            ),
            // Slug auto-generated, hidden for cleaner UI like car form
            const SizedBox(height: 16),
          ]),
            _formCard('Pricing', [
              LayoutBuilder(
                builder: (context, c) {
                  final row = c.maxWidth >= 480;
                  final priceField = TextFormField(
                    controller: _price,
                    decoration: const InputDecoration(
                      labelText: 'Price *',
                      hintText: 'Tour Price',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v?.trim().isEmpty ?? true) return 'Price is required';
                      if (double.tryParse(v!.trim()) == null)
                        return 'Enter valid number';
                      return null;
                    },
                  );
                  final saleField = TextField(
                    controller: _salePrice,
                    decoration: const InputDecoration(
                      labelText: 'Sale Price',
                      hintText: 'Tour Sale Price',
                      border: OutlineInputBorder(),
                      helperText:
                          'If the regular price is less than the discount, it will show the regular price',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  );
                  if (row) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: priceField),
                        const SizedBox(width: 16),
                        Expanded(child: saleField),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      priceField,
                      const SizedBox(height: 16),
                      saleField,
                    ],
                  );
                },
              ),
            ]),
            _formCard('Tour locations', [
              locationDropdown,
              const SizedBox(height: 16),
TextFormField(
              controller: _realTourAddress,
              decoration: const InputDecoration(
                labelText: 'Real tour address *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Real tour address is required' : null,
              maxLines: 2,
            ),
              const SizedBox(height: 16),
              Text(
                'Tap the map to set the meeting point. Latitude and longitude are saved automatically (no manual entry).',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              CarLocationMapPicker(
                key: ValueKey(
                  '${widget.itemToEdit?['id'] ?? 'new'}_${mapInitial?.latitude}_${mapInitial?.longitude}',
                ),
                initial: mapInitial,
                height: 260,
                onPick: (p) => setState(() {
                  _mapLat = p.latitude;
                  _mapLng = p.longitude;
                }),
              ),
              const SizedBox(height: 6),
              Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ]),
            _formCard('Feature image', [
              ImageUploadWidget(
                initialImageUrl: _imageUrl,
                initialImagePublicId: _imagePublicId,
                onImageSelected: _onImageSelected,
              ),
            ]),
          ],
        ),
      );
    }

    return ColoredBox(
      color: pageBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 0, 24),
                    child: mainColumn(),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 24),
                    child: _publishSidebar(),
                  ),
                ),
              ],
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [mainColumn(), _publishSidebar()],
            ),
          );
        },
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
  final _formKey = GlobalKey<FormState>();
  static const _gearOptions = ['Auto', 'Manual', 'CVT'];

  final _title = TextEditingController();
  final _slug = TextEditingController();
  final _price = TextEditingController();
  final _salePrice = TextEditingController();
  final _passenger = TextEditingController(text: '0');
  final _baggage = TextEditingController(text: '0');
  final _door = TextEditingController(text: '0');
  String _gearShift = 'Auto';
  String _status = 'publish';
  double? _mapLat;
  double? _mapLng;
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
      _passenger.text = item['passenger']?.toString() ?? '0';
      final g = item['gearShift']?.toString() ?? 'Auto';
      _gearShift = _gearOptions.contains(g) ? g : 'Auto';
      _baggage.text = item['baggage']?.toString() ?? '0';
      _door.text = item['door']?.toString() ?? '0';
      _mapLat = double.tryParse(item['mapLat']?.toString() ?? '');
      _mapLng = double.tryParse(item['mapLng']?.toString() ?? '');
      final st = item['status']?.toString().toLowerCase() ?? 'publish';
      _status = st == 'draft' ? 'draft' : 'publish';
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
    _baggage.dispose();
    _door.dispose();
    super.dispose();
  }

  void _generateSlug() {
    final title = _title.text.trim();
    if (title.isNotEmpty) {
      _slug.text = title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
    }
  }

  void _onImageSelected(String? url, String? publicId) {
    setState(() {
      _imageUrl = url;
      _imagePublicId = publicId;
    });
  }

  Widget _formCard(String heading, List<Widget> children) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              heading,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _loading = false);
      return;
    }
    if (_mapLat == null || _mapLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a location on the map (latitude and longitude are required)',
          ),
        ),
      );
      return;
    }
    if (_slug.text.trim().isEmpty && _title.text.trim().isNotEmpty) {
      _generateSlug();
    }
    setState(() => _loading = true);
    try {
      final body = {
        'title': _title.text.trim(),
        'name': _title.text.trim(),
        'slug': _slug.text.trim(),
        'price': _price.text.isEmpty ? "0" : _price.text.trim(),
        'salePrice': _salePrice.text.isEmpty ? "0" : _salePrice.text.trim(),
        'passenger': int.parse(
          _passenger.text.isEmpty ? "0" : _passenger.text.trim(),
        ),
        'gearShift': _gearShift,
        'baggage': int.parse(
          _baggage.text.isEmpty ? "0" : _baggage.text.trim(),
        ),
        'door': int.parse(_door.text.isEmpty ? "0" : _door.text.trim()),
        'mapLat': _mapLat != null ? _mapLat!.toString() : '',
        'mapLng': _mapLng != null ? _mapLng!.toString() : '',
        'imageUrl': _imageUrl ?? '',
        'imagePublicId': _imagePublicId ?? '',
        'status': _status,
        'published': _status == 'publish',
      };
      if (widget.itemToEdit != null) {
        await CarsApi.update(widget.itemToEdit!['id'], body);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Car updated')));
      } else {
        await CarsApi.create(body);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Car created')));
      }
      _title.clear();
      _slug.clear();
      _price.clear();
      _salePrice.clear();
      _passenger.text = '0';
      _baggage.text = '0';
      _door.text = '0';
      _gearShift = 'Auto';
      _status = 'publish';
      _mapLat = null;
      _mapLng = null;
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
          final details = body.entries
              .map((entry) => '${entry.key}: ${entry.value}')
              .join(', ');
          if (details.length < 200) {
            errorMsg += ' ($details)';
          }
        }
      } else {
        errorMsg = 'Error: $e';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMsg)));
    }
    if (mounted) setState(() => _loading = false);
  }

  Widget _publishSidebar() {
    return _formCard('Publish', [
      RadioListTile<String>(
        title: const Text('Publish'),
        value: 'publish',
        groupValue: _status,
        onChanged: _loading
            ? null
            : (v) => setState(() => _status = v ?? 'publish'),
        contentPadding: EdgeInsets.zero,
        dense: true,
      ),
      RadioListTile<String>(
        title: const Text('Draft'),
        value: 'draft',
        groupValue: _status,
        onChanged: _loading
            ? null
            : (v) => setState(() => _status = v ?? 'draft'),
        contentPadding: EdgeInsets.zero,
        dense: true,
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _loading ? null : _submit,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined, size: 20),
          label: Text(widget.itemToEdit != null ? 'Save changes' : 'Add car'),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    const pageBg = Color(0xFFF0F2F5);
    final mapInitial = (_mapLat != null && _mapLng != null)
        ? LatLng(_mapLat!, _mapLng!)
        : null;

    Widget mainColumn() {
      return Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _formCard('Car content', [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  hintText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Title is required' : null,
                onChanged: (_) {
                  if (widget.itemToEdit == null) _generateSlug();
                },
              ),
            ]),
            _formCard('Pricing', [
              LayoutBuilder(
                builder: (context, c) {
                  final row = c.maxWidth >= 480;
                  final priceField = TextFormField(
                    controller: _price,
                    decoration: const InputDecoration(
                      labelText: 'Price *',
                      hintText: 'Car Price',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v?.trim().isEmpty ?? true) return 'Price is required';
                      if (double.tryParse(v!.trim()) == null)
                        return 'Enter valid number';
                      return null;
                    },
                  );
                  final saleField = TextField(
                    controller: _salePrice,
                    decoration: const InputDecoration(
                      labelText: 'Sale Price',
                      hintText: 'Car Sale Price',
                      border: OutlineInputBorder(),
                      helperText:
                          'If the regular price is less than the discount, it will show the regular price',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  );
                  if (row) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: priceField),
                        const SizedBox(width: 16),
                        Expanded(child: saleField),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      priceField,
                      const SizedBox(height: 16),
                      saleField,
                    ],
                  );
                },
              ),
            ]),
            _formCard('Extra Info', [
              LayoutBuilder(
                builder: (context, c) {
                  Widget cell(
                    TextEditingController ctrl,
                    String label,
                    String hint,
                  ) {
                    return TextFormField(
                      controller: ctrl,
                      decoration: InputDecoration(
                        labelText: '$label *',
                        hintText: hint,
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.trim().isEmpty ?? true)
                          return '$label is required';
                        if (int.tryParse(v!.trim()) == null)
                          return 'Enter valid number';
                        return null;
                      },
                    );
                  }

                  final w = c.maxWidth;
                  if (w >= 720) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: cell(_passenger, 'Passenger', 'Example: 3'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: cell(_baggage, 'Baggage', 'Example: 5'),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: cell(_door, 'Door', 'Example: 4')),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _gearShift,
                            decoration: const InputDecoration(
                              labelText: 'Gear Shift',
                              border: OutlineInputBorder(),
                            ),
                            items: _gearOptions
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: _loading
                                ? null
                                : (v) =>
                                      setState(() => _gearShift = v ?? 'Auto'),
                          ),
                        ),
                      ],
                    );
                  }
                  if (w >= 400) {
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: cell(
                                _passenger,
                                'Passenger',
                                'Example: 3',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: cell(_baggage, 'Baggage', 'Example: 5'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: cell(_door, 'Door', 'Example: 4')),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _gearShift,
                                decoration: const InputDecoration(
                                  labelText: 'Gear Shift',
                                  border: OutlineInputBorder(),
                                ),
                                items: _gearOptions
                                    .map(
                                      (e) => DropdownMenuItem<String>(
                                        value: e,
                                        child: Text(e),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _loading
                                    ? null
                                    : (v) => setState(
                                        () => _gearShift = v ?? 'Auto',
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      cell(_passenger, 'Passenger', 'Example: 3'),
                      const SizedBox(height: 12),
                      cell(_baggage, 'Baggage', 'Example: 5'),
                      const SizedBox(height: 12),
                      cell(_door, 'Door', 'Example: 4'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _gearShift,
                        decoration: const InputDecoration(
                          labelText: 'Gear Shift',
                          border: OutlineInputBorder(),
                        ),
                        items: _gearOptions
                            .map(
                              (e) => DropdownMenuItem<String>(
                                value: e,
                                child: Text(e),
                              ),
                            )
                            .toList(),
                        onChanged: _loading
                            ? null
                            : (v) => setState(() => _gearShift = v ?? 'Auto'),
                      ),
                    ],
                  );
                },
              ),
            ]),
            _formCard('Locations', [
              Text(
                'Tap the map to set latitude and longitude (coordinates are saved automatically).',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              CarLocationMapPicker(
                key: ValueKey(
                  '${widget.itemToEdit?['id'] ?? 'new'}_${mapInitial?.latitude}_${mapInitial?.longitude}',
                ),
                initial: mapInitial,
                height: 260,
                onPick: (p) => setState(() {
                  _mapLat = p.latitude;
                  _mapLng = p.longitude;
                }),
              ),
              const SizedBox(height: 6),
              Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ]),
            _formCard('Feature image', [
              ImageUploadWidget(
                initialImageUrl: _imageUrl,
                initialImagePublicId: _imagePublicId,
                onImageSelected: _onImageSelected,
              ),
            ]),
          ],
        ),
      );
    }

    return ColoredBox(
      color: pageBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 0, 24),
                    child: mainColumn(),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 24),
                    child: _publishSidebar(),
                  ),
                ),
              ],
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [mainColumn(), _publishSidebar()],
            ),
          );
        },
      ),
    );
  }
}
