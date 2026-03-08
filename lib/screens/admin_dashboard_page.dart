import 'package:flutter/material.dart';

// Minimal admin dashboard with dark sidebar (Booking Core–style)
const _sidebarBg = Color(0xFF1E3A5F);
const _sidebarActive = Color(0xFF2C5282);
const _sidebarText = Colors.white;
const _sidebarTextMuted = Color(0xFFB0BEC5);

enum AdminSection {
  dashboard,
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
            onTap: () => setState(() => _current = AdminSection.reports),
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
    switch (_current) {
      case AdminSection.dashboard:
        return _buildDashboardContent();
      case AdminSection.toursAll:
        return _buildListPlaceholder('Tours', 'All Tours');
      case AdminSection.toursAdd:
        return _buildFormPlaceholder('Tour');
      case AdminSection.carsAll:
        return _buildListPlaceholder('Cars', 'All Cars');
      case AdminSection.carsAdd:
        return _buildFormPlaceholder('Car');
      case AdminSection.reports:
        return _buildPlaceholder('Reports', Icons.assessment);
      case AdminSection.settings:
        return _buildPlaceholder('Settings', Icons.settings);
    }
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
            _statCard('Tours', '0', Icons.tour),
            const SizedBox(width: 16),
            _statCard('Cars', '0', Icons.directions_car),
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

  Widget _buildListPlaceholder(String entity, String title) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.list_alt, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            'List and manage $entity. (CRUD + listing UI will go here.)',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFormPlaceholder(String entity) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Add new $entity',
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            'Create and edit $entity. (Form UI will go here.)',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
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
