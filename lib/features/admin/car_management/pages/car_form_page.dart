import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_travel_agency/api/cars_api.dart';
import 'package:flutter_travel_agency/features/admin/car_management/mappers/car_mapper.dart';
import 'package:flutter_travel_agency/features/admin/car_management/models/car_draft.dart';
import 'package:flutter_travel_agency/features/admin/car_management/validators/car_payload_validator.dart';
import 'package:flutter_travel_agency/features/admin/shared/widgets/admin_rich_text_editor.dart';
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
  String? _imageUrl;
  String? _imagePublicId;
  bool _loading = false;

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
      _gearShift = _gearOptions.contains(draft.gearShift) ? draft.gearShift : 'Auto';
      _status = draft.status;
      _mapLat = draft.mapLat;
      _mapLng = draft.mapLng;
      _imageUrl = draft.imageUrl;
      _imagePublicId = draft.imagePublicId;
    }
    if (_slug.text.trim().isEmpty) {
      _slug.text = _slugify(_title.text);
    }
    _title.addListener(_syncSlugFromTitle);
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
    if (!_formKey.currentState!.validate()) return;
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
      imageUrl: _imageUrl,
      imagePublicId: _imagePublicId,
    );
    final errors = CarPayloadValidator.validate(draft);
    if (errors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errors.first)));
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
      widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Divider(height: 28),
          ...children,
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapInitial = (_mapLat != null && _mapLng != null) ? LatLng(_mapLat!, _mapLng!) : null;
    final main = Form(
      key: _formKey,
      child: Column(
        children: [
          _card('Car Content', [
            TextFormField(controller: _title, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            AdminRichTextEditor(
              controller: _content,
              label: 'Content',
              hintText: 'Write a rich car description here...',
            ),
            const SizedBox(height: 16),
            TextFormField(controller: _carNumber, decoration: const InputDecoration(labelText: 'Car Number', border: OutlineInputBorder())),
          ]),
          _card('Pricing', [
            Row(children: [
              Expanded(child: TextFormField(controller: _price, decoration: const InputDecoration(labelText: 'Daily Price', border: OutlineInputBorder()))),
              const SizedBox(width: 16),
              Expanded(child: TextFormField(controller: _salePrice, decoration: const InputDecoration(labelText: 'Sale Price', border: OutlineInputBorder()))),
            ]),
          ]),
          _card('Vehicle Specs', [
            Row(children: [
              Expanded(child: TextFormField(controller: _passenger, decoration: const InputDecoration(labelText: 'Passengers', border: OutlineInputBorder()))),
              const SizedBox(width: 16),
              Expanded(child: TextFormField(controller: _door, decoration: const InputDecoration(labelText: 'Doors', border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(controller: _baggage, decoration: const InputDecoration(labelText: 'Baggage', border: OutlineInputBorder()))),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _gearShift,
                  items: _gearOptions.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _gearShift = v ?? 'Auto'),
                  decoration: const InputDecoration(labelText: 'Gear Shift', border: OutlineInputBorder()),
                ),
              ),
            ]),
          ]),
          _card('Location', [
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
          ]),
        ],
      ),
    );
    final side = _card('Publish', [
      RadioListTile<String>(title: const Text('Publish'), value: 'publish', groupValue: _status, onChanged: (v) => setState(() => _status = v!), contentPadding: EdgeInsets.zero),
      RadioListTile<String>(title: const Text('Draft'), value: 'draft', groupValue: _status, onChanged: (v) => setState(() => _status = v!), contentPadding: EdgeInsets.zero),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(widget.itemToEdit == null ? 'Add Car' : 'Update Car'),
        ),
      ),
    ]);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 7, child: main),
            const SizedBox(width: 24),
            Expanded(flex: 3, child: side),
          ]);
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
