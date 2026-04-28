import 'package:flutter_travel_agency/features/admin/car_management/models/car_draft.dart';

class CarMapper {
  static String _normalizeMoney(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '0.00';
    if (value.contains('.')) return value;
    return '$value.00';
  }

  static CarDraft fromApi(Map<String, dynamic> item) {
    List<String> parseGallery(dynamic source) {
      if (source is! List) return [];
      return source
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }

    return CarDraft(
      id: item['id'],
      title: (item['title'] ?? item['name'] ?? '').toString(),
      content: (item['content'] ?? '').toString(),
      slug: (item['slug'] ?? '').toString(),
      carNumber: (item['carNumber'] ?? '').toString(),
      price: (item['price'] ?? '').toString(),
      salePrice: (item['salePrice'] ?? '').toString(),
      passenger: (item['passenger'] ?? '4').toString(),
      baggage: (item['baggage'] ?? '2').toString(),
      door: (item['door'] ?? '4').toString(),
      gearShift: (item['gearShift'] ?? 'Auto').toString(),
      status: (item['status']?.toString().toLowerCase() == 'draft')
          ? 'draft'
          : 'publish',
      mapLat: double.tryParse((item['mapLat'] ?? '').toString()),
      mapLng: double.tryParse((item['mapLng'] ?? '').toString()),
      locationId: (item['locationId'] ?? item['location']?['id'])?.toString(),
      imageUrl: item['imageUrl']?.toString(),
      imagePublicId: item['imagePublicId']?.toString(),
      gallery: parseGallery(item['gallery']),
    );
  }

  static Map<String, dynamic> toApi(CarDraft draft) {
    final body = <String, dynamic>{
      'title': draft.title.trim(),
      'slug': draft.slug.trim().isEmpty
          ? draft.title.toLowerCase().replaceAll(' ', '-')
          : draft.slug.trim(),
      'carNumber': draft.carNumber.trim(),
      'price': _normalizeMoney(draft.price),
      'salePrice': _normalizeMoney(draft.salePrice),
      'passenger': int.tryParse(draft.passenger.trim()) ?? 0,
      'baggage': int.tryParse(draft.baggage.trim()) ?? 0,
      'door': int.tryParse(draft.door.trim()) ?? 0,
      'gearShift': draft.gearShift,
      'mapLat': draft.mapLat?.toString(),
      'mapLng': draft.mapLng?.toString(),
      'imageUrl': draft.imageUrl ?? '',
      'imagePublicId': draft.imagePublicId ?? '',
      'gallery': draft.gallery,
      'content': draft.content.trim(),
      'status': draft.status,
    };
    if (draft.locationId != null && draft.locationId!.isNotEmpty) {
      body['locationId'] = int.tryParse(draft.locationId!) ?? draft.locationId;
    }
    body.removeWhere((key, value) => value == null || value == '');
    return body;
  }
}
