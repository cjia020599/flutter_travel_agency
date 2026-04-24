import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const _surface = Color(0xFFF8FAFC);
const _surfaceBorder = Color(0xFFE2E8F0);

class AdminSearchBulkBar extends StatelessWidget {
  const AdminSearchBulkBar({
    super.key,
    required this.bulkAction,
    required this.onBulkActionChanged,
    required this.onApply,
    required this.hasSelection,
    required this.onSearchChanged,
    required this.onToggleAdvanced,
    required this.showAdvanced,
    this.advancedFilters,
    this.margin = const EdgeInsets.only(bottom: 20),
    this.padding = const EdgeInsets.all(18),
  });

  final String bulkAction;
  final ValueChanged<String> onBulkActionChanged;
  final VoidCallback onApply;
  final bool hasSelection;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleAdvanced;
  final bool showAdvanced;
  final Widget? advancedFilters;
  final EdgeInsets margin;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _surfaceBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Row(
                children: [
                  DropdownButton<String>(
                    value: bulkAction,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: 'delete',
                        child: Text('Delete selected'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) onBulkActionChanged(value);
                    },
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: hasSelection ? onApply : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D4ED8),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Apply'),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: 320,
                child: TextField(
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: onToggleAdvanced,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _surfaceBorder),
                ),
                child: const Text('Advanced'),
              ),
            ],
          ),
          if (showAdvanced && advancedFilters != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: advancedFilters!,
            ),
        ],
      ),
    );
  }
}

class AdminSelectionBanner extends StatelessWidget {
  const AdminSelectionBanner({
    super.key,
    required this.selectedCount,
    required this.onClear,
    required this.onDeleteSelected,
    this.clearLabel = 'Clear selection',
  });

  final int selectedCount;
  final VoidCallback onClear;
  final VoidCallback onDeleteSelected;
  final String clearLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '$selectedCount selected',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(onPressed: onClear, child: Text(clearLabel)),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: onDeleteSelected,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete selected'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminAuthorStatusFilters extends StatelessWidget {
  const AdminAuthorStatusFilters({
    super.key,
    required this.authorFilter,
    required this.statusFilter,
    required this.onAuthorFilterChanged,
    required this.onStatusFilterChanged,
    this.authorLabel = 'Author',
    this.statusLabel = 'Status',
  });

  final String authorFilter;
  final String statusFilter;
  final ValueChanged<String> onAuthorFilterChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final String authorLabel;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            initialValue: authorFilter,
            decoration: InputDecoration(
              labelText: authorLabel,
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('-- All --')),
              DropdownMenuItem(value: 'vendor', child: Text('Vendor')),
              DropdownMenuItem(
                value: 'administrator',
                child: Text('Administrator'),
              ),
            ],
            onChanged: (value) {
              if (value != null) onAuthorFilterChanged(value);
            },
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<String>(
            initialValue: statusFilter,
            decoration: InputDecoration(
              labelText: statusLabel,
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('-- All --')),
              DropdownMenuItem(value: 'publish', child: Text('Publish')),
              DropdownMenuItem(value: 'draft', child: Text('Draft')),
            ],
            onChanged: (value) {
              if (value != null) onStatusFilterChanged(value);
            },
          ),
        ),
      ],
    );
  }
}

class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({super.key, required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final normalized = (status ?? 'publish').toLowerCase();
    final isPublish = normalized == 'publish' || normalized == 'confirmed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isPublish ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        (status ?? 'publish').toString(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isPublish ? const Color(0xFF166534) : const Color(0xFF991B1B),
        ),
      ),
    );
  }
}

class AdminEntityTable extends StatelessWidget {
  const AdminEntityTable({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.onSelectAll,
    required this.onToggleSelection,
    required this.onEdit,
    required this.onDelete,
    required this.titleGetter,
    required this.locationGetter,
    required this.authorGetter,
    required this.reviewCountGetter,
    required this.statusGetter,
    this.emptyTitle = 'Untitled',
  });

  final List<dynamic> items;
  final Set<String> selectedIds;
  final ValueChanged<bool> onSelectAll;
  final void Function(String id, bool selected) onToggleSelection;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<String> onDelete;
  final String Function(Map<String, dynamic> item) titleGetter;
  final String Function(Map<String, dynamic> item) locationGetter;
  final String Function(Map<String, dynamic> item) authorGetter;
  final String Function(Map<String, dynamic> item) reviewCountGetter;
  final String? Function(Map<String, dynamic> item) statusGetter;
  final String emptyTitle;

  @override
  Widget build(BuildContext context) {
    Widget clippedText(
      String value, {
      double width = 170,
      int maxLines = 1,
      TextAlign textAlign = TextAlign.left,
    }) {
      return SizedBox(
        width: width,
        child: Text(
          value,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          softWrap: true,
          textAlign: textAlign,
        ),
      );
    }

    return Theme(
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
          showCheckboxColumn: true,
          onSelectAll: (selected) => onSelectAll(selected == true),
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Location')),
            DataColumn(label: Text('Author')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Reviews')),
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Actions')),
          ],
          rows: items.map<DataRow>((item) {
            final m = item as Map<String, dynamic>;
            final id = m['id']?.toString() ?? '';
            final createdAt = m['createdAt'] ?? m['dateCreated'] ?? DateTime.now();
            final dateStr = _formatDate(createdAt);
            return DataRow(
              selected: id.isNotEmpty && selectedIds.contains(id),
              onSelectChanged: id.isEmpty
                  ? null
                  : (selected) => onToggleSelection(id, selected == true),
              cells: [
                DataCell(
                  clippedText(
                    titleGetter(m).isEmpty ? emptyTitle : titleGetter(m),
                    width: 220,
                  ),
                ),
                DataCell(clippedText(locationGetter(m), width: 220, maxLines: 2)),
                DataCell(clippedText(authorGetter(m), width: 140)),
                DataCell(AdminStatusChip(status: statusGetter(m))),
                DataCell(clippedText(reviewCountGetter(m), width: 80)),
                DataCell(clippedText(dateStr, width: 110)),
                DataCell(
                  SizedBox(
                    width: 170,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => onEdit(m),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1D4ED8),
                          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: id.isEmpty ? null : () => onDelete(id),
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
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
    );
  }

  String _formatDate(dynamic value) {
    try {
      final date = value is String ? DateTime.parse(value) : value as DateTime;
      return DateFormat('MM/dd/yyyy').format(date);
    } catch (_) {
      return 'N/A';
    }
  }
}

class AdminEntityListSection extends StatelessWidget {
  const AdminEntityListSection({
    super.key,
    required this.loading,
    required this.items,
    required this.emptyText,
    required this.selectedIds,
    required this.bulkAction,
    required this.authorFilter,
    required this.statusFilter,
    required this.onSearchChanged,
    required this.onToggleAdvancedFilters,
    required this.showAdvancedFilters,
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
    required this.titleGetter,
    required this.locationGetter,
    required this.authorGetter,
    required this.reviewCountGetter,
    required this.statusGetter,
    required this.emptyTitle,
    this.clearLabel = 'Clear selection',
    this.toolbarMargin = const EdgeInsets.only(bottom: 20),
    this.toolbarPadding = const EdgeInsets.all(18),
  });

  final bool loading;
  final List<dynamic> items;
  final String emptyText;
  final Set<String> selectedIds;
  final String bulkAction;
  final String authorFilter;
  final String statusFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleAdvancedFilters;
  final bool showAdvancedFilters;
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
  final String Function(Map<String, dynamic>) titleGetter;
  final String Function(Map<String, dynamic>) locationGetter;
  final String Function(Map<String, dynamic>) authorGetter;
  final String Function(Map<String, dynamic>) reviewCountGetter;
  final String? Function(Map<String, dynamic>) statusGetter;
  final String emptyTitle;
  final String clearLabel;
  final EdgeInsets toolbarMargin;
  final EdgeInsets toolbarPadding;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) return Center(child: Text(emptyText));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminSearchBulkBar(
          bulkAction: bulkAction,
          onBulkActionChanged: onBulkActionChanged,
          onApply: onApplyBulkAction,
          hasSelection: selectedIds.isNotEmpty,
          onSearchChanged: onSearchChanged,
          onToggleAdvanced: onToggleAdvancedFilters,
          showAdvanced: showAdvancedFilters,
          margin: toolbarMargin,
          padding: toolbarPadding,
          advancedFilters: AdminAuthorStatusFilters(
            authorFilter: authorFilter,
            statusFilter: statusFilter,
            onAuthorFilterChanged: onAuthorFilterChanged,
            onStatusFilterChanged: onStatusFilterChanged,
          ),
        ),
        if (selectedIds.isNotEmpty)
          AdminSelectionBanner(
            selectedCount: selectedIds.length,
            onClear: onClearSelection,
            onDeleteSelected: onDeleteSelected,
            clearLabel: clearLabel,
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Found ${items.length} items',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
        AdminEntityTable(
          items: items,
          selectedIds: selectedIds,
          onSelectAll: onSelectAll,
          onToggleSelection: onToggleSelection,
          onEdit: onEdit,
          onDelete: onDelete,
          titleGetter: titleGetter,
          locationGetter: locationGetter,
          authorGetter: authorGetter,
          reviewCountGetter: reviewCountGetter,
          statusGetter: statusGetter,
          emptyTitle: emptyTitle,
        ),
      ],
    );
  }
}
