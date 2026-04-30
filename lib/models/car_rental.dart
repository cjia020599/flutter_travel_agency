
class CarRental {
  final int id;
  final int carId;
  final String carTitle;
  final String carImageUrl;
  final double carPrice;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String? buyerName;
  final String? buyerEmail;
  final String? buyerPhone;
  final String? bookedBy;
  final String? creator;

  CarRental({
    required this.id,
    required this.carId,
    required this.carTitle,
    required this.carImageUrl,
    required this.carPrice,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.buyerName,
    this.buyerEmail,
    this.buyerPhone,
    this.bookedBy,
    this.creator,
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
      buyerName: json['buyerName'],
      buyerEmail: json['buyerEmail'],
      buyerPhone: json['buyerPhone'],
      bookedBy: json['bookedBy']?.toString(),
      creator: json['creator']?.toString(),
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
    'buyerName': buyerName,
    'buyerEmail': buyerEmail,
    'buyerPhone': buyerPhone,
    'bookedBy': bookedBy,
    'creator': creator,
  };
}



