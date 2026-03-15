import 'api_client.dart';

class UserApi {
  static final _client = ApiClient.instance;

  static Future<Map<String, dynamic>> getProfile() async {
    return _client.get('/api/user/profile', auth: true);
  }

  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    return _client.put('/api/user/profile/update', data, auth: true);
  }

  /// Returns true if the current user is an admin.
  ///
  /// This prefers the backend JWT role claim (if present) but falls back to
  /// inspecting the profile response, since some auth implementations do not
  /// include the role in the token.
  static bool _valueContainsAdmin(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase().contains('admin');
    if (value is List) return value.any((e) => _valueContainsAdmin(e));
    if (value is Map) return value.values.any((e) => _valueContainsAdmin(e));
    return false;
  }

  static Future<bool> isAdmin() async {
    final claims = await _client.tokenClaims;
    if (claims != null) {
      final roleValue = claims['role'] ?? claims['roles'] ?? claims['roleName'];
      if (_valueContainsAdmin(roleValue)) return true;
    }

    try {
      final profile = await getProfile();
      final possibleRoleKeys = ['role', 'roles', 'roleName', 'role_name', 'userType', 'type', 'roleId', 'role_id'];
      for (final k in possibleRoleKeys) {
        if (_valueContainsAdmin(profile[k])) return true;
      }

      // Some backends use a boolean flag
      if (profile['isAdmin'] == true || profile['is_admin'] == true || profile['admin'] == true) return true;

      // As a fallback, search any string-ish field for "admin".
      for (final value in profile.values) {
        if (_valueContainsAdmin(value)) return true;
      }
    } catch (_) {
      // Ignore; we can't determine role without profile.
    }

    return false;
  }
}
