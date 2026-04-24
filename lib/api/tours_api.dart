import 'api_client.dart';

class ToursApi {
  static final _client = ApiClient.instance;

  static Future<List<dynamic>> list() async {
    final res = await _client.get('/api/tours');
    final data = res['data'] ?? res['tours'];
    if (data is List) return data;
    if (res is List) return res as List<dynamic>;
    return [];
  }

  static Future<Map<String, dynamic>> get(int id) async {
    return _client.get('/api/tours/$id');
  }

  static Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    return _client.post('/api/tours', body, auth: true);
  }

  static Future<Map<String, dynamic>> update(int id, Map<String, dynamic> body) async {
    return _client.put('/api/tours/$id', body, auth: true);
  }

  static Future<void> delete(int id) async {
    return _client.delete('/api/tours/$id', auth: true);
  }

  static Future<List<dynamic>> deletedTours() async {
    final dynamic res = await _client.get('/api/tours/recovery/deleted', auth: true);
    if (res is List) return List<dynamic>.from(res);
    final data = res['data'];
    if (data is List) return List<dynamic>.from(data);
    return [];
  }

  static Future<Map<String, dynamic>> restoreTour(int id) async {
    return _client.patch('/api/tours/recovery/$id/restore', {}, auth: true);
  }

  static Future<void> forceDeleteTour(int id) async {
    await _client.delete('/api/tours/recovery/$id', auth: true);
  }
}
