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

  static Future<List<dynamic>> categories() async {
    final res = await _client.get('/api/categories');
    if (res is List) return res as List<dynamic>;
    final data = res['data'];
    if (data is List) return data;
    return [];
  }

  static Future<Map<String, dynamic>> createCategory(Map<String, dynamic> payload) async {
    final res = await _client.post('/api/categories', payload, auth: true);
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> updateCategory(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _client.put('/api/categories/$id', payload, auth: true);
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<void> deleteCategory(int id) async {
    await _client.delete('/api/categories/$id', auth: true);
  }

  static Future<Map<String, dynamic>> createAttribute(Map<String, dynamic> payload) async {
    final res = await _client.post('/api/attributes', payload, auth: true);
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<Map<String, dynamic>> updateAttribute(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _client.put('/api/attributes/$id', payload, auth: true);
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<void> deleteAttribute(int id) async {
    await _client.delete('/api/attributes/$id', auth: true);
  }

  static Future<List<dynamic>> attributeTerms(int attributeId) async {
    final res = await _client.get('/api/attributes/$attributeId/terms');
    if (res is List) return res as List<dynamic>;
    final data = res['data'];
    if (data is List) return data;
    return [];
  }

  static Future<Map<String, dynamic>> createAttributeTerm(
    int attributeId,
    Map<String, dynamic> payload,
  ) async {
    final res = await _client.post('/api/attributes/$attributeId/terms', payload, auth: true);
    return Map<String, dynamic>.from(res as Map);
  }

  static Future<void> deleteAttributeTerm(int termId) async {
    await _client.delete('/api/attribute-terms/$termId', auth: true);
  }
}
