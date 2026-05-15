import 'package:flutter_travel_agency/api/api_client.dart';
import 'package:flutter_travel_agency/models/tour_booking.dart';

class TourBookingsApi {
  static final _client = ApiClient.instance;

  static Future<List<TourBooking>> getMyBookings({int? userId}) async {
    try {
      final path = '/api/tour-bookings${userId != null ? '?userId=$userId' : ''}';
      final res = await _client.get(path, auth: true);
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
  /// Number of travelers (UI); backend may ignore until supported.
  final int? guestCount;
  /// One name per guest; backend may ignore until supported (see `buyerName` fallback).
  final List<String>? guestNames;

  CreateTourBookingRequest({
    required this.tourId,
    required this.startDate,
    required this.endDate,
    this.buyerName,
    this.buyerEmail,
    this.buyerPhone,
    this.guestCount,
    this.guestNames,
  });

  Map<String, dynamic> toJson() {
    final gn = guestNames;
    return {
      'tourId': tourId,
      'startDate': startDate.toUtc().toIso8601String(),
      'endDate': endDate.toUtc().toIso8601String(),
      if (buyerName != null) 'buyerName': buyerName,
      if (buyerEmail != null) 'buyerEmail': buyerEmail,
      if (buyerPhone != null) 'buyerPhone': buyerPhone,
      if (guestCount != null) 'guestCount': guestCount,
      if (gn != null && gn.isNotEmpty) 'guestNames': gn,
    };
  }
}
