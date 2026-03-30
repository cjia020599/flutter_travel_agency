import 'api_client.dart';

class RatingsApi {
  static final _client = ApiClient.instance;

  static Future<List<dynamic>> list({
    String? moduleType,
    int? moduleId,
    int? userId,
  }) async {
    final query = <String>[];
    if (moduleType != null && moduleType.isNotEmpty) {
      query.add('moduleType=$moduleType');
    }
    if (moduleId != null) {
      query.add('moduleId=$moduleId');
    }
    if (userId != null) {
      query.add('userId=$userId');
    }

    final path = query.isEmpty
        ? '/api/ratings'
        : '/api/ratings?${query.join('&')}';

    final res = await _client.get(path);

    final data = res['data'] ?? res['ratings'];
    if (data is List) return data;

    // Handle backend shapes like:
    // { success: true, rating: [...] } or { success: true, rows: [...] }
    final altList = res['rating'] ?? res['rows'] ?? res['items'] ?? res['results'];
    if (altList is List) return altList;

    // Handle nested payload in case backend wraps as object
    // e.g. { data: { ratings: [...] } }
    if (data is Map) {
      final nested = data['ratings'] ?? data['rating'] ?? data['rows'] ?? data['items'] ?? data['results'];
      if (nested is List) return nested;
    }

    return [];
  }

  static Future<Map<String, dynamic>> get(int id) async {
    return _client.get('/api/ratings/$id');
  }

  static Future<Map<String, dynamic>> create({
    required String moduleType,
    required int moduleId,
    required int stars,
    String? comment,
  }) async {
    final body = <String, dynamic>{
      'moduleType': moduleType,
      'moduleId': moduleId,
      'stars': stars,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    };
    return _client.post('/api/ratings', body, auth: true);
  }

  static Future<Map<String, dynamic>> update(
    int id, {
    int? stars,
    String? comment,
  }) async {
    final body = <String, dynamic>{};
    if (stars != null) body['stars'] = stars;
    if (comment != null) body['comment'] = comment;
    return _client.put('/api/ratings/$id', body, auth: true);
  }

  static Future<void> delete(int id) async {
    return _client.delete('/api/ratings/$id', auth: true);
  }
}
