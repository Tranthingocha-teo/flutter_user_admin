import 'dart:convert';

/// Model đại diện cho Người dùng (User)
/// ĐÁP ỨNG CHÍNH XÁC YÊU CẦU ĐỀ THI:
/// "Chỉ chấp nhận cơ sở dữ liệu gồm các trường: email, matkhau, hoten, hinhanh (không tự bổ sung thêm trường)"
class UserModel {
  final String email;
  final String matkhau;
  final String hoten;
  final String hinhanh;

  UserModel({
    required this.email,
    required this.matkhau,
    required this.hoten,
    required this.hinhanh,
  });

  /// Chuyển đối tượng thành Map để lưu vào Firebase / MongoDB / JSON
  /// Tuyệt đối chỉ gồm đúng 4 trường được yêu cầu
  Map<String, dynamic> toMap() {
    return {
      'email': email.trim(),
      'matkhau': matkhau,
      'hoten': hoten.trim(),
      'hinhanh': hinhanh.trim(),
    };
  }

  /// Khởi tạo đối tượng từ Map (JSON)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      email: (map['email'] ?? '').toString().trim(),
      matkhau: (map['matkhau'] ?? '').toString(),
      hoten: (map['hoten'] ?? '').toString().trim(),
      hinhanh: (map['hinhanh'] ?? '').toString().trim(),
    );
  }

  /// Chuyển thành chuỗi JSON
  String toJson() => json.encode(toMap());

  /// Khởi tạo từ chuỗi JSON
  factory UserModel.fromJson(String source) =>
      UserModel.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Sao chép và cập nhật một số trường
  UserModel copyWith({
    String? email,
    String? matkhau,
    String? hoten,
    String? hinhanh,
  }) {
    return UserModel(
      email: email ?? this.email,
      matkhau: matkhau ?? this.matkhau,
      hoten: hoten ?? this.hoten,
      hinhanh: hinhanh ?? this.hinhanh,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.email.toLowerCase() == email.toLowerCase();
  }

  @override
  int get hashCode => email.toLowerCase().hashCode;
}
