import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'api_client.dart';

class UploadApi {
  static final _client = ApiClient.instance;

  static Future<Map<String, dynamic>> _uploadWithField(
    PlatformFile file,
    String fieldName,
  ) async {
    final ext = file.extension?.toLowerCase() ?? '';
    final mimeType = switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };

    final http.MultipartFile multipartFile;
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      multipartFile = http.MultipartFile.fromBytes(
        fieldName,
        file.bytes!,
        filename: file.name,
        contentType: MediaType.parse(mimeType),
      );
    } else if ((file.path ?? '').isNotEmpty) {
      multipartFile = await http.MultipartFile.fromPath(
        fieldName,
        file.path!,
        filename: file.name,
        contentType: MediaType.parse(mimeType),
      );
    } else {
      throw Exception(
        'Selected file has no uploadable bytes/path. Re-select the file and try again.',
      );
    }

    return _client.postMultipart(
      '/api/upload/image',
      files: [multipartFile],
      auth: true,
    );
  }

  static Future<Map<String, dynamic>> uploadImage(PlatformFile file) async {
    try {
      // Most backend routes expect "images".
      return await _uploadWithField(file, 'images');
    } on ApiException {
      // Fallback for APIs expecting "image".
      return _uploadWithField(file, 'image');
    }
  }

  static Future<bool> deleteImage(String publicId) async {
    try {
      await _client.delete('/api/upload/image/$publicId', auth: true);
      return true;
    } catch (e) {
      print('Delete error: $e');
      return false;
    }
  }
}
