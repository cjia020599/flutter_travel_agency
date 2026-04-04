import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// OpenStreetMap picker: tap sets coordinates (no manual lat/lng fields).
class CarLocationMapPicker extends StatefulWidget {
  const CarLocationMapPicker({
    super.key,
    this.initial,
    required this.onPick,
    this.height = 280,
  });

  final LatLng? initial;
  final ValueChanged<LatLng> onPick;
  final double height;

  @override
  State<CarLocationMapPicker> createState() => _CarLocationMapPickerState();
}

class _CarLocationMapPickerState extends State<CarLocationMapPicker> {
  LatLng? _marker;

  static final _defaultCenter = LatLng(14.5995, 120.9842);

  @override
  void initState() {
    super.initState();
    _marker = widget.initial;
  }

  @override
  void didUpdateWidget(CarLocationMapPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initial?.latitude != oldWidget.initial?.latitude ||
        widget.initial?.longitude != oldWidget.initial?.longitude) {
      _marker = widget.initial;
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = _marker ?? widget.initial ?? _defaultCenter;
    final zoom = (_marker != null || widget.initial != null) ? 12.0 : 8.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: zoom,
            onTap: (_, point) {
              setState(() => _marker = point);
              widget.onPick(point);
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.flutter_travel_agency',
            ),
            if (_marker != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _marker!,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on, color: Color(0xFFD32F2F), size: 44),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
