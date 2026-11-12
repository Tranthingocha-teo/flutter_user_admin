import 'dart:convert';

/// Model đại diện cho Sản phẩm (Product)
/// ĐÁP ỨNG CHÍNH XÁC YÊU CẦU ĐỀ THI:
/// "Chỉ chấp nhận cơ sở dữ liệu gồm các trường: name, price, soluong, image
///  (không tự bổ sung thêm trường)"
///
/// [key] KHÔNG phải là một trường dữ liệu: đó là ID document trên Firestore
/// (ID document trong collection products) do Firestore tự sinh, dùng để sửa/xóa đúng sản phẩm.
/// [key] không bao giờ được ghi vào CSDL hay file database.json.
class ProductModel {
  final String key;
  final String name;
  final int price;
  final int soluong;
  final String image;

  ProductModel({
    this.key = '',
    required this.name,
    required this.price,
    required this.soluong,
    required this.image,
  });

  /// Map lưu vào Firestore / file JSON — chỉ đúng 4 trường
  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'price': price,
      'soluong': soluong,
      'image': image.trim(),
    };
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(
          v?.toString().replaceAll(RegExp(r'[^0-9-]'), '') ?? '',
        ) ??
        0;
  }

  factory ProductModel.fromMap(Map<String, dynamic> map, {String key = ''}) {
    return ProductModel(
      key: key,
      name: (map['name'] ?? '').toString().trim(),
      price: _toInt(map['price']),
      soluong: _toInt(map['soluong']),
      image: (map['image'] ?? '').toString().trim(),
    );
  }

  String toJson() => json.encode(toMap());

  ProductModel copyWith({
    String? key,
    String? name,
    int? price,
    int? soluong,
    String? image,
  }) {
    return ProductModel(
      key: key ?? this.key,
      name: name ?? this.name,
      price: price ?? this.price,
      soluong: soluong ?? this.soluong,
      image: image ?? this.image,
    );
  }
}
