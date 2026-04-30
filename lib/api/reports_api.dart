import 'api_client.dart';

class ReportsApi {
  static final _client = ApiClient.instance;

  static String _withQuery(String path, Map<String, String?> query) {
    final pairs = query.entries
        .where((entry) => (entry.value ?? '').isNotEmpty)
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value!)}',
        )
        .toList();
    if (pairs.isEmpty) return path;
    return '$path?${pairs.join('&')}';
  }

  static Future<List<dynamic>> tours({bool auth = true}) async {
    final res = await _client.get('/api/reports/tours', auth: auth);
    final data = res['data'] ?? res;
    return data is List ? data : [];
  }

  static Future<List<dynamic>> cars({bool auth = true}) async {
    final res = await _client.get('/api/reports/cars', auth: auth);
    final data = res['data'] ?? res;
    return data is List ? data : [];
  }

  static Future<Map<String, dynamic>> bookings({bool auth = true}) async {
    final res = await _client.get('/api/reports/bookings', auth: auth);
    return res;
  }

  static Future<List<dynamic>> locations({bool auth = true}) async {
    final res = await _client.get('/api/reports/locations', auth: auth);
    final data = res['data'] ?? res;
    return data is List ? data : [];
  }

  static Future<Map<String, dynamic>> dashboard({bool auth = true}) async {
    final res = await _client.get('/api/reports/dashboard', auth: auth);
    return res;
  }

  static Future<Map<String, dynamic>> revenues({
    required DateTime fromDate,
    required DateTime toDate,
    bool auth = true,
  }) async {
    final path = _withQuery('/api/reports/revenues', {
      'fromDate': fromDate.toIso8601String(),
      'toDate': toDate.toIso8601String(),
    });
    final res = await _client.get(path, auth: auth);
    return res;
  }

  static Future<void> refreshAll() async {
    // Parallel fetch all reports
    await Future.wait([tours(), cars(), bookings(), locations(), dashboard()]);
  }
}
