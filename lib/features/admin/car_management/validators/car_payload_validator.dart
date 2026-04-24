import 'package:flutter_travel_agency/features/admin/car_management/models/car_draft.dart';

class CarPayloadValidator {
  static List<String> validate(CarDraft draft) {
    final errors = <String>[];
    if (draft.title.trim().isEmpty) errors.add('Car title is required.');
    if (draft.mapLat == null || draft.mapLng == null) {
      errors.add('Please set car location on the map.');
    }
    if (draft.price.trim().isEmpty) errors.add('Price is required.');
    if (double.tryParse(draft.price.trim()) == null) {
      errors.add('Price must be numeric.');
    }
    return errors;
  }
}
