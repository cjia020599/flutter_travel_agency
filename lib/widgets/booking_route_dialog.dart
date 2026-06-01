import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// BookingRouteDialog
/// - Attempts to get device current location (via `geolocator`).
/// - If allowed, uses current location as origin; otherwise lets user enter a start address.
/// - Uses Nominatim to forward-geocode manual input and OSRM public API to fetch
///   simple travel estimates for `driving`, `walking`, and `cycling`.
///
/// Returns a map with keys: `allRoutes` (map of profile -> {duration,distance,profile,origin,destination,originAddress}),
/// and `origin`/`originAddress` when the user taps Done. Returns `null` if cancelled.
class BookingRouteDialog extends StatefulWidget {
  const BookingRouteDialog({
    super.key,
    required this.destination,
    this.destinationAddress,
  });

  final LatLng destination;
  final String? destinationAddress;

  @override
  State<BookingRouteDialog> createState() => _BookingRouteDialogState();
}

class _BookingRouteDialogState extends State<BookingRouteDialog> {
  bool _loading = false;
  String? _statusMessage;
  LatLng? _origin;
  String? _originAddress;
  Map<String, Map<String, dynamic>> _routes = {};
  Map<String, String>? _recommendation;
  final _manualController = TextEditingController();

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _loading = true;
      _statusMessage = 'Requesting location permission...';
    });
    try {
      final pos = await _determinePosition();
      if (!mounted) return;
      _origin = LatLng(pos.latitude, pos.longitude);
      _originAddress = null;
      await _fetchRoutesForOrigin(_origin!);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Unable to get current location: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useManualLocation() async {
    final query = _manualController.text.trim();
    if (query.isEmpty) {
      setState(() => _statusMessage = 'Please enter a start location.');
      return;
    }
    setState(() {
      _loading = true;
      _statusMessage = 'Geocoding address...';
    });
    try {
      final coords = await _forwardGeocode(query);
      if (coords == null) {
        setState(() => _statusMessage = 'Unable to locate that address.');
        return;
      }
      _origin = coords;
      _originAddress = query;
      await _fetchRoutesForOrigin(_origin!);
    } catch (e) {
      setState(() => _statusMessage = 'Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Position> _determinePosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location services are disabled.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied.');
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
  }

  Future<LatLng?> _forwardGeocode(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
    });
    final resp = await http.get(
      uri,
      headers: {'User-Agent': 'flutter_travel_agency/1.0'},
    );
    if (resp.statusCode != 200) return null;
    final body = jsonDecode(resp.body) as List<dynamic>;
    if (body.isEmpty) return null;
    final first = body.first as Map<String, dynamic>;
    return LatLng(
      double.parse(first['lat'].toString()),
      double.parse(first['lon'].toString()),
    );
  }

  Future<void> _fetchRoutesForOrigin(LatLng origin) async {
    setState(() => _statusMessage = 'Fetching route estimates...');
    final profiles = ['driving', 'walking', 'cycling'];
    final results = <String, Map<String, dynamic>>{};
    for (final p in profiles) {
      try {
        final route = await _fetchRoute(origin, p);
        if (route != null) results[p] = route;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _routes = results;
      _statusMessage = null;
    });

    // Compute a simple recommendation based on fastest duration and distance.
    if (_routes.isNotEmpty) {
      _recommendation = _computeRecommendation(_routes);
    } else {
      _recommendation = null;
    }

    // Do not auto-select. Keep the per-profile estimates in `_routes`
    // and let the user inspect them. Return occurs when the user taps
    // the Done button (see actions).
  }

  Future<Map<String, dynamic>?> _fetchRoute(
    LatLng origin,
    String profile,
  ) async {
    final coords =
        '${origin.longitude},${origin.latitude};${widget.destination.longitude},${widget.destination.latitude}';
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/$profile/$coords',
      {'overview': 'false', 'alternatives': 'false', 'steps': 'true'},
    );
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return null;
    final r = routes.first as Map<String, dynamic>;

    // Attempt to extract step-by-step instructions from the first leg.
    List<dynamic> steps = [];
    try {
      final legs = r['legs'] as List<dynamic>?;
      if (legs != null && legs.isNotEmpty) {
        final firstLeg = legs.first as Map<String, dynamic>;
        steps = (firstLeg['steps'] as List<dynamic>?) ?? [];
      }
    } catch (_) {
      steps = [];
    }

    return {
      'duration': (r['duration'] as num?)?.toDouble(),
      'distance': (r['distance'] as num?)?.toDouble(),
      'profile': profile,
      'origin': origin,
      'destination': widget.destination,
      'originAddress': _originAddress,
      'steps': steps,
    };
  }

  Map<String, String> _computeRecommendation(
    Map<String, Map<String, dynamic>> routes,
  ) {
    // Pick the profile with lowest duration.
    String bestProfile = '';
    double bestDuration = double.infinity;
    double bestDistance = 0.0;
    routes.forEach((p, data) {
      final d = (data['duration'] as num?)?.toDouble() ?? double.infinity;
      final dist = (data['distance'] as num?)?.toDouble() ?? 0.0;
      if (d < bestDuration) {
        bestDuration = d;
        bestProfile = p;
        bestDistance = dist;
      }
    });

    final label = bestProfile == 'driving'
        ? 'Drive'
        : bestProfile == 'walking'
            ? 'Walk'
            : 'Cycle';

    String reason;
    final km = bestDistance / 1000.0;
    if (bestProfile == 'walking') {
      reason = 'Short distance (${km.toStringAsFixed(1)} km) — walking is quickest.';
    } else if (bestProfile == 'cycling') {
      reason = 'Cycling is fastest and efficient for this distance (${km.toStringAsFixed(1)} km).';
    } else {
      reason = 'Driving is fastest for this route (${km.toStringAsFixed(1)} km).';
    }

    return {
      'profile': bestProfile,
      'label': label,
      'reason': reason,
    };
  }

  Widget _buildRouteSummary(String profile, Map<String, dynamic> data) {
    final dur = (data['duration'] as double?) ?? 0.0;
    final dist = (data['distance'] as double?) ?? 0.0;
    final minutes = (dur / 60).round();
    final km = (dist / 1000).toStringAsFixed(1);
    final label = profile == 'driving'
        ? 'Drive'
        : profile == 'walking'
            ? 'Walk'
            : 'Cycle';
    final stepCount = (data['steps'] as List<dynamic>?)?.length ?? 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue.shade700,
              child: Icon(
                profile == 'driving'
                    ? Icons.directions_car
                    : profile == 'walking'
                        ? Icons.directions_walk
                        : Icons.directions_bike,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'How can I get there from my location?',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$label • $minutes min • $km km',
                    style: TextStyle(color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    stepCount > 0 ? '$stepCount direction steps available' : 'No step-by-step directions available',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatStepInstruction(Map<String, dynamic> step) {
    final maneuver = step['maneuver'] as Map<String, dynamic>?;
    final String type = maneuver?['type']?.toString() ?? '';
    final String modifier = maneuver?['modifier']?.toString() ?? '';
    final String roadName = step['name']?.toString() ?? '';
    final String instruction;

    if (type == 'turn' && modifier.isNotEmpty) {
      instruction = 'Turn ${modifier.toLowerCase()}${roadName.isNotEmpty ? ' onto $roadName' : ''}';
    } else if (type == 'new name') {
      instruction = 'Continue onto $roadName';
    } else if (type == 'roundabout') {
      instruction = 'Enter the roundabout${roadName.isNotEmpty ? ' onto $roadName' : ''}';
    } else if (type == 'depart') {
      instruction = 'Depart${modifier.isNotEmpty ? ' $modifier' : ''}${roadName.isNotEmpty ? ' onto $roadName' : ''}';
    } else if (type == 'arrive') {
      instruction = 'Arrive at your destination';
    } else if (type == 'merge') {
      instruction = 'Merge${modifier.isNotEmpty ? ' $modifier' : ''}${roadName.isNotEmpty ? ' onto $roadName' : ''}';
    } else if (type == 'roundabout turn') {
      instruction = 'Exit roundabout${roadName.isNotEmpty ? ' onto $roadName' : ''}';
    } else {
      instruction = roadName.isNotEmpty ? 'Continue on $roadName' : 'Continue';
    }

    return instruction;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('How will you get there?'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.destinationAddress != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Destination: ${widget.destinationAddress}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            if (_statusMessage != null) Text(_statusMessage!),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            if (_routes.isEmpty) ...[
              ElevatedButton.icon(
                onPressed: _useCurrentLocation,
                icon: const Icon(Icons.my_location),
                label: const Text('Use my current location'),
              ),
              const SizedBox(height: 8),
              Row(children: const [Expanded(child: Divider())]),
              const SizedBox(height: 8),
              TextFormField(
                controller: _manualController,
                decoration: const InputDecoration(
                  labelText: 'Or enter start address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _useManualLocation,
                icon: const Icon(Icons.search),
                label: const Text('Lookup address'),
              ),
            ] else ...[
              if (_recommendation != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildRouteSummary(
                      _recommendation!['profile']!,
                      _routes[_recommendation!['profile']!]!,
                    ),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Directions',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 12),
                                ...((_routes[_recommendation!['profile']!]?['steps'] as List<dynamic>?) ?? [])
                                    .asMap()
                                    .entries
                                    .map((entry) {
                                      final i = entry.key + 1;
                                      final step = entry.value as Map<String, dynamic>;
                                      final instruction = _formatStepInstruction(step);
                                      final dist = (step['distance'] as num?)?.toDouble() ?? 0.0;
                                      final dur = (step['duration'] as num?)?.toDouble() ?? 0.0;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: Colors.blue.shade700,
                                              child: Text(
                                                '$i',
                                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    instruction,
                                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${(dur / 60).round()} min • ${(dist / 1000).toStringAsFixed(2)} km',
                                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    })
                                    .toList(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _routes.isEmpty
              ? null
              : () {
                  final result = <String, dynamic>{
                    'allRoutes': _routes,
                    'origin': _origin,
                    'originAddress': _originAddress,
                    'recommendation': _recommendation,
                  };
                  Navigator.of(context).pop(result);
                },
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// Helper to show the dialog. Returns a map containing `allRoutes` and origin info, or null.
Future<Map<String, dynamic>?> showBookingRouteDialog(
  BuildContext context, {
  required LatLng destination,
  String? destinationAddress,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (c) => BookingRouteDialog(
      destination: destination,
      destinationAddress: destinationAddress,
    ),
  );
}
