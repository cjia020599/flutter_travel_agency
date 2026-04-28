import 'package:file_picker/file_picker.dart';
import '../api/upload_api.dart';

class ImageUploadService {
  static Map<String, String?> _extractUploadResult(Map<String, dynamic> raw) {
    String? readUrl(Map<String, dynamic> source) {
      return source['url']?.toString() ??
          source['secure_url']?.toString() ??
          source['imageUrl']?.toString();
    }

    String? readPublicId(Map<String, dynamic> source) {
      return source['publicId']?.toString() ??
          source['public_id']?.toString() ??
          source['imagePublicId']?.toString();
    }

    final directUrl = readUrl(raw);
    final directPublicId = readPublicId(raw);
    if ((directUrl ?? '').isNotEmpty || (directPublicId ?? '').isNotEmpty) {
      return {'url': directUrl, 'publicId': directPublicId};
    }

    final data = raw['data'];
    if (data is Map<String, dynamic>) {
      final url = readUrl(data);
      final publicId = readPublicId(data);
      if ((url ?? '').isNotEmpty || (publicId ?? '').isNotEmpty) {
        return {'url': url, 'publicId': publicId};
      }
    }

    dynamic firstFromList(dynamic value) {
      if (value is List && value.isNotEmpty) return value.first;
      return null;
    }

    final first =
        firstFromList(raw['images']) ??
        firstFromList(raw['files']) ??
        firstFromList(raw['data']);
    if (first is Map) {
      final map = first.map((key, value) => MapEntry(key.toString(), value));
      final url = readUrl(map);
      final publicId = readPublicId(map);
      if ((url ?? '').isNotEmpty || (publicId ?? '').isNotEmpty) {
        return {'url': url, 'publicId': publicId};
      }
    }

    throw Exception(
      'Upload response is missing image URL/publicId. Response: $raw',
    );
  }

  static Future<Map<String, String?>> uploadImage(PlatformFile file) async {
    if (file.bytes == null || file.bytes!.isEmpty) {
      throw Exception('Selected file has no bytes to upload.');
    }

    final response = await UploadApi.uploadImage(file);
    return _extractUploadResult(response);
  }

  static Future<bool> deleteImage(String publicId) async {
    try {
      return await UploadApi.deleteImage(publicId);
    } catch (e) {
      print('Delete error: $e');
      return false;
    }
  }
}
