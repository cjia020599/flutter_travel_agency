import 'api_client.dart';

class RatingsApi {
  static final _client = ApiClient.instance;

  static Future<List<dynamic>> list({
    String? moduleType,
    int? moduleId,
    int? userId,
  }) async {
    String path;
    
    // If both moduleType and moduleId are provided, use path-based endpoint
    if (moduleType != null && moduleType.isNotEmpty && moduleId != null) {
      path = '/api/ratings/$moduleType/$moduleId';
    } else {
      // Otherwise use query parameters
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
      final queryString = query.isNotEmpty ? '?${query.join('&')}' : '';
      path = '/api/ratings$queryString';
    }

    print('DEBUG: RatingsApi.list() called with moduleType=$moduleType, moduleId=$moduleId');
    print('DEBUG: Path used: $path');
    
    final res = await _client.get(path, auth: true);
    
    print('DEBUG: GET $path returned. Response type: ${res.runtimeType}');
    print('DEBUG: Full response: $res');

    // The API should return a list directly or wrapped in a data field
    if (res is List) {
      print('DEBUG: Response is already a list with ${(res as List).length} items');
      return res as List<dynamic>;
    }

    // Try different possible field names
    if (res['data'] is List) {
      print('DEBUG: Found ratings at "data" key with ${(res['data'] as List).length} items');
      return res['data'] as List<dynamic>;
    }
    if (res['ratings'] is List) {
      print('DEBUG: Found ratings at "ratings" key with ${(res['ratings'] as List).length} items');
      return res['ratings'] as List<dynamic>;
    }
    if (res['rating'] is List) {
      print('DEBUG: Found ratings at "rating" key with ${(res['rating'] as List).length} items');
      return res['rating'] as List<dynamic>;
    }
    if (res['rows'] is List) {
      print('DEBUG: Found ratings at "rows" key with ${(res['rows'] as List).length} items');
      return res['rows'] as List<dynamic>;
    }
    if (res['items'] is List) {
      print('DEBUG: Found ratings at "items" key with ${(res['items'] as List).length} items');
      return res['items'] as List<dynamic>;
    }
    if (res['results'] is List) {
      print('DEBUG: Found ratings at "results" key with ${(res['results'] as List).length} items');
      return res['results'] as List<dynamic>;
    }
  
    print('DEBUG: No ratings found, returning empty list. Response was: $res');
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
