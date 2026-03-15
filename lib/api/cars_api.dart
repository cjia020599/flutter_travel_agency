import 'api_client.dart';

class CarsApi {
  static final _client = ApiClient.instance;

  static Future<List<dynamic>> list() async {
    final res = await _client.get('/api/cars');
    final data = res['data'] ?? res['cars'];
    if (data is List) return data;
    if (res is List) return res as List<dynamic>;
    return [];
  }

  static Future<Map<String, dynamic>> get(int id) async {
    return _client.get('/api/cars/$id');
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    return _client.post('/api/cars', body, auth: true);
  }

  static Future<Map<String, dynamic>> update(int id, Map<String, dynamic> body) async {
    return _client.put('/api/cars/$id', body, auth: true);
  }

  static Future<void> delete(int id) async {
    return _client.delete('/api/cars/$id', auth: true);
  }
}
