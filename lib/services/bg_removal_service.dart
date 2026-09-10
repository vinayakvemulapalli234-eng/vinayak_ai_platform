import 'dart:typed_data';
import 'package:http/http.dart' as http;

class BgRemovalService {
  static const String _apiKey = 'oBqJKQWVFXDPM3fwvs4T7L3i';

  static Future<Uint8List?> removeBackground(
      Uint8List imageBytes) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.remove.bg/v1.0/removebg'),
      );

      request.headers['X-Api-Key'] = _apiKey;

      request.fields['size'] = 'auto';

      request.files.add(
        http.MultipartFile.fromBytes(
          'image_file',
          imageBytes,
          filename: 'product.jpg',
        ),
      );

      final response = await request.send();

      if (response.statusCode == 200) {
        return await response.stream.toBytes();
      }

      print('Background removal failed: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Background removal error: $e');
      return null;
    }
  }
}