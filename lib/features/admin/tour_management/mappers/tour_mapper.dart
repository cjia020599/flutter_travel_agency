import 'package:flutter_travel_agency/features/admin/tour_management/models/tour_draft.dart';

class TourMapper {
  static int? _parseOptionalInt(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }

  static String _normalizeMoney(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return '0.00';
    if (value.contains('.')) return value;
    return '$value.00';
  }

  static TourDraft fromApi(Map<String, dynamic> item) {
    List<Map<String, String>> parsePairs(dynamic source) {
      if (source is! List) return [];
      return source
          .map(
            (e) => <String, String>{
              'title': (e is Map ? e['title'] : '')?.toString() ?? '',
              'content':
                  (e is Map ? e['content'] ?? e['desc'] : '')?.toString() ?? '',
            },
          )
          .toList();
    }

    List<String> parseGallery(dynamic source) {
      if (source is! List) return [];
      return source
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    List<String> parseAttributeIds(Map<String, dynamic> source) {
      final direct = source['attributeIds'];
      if (direct is List) {
        return direct
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      final attrs = source['attributes'];
      if (attrs is List) {
        return attrs
            .map((e) {
              if (e is Map)
                return (e['id'] ?? e['attributeId'])?.toString() ?? '';
              return '';
            })
            .where((e) => e.isNotEmpty)
            .toList();
      }
      return [];
    }

    final loc = item['location'];
    return TourDraft(
      id: item['id'],
      title: (item['title'] ?? item['name'] ?? '').toString(),
      content: (item['content'] ?? '').toString(),
      slug: (item['slug'] ?? '').toString(),
      price: (item['price'] ?? '').toString(),
      salePrice: (item['salePrice'] ?? '').toString(),
      realTourAddress: (item['realTourAddress'] ?? item['address'] ?? '')
          .toString(),
      imageUrl: item['imageUrl']?.toString(),
      imagePublicId: item['imagePublicId']?.toString(),
      bannerImageUrl: (item['bannerImageUrl'] ?? item['bannerImage'])
          ?.toString(),
      bannerImagePublicId: item['bannerImagePublicId']?.toString(),
      status: (item['status']?.toString().toLowerCase() == 'draft')
          ? 'draft'
          : 'publish',
      availability: (item['availability'] ?? 'always').toString(),
      isFeatured: item['isFeatured'] == true || item['featured'] == true,
      serviceFeeEnabled:
          item['serviceFeeEnabled'] == true || item['enableServiceFee'] == true,
      fixedDateEnabled:
          item['fixedDateEnabled'] == true || item['enableFixedDate'] == true,
      openHoursEnabled:
          item['openHoursEnabled'] == true || item['enableOpenHours'] == true,
      metaTitle: (item['metaTitle'] ?? item['seoTitle'] ?? '').toString(),
      metaDescription: (item['metaDescription'] ?? item['seoDescription'] ?? '')
          .toString(),
      mapLat: double.tryParse((item['mapLat'] ?? '').toString()),
      mapLng: double.tryParse((item['mapLng'] ?? '').toString()),
      locationId: (item['locationId'] ?? (loc is Map ? loc['id'] : loc))
          ?.toString(),
      categoryId: item['categoryId']?.toString(),
      duration: (item['duration'] ?? '').toString(),
      minPeople: (item['minPeople'] ?? '').toString(),
      maxPeople: (item['maxPeople'] ?? '').toString(),
      attributeIds: parseAttributeIds(item),
      faqs: parsePairs(item['faqs']),
      includeItems: parsePairs(item['include']),
      excludeItems: parsePairs(item['exclude']),
      itineraryItems: parsePairs(item['itinerary']),
      surroundingsEducation: parsePairs(item['surroundingsEducation']),
      surroundingsHealth: parsePairs(item['surroundingsHealth']),
      surroundingsTransportation: parsePairs(
        item['surroundingsTransportation'],
      ),
      gallery: parseGallery(item['gallery']),
    );
  }

  static Map<String, dynamic> toApi(TourDraft draft) {
    final body = <String, dynamic>{
      'title': draft.title.trim(),
      'name': draft.title.trim(),
      'slug': draft.slug.trim(),
      'price': _normalizeMoney(draft.price),
      'salePrice': _normalizeMoney(draft.salePrice),
      'realTourAddress': draft.realTourAddress.trim(),
      'address': draft.realTourAddress.trim(),
      'mapLat': draft.mapLat?.toString(),
      'mapLng': draft.mapLng?.toString(),
      'imageUrl': draft.imageUrl ?? '',
      'imagePublicId': draft.imagePublicId ?? '',
      'bannerImageUrl': draft.bannerImageUrl ?? '',
      'bannerImagePublicId': draft.bannerImagePublicId ?? '',
      'content': draft.content.trim(),
      'status': draft.status,
      'published': draft.status == 'publish',
      'availability': draft.availability,
      'isFeatured': draft.isFeatured,
      'serviceFeeEnabled': draft.serviceFeeEnabled,
      'fixedDateEnabled': draft.fixedDateEnabled,
      'openHoursEnabled': draft.openHoursEnabled,
      'metaTitle': draft.metaTitle.trim(),
      'metaDescription': draft.metaDescription.trim(),
      'duration': _parseOptionalInt(draft.duration),
      'minPeople': _parseOptionalInt(draft.minPeople),
      'maxPeople': _parseOptionalInt(draft.maxPeople),
      'faqs': draft.faqs,
      'include': draft.includeItems,
      'exclude': draft.excludeItems,
      'itinerary': draft.itineraryItems,
      'surroundingsEducation': draft.surroundingsEducation,
      'surroundingsHealth': draft.surroundingsHealth,
      'surroundingsTransportation': draft.surroundingsTransportation,
      'gallery': draft.gallery,
    };
    if (draft.locationId != null && draft.locationId!.isNotEmpty) {
      body['locationId'] = int.tryParse(draft.locationId!) ?? draft.locationId;
    }
    if (draft.categoryId != null && draft.categoryId!.isNotEmpty) {
      body['categoryId'] = int.tryParse(draft.categoryId!) ?? draft.categoryId;
    }
    if (draft.attributeIds.isNotEmpty) {
      body['attributeIds'] = draft.attributeIds
          .map((e) => int.tryParse(e) ?? e)
          .toList();
    }
    body.removeWhere((key, value) => value == null || value == '');
    return body;
  }
}
