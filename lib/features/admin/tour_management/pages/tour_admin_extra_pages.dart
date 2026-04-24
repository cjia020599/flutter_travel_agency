import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:flutter_travel_agency/api/lookups_api.dart';
import 'package:flutter_travel_agency/api/tour_bookings_api.dart';
import 'package:flutter_travel_agency/api/tours_api.dart';
import 'package:flutter_travel_agency/models/tour_booking.dart';

const _panelBg = Color(0xFFF8FAFC);
const _panelBorder = Color(0xFFE2E8F0);

Widget _pageHeader(String title, String subtitle) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
      const SizedBox(height: 2),
      Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
    ],
  );
}

InputDecoration _searchDecoration(String hint) {
  return InputDecoration(
    prefixIcon: const Icon(Icons.search),
    hintText: hint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    isDense: true,
    filled: true,
    fillColor: Colors.white,
  );
}

Widget _sectionCard({required Widget child}) {
  return Container(
    decoration: BoxDecoration(
      color: _panelBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _panelBorder),
    ),
    child: Padding(padding: const EdgeInsets.all(14), child: child),
  );
}

Widget _tableWrap(Widget table) {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: table,
  );
}

Widget _cellText(
  String value, {
  double width = 170,
  int maxLines = 1,
}) {
  return SizedBox(
    width: width,
    child: Text(
      value,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      softWrap: true,
    ),
  );
}

Widget _statusChip(String value) {
  final status = value.toLowerCase();
  final isGood = status == 'publish' || status == 'confirmed';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: isGood ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(value, style: TextStyle(color: isGood ? const Color(0xFF166534) : const Color(0xFF991B1B))),
  );
}

Widget _actionTextButton({
  required IconData icon,
  required String label,
  required VoidCallback onPressed,
  Color? color,
}) {
  final effectiveColor = color ?? const Color(0xFF1D4ED8);
  return TextButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 16, color: effectiveColor),
    label: Text(label, style: TextStyle(color: effectiveColor)),
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      minimumSize: const Size(0, 0),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      alignment: Alignment.centerLeft,
    ),
  );
}

class TourCategoriesPage extends StatefulWidget {
  const TourCategoriesPage({super.key, required this.tours});

  final List<dynamic> tours;

  @override
  State<TourCategoriesPage> createState() => _TourCategoriesPageState();
}

class _TourCategoriesPageState extends State<TourCategoriesPage> {
  bool _loading = true;
  List<dynamic> _categories = [];
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final Set<int> _selectedIds = {};
  int _rowsPerPage = 10;
  int _page = 0;

  void _notifySuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _notifyError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    return value == true;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _categories = await LookupsApi.categories();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _slugify(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<void> _saveCategory({Map<String, dynamic>? current}) async {
    final isEdit = current != null;
    _nameCtrl.text = isEdit ? (current['name'] ?? '').toString() : '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Edit Category' : 'Add Category'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Slug is generated automatically from name',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _notifyError('Category name is required.');
      return;
    }
    final payload = {
      'name': name,
      'slug': _slugify(name),
      'status': 'publish',
    };
    if (payload['slug']!.isEmpty) {
      _notifyError('Unable to generate slug from category name.');
      return;
    }
    try {
      if (isEdit) {
        await LookupsApi.updateCategory((current['id'] as num).toInt(), payload);
      } else {
        await LookupsApi.createCategory(payload);
      }
      await _load();
      if (mounted) {
        setState(() {});
        _notifySuccess(isEdit ? 'Category updated' : 'Category created');
      }
    } catch (e) {
      if (!mounted) return;
      _notifyError('Failed to save category: $e');
    }
  }

  Future<void> _deleteCategory(int id) async {
    final ok = await _confirm('Delete category', 'Are you sure you want to delete this category?');
    if (!ok) return;
    try {
      await LookupsApi.deleteCategory(id);
      await _load();
      if (mounted) {
        setState(() {});
        _notifySuccess('Category deleted');
      }
    } catch (e) {
      if (!mounted) return;
      _notifyError('Failed to delete category: $e');
    }
  }

  Future<void> _bulkDeleteSelected() async {
    final ids = _selectedIds.toList();
    final ok = await _confirm(
      'Delete selected categories',
      'Delete ${ids.length} selected categories?',
    );
    if (!ok) return;
    for (final id in ids) {
      await LookupsApi.deleteCategory(id);
    }
    _selectedIds.clear();
    await _load();
    if (mounted) {
      setState(() {});
      _notifySuccess('${ids.length} categories deleted');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final Map<String, int> categoryCounts = {};
    for (final item in widget.tours) {
      final m = item as Map<String, dynamic>;
      final id = (m['categoryId'] ?? 'uncategorized').toString();
      categoryCounts[id] = (categoryCounts[id] ?? 0) + 1;
    }
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _categories.where((e) {
      final m = e as Map<String, dynamic>;
      final hay =
          '${m['id'] ?? ''} ${m['name'] ?? ''} ${m['slug'] ?? ''} ${m['status'] ?? ''}'.toLowerCase();
      return query.isEmpty || hay.contains(query);
    }).toList();
    final totalPages = math.max(1, (filtered.length / _rowsPerPage).ceil());
    if (_page >= totalPages) _page = totalPages - 1;
    final start = _page * _rowsPerPage;
    final end = math.min(filtered.length, start + _rowsPerPage);
    final pageItems = filtered.sublist(start, end);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader('Tour Categories', 'Manage taxonomy, status, and assignment coverage'),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () => _saveCategory(),
            icon: const Icon(Icons.add),
            label: const Text('Add Category'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() => _page = 0),
                decoration: _searchDecoration('Search categories...'),
              ),
            ),
            const SizedBox(width: 10),
            if (_selectedIds.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _bulkDeleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: Text('Delete Selected (${_selectedIds.length})'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _sectionCard(
          child: _categories.isEmpty
                ? const Text('No categories found.')
                : _tableWrap(DataTable(
                    columns: const [
                      DataColumn(label: Text('')),
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Tours Count')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: pageItems.map<DataRow>((e) {
                      final m = e as Map<String, dynamic>;
                      final id = (m['id'] as num?)?.toInt() ?? 0;
                      final idText = id.toString();
                      return DataRow(
                        cells: [
                          DataCell(
                            Checkbox(
                              value: _selectedIds.contains(id),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _selectedIds.add(id);
                                } else {
                                  _selectedIds.remove(id);
                                }
                              }),
                            ),
                          ),
                          DataCell(_cellText(idText, width: 70)),
                          DataCell(_cellText((m['name'] ?? '').toString(), width: 180)),
                          DataCell(_statusChip((m['status'] ?? '').toString())),
                          DataCell(_cellText('${categoryCounts[idText] ?? 0}', width: 90)),
                          DataCell(
                            SizedBox(
                              width: 200,
                              child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _actionTextButton(
                                  icon: Icons.edit_outlined,
                                  label: 'Edit',
                                  onPressed: () => _saveCategory(current: m),
                                ),
                                _actionTextButton(
                                  icon: Icons.delete_outline,
                                  label: 'Delete',
                                  onPressed: () => _deleteCategory((m['id'] as num).toInt()),
                                  color: const Color(0xFFDC2626),
                                ),
                              ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  )),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Showing ${pageItems.length} of ${filtered.length}'),
            Row(
              children: [
                DropdownButton<int>(
                  value: _rowsPerPage,
                  items: const [10, 20, 50]
                      .map((e) => DropdownMenuItem(value: e, child: Text('$e / page')))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _rowsPerPage = v ?? 10;
                    _page = 0;
                  }),
                ),
                IconButton(
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${_page + 1} / $totalPages'),
                IconButton(
                  onPressed: _page < totalPages - 1 ? () => setState(() => _page++) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class TourAttributesPage extends StatefulWidget {
  const TourAttributesPage({super.key});

  @override
  State<TourAttributesPage> createState() => _TourAttributesPageState();
}

class _TourAttributesPageState extends State<TourAttributesPage> {
  bool _loading = true;
  List<dynamic> _attributes = [];
  final _nameCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _termCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final Set<int> _selectedIds = {};
  bool _hideInDetail = false;
  bool _hideInFilter = false;
  int _rowsPerPage = 10;
  int _page = 0;

  void _notifySuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _notifyError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _confirm(String title, String message) async {
    final value = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    return value == true;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _attributes = await LookupsApi.attributes();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _positionCtrl.dispose();
    _termCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAttribute({Map<String, dynamic>? current}) async {
    final isEdit = current != null;
    _nameCtrl.text = isEdit ? (current['name'] ?? '').toString() : '';
    _positionCtrl.text = isEdit ? (current['positionOrder'] ?? 0).toString() : '0';
    _hideInDetail = isEdit ? current['hideInDetail'] == true : false;
    _hideInFilter = isEdit ? current['hideInFilter'] == true : false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Attribute' : 'Add Attribute'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Attribute name')),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _positionCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Position order'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Higher number means higher priority in filters.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _hideInDetail,
                    onChanged: (v) => setDialogState(() => _hideInDetail = v ?? false),
                    title: const Text('Hide in detail service'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    value: _hideInFilter,
                    onChanged: (v) => setDialogState(() => _hideInFilter = v ?? false),
                    title: const Text('Hide in filter search'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (confirmed != true) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _notifyError('Attribute name is required.');
      return;
    }
    final payload = {
      'name': name,
      'type': (current?['type'] ?? 'Tour Attribute').toString(),
      'positionOrder': int.tryParse(_positionCtrl.text.trim()) ?? 0,
      'hideInDetail': _hideInDetail,
      'hideInFilter': _hideInFilter,
    };
    try {
      if (isEdit) {
        await LookupsApi.updateAttribute((current['id'] as num).toInt(), payload);
      } else {
        await LookupsApi.createAttribute(payload);
      }
      await _load();
      if (mounted) {
        setState(() {});
        _notifySuccess(isEdit ? 'Attribute updated' : 'Attribute created');
      }
    } catch (e) {
      if (!mounted) return;
      _notifyError('Failed to save attribute: $e');
    }
  }

  Future<void> _deleteAttribute(int id) async {
    final ok = await _confirm('Delete attribute', 'Are you sure you want to delete this attribute?');
    if (!ok) return;
    try {
      await LookupsApi.deleteAttribute(id);
      await _load();
      if (mounted) {
        setState(() {});
        _notifySuccess('Attribute deleted');
      }
    } catch (e) {
      if (!mounted) return;
      _notifyError('Failed to delete attribute: $e');
    }
  }

  Future<void> _bulkDeleteSelected() async {
    final ids = _selectedIds.toList();
    final ok = await _confirm(
      'Delete selected attributes',
      'Delete ${ids.length} selected attributes?',
    );
    if (!ok) return;
    for (final id in ids) {
      await LookupsApi.deleteAttribute(id);
    }
    _selectedIds.clear();
    await _load();
    if (mounted) {
      setState(() {});
      _notifySuccess('${ids.length} attributes deleted');
    }
  }

  Future<void> _manageTerms(Map<String, dynamic> attribute) async {
    final attributeId = (attribute['id'] as num).toInt();
    List<dynamic> terms = await LookupsApi.attributeTerms(attributeId);
    _termCtrl.clear();
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Terms - ${attribute['name'] ?? ''}'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _termCtrl,
                        decoration: const InputDecoration(labelText: 'New term name'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final name = _termCtrl.text.trim();
                        if (name.isEmpty) {
                          _notifyError('Term name is required.');
                          return;
                        }
                        await LookupsApi.createAttributeTerm(attributeId, {'name': name});
                        terms = await LookupsApi.attributeTerms(attributeId);
                        _termCtrl.clear();
                        setDialogState(() {});
                        _notifySuccess('Term added');
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 260,
                  child: ListView.builder(
                    itemCount: terms.length,
                    itemBuilder: (_, i) {
                      final t = terms[i] as Map<String, dynamic>;
                      return ListTile(
                        title: Text((t['name'] ?? '').toString()),
                        subtitle: Text('ID: ${t['id']}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await _confirm(
                              'Delete term',
                              'Are you sure you want to delete this term?',
                            );
                            if (!ok) return;
                            await LookupsApi.deleteAttributeTerm((t['id'] as num).toInt());
                            terms = await LookupsApi.attributeTerms(attributeId);
                            setDialogState(() {});
                            _notifySuccess('Term deleted');
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _attributes.where((e) {
      final m = e as Map<String, dynamic>;
      final hay =
          '${m['id'] ?? ''} ${m['name'] ?? ''} ${m['positionOrder'] ?? ''} ${m['type'] ?? ''}'
              .toLowerCase();
      return query.isEmpty || hay.contains(query);
    }).toList();
    final totalPages = math.max(1, (filtered.length / _rowsPerPage).ceil());
    if (_page >= totalPages) _page = totalPages - 1;
    final start = _page * _rowsPerPage;
    final end = math.min(filtered.length, start + _rowsPerPage);
    final pageItems = filtered.sublist(start, end);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader('Tour Attributes', 'Configure reusable tour filters and terms'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() => _page = 0),
                decoration: _searchDecoration('Search attributes...'),
              ),
            ),
            const SizedBox(width: 10),
            if (_selectedIds.isNotEmpty)
              OutlinedButton.icon(
                onPressed: _bulkDeleteSelected,
                icon: const Icon(Icons.delete_outline),
                label: Text('Delete Selected (${_selectedIds.length})'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: () => _saveAttribute(),
            icon: const Icon(Icons.add),
            label: const Text('Add Attribute'),
          ),
        ),
        const SizedBox(height: 10),
        _sectionCard(
          child: _attributes.isEmpty
                ? const Text('No attributes found.')
                : _tableWrap(DataTable(
                    columns: const [
                      DataColumn(label: Text('')),
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Position Order')),
                      DataColumn(label: Text('Detail')),
                      DataColumn(label: Text('Filter')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: pageItems.map<DataRow>((e) {
                      final m = e as Map<String, dynamic>;
                      final id = (m['id'] as num?)?.toInt() ?? 0;
                      return DataRow(
                        cells: [
                          DataCell(
                            Checkbox(
                              value: _selectedIds.contains(id),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _selectedIds.add(id);
                                } else {
                                  _selectedIds.remove(id);
                                }
                              }),
                            ),
                          ),
                          DataCell(_cellText((m['id'] ?? '').toString(), width: 70)),
                          DataCell(_cellText((m['name'] ?? '').toString(), width: 180)),
                          DataCell(_cellText((m['positionOrder'] ?? 0).toString(), width: 120)),
                          DataCell(_cellText((m['hideInDetail'] == true) ? 'Yes' : 'No', width: 90)),
                          DataCell(_cellText((m['hideInFilter'] == true) ? 'Yes' : 'No', width: 90)),
                          DataCell(
                            SizedBox(
                              width: 270,
                              child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _actionTextButton(
                                  icon: Icons.category_outlined,
                                  label: 'Terms',
                                  onPressed: () => _manageTerms(m),
                                ),
                                _actionTextButton(
                                  icon: Icons.edit_outlined,
                                  label: 'Edit',
                                  onPressed: () => _saveAttribute(current: m),
                                ),
                                _actionTextButton(
                                  icon: Icons.delete_outline,
                                  label: 'Delete',
                                  onPressed: () => _deleteAttribute(id),
                                  color: const Color(0xFFDC2626),
                                ),
                              ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  )),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Showing ${pageItems.length} of ${filtered.length}'),
            Row(
              children: [
                DropdownButton<int>(
                  value: _rowsPerPage,
                  items: const [10, 20, 50]
                      .map((e) => DropdownMenuItem(value: e, child: Text('$e / page')))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _rowsPerPage = v ?? 10;
                    _page = 0;
                  }),
                ),
                IconButton(
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${_page + 1} / $totalPages'),
                IconButton(
                  onPressed: _page < totalPages - 1 ? () => setState(() => _page++) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class TourAvailabilityCalendarPage extends StatefulWidget {
  const TourAvailabilityCalendarPage({super.key, required this.tours});

  final List<dynamic> tours;

  @override
  State<TourAvailabilityCalendarPage> createState() => _TourAvailabilityCalendarPageState();
}

class _TourAvailabilityCalendarPageState extends State<TourAvailabilityCalendarPage> {
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String _search = '';
  int? _selectedTourId;
  List<TourBooking> _bookings = [];

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    _bookings = await TourBookingsApi.getMyBookings();
    if (mounted) setState(() {});
  }

  List<DateTime> _monthCells(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    final leading = first.weekday % 7;
    final total = leading + last.day;
    final trailing = (7 - (total % 7)) % 7;
    final all = <DateTime>[];
    for (int i = 0; i < leading; i++) {
      all.add(first.subtract(Duration(days: leading - i)));
    }
    for (int d = 1; d <= last.day; d++) {
      all.add(DateTime(month.year, month.month, d));
    }
    for (int i = 1; i <= trailing; i++) {
      all.add(last.add(Duration(days: i)));
    }
    return all;
  }

  @override
  Widget build(BuildContext context) {
    final tours = widget.tours.where((item) {
      final m = item as Map<String, dynamic>;
      final title = (m['title'] ?? '').toString().toLowerCase();
      return _search.isEmpty || title.contains(_search.toLowerCase());
    }).toList();

    final cells = _monthCells(_visibleMonth);
    final previewTours = tours.take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader('Tours Availability Calendar', 'Select a tour to highlight all NO-BOOKING days'),
        const SizedBox(height: 14),
        _sectionCard(
          child: Row(
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: _searchDecoration('Search by name'),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Search'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(88, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              const Spacer(),
              Text(
                'Showing 1 - ${tours.length.clamp(1, 15)} of ${tours.length} spaces',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Availability', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 300,
                    height: 360,
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Text(
                            _selectedTourId == null
                                ? 'Select a tour from list'
                                : 'Selected tour ID: $_selectedTourId',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.separated(
                            itemCount: previewTours.length,
                            separatorBuilder: (_, _) => const Divider(height: 10),
                            itemBuilder: (_, i) {
                              final m = previewTours[i] as Map<String, dynamic>;
                              final rawId = m['id'];
                              final id = rawId is num
                                  ? rawId.toInt()
                                  : int.tryParse(rawId?.toString() ?? '');
                              final selected = id != null && _selectedTourId == id;
                              final status = (m['status'] ?? 'publish').toString();
                              return InkWell(
                                onTap: id == null ? null : () => setState(() => _selectedTourId = id),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: selected ? const Color(0xFFDBEAFE) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                        size: 14,
                                        color: selected ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '#${m['id'] ?? ''} - ${(m['title'] ?? '').toString()}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: selected
                                                      ? const Color(0xFF1D4ED8)
                                                      : const Color(0xFF0369A1),
                                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            _statusChip(status),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Spacer(),
                            Text(
                              DateFormat('MMM-yyyy').format(_visibleMonth),
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => setState(() {
                                _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
                              }),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            IconButton(
                              onPressed: () => setState(() {
                                _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
                              }),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: const [
                            Expanded(child: Center(child: Text('Mon'))),
                            Expanded(child: Center(child: Text('Tue'))),
                            Expanded(child: Center(child: Text('Wed'))),
                            Expanded(child: Center(child: Text('Thu'))),
                            Expanded(child: Center(child: Text('Fri'))),
                            Expanded(child: Center(child: Text('Sat'))),
                            Expanded(child: Center(child: Text('Sun'))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            childAspectRatio: 1.9,
                          ),
                          itemCount: cells.length,
                          itemBuilder: (_, index) {
                            final day = cells[index];
                            final inMonth = day.month == _visibleMonth.month;
                            final dayStart = DateTime(day.year, day.month, day.day);
                            bool hasBooking = false;
                            if (_selectedTourId != null) {
                              for (final b in _bookings) {
                                if (b.tourId == _selectedTourId) {
                                  final start = DateTime(b.startDate.year, b.startDate.month, b.startDate.day);
                                  final end = DateTime(b.endDate.year, b.endDate.month, b.endDate.day);
                                  if (!dayStart.isBefore(start) && !dayStart.isAfter(end)) {
                                    hasBooking = true;
                                    break;
                                  }
                                }
                              }
                            }
                            final highlightNoBooking = _selectedTourId != null && inMonth && !hasBooking;
                            return Container(
                              margin: const EdgeInsets.all(2),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              decoration: BoxDecoration(
                                color: highlightNoBooking
                                    ? const Color(0xFFBBF7D0)
                                    : inMonth
                                        ? const Color(0xFF2196F3)
                                        : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: highlightNoBooking
                                      ? const Color(0xFF16A34A)
                                      : const Color(0xFFE2E8F0),
                                  width: highlightNoBooking ? 1.2 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: inMonth ? Colors.white : const Color(0xFF64748B),
                                    ),
                                  ),
                                  if (highlightNoBooking)
                                    const Text(
                                      'AVAILABLE',
                                      style: TextStyle(
                                        fontSize: 7,
                                        color: Color(0xFF14532D),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  else if (inMonth)
                                    const Text('Booked/NA', style: TextStyle(fontSize: 7, color: Colors.white)),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TourBookingCalendarPage extends StatefulWidget {
  const TourBookingCalendarPage({super.key});

  @override
  State<TourBookingCalendarPage> createState() => _TourBookingCalendarPageState();
}

class _TourBookingCalendarPageState extends State<TourBookingCalendarPage> {
  bool _loading = true;
  List<TourBooking> _bookings = [];
  List<Map<String, dynamic>> _categoryRows = [];
  final Map<int, String> _tourCategoryByTourId = {};
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all';
  int _rowsPerPage = 10;
  int _page = 0;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String _categoryFilter = 'all';
  final Set<int> _selectedBookingIds = {};

  void _toggleSelectAll(List<TourBooking> source, bool selected) {
    setState(() {
      if (selected) {
        _selectedBookingIds
          ..clear()
          ..addAll(source.map((b) => b.id));
      } else {
        _selectedBookingIds.clear();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _bookings = await TourBookingsApi.getMyBookings();
      final categories = await LookupsApi.categories();
      final tours = await ToursApi.list();
      _categoryRows = categories
          .map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e))
          .toList();
      final tourRows = tours
          .map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e))
          .toList();
      _tourCategoryByTourId.clear();
      for (final tour in tourRows) {
        final rawTourId = tour['id'];
        final rawCategoryId = tour['categoryId'];
        final tourId = rawTourId is num ? rawTourId.toInt() : int.tryParse(rawTourId?.toString() ?? '');
        final categoryId = rawCategoryId?.toString();
        if (tourId != null && categoryId != null && categoryId.isNotEmpty) {
          _tourCategoryByTourId[tourId] = categoryId;
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<DateTime, List<TourBooking>> _bookingsByDay(List<TourBooking> source) {
    final map = <DateTime, List<TourBooking>>{};
    for (final booking in source) {
      DateTime day = DateTime(booking.startDate.year, booking.startDate.month, booking.startDate.day);
      final end = DateTime(booking.endDate.year, booking.endDate.month, booking.endDate.day);
      while (!day.isAfter(end)) {
        map.putIfAbsent(day, () => []).add(booking);
        day = day.add(const Duration(days: 1));
      }
    }
    return map;
  }

  List<DateTime> _buildCalendarCells(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    final leading = first.weekday % 7;
    final total = leading + last.day;
    final trailing = (7 - (total % 7)) % 7;
    final all = <DateTime>[];
    for (int i = 0; i < leading; i++) {
      all.add(first.subtract(Duration(days: leading - i)));
    }
    for (int d = 1; d <= last.day; d++) {
      all.add(DateTime(month.year, month.month, d));
    }
    for (int i = 1; i <= trailing; i++) {
      all.add(last.add(Duration(days: i)));
    }
    return all;
  }

  Future<void> _showDayBookingsDialog(DateTime day, List<TourBooking> bookings) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bookings - ${DateFormat('MMM dd, yyyy').format(day)}'),
        content: SizedBox(
          width: 520,
          child: bookings.isEmpty
              ? const Text('No bookings for this day.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: bookings.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (_, i) {
                    final b = bookings[i];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.tourTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('MMM dd').format(b.startDate)} - ${DateFormat('MMM dd').format(b.endDate)}',
                        ),
                        const SizedBox(height: 4),
                        _statusChip(b.status),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _bookings.where((b) {
      final q = query.isEmpty ||
          b.tourTitle.toLowerCase().contains(query) ||
          b.status.toLowerCase().contains(query);
      final s = _statusFilter == 'all' || b.status.toLowerCase() == _statusFilter;
      final categoryId = _tourCategoryByTourId[b.tourId];
      final c = _categoryFilter == 'all' || categoryId == _categoryFilter;
      return q && s && c;
    }).toList();
    final totalPages = math.max(1, (filtered.length / _rowsPerPage).ceil());
    if (_page >= totalPages) _page = totalPages - 1;
    final start = _page * _rowsPerPage;
    final end = math.min(filtered.length, start + _rowsPerPage);
    final pageItems = filtered.sublist(start, end);
    final byDay = _bookingsByDay(filtered);
    final cells = _buildCalendarCells(_visibleMonth);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader('Tour Booking Calendar', 'Track bookings by status and date range'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() => _page = 0),
                decoration: _searchDecoration('Search bookings...'),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                initialValue: _categoryFilter,
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Category', isDense: true),
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('--All Category--')),
                  ..._categoryRows.map(
                    (row) => DropdownMenuItem(
                      value: (row['id'] ?? '').toString(),
                      child: Text((row['name'] ?? row['title'] ?? '').toString()),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() {
                  _categoryFilter = v ?? 'all';
                  _page = 0;
                }),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                initialValue: _statusFilter,
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Status', isDense: true),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                  DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                ],
                onChanged: (v) => setState(() {
                  _statusFilter = v ?? 'all';
                  _page = 0;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 280,
                    height: 360,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: filtered.isNotEmpty &&
                                  _selectedBookingIds.length == filtered.length,
                              onChanged: (v) => _toggleSelectAll(filtered, v == true),
                            ),
                            const Text('Check all'),
                          ],
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.separated(
                            itemCount: pageItems.length,
                            separatorBuilder: (_, _) => const Divider(height: 8),
                            itemBuilder: (_, i) {
                              final b = pageItems[i];
                              final selected = _selectedBookingIds.contains(b.id);
                              return InkWell(
                                onTap: () => setState(() {
                                  _selectedBookingIds
                                    ..clear()
                                    ..add(b.id);
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: selected ? const Color(0xFFE0F2FE) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Checkbox(
                                        value: selected,
                                        onChanged: (v) => setState(() {
                                          if (v == true) {
                                            _selectedBookingIds.add(b.id);
                                          } else {
                                            _selectedBookingIds.remove(b.id);
                                          }
                                        }),
                                      ),
                                      Expanded(
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '#${b.id} - ${b.tourTitle}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: selected
                                                      ? const Color(0xFF1D4ED8)
                                                      : const Color(0xFF0369A1),
                                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            _statusChip(b.status),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Spacer(),
                            Text(
                              DateFormat('MMM-yyyy').format(_visibleMonth),
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => setState(() {
                                _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
                              }),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            IconButton(
                              onPressed: () => setState(() {
                                _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
                              }),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                        Row(
                          children: const [
                            Expanded(child: Center(child: Text('Sun'))),
                            Expanded(child: Center(child: Text('Mon'))),
                            Expanded(child: Center(child: Text('Tue'))),
                            Expanded(child: Center(child: Text('Wed'))),
                            Expanded(child: Center(child: Text('Thu'))),
                            Expanded(child: Center(child: Text('Fri'))),
                            Expanded(child: Center(child: Text('Sat'))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            childAspectRatio: 2.15,
                          ),
                          itemCount: cells.length,
                          itemBuilder: (_, index) {
                            final day = cells[index];
                            final dayKey = DateTime(day.year, day.month, day.day);
                            final list = byDay[dayKey] ?? [];
                            final inMonth = day.month == _visibleMonth.month;
                            bool activeDay = false;
                            for (final b in filtered) {
                              if (!_selectedBookingIds.contains(b.id)) continue;
                              final start = DateTime(b.startDate.year, b.startDate.month, b.startDate.day);
                              final end = DateTime(b.endDate.year, b.endDate.month, b.endDate.day);
                              if (!day.isBefore(start) && !day.isAfter(end)) {
                                activeDay = true;
                                break;
                              }
                            }
                            return InkWell(
                              onTap: () => _showDayBookingsDialog(day, list),
                              child: Container(
                                margin: const EdgeInsets.all(2),
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: activeDay
                                      ? const Color(0xFFBBF7D0)
                                      : inMonth
                                          ? Colors.white
                                          : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${day.day}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: inMonth ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    if (list.isNotEmpty)
                                      Text(
                                        '${list.length}x',
                                        style: const TextStyle(fontSize: 9, color: Color(0xFF1E3A8A)),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Showing ${pageItems.length} of ${filtered.length}'),
            Row(
              children: [
                DropdownButton<int>(
                  value: _rowsPerPage,
                  items: const [10, 20, 50]
                      .map((e) => DropdownMenuItem(value: e, child: Text('$e / page')))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _rowsPerPage = v ?? 10;
                    _page = 0;
                  }),
                ),
                IconButton(
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${_page + 1} / $totalPages'),
                IconButton(
                  onPressed: _page < totalPages - 1 ? () => setState(() => _page++) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class TourRecoveryPage extends StatefulWidget {
  const TourRecoveryPage({super.key});

  @override
  State<TourRecoveryPage> createState() => _TourRecoveryPageState();
}

class _TourRecoveryPageState extends State<TourRecoveryPage> {
  bool _loading = true;
  List<dynamic> _deletedTours = [];
  final _searchCtrl = TextEditingController();
  final Set<int> _selectedIds = {};
  int _rowsPerPage = 10;
  int _page = 0;

  void _notifySuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _confirmAction(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    return result == true;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _deletedTours = await ToursApi.deletedTours();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore(int id) async {
    final ok = await _confirmAction('Restore tour', 'Do you want to restore this tour?');
    if (!ok) return;
    await ToursApi.restoreTour(id);
    await _load();
    if (mounted) {
      setState(() {});
      _notifySuccess('Tour restored');
    }
  }

  Future<void> _forceDelete(int id) async {
    final ok = await _confirmAction(
      'Delete permanently',
      'Do you want to permanently delete this tour? This cannot be undone.',
    );
    if (!ok) return;
    await ToursApi.forceDeleteTour(id);
    await _load();
    if (mounted) {
      setState(() {});
      _notifySuccess('Tour deleted permanently');
    }
  }

  Future<void> _bulkRestore() async {
    final ids = _selectedIds.toList();
    final ok = await _confirmAction('Restore selected', 'Restore ${ids.length} selected tours?');
    if (!ok) return;
    for (final id in ids) {
      await ToursApi.restoreTour(id);
    }
    _selectedIds.clear();
    await _load();
    if (mounted) {
      setState(() {});
      _notifySuccess('${ids.length} tours restored');
    }
  }

  Future<void> _bulkForceDelete() async {
    final ids = _selectedIds.toList();
    final ok = await _confirmAction(
      'Delete selected permanently',
      'Permanently delete ${ids.length} selected tours? This cannot be undone.',
    );
    if (!ok) return;
    for (final id in ids) {
      await ToursApi.forceDeleteTour(id);
    }
    _selectedIds.clear();
    await _load();
    if (mounted) {
      setState(() {});
      _notifySuccess('${ids.length} tours deleted permanently');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = _deletedTours.where((e) {
      final m = e as Map<String, dynamic>;
      final hay = '${m['id'] ?? ''} ${m['title'] ?? ''} ${m['deletedAt'] ?? ''}'.toLowerCase();
      return query.isEmpty || hay.contains(query);
    }).toList();
    final totalPages = math.max(1, (filtered.length / _rowsPerPage).ceil());
    if (_page >= totalPages) _page = totalPages - 1;
    final start = _page * _rowsPerPage;
    final end = math.min(filtered.length, start + _rowsPerPage);
    final pageItems = filtered.sublist(start, end);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _pageHeader('Tour Recovery', 'Restore or permanently delete archived tours'),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() => _page = 0),
                decoration: _searchDecoration('Search deleted tours...'),
              ),
            ),
            const SizedBox(width: 10),
            if (_selectedIds.isNotEmpty) ...[
              OutlinedButton(
                onPressed: _bulkRestore,
                child: Text('Restore Selected (${_selectedIds.length})'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _bulkForceDelete,
                child: const Text('Delete Selected'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        _sectionCard(
          child: _deletedTours.isEmpty
                ? const Text('No deleted tours found.')
                : _tableWrap(DataTable(
                    columns: const [
                      DataColumn(label: Text('')),
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Title')),
                      DataColumn(label: Text('Deleted At')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: pageItems.map<DataRow>((e) {
                      final m = e as Map<String, dynamic>;
                      final id = (m['id'] as num?)?.toInt() ?? 0;
                      return DataRow(
                        cells: [
                          DataCell(
                            Checkbox(
                              value: _selectedIds.contains(id),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _selectedIds.add(id);
                                } else {
                                  _selectedIds.remove(id);
                                }
                              }),
                            ),
                          ),
                          DataCell(_cellText((m['id'] ?? '').toString(), width: 70)),
                          DataCell(_cellText((m['title'] ?? '').toString(), width: 220)),
                          DataCell(_cellText((m['deletedAt'] ?? '').toString(), width: 160)),
                          DataCell(
                            SizedBox(
                              width: 250,
                              child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _actionTextButton(
                                  icon: Icons.restore,
                                  label: 'Restore',
                                  onPressed: () => _restore(id),
                                  color: const Color(0xFF059669),
                                ),
                                _actionTextButton(
                                  icon: Icons.delete_forever_outlined,
                                  label: 'Delete Permanently',
                                  onPressed: () => _forceDelete(id),
                                  color: const Color(0xFFDC2626),
                                ),
                              ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  )),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Showing ${pageItems.length} of ${filtered.length}'),
            Row(
              children: [
                DropdownButton<int>(
                  value: _rowsPerPage,
                  items: const [10, 20, 50]
                      .map((e) => DropdownMenuItem(value: e, child: Text('$e / page')))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _rowsPerPage = v ?? 10;
                    _page = 0;
                  }),
                ),
                IconButton(
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${_page + 1} / $totalPages'),
                IconButton(
                  onPressed: _page < totalPages - 1 ? () => setState(() => _page++) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
