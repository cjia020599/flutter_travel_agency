import 'dart:convert';
import 'package:flutter_travel_agency/api/api_client.dart';
import 'package:flutter_travel_agency/models/car_rental.dart';

class CarRentalsApi {
  static final _client = ApiClient.instance;

  static Future<List<CarRental>> getCarRentals({int? userId}) async {
    try {
      final path = '/api/car-rentals${userId != null ? '?userId=$userId' : ''}';
      final res = await _client.get(path, auth: true);
      final data = res['data'] ?? res;
      if (data is List) {
        return data.map((json) => CarRental.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('Error loading rentals: $e');
      return [];
    }
  }

  static Future<bool> rentCar(CreateRentalRequest request) async {
    try {
      final res = await _client.post('/api/car-rentals', request.toJson(), auth: true);
      return res['success'] == true || res['id'] != null;
    } catch (e) {
      print('Error renting car: $e');
      return false;
    }
  }

  static Future<bool> cancelRental(int rentalId) async {
    try {
      await _client.delete('/api/car-rentals/$rentalId', auth: true);
      return true;
    } catch (e) {
      print('Error cancelling rental: $e');
      return false;
    }
  }
}

