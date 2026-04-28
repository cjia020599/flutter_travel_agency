import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_travel_agency/api/lookups_api.dart';
import 'package:flutter_travel_agency/api/tours_api.dart';
import 'package:flutter_travel_agency/features/admin/tour_management/mappers/tour_mapper.dart';
import 'package:flutter_travel_agency/features/admin/tour_management/models/tour_draft.dart';
import 'package:flutter_travel_agency/features/admin/tour_management/validators/tour_payload_validator.dart';
import 'package:flutter_travel_agency/features/admin/shared/widgets/admin_rich_text_editor.dart';
import 'package:flutter_travel_agency/services/image_upload_service.dart';
import 'package:flutter_travel_agency/widgets/car_location_map_picker.dart';
import 'package:flutter_travel_agency/widgets/image_upload_widget.dart';

class TourFormPage extends StatefulWidget {
  const TourFormPage({super.key, required this.onCreated, this.itemToEdit});

  final VoidCallback onCreated;
  final Map<String, dynamic>? itemToEdit;

  @override
  State<TourFormPage> createState() => _TourFormPageState();
}

class _TourFormPageState extends State<TourFormPage> {
  final _formKey = GlobalKey<FormState>();
  static final _moneyInputFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*\.?\d{0,2}$'),
  );
  static const _availabilityOptions = <MapEntry<String, String>>[
    MapEntry('always', 'Always available'),
  ];

  final _title = TextEditingController();
  final _content = TextEditingController();
  final _slug = TextEditingController();
  final _price = TextEditingController();
  final _salePrice = TextEditingController();
  final _realTourAddress = TextEditingController();
  final _duration = TextEditingController();
  final _minPeople = TextEditingController();
  final _maxPeople = TextEditingController();
  final _metaTitle = TextEditingController();
  final _metaDescription = TextEditingController();
  String? _imageUrl;
  String? _imagePublicId;
  String? _bannerImageUrl;
  String? _bannerImagePublicId;
  final List<String> _galleryUrls = [];
  bool _galleryUploading = false;
  bool _loading = false;
  String _status = 'publish';
  String _availability = 'always';
  bool _isFeatured = false;
  bool _serviceFeeEnabled = false;
  bool _fixedDateEnabled = false;
  bool _openHoursEnabled = false;
  double? _mapLat;
  double? _mapLng;
  String? _locationId;
  String? _categoryId;
  List<Map<String, dynamic>> _locationRows = [];
  List<Map<String, dynamic>> _categoryRows = [];
  List<Map<String, dynamic>> _attributeRows = [];
  final Set<String> _selectedAttributeIds = {};
  List<Map<String, String>> _faqs = [];
  List<Map<String, String>> _includeItems = [];
  List<Map<String, String>> _excludeItems = [];
  List<Map<String, String>> _itineraryItems = [];
  List<Map<String, String>> _surroundingsEducation = [];
  List<Map<String, String>> _surroundingsHealth = [];
  List<Map<String, String>> _surroundingsTransportation = [];

  @override
  void initState() {
    super.initState();
    if (widget.itemToEdit != null) {
      final draft = TourMapper.fromApi(widget.itemToEdit!);
      _title.text = draft.title;
      _content.text = draft.content;
      _slug.text = draft.slug;
      _price.text = draft.price;
      _salePrice.text = draft.salePrice;
      _realTourAddress.text = draft.realTourAddress;
      _duration.text = draft.duration;
      _minPeople.text = draft.minPeople;
      _maxPeople.text = draft.maxPeople;
      _metaTitle.text = draft.metaTitle;
      _metaDescription.text = draft.metaDescription;
      _imageUrl = draft.imageUrl;
      _imagePublicId = draft.imagePublicId;
      _bannerImageUrl = draft.bannerImageUrl;
      _bannerImagePublicId = draft.bannerImagePublicId;
      _galleryUrls
        ..clear()
        ..addAll(draft.gallery);
      _status = draft.status;
      _availability = draft.availability;
      _isFeatured = draft.isFeatured;
      _serviceFeeEnabled = draft.serviceFeeEnabled;
      _fixedDateEnabled = draft.fixedDateEnabled;
      _openHoursEnabled = draft.openHoursEnabled;
      _mapLat = draft.mapLat;
      _mapLng = draft.mapLng;
      _locationId = draft.locationId;
      _categoryId = draft.categoryId;
      _selectedAttributeIds
        ..clear()
        ..addAll(draft.attributeIds);
      _faqs = List.of(draft.faqs);
      _includeItems = List.of(draft.includeItems);
      _excludeItems = List.of(draft.excludeItems);
      _itineraryItems = List.of(draft.itineraryItems);
      _surroundingsEducation = List.of(draft.surroundingsEducation);
      _surroundingsHealth = List.of(draft.surroundingsHealth);
      _surroundingsTransportation = List.of(draft.surroundingsTransportation);
    }
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final locations = await LookupsApi.locations();
      final categories = await LookupsApi.categories();
      final attributes = await LookupsApi.attributes();
      if (!mounted) return;
      setState(() {
        _locationRows = locations
            .map(
              (e) =>
                  e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e),
            )
            .toList();
        _categoryRows = categories
            .map(
              (e) =>
                  e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e),
            )
            .toList();
        _attributeRows = attributes
            .map(
              (e) =>
                  e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e),
            )
            .toList();
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _slug.dispose();
    _price.dispose();
    _salePrice.dispose();
    _realTourAddress.dispose();
    _duration.dispose();
    _minPeople.dispose();
    _maxPeople.dispose();
    _metaTitle.dispose();
    _metaDescription.dispose();
    super.dispose();
  }

  void _generateSlug() {
    _slug.text = _slugify(_title.text);
  }

  String _slugify(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<void> _pickAndUploadGalleryImages() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      withData: true,
      allowedExtensions: const ['png', 'jpg', 'jpeg', 'gif', 'webp'],
    );
    if (result == null || result.files.isEmpty) return;

    setState(() => _galleryUploading = true);
    final uploadedUrls = <String>[];
    final failedFiles = <String>[];

    for (final file in result.files) {
      try {
        final upload = await ImageUploadService.uploadImage(file);
        final url = (upload['url'] ?? '').trim();
        if (url.isNotEmpty) {
          uploadedUrls.add(url);
        } else {
          failedFiles.add(file.name);
        }
      } catch (_) {
        failedFiles.add(file.name);
      }
    }

    if (!mounted) return;
    setState(() {
      _galleryUploading = false;
      _galleryUrls.addAll(uploadedUrls);
      _galleryUrls.retainWhere((e) => e.trim().isNotEmpty);
    });

    final uploadedCount = uploadedUrls.length;
    final failedCount = failedFiles.length;
    if (uploadedCount > 0 && failedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Uploaded $uploadedCount image(s) to gallery.')),
      );
    } else if (uploadedCount > 0 && failedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Uploaded $uploadedCount image(s), $failedCount failed.',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No images were uploaded.')));
    }
  }

  TourDraft _buildDraft() {
    return TourDraft(
      id: widget.itemToEdit?['id'],
      title: _title.text,
      content: _content.text,
      slug: _slug.text.isEmpty ? _slugify(_title.text) : _slug.text,
      price: _price.text,
      salePrice: _salePrice.text,
      realTourAddress: _realTourAddress.text,
      imageUrl: _imageUrl,
      imagePublicId: _imagePublicId,
      status: _status,
      availability: _availability,
      isFeatured: _isFeatured,
      serviceFeeEnabled: _serviceFeeEnabled,
      fixedDateEnabled: _fixedDateEnabled,
      openHoursEnabled: _openHoursEnabled,
      metaTitle: _metaTitle.text,
      metaDescription: _metaDescription.text,
      mapLat: _mapLat,
      mapLng: _mapLng,
      locationId: _locationId,
      categoryId: _categoryId,
      duration: _duration.text,
      minPeople: _minPeople.text,
      maxPeople: _maxPeople.text,
      attributeIds: _selectedAttributeIds.toList(),
      faqs: _faqs,
      includeItems: _includeItems,
      excludeItems: _excludeItems,
      itineraryItems: _itineraryItems,
      surroundingsEducation: _surroundingsEducation,
      surroundingsHealth: _surroundingsHealth,
      surroundingsTransportation: _surroundingsTransportation,
      bannerImageUrl: _bannerImageUrl,
      bannerImagePublicId: _bannerImagePublicId,
      gallery: _galleryUrls,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_slug.text.trim().isEmpty) _generateSlug();

    final draft = _buildDraft();
    final errors = TourPayloadValidator.validate(draft);
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errors.first)));
      return;
    }

    setState(() => _loading = true);
    try {
      final body = TourMapper.toApi(draft);
      if (widget.itemToEdit != null) {
        await ToursApi.update(widget.itemToEdit!['id'], body);
      } else {
        await ToursApi.create(body);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.itemToEdit != null ? 'Tour updated' : 'Tour created',
          ),
        ),
      );
      widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 28),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _dynamicRows({
    required String title,
    required List<Map<String, String>> rows,
    required VoidCallback onAdd,
  }) {
    return _card(title, [
      if (rows.isEmpty) const Text('No items yet.'),
      ...rows.asMap().entries.map((entry) {
        final index = entry.key;
        final row = entry.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: row['title'] ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => rows[index]['title'] = value,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: row['content'] ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => rows[index]['content'] = value,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => rows.removeAt(index)),
                icon: const Icon(Icons.delete, color: Colors.redAccent),
              ),
            ],
          ),
        );
      }),
      Align(
        alignment: Alignment.centerRight,
        child: ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add item'),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final mapInitial = (_mapLat != null && _mapLng != null)
        ? LatLng(_mapLat!, _mapLng!)
        : null;
    final selectedAttributes = _attributeRows.where((row) {
      final id = (row['id'] ?? '').toString();
      return _selectedAttributeIds.contains(id);
    }).toList();

    final mainForm = Form(
      key: _formKey,
      child: Column(
        children: [
          _card('Tour Content', [
            const Text('Title', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Tour Name',
              ),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
              onChanged: (_) {
                _generateSlug();
              },
            ),
            const SizedBox(height: 16),
            AdminRichTextEditor(
              controller: _content,
              label: 'Content',
              hintText: 'Write tour description...',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _categoryId,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('-- Please Select --'),
                ),
                ..._categoryRows.map(
                  (row) => DropdownMenuItem(
                    value: row['id']?.toString(),
                    child: Text((row['name'] ?? row['title'] ?? '').toString()),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final temp = Set<String>.from(_selectedAttributeIds);
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => StatefulBuilder(
                    builder: (context, setDialogState) => AlertDialog(
                      title: const Text('Select Attributes'),
                      content: SizedBox(
                        width: 520,
                        child: _attributeRows.isEmpty
                            ? const Text('No attributes available.')
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _attributeRows.length,
                                itemBuilder: (_, i) {
                                  final row = _attributeRows[i];
                                  final id = (row['id'] ?? '').toString();
                                  return CheckboxListTile(
                                    value: temp.contains(id),
                                    onChanged: (v) => setDialogState(() {
                                      if (v == true) {
                                        temp.add(id);
                                      } else {
                                        temp.remove(id);
                                      }
                                    }),
                                    title: Text((row['name'] ?? '').toString()),
                                    subtitle: Text(
                                      'Order: ${(row['positionOrder'] ?? 0).toString()}',
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    contentPadding: EdgeInsets.zero,
                                  );
                                },
                              ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  ),
                );
                if (ok == true && mounted) {
                  setState(() {
                    _selectedAttributeIds
                      ..clear()
                      ..addAll(temp);
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Attributes',
                  border: OutlineInputBorder(),
                ),
                child: selectedAttributes.isEmpty
                    ? const Text('Select attributes')
                    : Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: selectedAttributes
                            .map(
                              (row) => Chip(
                                label: Text((row['name'] ?? '').toString()),
                                onDeleted: () {
                                  setState(() {
                                    _selectedAttributeIds.remove(
                                      (row['id'] ?? '').toString(),
                                    );
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _duration,
                    decoration: const InputDecoration(
                      labelText: 'Duration',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _minPeople,
                    decoration: const InputDecoration(
                      labelText: 'Tour Min People',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _maxPeople,
                    decoration: const InputDecoration(
                      labelText: 'Tour Max People',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ]),
          _dynamicRows(
            title: 'FAQs',
            rows: _faqs,
            onAdd: () =>
                setState(() => _faqs.add({'title': '', 'content': ''})),
          ),
          _dynamicRows(
            title: 'Include',
            rows: _includeItems,
            onAdd: () =>
                setState(() => _includeItems.add({'title': '', 'content': ''})),
          ),
          _dynamicRows(
            title: 'Exclude',
            rows: _excludeItems,
            onAdd: () =>
                setState(() => _excludeItems.add({'title': '', 'content': ''})),
          ),
          _dynamicRows(
            title: 'Itinerary',
            rows: _itineraryItems,
            onAdd: () => setState(
              () => _itineraryItems.add({'title': '', 'content': ''}),
            ),
          ),
          _card('Tour Locations', [
            DropdownButtonFormField<String?>(
              initialValue: _locationId,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('-- Please Select --'),
                ),
                ..._locationRows.map(
                  (l) => DropdownMenuItem(
                    value: l['id']?.toString(),
                    child: Text(l['name']?.toString() ?? ''),
                  ),
                ),
              ],
              onChanged: (v) => setState(() => _locationId = v),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _realTourAddress,
              decoration: const InputDecoration(
                labelText: 'Real tour address',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: CarLocationMapPicker(
                key: ValueKey('map_${_mapLat}_$_mapLng'),
                initial: mapInitial,
                onPick: (p) => setState(() {
                  _mapLat = p.latitude;
                  _mapLng = p.longitude;
                }),
              ),
            ),
          ]),
          _dynamicRows(
            title: 'Surroundings Education',
            rows: _surroundingsEducation,
            onAdd: () => setState(
              () => _surroundingsEducation.add({'title': '', 'content': ''}),
            ),
          ),
          _dynamicRows(
            title: 'Surroundings Health',
            rows: _surroundingsHealth,
            onAdd: () => setState(
              () => _surroundingsHealth.add({'title': '', 'content': ''}),
            ),
          ),
          _dynamicRows(
            title: 'Surroundings Transportation',
            rows: _surroundingsTransportation,
            onAdd: () => setState(
              () =>
                  _surroundingsTransportation.add({'title': '', 'content': ''}),
            ),
          ),
          _card('Pricing', [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [_moneyInputFormatter],
                    validator: (v) =>
                        (v?.trim().isEmpty ?? true) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: TextFormField(
                    controller: _salePrice,
                    decoration: const InputDecoration(
                      labelText: 'Sale Price',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [_moneyInputFormatter],
                  ),
                ),
              ],
            ),
          ]),
          _card('Feature Image', [
            ImageUploadWidget(
              initialImageUrl: _imageUrl,
              initialImagePublicId: _imagePublicId,
              onImageSelected: (url, id) => setState(() {
                _imageUrl = url;
                _imagePublicId = id;
              }),
            ),
          ]),
          _card('Banner Image', [
            ImageUploadWidget(
              initialImageUrl: _bannerImageUrl,
              initialImagePublicId: _bannerImagePublicId,
              onImageSelected: (url, id) => setState(() {
                _bannerImageUrl = url;
                _bannerImagePublicId = id;
              }),
            ),
            const SizedBox(height: 14),
            const Text(
              'Gallery',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _galleryUrls
                  .asMap()
                  .entries
                  .map(
                    (e) => Chip(
                      label: Text('Image ${e.key + 1}'),
                      onDeleted: () =>
                          setState(() => _galleryUrls.removeAt(e.key)),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _galleryUploading
                    ? null
                    : _pickAndUploadGalleryImages,
                icon: _galleryUploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.collections),
                label: Text(
                  _galleryUploading
                      ? 'Uploading gallery...'
                      : 'Upload Gallery Images',
                ),
              ),
            ),
          ]),
          _card('Search Engine', [
            TextFormField(
              controller: _metaTitle,
              decoration: const InputDecoration(
                labelText: 'Meta title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _metaDescription,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Meta description',
                border: OutlineInputBorder(),
              ),
            ),
          ]),
        ],
      ),
    );

    final sidebar = Column(
      children: [
        _card('Publish', [
          RadioListTile<String>(
            title: const Text('Publish'),
            value: 'publish',
            groupValue: _status,
            onChanged: (v) => setState(() => _status = v!),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<String>(
            title: const Text('Draft'),
            value: 'draft',
            groupValue: _status,
            onChanged: (v) => setState(() => _status = v!),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ]),
        _card('Tour Featured', [
          CheckboxListTile(
            title: const Text('Enable featured'),
            value: _isFeatured,
            onChanged: (v) => setState(() => _isFeatured = v ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ]),
        _card('Availability', [
          SwitchListTile(
            value: _fixedDateEnabled,
            onChanged: (v) => setState(() => _fixedDateEnabled = v),
            title: const Text('Enable fixed date'),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: _openHoursEnabled,
            onChanged: (v) => setState(() => _openHoursEnabled = v),
            title: const Text('Enable open hours'),
            contentPadding: EdgeInsets.zero,
          ),
          DropdownButtonFormField<String>(
            initialValue: _availability,
            decoration: const InputDecoration(
              labelText: 'Default State',
              border: OutlineInputBorder(),
            ),
            items: _availabilityOptions
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _availability = v ?? 'always'),
          ),
        ]),
        _card('Service fee', [
          SwitchListTile(
            value: _serviceFeeEnabled,
            onChanged: (v) => setState(() => _serviceFeeEnabled = v),
            title: const Text('Enable service fee'),
            contentPadding: EdgeInsets.zero,
          ),
        ]),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: mainForm),
              const SizedBox(width: 24),
              Expanded(flex: 3, child: sidebar),
            ],
          );
        }
        return Column(children: [mainForm, sidebar]);
      },
    );
  }
}
