import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'api_client.dart';

class UploadApi {
  static final _client = ApiClient.instance;

  static Future<Map<String, dynamic>> uploadImage(PlatformFile file) async {
    print('=== UPLOAD DEBUG ===');
    print('File: ${file.name} (${file.extension}) size: ${file.size} bytes: ${file.bytes != null}');
    
    final ext = file.extension?.toLowerCase() ?? '';
    final mimeType = switch(ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'application/octet-stream',
    };
    
    print('MIME: $mimeType field: images');
    
    final bytes = file.bytes ?? <int>[];
    print('Bytes length: ${bytes.length}');

    final multipartFile = http.MultipartFile.fromBytes(
      'images',
      bytes,
      filename: file.name,
      contentType: MediaType.parse(mimeType),
    );

    print('Created MultipartFile ready');

    final response = await _client.postMultipart(
      '/api/upload/image',
      files: [multipartFile],
      auth: true,
    );

    print('=== UPLOAD RESULT === $response');
    return response;
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
