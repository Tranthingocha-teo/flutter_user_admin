import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Cấu hình Cloudinary (tài khoản miễn phí).
/// - cloudName: hiển thị ở trang Dashboard của Cloudinary.
/// - uploadPreset: tên "Upload preset" ở chế độ Unsigned
///   (Settings → Upload → Upload presets).
class CloudinaryConfig {
  static const String cloudName = 'dkogrqsdw';
  static const String uploadPreset = 'flutter_user_admin';
  static const String folder = 'flutter_user_admin';

  static bool get isConfigured =>
      !cloudName.startsWith('YOUR_') && !uploadPreset.startsWith('YOUR_');
}

/// Upload ảnh lên Cloudinary và trả về đường link https của ảnh.
/// Link này được lưu vào trường `hinhanh` trên Firebase.
class ImageUploadService {
  static Future<String> uploadImage(Uint8List bytes, String fileName) async {
    if (!CloudinaryConfig.isConfigured) {
      throw Exception(
        'Chưa cấu hình Cloudinary (cloudName / uploadPreset) trong image_upload_service.dart',
      );
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..fields['folder'] = CloudinaryConfig.folder
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName.isNotEmpty ? fileName : 'avatar.jpg',
        ),
      );

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();
    final data = json.decode(body) as Map<String, dynamic>;

    if (streamed.statusCode == 200 && data['secure_url'] is String) {
      return data['secure_url'] as String;
    }
    final msg = (data['error'] is Map) ? data['error']['message'] : body;
    throw Exception('Upload ảnh thất bại (${streamed.statusCode}): $msg');
  }
}
