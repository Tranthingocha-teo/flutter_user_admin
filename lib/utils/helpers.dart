import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class AppHelpers {
  /// Kiểm tra định dạng Email hợp lệ bằng biểu thức chính quy (Regex)
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email.trim());
  }

  /// Kiểm tra chuỗi có phải là Base64 Data URI không
  static bool isBase64Image(String source) {
    return source.startsWith('data:image/') && source.contains('base64,');
  }

  /// Chuyển Base64 Data URI thành Uint8List để hiển thị ảnh
  static Uint8List? getBytesFromBase64(String source) {
    try {
      final base64Str = source.split('base64,').last;
      return base64Decode(base64Str);
    } catch (_) {
      return null;
    }
  }

  /// Lấy 1 hoặc 2 chữ cái đầu của họ tên làm avatar đại diện khi ảnh lỗi
  static String getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  /// Widget hiển thị Avatar người dùng thông minh:
  /// - Hỗ trợ URL mạng (NetworkImage)
  /// - Hỗ trợ Base64 Data URI (MemoryImage)
  /// - Tự động fallback sang chữ cái đầu nếu không có ảnh hoặc ảnh hỏng
  static Widget buildAvatar({
    required String imageUrl,
    required String name,
    double radius = 24,
    Color? backgroundColor,
    Color? textColor,
  }) {
    final cleanUrl = imageUrl.trim();

    Widget fallbackWidget = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? const Color(0xFF6366F1).withOpacity(0.15),
      child: Text(
        getInitials(name),
        style: TextStyle(
          color: textColor ?? const Color(0xFF4F46E5),
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.75,
        ),
      ),
    );

    if (cleanUrl.isEmpty) {
      return fallbackWidget;
    }

    if (isBase64Image(cleanUrl)) {
      final bytes = getBytesFromBase64(cleanUrl);
      if (bytes != null) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(bytes),
          onBackgroundImageError: (exception, stackTrace) => fallbackWidget,
        );
      }
    }

    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.grey.shade200,
        child: ClipOval(
          child: Image.network(
            cleanUrl,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => fallbackWidget,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: radius * 0.8,
                  height: radius * 0.8,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return fallbackWidget;
  }
}
