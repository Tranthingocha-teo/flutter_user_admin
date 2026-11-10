import '../models/user_model.dart';

/// Dữ liệu mẫu ban đầu tuân thủ nghiêm ngặt 4 trường:
/// email, matkhau, hoten, hinhanh
class InitialUsersData {
  static List<UserModel> get defaultUsers => [
        UserModel(
          email: 'admin@gmail.com',
          matkhau: 'Admin@123',
          hoten: 'Trần Thị Ngọc Hà',
          hinhanh:
              'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=80',
        ),
        UserModel(
          email: 'nguyenvanan@gmail.com',
          matkhau: 'An123456',
          hoten: 'Nguyễn Văn An',
          hinhanh:
              'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=500&auto=format&fit=crop&q=80',
        ),
        UserModel(
          email: 'lethibaotran@gmail.com',
          matkhau: 'TranLe2026',
          hoten: 'Lê Thị Bảo Trân',
          hinhanh:
              'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=500&auto=format&fit=crop&q=80',
        ),
        UserModel(
          email: 'phamquanghuy@gmail.com',
          matkhau: 'HuyPham88',
          hoten: 'Phạm Quang Huy',
          hinhanh:
              'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=500&auto=format&fit=crop&q=80',
        ),
        UserModel(
          email: 'hoangthimaiphuong@gmail.com',
          matkhau: 'PhuongMai99',
          hoten: 'Hoàng Thị Mai Phương',
          hinhanh:
              'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=500&auto=format&fit=crop&q=80',
        ),
      ];

  /// Bộ avatar mẫu có sẵn để người dùng chọn nhanh khi thêm/sửa
  static const List<String> presetAvatars = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=500&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=500&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=500&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=500&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=500&auto=format&fit=crop&q=80',
    'https://images.unsplash.com/photo-1628157582853-a796fa650a6a?w=500&auto=format&fit=crop&q=80',
  ];
}
