import 'dart:math' as math;

/// Shared parsing and pricing helpers for tour/car listing detail UI.
class ListingDataHelpers {
  ListingDataHelpers._();

  static double? effectivePrice(Map<String, dynamic> item) {
    final sale = double.tryParse(item['salePrice']?.toString() ?? '');
    final reg = double.tryParse(item['price']?.toString() ?? '');
    if (sale != null && sale > 0) return sale;
    if (reg != null && reg > 0) return reg;
    if (sale != null) return sale;
    return reg;
  }

  static int minPeople(Map<String, dynamic> item) {
    final n = int.tryParse(item['minPeople']?.toString() ?? '');
    return math.max(1, n ?? 1);
  }

  /// Returns the tour max capacity.
  ///
  /// If the API does not provide `maxPeople`, we avoid showing a fake ceiling
  /// (like 32). In that case, this returns [minPeople] (i.e. no range).
  static int maxPeople(Map<String, dynamic> item, {int fallback = 0}) {
    final min = minPeople(item);
    final n = int.tryParse(item['maxPeople']?.toString() ?? '');
    return math.max(min, n ?? fallback);
  }

  /// Listed price is treated as the package total for [minPeople] guests.
  /// Each additional guest pays the same per-person rate.
  static double? perPersonRate(Map<String, dynamic> item) {
    final package = effectivePrice(item);
    if (package == null) return null;
    return package / minPeople(item);
  }

  static double? tourTotalForGuests(Map<String, dynamic> item, int guests) {
    final rate = perPersonRate(item);
    if (rate == null) return null;
    return rate * math.max(1, guests);
  }

  static int rentalDaysInclusive(DateTime start, DateTime end) {
    final days = end.difference(start).inDays;
    return days < 0 ? 0 : days + 1;
  }

  static double? carTotalForDates(
    Map<String, dynamic> item,
    DateTime start,
    DateTime end,
  ) {
    final daily = effectivePrice(item);
    if (daily == null) return null;
    final days = rentalDaysInclusive(start, end);
    if (days <= 0) return null;
    return daily * days;
  }

  static List<Map<String, String>> parseTitleContentPairs(dynamic source) {
    if (source is! List) return [];
    return source
        .map(
          (e) => <String, String>{
            'title': (e is Map ? e['title'] : '')?.toString() ?? '',
            'content':
                (e is Map ? e['content'] ?? e['desc'] : '')?.toString() ?? '',
          },
        )
        .toList();
  }

  static List<Map<String, String>> parseSurroundingsGroup(
    Map<String, dynamic> source, {
    required String directKey,
    required String nestedKey,
  }) {
    final direct = parseTitleContentPairs(source[directKey]);
    if (direct.isNotEmpty) return direct;
    final surroundings = source['surroundings'];
    if (surroundings is Map) {
      return parseTitleContentPairs(surroundings[nestedKey]);
    }
    return [];
  }

  static List<String> parseGalleryUrls(Map<String, dynamic> item) {
    final gallery = item['gallery'];
    if (gallery is! List) return [];
    return gallery
        .map((e) {
          if (e is Map) {
            return (e['url'] ?? e['imageUrl'] ?? e['src'])?.toString() ?? '';
          }
          return e.toString();
        })
        .where((u) => u.trim().isNotEmpty)
        .toList();
  }

  static String? descriptionRaw(Map<String, dynamic> item) {
    for (final key in ['content', 'description', 'desc']) {
      final v = item[key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  static String formatMoney(double value, String peso) {
    final whole = value == value.roundToDouble();
    final text = whole
        ? value.round().toString()
        : value.toStringAsFixed(2);
    return '$peso$text';
  }
}
