import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class AppHelpers {
  static bool isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email.trim());
  }

  /// 7490000 -> "7.490.000 ₫"
  static String formatPrice(int price) => '${formatNumber(price)} ₫';

  /// 7490000 -> "7.490.000"
  static String formatNumber(int n) {
    final s = n.abs().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return n < 0 ? '-$buf' : buf.toString();
  }

  static bool isBase64Image(String source) {
    return source.startsWith('data:image/') && source.contains('base64,');
  }

  static Uint8List? getBytesFromBase64(String source) {
    try {
      return base64Decode(source.split('base64,').last);
    } catch (_) {
      return null;
    }
  }

  /// Ảnh sản phẩm bo góc: hỗ trợ URL mạng, Base64, và ô thay thế khi ảnh lỗi
  static Widget buildProductImage({
    required String imageUrl,
    double size = 48,
    double radius = 10,
  }) {
    final cleanUrl = imageUrl.trim();

    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        size: size * 0.45,
        color: const Color(0xFF4F46E5),
      ),
    );

    Widget image;
    if (isBase64Image(cleanUrl) && getBytesFromBase64(cleanUrl) != null) {
      image = Image.memory(
        getBytesFromBase64(cleanUrl)!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      );
    } else if (cleanUrl.startsWith('http://') ||
        cleanUrl.startsWith('https://')) {
      image = Image.network(
        cleanUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: size,
            height: size,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    } else {
      return placeholder;
    }

    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: image);
  }
}

/// Tình trạng tồn kho — TÍNH TỪ trường `soluong`, không lưu thành trường mới
/// (đề chỉ cho phép 4 trường name, price, soluong, image).
class StockStatus {
  static const int lowStock = 5;

  final String label;
  final Color color;
  final IconData icon;

  const StockStatus._(this.label, this.color, this.icon);

  static const outOfStock = StockStatus._(
    'Hết hàng',
    Color(0xFFEF4444),
    Icons.cancel_rounded,
  );
  static const low = StockStatus._(
    'Sắp hết',
    Color(0xFFF59E0B),
    Icons.warning_amber_rounded,
  );
  static const inStock = StockStatus._(
    'Còn hàng',
    Color(0xFF10B981),
    Icons.check_circle_rounded,
  );

  factory StockStatus.of(int soluong) =>
      soluong <= 0 ? outOfStock : (soluong < lowStock ? low : inStock);

  /// Nhãn tình trạng dạng viên thuốc (dùng ở bảng, thẻ, chi tiết)
  Widget badge({double fontSize = 12}) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: fontSize * 0.8,
      vertical: fontSize * 0.35,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: fontSize + 2, color: color),
        SizedBox(width: fontSize * 0.35),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
          ),
        ),
      ],
    ),
  );
}
