import 'package:flutter_travel_agency/features/admin/tour_management/models/tour_draft.dart';

class TourPayloadValidator {
  static List<String> validate(TourDraft draft) {
    final errors = <String>[];
    if (draft.title.trim().isEmpty) errors.add('Title is required.');
    if (draft.realTourAddress.trim().isEmpty) {
      errors.add('Real tour address is required.');
    }
    if (draft.mapLat == null || draft.mapLng == null) {
      errors.add('Map latitude and longitude are required.');
    }
    if (draft.price.trim().isEmpty) errors.add('Price is required.');
    if (double.tryParse(draft.price.trim()) == null) {
      errors.add('Price must be numeric.');
    }
    if (draft.salePrice.trim().isNotEmpty &&
        double.tryParse(draft.salePrice.trim()) == null) {
      errors.add('Sale price must be numeric.');
    }
    return errors;
  }
}
