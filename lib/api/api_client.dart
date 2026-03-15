import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = 'https://flutter-travel-agency-backend.onrender.com';
const String _tokenKey = 'auth_token';

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _token;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
    _initialized = true;
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString(_tokenKey, token);
    } else {
      await prefs.remove(_tokenKey);
    }
  }

  Future<String?> getToken() async {
    await _ensureInitialized();
    return _token;
  }

  Future<bool> get isLoggedIn async {
    final t = await getToken();
    return t != null && t.isNotEmpty;
  }

  Map<String, String> _headers({bool auth = false}) {
    final h = {'Content-Type': 'application/json'};
    if (auth && _token != null) {
      h['Authorization'] = 'Bearer $_token';
    }
    return h;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response res) async {
    dynamic body;
    try {
      body = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    } catch (e) {
      body = res.body; // if not JSON, use as string
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (body is Map) return body as Map<String, dynamic>;
      if (body is List) return {'data': body};
      return {'data': body};
    }
    final msg = body is Map ? (body['message'] ?? body['error'] ?? res.body) : (body is String ? body : res.body);
    throw ApiException(res.statusCode, msg.toString(), body);
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body, {bool auth = false}) async {
    await _ensureInitialized();
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> get(String path, {bool auth = false}) async {
    await _ensureInitialized();
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: _headers(auth: auth),
    );
    return _handleResponse(res);
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body, {bool auth = false}) async {
    await _ensureInitialized();
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers(auth: auth),
      body: jsonEncode(body),
    );
    return _handleResponse(res);
  }

  Future<void> delete(String path, {bool auth = false}) async {
    await _ensureInitialized();
    final res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: _headers(auth: auth),
    );
    if (res.statusCode >= 200 && res.statusCode < 300) return;
    await _handleResponse(res);
  }

  Map<String, dynamic>? _parseJwtClaims(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final claims = jsonDecode(decoded);
      if (claims is Map<String, dynamic>) return claims;
    } catch (_) {
      // ignore
    }
    return null;
  }

  Future<Map<String, dynamic>?> get tokenClaims async {
    final token = await getToken();
    if (token == null) return null;
    return _parseJwtClaims(token);
  }

  Future<bool> get isAdmin async {
    final claims = await tokenClaims;
    if (claims == null) return false;
    final roleValue = claims['role'] ?? claims['roles'] ?? claims['roleName'];
    if (roleValue == null) return false;

    if (roleValue is String) {
      return roleValue.toLowerCase().contains('admin');
    }

    if (roleValue is List) {
      return roleValue.any((e) => e.toString().toLowerCase().contains('admin'));
    }

    return false;
  }

  Future<String?> get currentUserId async {
    final claims = await tokenClaims;
    if (claims == null) return null;
    return claims['sub']?.toString() ?? claims['id']?.toString() ?? claims['userId']?.toString();
  }
}

class ApiException implements Exception {
  ApiException(this.statusCode, this.message, this.body);
  final int statusCode;
  final String message;
  final dynamic body;
  @override
  String toString() => message;
}
