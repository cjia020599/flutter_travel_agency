import 'package:flutter/material.dart';
import 'package:flutter_travel_agency/features/admin/shared/widgets/admin_list_widgets.dart';

class TourListPage extends StatelessWidget {
  const TourListPage({
    super.key,
    required this.loading,
    required this.tours,
    required this.selectedIds,
    required this.showAdvancedFilters,
    required this.bulkAction,
    required this.authorFilter,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onToggleAdvancedFilters,
    required this.onBulkActionChanged,
    required this.onAuthorFilterChanged,
    required this.onStatusFilterChanged,
    required this.onApplyBulkAction,
    required this.onSelectAll,
    required this.onToggleSelection,
    required this.onClearSelection,
    required this.onDeleteSelected,
    required this.onEdit,
    required this.onDelete,
  });

  final bool loading;
  final List<dynamic> tours;
  final Set<String> selectedIds;
  final bool showAdvancedFilters;
  final String bulkAction;
  final String authorFilter;
  final String statusFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleAdvancedFilters;
  final ValueChanged<String> onBulkActionChanged;
  final ValueChanged<String> onAuthorFilterChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final VoidCallback onApplyBulkAction;
  final ValueChanged<bool> onSelectAll;
  final void Function(String id, bool selected) onToggleSelection;
  final VoidCallback onClearSelection;
  final VoidCallback onDeleteSelected;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return AdminEntityListSection(
      loading: loading,
      items: tours,
      emptyText: 'No tours yet.',
      selectedIds: selectedIds,
      bulkAction: bulkAction,
      authorFilter: authorFilter,
      statusFilter: statusFilter,
      onSearchChanged: onSearchChanged,
      onToggleAdvancedFilters: onToggleAdvancedFilters,
      showAdvancedFilters: showAdvancedFilters,
      onBulkActionChanged: onBulkActionChanged,
      onAuthorFilterChanged: onAuthorFilterChanged,
      onStatusFilterChanged: onStatusFilterChanged,
      onApplyBulkAction: onApplyBulkAction,
      onSelectAll: onSelectAll,
      onToggleSelection: onToggleSelection,
      onClearSelection: onClearSelection,
      onDeleteSelected: onDeleteSelected,
      onEdit: onEdit,
      onDelete: onDelete,
      clearLabel: 'Clear',
      toolbarMargin: const EdgeInsets.only(bottom: 24),
      toolbarPadding: const EdgeInsets.all(16),
      titleGetter: (m) => (m['title'] ?? m['name'] ?? '').toString(),
      locationGetter: (m) =>
          (m['realTourAddress'] ?? m['location'] ?? m['address'] ?? m['city'] ?? 'N/A')
              .toString(),
      authorGetter: (m) =>
          (m['author'] ?? m['userName'] ?? m['username'] ?? 'Admin').toString(),
      reviewCountGetter: (m) => (m['reviewCount'] ?? m['reviews'] ?? 0).toString(),
      statusGetter: (m) => m['status']?.toString(),
      emptyTitle: 'Tour',
    );
  }
}
