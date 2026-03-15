import 'api_client.dart';

class AuthApi {
  static final _client = ApiClient.instance;

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _client.post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    final token = res['token'] as String?;
    if (token != null) {
      await _client.setToken(token);
    }
    return res;
  }

  static Future<void> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
    required String role,
    String? businessName,
  }) async {
    final body = {
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'email': email,
      'password': password,
      'role': role,
    };
    if (businessName != null && businessName.isNotEmpty) {
      body['businessName'] = businessName;
    }
    await _client.post('/api/auth/register', body);
  }

  static Future<void> logout() async {
    await _client.setToken(null);
  }
}
