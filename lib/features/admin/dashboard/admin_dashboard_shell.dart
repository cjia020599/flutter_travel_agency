import 'package:flutter/material.dart';
import 'package:flutter_travel_agency/features/admin/dashboard/admin_section.dart';

const _sidebarBg = Color(0xFF1E3A5F);
const _sidebarActive = Color(0xFF2C5282);
const _sidebarText = Colors.white;
const _sidebarTextMuted = Color(0xFFB0BEC5);

class AdminDashboardShell extends StatelessWidget {
  const AdminDashboardShell({
    super.key,
    required this.showSidebar,
    required this.showHeader,
    required this.showBackButton,
    required this.current,
    required this.toursExpanded,
    required this.carsExpanded,
    required this.sectionTitle,
    required this.onBack,
    required this.onSectionSelected,
    required this.onToursToggle,
    required this.onCarsToggle,
    required this.child,
  });

  final bool showSidebar;
  final bool showHeader;
  final bool showBackButton;
  final AdminSection current;
  final bool toursExpanded;
  final bool carsExpanded;
  final String sectionTitle;
  final VoidCallback onBack;
  final ValueChanged<AdminSection> onSectionSelected;
  final VoidCallback onToursToggle;
  final VoidCallback onCarsToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 1024;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) _buildHeader(isMobile: isMobile),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: child,
          ),
        ),
      ],
    );

    if (showSidebar && isMobile) {
      return Scaffold(
        drawer: Drawer(child: SafeArea(child: _buildSidebar())),
        body: content,
      );
    }

    return Row(
      children: [
        if (showSidebar) _buildSidebar(),
        Expanded(child: content),
      ],
    );
  }

  Widget _buildHeader({required bool isMobile}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: 12,
      ),
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
          if (isMobile && showSidebar)
            Builder(
              builder: (drawerContext) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(drawerContext).openDrawer(),
              ),
            ),
          if (showBackButton)
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)
          else
            const SizedBox(width: 40),
          const SizedBox(width: 8),
          Text(
            sectionTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
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
            isActive: current == AdminSection.dashboard,
            onTap: () => onSectionSelected(AdminSection.dashboard),
          ),
          _sideItem(
            icon: Icons.people_outline,
            label: 'Users',
            isActive: current == AdminSection.users,
            onTap: () => onSectionSelected(AdminSection.users),
          ),
          const SizedBox(height: 8),
          _sideGroup(
            icon: Icons.tour,
            label: 'Tours',
            expanded: toursExpanded,
            onToggle: onToursToggle,
            children: [
              _sideSubItem(
                'All Tours',
                current == AdminSection.toursAll,
                () => onSectionSelected(AdminSection.toursAll),
              ),
              _sideSubItem(
                'Add Tour',
                current == AdminSection.toursAdd,
                () => onSectionSelected(AdminSection.toursAdd),
              ),
              _sideSubItem(
                'Categories',
                current == AdminSection.tourCategories,
                () => onSectionSelected(AdminSection.tourCategories),
              ),
              _sideSubItem(
                'Attributes',
                current == AdminSection.tourAttributes,
                () => onSectionSelected(AdminSection.tourAttributes),
              ),
              _sideSubItem(
                'Availability',
                current == AdminSection.tourAvailability,
                () => onSectionSelected(AdminSection.tourAvailability),
              ),
              _sideSubItem(
                'Booking Calendar',
                current == AdminSection.tourBookingCalendar,
                () => onSectionSelected(AdminSection.tourBookingCalendar),
              ),
              _sideSubItem(
                'Recovery',
                current == AdminSection.tourRecovery,
                () => onSectionSelected(AdminSection.tourRecovery),
              ),
            ],
          ),
          _sideGroup(
            icon: Icons.directions_car_outlined,
            label: 'Car Rental',
            expanded: carsExpanded,
            onToggle: onCarsToggle,
            children: [
              _sideSubItem(
                'All Cars',
                current == AdminSection.carsAll,
                () => onSectionSelected(AdminSection.carsAll),
              ),
              _sideSubItem(
                'Add new car',
                current == AdminSection.carsAdd,
                () => onSectionSelected(AdminSection.carsAdd),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _sideItem(
            icon: Icons.star_outline,
            label: 'Ratings',
            isActive: current == AdminSection.ratings,
            onTap: () => onSectionSelected(AdminSection.ratings),
          ),
          _sideItem(
            icon: Icons.payments_outlined,
            label: 'Revenues',
            isActive: current == AdminSection.revenues,
            onTap: () => onSectionSelected(AdminSection.revenues),
          ),
          _sideItem(
            icon: Icons.assessment_outlined,
            label: 'Reports',
            isActive: current == AdminSection.reports,
            onTap: () => onSectionSelected(AdminSection.reports),
          ),
          _sideItem(
            icon: Icons.chat_bubble_outline,
            label: 'Chatbot Q&A',
            isActive: current == AdminSection.chatbot,
            onTap: () => onSectionSelected(AdminSection.chatbot),
          ),
          _sideItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isActive: current == AdminSection.settings,
            onTap: () => onSectionSelected(AdminSection.settings),
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
        child: Padding(
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
            child: Padding(
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
        child: Padding(
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
}
