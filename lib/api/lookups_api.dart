import 'api_client.dart';

class LookupsApi {
  static final _client = ApiClient.instance;

  static Future<List<dynamic>> locations() async {
    final res = await _client.get('/api/locations');
    final data = res['data'] ?? res['locations'];
    if (data is List) return data;
    if (res is List) return res as List<dynamic>;
    return [];
  }

  static Future<List<dynamic>> attributes() async {
    final res = await _client.get('/api/attributes');
    if (res is List) return res as List<dynamic>;
    final data = res['data'];
    if (data is List) return data;
    return [];
  }
}
