import 'dart:convert';
import 'package:flutter_travel_agency/api/api_client.dart';
import 'package:flutter_travel_agency/models/tour_booking.dart';

class TourBookingsApi {
  static final _client = ApiClient.instance;

  static Future<List<TourBooking>> getMyBookings() async {
    try {
      final res = await _client.get('/api/tour-bookings', auth: true);
      final data = res['data'] ?? res;
      if (data is List) {
        return data.map((json) => TourBooking.fromJson(json as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      print('Error loading tour bookings: $e');
      return [];
    }
  }

  static Future<bool> buyTour(CreateTourBookingRequest request) async {
    try {
      final res = await _client.post('/api/tour-bookings', request.toJson(), auth: true);
      return res['success'] == true || res['id'] != null;
    } catch (e) {
      print('Error booking tour: $e');
      return false;
    }
  }

  static Future<bool> cancelBooking(int bookingId) async {
    try {
      await _client.delete('/api/tour-bookings/$bookingId', auth: true);
      return true;
    } catch (e) {
      print('Error cancelling tour booking: $e');
      return false;
    }
  }
}

class CreateTourBookingRequest {
  final int tourId;
  final DateTime startDate;
  final DateTime endDate;
  final String? buyerName;
  final String? buyerEmail;
  final String? buyerPhone;

  CreateTourBookingRequest({
    required this.tourId,
    required this.startDate,
    required this.endDate,
    this.buyerName,
    this.buyerEmail,
    this.buyerPhone,
  });

  Map<String, dynamic> toJson() => {
    'tourId': tourId,
    'startDate': startDate.toUtc().toIso8601String(),
    'endDate': endDate.toUtc().toIso8601String(),
    if (buyerName != null) 'buyerName': buyerName,
    if (buyerEmail != null) 'buyerEmail': buyerEmail,
    if (buyerPhone != null) 'buyerPhone': buyerPhone,
  };
}
