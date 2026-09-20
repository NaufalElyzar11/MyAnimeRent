import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ImgurService {
  static const String _clientId = '4d3927cf6129dd2';

  Future<String?> uploadImage(File imageFile) async {
    try {
      final uri = Uri.parse('https://api.imgur.com/3/image');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Client-ID $_clientId'
        ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final streamedResponse =
          await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['success'] == true && json['data'] != null) {
          return json['data']['link'] as String?;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
