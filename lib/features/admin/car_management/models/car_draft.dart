class CarDraft {
  CarDraft({
    this.id,
    this.title = '',
    this.content = '',
    this.slug = '',
    this.carNumber = '',
    this.price = '',
    this.salePrice = '',
    this.passenger = '',
    this.baggage = '',
    this.door = '',
    this.gearShift = 'Auto',
    this.status = 'publish',
    this.mapLat,
    this.mapLng,
    this.imageUrl,
    this.imagePublicId,
  });

  final dynamic id;
  final String title;
  final String content;
  final String slug;
  final String carNumber;
  final String price;
  final String salePrice;
  final String passenger;
  final String baggage;
  final String door;
  final String gearShift;
  final String status;
  final double? mapLat;
  final double? mapLng;
  final String? imageUrl;
  final String? imagePublicId;
}
