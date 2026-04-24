class TourDraft {
  TourDraft({
    this.id,
    this.title = '',
    this.content = '',
    this.slug = '',
    this.price = '',
    this.salePrice = '',
    this.realTourAddress = '',
    this.imageUrl,
    this.imagePublicId,
    this.bannerImageUrl,
    this.bannerImagePublicId,
    this.status = 'publish',
    this.availability = 'always',
    this.isFeatured = false,
    this.serviceFeeEnabled = false,
    this.fixedDateEnabled = false,
    this.openHoursEnabled = false,
    this.metaTitle = '',
    this.metaDescription = '',
    this.mapLat,
    this.mapLng,
    this.locationId,
    this.categoryId,
    this.duration = '',
    this.minPeople = '',
    this.maxPeople = '',
    List<String>? attributeIds,
    List<Map<String, String>>? faqs,
    List<Map<String, String>>? includeItems,
    List<Map<String, String>>? excludeItems,
    List<Map<String, String>>? itineraryItems,
    List<Map<String, String>>? surroundingsEducation,
    List<Map<String, String>>? surroundingsHealth,
    List<Map<String, String>>? surroundingsTransportation,
    List<String>? gallery,
  }) : faqs = faqs ?? [],
       includeItems = includeItems ?? [],
       excludeItems = excludeItems ?? [],
       itineraryItems = itineraryItems ?? [],
       attributeIds = attributeIds ?? [],
       surroundingsEducation = surroundingsEducation ?? [],
       surroundingsHealth = surroundingsHealth ?? [],
       surroundingsTransportation = surroundingsTransportation ?? [],
       gallery = gallery ?? [];

  final dynamic id;
  final String title;
  final String content;
  final String slug;
  final String price;
  final String salePrice;
  final String realTourAddress;
  final String? imageUrl;
  final String? imagePublicId;
  final String? bannerImageUrl;
  final String? bannerImagePublicId;
  final String status;
  final String availability;
  final bool isFeatured;
  final bool serviceFeeEnabled;
  final bool fixedDateEnabled;
  final bool openHoursEnabled;
  final String metaTitle;
  final String metaDescription;
  final double? mapLat;
  final double? mapLng;
  final String? locationId;
  final String? categoryId;
  final String duration;
  final String minPeople;
  final String maxPeople;
  final List<String> attributeIds;
  final List<Map<String, String>> faqs;
  final List<Map<String, String>> includeItems;
  final List<Map<String, String>> excludeItems;
  final List<Map<String, String>> itineraryItems;
  final List<Map<String, String>> surroundingsEducation;
  final List<Map<String, String>> surroundingsHealth;
  final List<Map<String, String>> surroundingsTransportation;
  final List<String> gallery;
}
