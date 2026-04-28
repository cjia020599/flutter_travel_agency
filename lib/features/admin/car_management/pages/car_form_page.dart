import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_travel_agency/api/cars_api.dart';
import 'package:flutter_travel_agency/api/lookups_api.dart';
import 'package:flutter_travel_agency/features/admin/car_management/mappers/car_mapper.dart';
import 'package:flutter_travel_agency/features/admin/car_management/models/car_draft.dart';
import 'package:flutter_travel_agency/features/admin/car_management/validators/car_payload_validator.dart';
import 'package:flutter_travel_agency/features/admin/shared/widgets/admin_rich_text_editor.dart';
import 'package:flutter_travel_agency/services/image_upload_service.dart';
import 'package:flutter_travel_agency/widgets/car_location_map_picker.dart';
import 'package:flutter_travel_agency/widgets/image_upload_widget.dart';

class CarFormPage extends StatefulWidget {
  const CarFormPage({super.key, required this.onCreated, this.itemToEdit});

  final VoidCallback onCreated;
  final Map<String, dynamic>? itemToEdit;

  @override
  State<CarFormPage> createState() => _CarFormPageState();
}

class _CarFormPageState extends State<CarFormPage> {
  final _formKey = GlobalKey<FormState>();
  static final _moneyInputFormatter = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*\.?\d{0,2}$'),
  );
  static const _gearOptions = ['Auto', 'Manual', 'CVT'];

  final _title = TextEditingController();
  final _content = TextEditingController();
  final _slug = TextEditingController();
  final _carNumber = TextEditingController();
  final _price = TextEditingController();
  final _salePrice = TextEditingController();
  final _passenger = TextEditingController(text: '4');
  final _baggage = TextEditingController(text: '2');
  final _door = TextEditingController(text: '4');
  String _gearShift = 'Auto';
  String _status = 'publish';
  double? _mapLat;
  double? _mapLng;
  String? _locationId;
  List<Map<String, dynamic>> _locationRows = [];
  String? _imageUrl;
  String? _imagePublicId;
  final List<String> _galleryUrls = [];
  bool _galleryUploading = false;
  bool _loading = false;
  String? _submitNotice;

  @override
  void initState() {
    super.initState();
    if (widget.itemToEdit != null) {
      final draft = CarMapper.fromApi(widget.itemToEdit!);
      _title.text = draft.title;
      _content.text = draft.content;
      _slug.text = draft.slug;
      _carNumber.text = draft.carNumber;
      _price.text = draft.price;
      _salePrice.text = draft.salePrice;
      _passenger.text = draft.passenger;
      _baggage.text = draft.baggage;
      _door.text = draft.door;
      _gearShift = _gearOptions.contains(draft.gearShift)
          ? draft.gearShift
          : 'Auto';
      _status = draft.status;
      _mapLat = draft.mapLat;
      _mapLng = draft.mapLng;
      _locationId = draft.locationId;
      _imageUrl = draft.imageUrl;
      _imagePublicId = draft.imagePublicId;
      _galleryUrls
        ..clear()
        ..addAll(draft.gallery);
    }
    if (_slug.text.trim().isEmpty) {
      _slug.text = _slugify(_title.text);
    }
    _title.addListener(_syncSlugFromTitle);
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final locations = await LookupsApi.locations();
      if (!mounted) return;
      setState(() {
        _locationRows = locations
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
    _title.removeListener(_syncSlugFromTitle);
    _title.dispose();
    _content.dispose();
    _slug.dispose();
    _carNumber.dispose();
    _price.dispose();
    _salePrice.dispose();
    _passenger.dispose();
    _baggage.dispose();
    _door.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitNotice = null);
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _submitNotice = 'Please complete all required fields before saving.';
      });
      return;
    }
    if (_slug.text.trim().isEmpty) {
      _slug.text = _slugify(_title.text);
    }
    final draft = CarDraft(
      id: widget.itemToEdit?['id'],
      title: _title.text,
      content: _content.text,
      slug: _slug.text,
      carNumber: _carNumber.text,
      price: _price.text,
      salePrice: _salePrice.text,
      passenger: _passenger.text,
      baggage: _baggage.text,
      door: _door.text,
      gearShift: _gearShift,
      status: _status,
      mapLat: _mapLat,
      mapLng: _mapLng,
      locationId: _locationId,
      imageUrl: _imageUrl,
      imagePublicId: _imagePublicId,
      gallery: _galleryUrls,
    );
    final errors = CarPayloadValidator.validate(draft);
    if (errors.isNotEmpty) {
      setState(() {
        _submitNotice = errors.first;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errors.first)));
      return;
    }
    setState(() => _loading = true);
    try {
      final body = CarMapper.toApi(draft);
      if (widget.itemToEdit != null) {
        await CarsApi.update(widget.itemToEdit!['id'], body);
      } else {
        await CarsApi.create(body);
      }
      if (mounted) {
        setState(() => _submitNotice = null);
      }
      widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitNotice = 'Unable to save right now. Please try again.';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final mapInitial = (_mapLat != null && _mapLng != null)
        ? LatLng(_mapLat!, _mapLng!)
        : null;
    final main = Form(
      key: _formKey,
      child: Column(
        children: [
          _card('Car Content', [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            AdminRichTextEditor(
              controller: _content,
              label: 'Content',
              hintText: 'Write a rich car description here...',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _carNumber,
              decoration: const InputDecoration(
                labelText: 'Car Number',
                border: OutlineInputBorder(),
              ),
            ),
          ]),
          _card('Pricing', [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [_moneyInputFormatter],
                    decoration: const InputDecoration(
                      labelText: 'Daily Price',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _salePrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [_moneyInputFormatter],
                    decoration: const InputDecoration(
                      labelText: 'Sale Price',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ]),
          _card('Vehicle Specs', [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _passenger,
                    decoration: const InputDecoration(
                      labelText: 'Passengers',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _door,
                    decoration: const InputDecoration(
                      labelText: 'Doors',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _baggage,
                    decoration: const InputDecoration(
                      labelText: 'Baggage',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _gearShift,
                    items: _gearOptions
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _gearShift = v ?? 'Auto'),
                    decoration: const InputDecoration(
                      labelText: 'Gear Shift',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ]),
          _card('Location', [
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
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: CarLocationMapPicker(
                key: ValueKey('car_map_$_mapLat'),
                initial: mapInitial,
                onPick: (p) => setState(() {
                  _mapLat = p.latitude;
                  _mapLng = p.longitude;
                }),
              ),
            ),
          ]),
          _card('Feature Image', [
            ImageUploadWidget(
              initialImageUrl: _imageUrl,
              initialImagePublicId: _imagePublicId,
              onImageSelected: (u, i) => setState(() {
                _imageUrl = u;
                _imagePublicId = i;
              }),
            ),
            const SizedBox(height: 14),
            const Text(
              'Gallery',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_galleryUrls.isEmpty)
              Text(
                'No gallery images yet.',
                style: TextStyle(color: Colors.grey[600]),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _galleryUrls
                    .asMap()
                    .entries
                    .map(
                      (entry) => Chip(
                        label: Text('Image ${entry.key + 1}'),
                        onDeleted: () =>
                            setState(() => _galleryUrls.removeAt(entry.key)),
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
        ],
      ),
    );
    final side = _card('Publish', [
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
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _loading
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(widget.itemToEdit == null ? 'Add Car' : 'Update Car'),
        ),
      ),
      if (_submitNotice != null) ...[
        const SizedBox(height: 10),
        Text(
          _submitNotice!,
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ]);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: main),
              const SizedBox(width: 24),
              Expanded(flex: 3, child: side),
            ],
          );
        }
        return Column(children: [main, side]);
      },
    );
  }

  void _syncSlugFromTitle() {
    final generated = _slugify(_title.text);
    if (_slug.text != generated) {
      _slug.text = generated;
    }
  }
}
