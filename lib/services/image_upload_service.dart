import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';
import '../api/api_client.dart';

class ImageUploadService {
  static Future<Map<String, String?>?> uploadImage(PlatformFile file) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/upload/image'),
      );

      // Add auth header
      final token = await ApiClient.instance.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Debug info for web upload
      print('Uploading file: name=${file.name}, size=${file.size}, extension=${file.extension}');

      // Add the file with explicit content type (important for web upload)
      final ext = file.extension?.toLowerCase();
      final mimeType = <String, String>{
        'png': 'image/png',
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'gif': 'image/gif',
        'webp': 'image/webp',
      }[ext ?? ''] ?? 'application/octet-stream';

      // Some backends accept 'file' instead of 'image'. If your backend expects a different key, switch here.
      request.files.add(
        http.MultipartFile.fromBytes(
'images', // Backend expects 'images' per feedback
          file.bytes!,
          filename: file.name,
          contentType: MediaType(mimeType.split('/')[0], mimeType.split('/')[1]),
        ),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      print('Image upload response status=${response.statusCode}, body=$responseData');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        var jsonResponse = json.decode(responseData);
        return {
          'url': jsonResponse['url'] as String?,
          'publicId': jsonResponse['publicId'] as String?,
        };
      } else {
        throw Exception('Upload failed: ${response.statusCode} - $responseData');
      }
    } catch (e) {
      print('Upload error: $e');
      return null;
    }
  }

  static Future<bool> deleteImage(String publicId) async {
    try {
      final token = await ApiClient.instance.getToken();
      final headers = <String, String>{};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/api/upload/image/$publicId'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Delete error: $e');
      return false;
    }
  }
}