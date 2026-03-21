import 'package:intl/intl.dart';

class CarRental {
  final int id;
  final int carId;
  final String carTitle;
  final String carImageUrl;
  final double carPrice;
  final DateTime startDate;
  final DateTime endDate;
  final String status;

  CarRental({
    required this.id,
    required this.carId,
    required this.carTitle,
    required this.carImageUrl,
    required this.carPrice,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  factory CarRental.fromJson(Map<String, dynamic> json) {
    return CarRental(
      id: json['id'],
      carId: json['moduleId'] ?? json['carId'] ?? 0,
      carTitle: json['car']['title'] ?? json['carTitle'] ?? '',
      carImageUrl: json['car']['imageUrl'] ?? json['carImageUrl'] ?? '',
      carPrice: double.tryParse(json['car']['price']?.toString() ?? '0') ?? 0.0,
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'carId': carId,
    'carTitle': carTitle,
    'carImageUrl': carImageUrl,
    'carPrice': carPrice,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'status': status,
  };
}

class CreateRentalRequest {
  final int carId;
  final DateTime startDate;
  final DateTime endDate;

  CreateRentalRequest({
    required this.carId,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toJson() => {
    'carId': carId,
    'startDate': startDate.toUtc().toIso8601String(),
    'endDate': endDate.toUtc().toIso8601String(),
  };

}

