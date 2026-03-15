import 'api_client.dart';

class AdminApi {
  static final _client = ApiClient.instance;

  /// Returns all users except the currently authenticated user.
  static Future<List<dynamic>> listUsers() async {
    final dynamic res = await _client.get('/api/admin/users', auth: true);
    // The API client wraps list responses in a map under `data`.
    if (res is Map && res['data'] is List) return res['data'] as List<dynamic>;
    // If the backend returns the list directly, handle that case.
    if (res is List) return res;
    return [];
  }

  /// Read a user by their id.
  static Future<Map<String, dynamic>> getUser(String id) async {
    return _client.get('/api/admin/users/$id', auth: true);
  }

  /// Update a user by id (same schema as profile update).
  static Future<Map<String, dynamic>> updateUser(String id, Map<String, dynamic> body) async {
    return _client.put('/api/admin/users/$id', body, auth: true);
  }

  /// Delete a user by id.
  static Future<void> deleteUser(String id) async {
    await _client.delete('/api/admin/users/$id', auth: true);
  }
}
