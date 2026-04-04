import '../models/notification_item.dart';
import 'api_client.dart';

class NotificationsApi {
  static final _client = ApiClient.instance;

  static Future<List<NotificationItem>> list({
    int page = 1,
    int limit = 20,
    bool unreadOnly = false,
  }) async {
    final path = '/api/notifications?page=$page&limit=$limit&unreadOnly=$unreadOnly';
    final res = await _client.get(path, auth: true);

    final rawList = _extractList(res);
    return rawList.map((e) => NotificationItem.fromJson(e)).toList();
  }

  static Future<NotificationItem> markRead(int id) async {
    final res = await _client.patch('/api/notifications/$id/read', <String, dynamic>{}, auth: true);
    if (res['data'] is Map<String, dynamic>) {
      return NotificationItem.fromJson(res['data'] as Map<String, dynamic>);
    }
    return NotificationItem.fromJson(res);
  }

  static List<Map<String, dynamic>> _extractList(Map<String, dynamic> res) {
    final data = res['items'] ?? res['data'] ?? res['notifications'] ?? res['rows'];
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    if (data is Map) {
      final nested = data['items'] ?? data['data'] ?? data['notifications'] ?? data['rows'];
      if (nested is List) {
        return nested.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }

    final alt = res['results'] ?? res['result'];
    if (alt is List) {
      return alt.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    return <Map<String, dynamic>>[];
  }
}
