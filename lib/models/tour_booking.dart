
class TourBooking {
  final int id;
  final int tourId;
  final String tourTitle;
  final String tourImageUrl;
  final double tourPrice;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final String moduleType; // 'tour'
  final String? buyerName;
  final String? buyerEmail;
  final String? buyerPhone;
  final String? bookedBy;
  final String? creator;

  TourBooking({
    required this.id,
    required this.tourId,
    required this.tourTitle,
    required this.tourImageUrl,
    required this.tourPrice,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.moduleType,
    this.buyerName,
    this.buyerEmail,
    this.buyerPhone,
    this.bookedBy,
    this.creator,
  });

  factory TourBooking.fromJson(Map<String, dynamic> json) {
    return TourBooking(
      id: json['id'] ?? 0,
      tourId: json['tour']?['id'] ?? json['tourId'] ?? json['moduleId'] ?? 0,
      tourTitle: json['tour']?['title'] ?? json['tourTitle'] ?? '',
      tourImageUrl: json['tour']?['imageUrl'] ?? json['tourImageUrl'] ?? '',
      tourPrice: double.tryParse(json['tour']?['price']?.toString() ?? '0') ?? 0.0,
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
      status: json['status'] ?? 'active',
      moduleType: json['moduleType'] ?? 'tour',
      buyerName: json['buyerName']?.toString(),
      buyerEmail: json['buyerEmail']?.toString(),
      buyerPhone: json['buyerPhone']?.toString(),
      bookedBy: json['bookedBy']?.toString(),
      creator: json['creator']?.toString(),
    );
  }
}
