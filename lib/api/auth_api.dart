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
    print('AuthApi.register called with: role=$role, email=$email');
    final body = {
      'firstName': firstName,
      'lastName': lastName,
      'username': username,  // Backend requires exactly "username"
      'userName': username,  // Send both to match all backend expectations
      'email': email,
      'password': password,
      'role': role,
    };
    if (businessName != null && businessName.isNotEmpty) {
      body['businessName'] = businessName;
    }
    print('Sending POST to /api/auth/register with body: $body');
    
    final res = await _client.post('/api/auth/register', body).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        print('Register API timeout after 30s');
        throw Exception('Registration request timed out after 30 seconds');
      },
    );
    print('Register API response: $res');
  }

  static Future<void> logout() async {
    await _client.setToken(null);
  }
}
