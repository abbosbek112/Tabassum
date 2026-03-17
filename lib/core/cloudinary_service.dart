import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'constants.dart';

class CloudinaryService {
  static Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    String? folder,
  }) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
      ));
    
    if (folder != null) {
      request.fields['folder'] = folder;
    }

    final response = await request.send();
    final responseData = await response.stream.toBytes();
    final responseString = String.fromCharCodes(responseData);

    if (response.statusCode == 200) {
      final json = jsonDecode(responseString);
      return json['secure_url'];
    } else {
      throw Exception('Failed to upload image to Cloudinary: $responseString');
    }
  }
}
