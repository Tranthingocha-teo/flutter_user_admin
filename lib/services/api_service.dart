import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'mock_data.dart';

enum DatabaseSource {
  firebase,
  mongodb,
  localStorage,
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String _storageKey = 'vku_midterm_users_data';
  static const String _firebaseUrlKey = 'vku_firebase_url';
  static const String _databaseSourceKey = 'vku_database_source';

  /// URL mặc định của Firebase Realtime Database
  /// Có thể tùy chỉnh linh hoạt từ giao diện cài đặt CSDL
  String _firebaseBaseUrl =
      'https://skinsense2-f4f3c-default-rtdb.firebaseio.com';

  /// URL Backend MongoDB (Node.js Express Server)
  String _mongoBaseUrl = 'http://localhost:5000/api/users';

  DatabaseSource _currentSource = DatabaseSource.firebase;

  DatabaseSource get currentSource => _currentSource;
  String get firebaseUrl => _firebaseBaseUrl;
  String get mongoUrl => _mongoBaseUrl;

  /// Khởi tạo và nạp dữ liệu
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_firebaseUrlKey);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _firebaseBaseUrl = savedUrl;
    }

    final savedSource = prefs.getString(_databaseSourceKey);
    if (savedSource != null) {
      if (savedSource == 'mongodb') {
        _currentSource = DatabaseSource.mongodb;
      } else if (savedSource == 'localStorage') {
        _currentSource = DatabaseSource.localStorage;
      } else {
        _currentSource = DatabaseSource.firebase;
      }
    }

    // Nếu chưa có dữ liệu nào trong máy, khởi tạo bộ dữ liệu mẫu chuẩn
    final localData = prefs.getString(_storageKey);
    if (localData == null || localData.isEmpty) {
      await _saveLocalUsers(InitialUsersData.defaultUsers);
    }
  }

  /// Cập nhật nguồn cơ sở dữ liệu
  Future<void> setDatabaseSource(DatabaseSource source, {String? customUrl}) async {
    _currentSource = source;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_databaseSourceKey, source.name);

    if (customUrl != null && customUrl.isNotEmpty) {
      if (source == DatabaseSource.firebase) {
        _firebaseBaseUrl = customUrl;
        await prefs.setString(_firebaseUrlKey, customUrl);
      } else if (source == DatabaseSource.mongodb) {
        _mongoBaseUrl = customUrl;
      }
    }
  }

  /// Khóa an toàn cho Firebase Realtime Database key
  String _sanitizeKey(String email) {
    return email
        .toLowerCase()
        .replaceAll('.', '_dot_')
        .replaceAll('@', '_at_')
        .replaceAll('#', '_hash_')
        .replaceAll(r'$', '_dollar_')
        .replaceAll('[', '_lb_')
        .replaceAll(']', '_rb_');
  }

  // ==========================================
  // 1. LẤY DANH SÁCH NGƯỜI DÙNG (READ)
  // ==========================================
  Future<List<UserModel>> getUsers() async {
    List<UserModel> users = [];

    // Ưu tiên gọi Firebase Realtime Database nếu chọn Firebase
    if (_currentSource == DatabaseSource.firebase && _firebaseBaseUrl.isNotEmpty) {
      try {
        final url = Uri.parse('$_firebaseBaseUrl/users.json');
        final response =
            await http.get(url).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200 && response.body != 'null') {
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            decoded.forEach((key, value) {
              if (value is Map<String, dynamic>) {
                users.add(UserModel.fromMap(value));
              }
            });
          } else if (decoded is List) {
            for (var item in decoded) {
              if (item is Map<String, dynamic>) {
                users.add(UserModel.fromMap(item));
              }
            }
          }
          if (users.isNotEmpty) {
            // Đồng bộ lại local cache
            await _saveLocalUsers(users);
            return users;
          }
        }
      } catch (e) {
        debugPrint('Firebase fetch warning (dùng local sync fallback): $e');
      }
    }

    // Nếu chọn MongoDB API
    if (_currentSource == DatabaseSource.mongodb) {
      try {
        final url = Uri.parse(_mongoBaseUrl);
        final response =
            await http.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final decoded = json.decode(response.body);
          if (decoded is List) {
            users = decoded
                .map((item) => UserModel.fromMap(item as Map<String, dynamic>))
                .toList();
            await _saveLocalUsers(users);
            return users;
          }
        }
      } catch (e) {
        debugPrint('MongoDB fetch warning (dùng local sync fallback): $e');
      }
    }

    // Fallback: Đọc từ Local Storage (Bảo đảm ứng dụng luôn chạy 100% không bao giờ crash)
    return await _getLocalUsers();
  }

  // ==========================================
  // 2. THÊM NGƯỜI DÙNG MỚI (CREATE)
  // ==========================================
  Future<bool> addUser(UserModel newUser) async {
    // 1. Lưu vào Local Storage trước
    final currentList = await _getLocalUsers();
    final index = currentList
        .indexWhere((u) => u.email.toLowerCase() == newUser.email.toLowerCase());
    if (index != -1) {
      throw Exception('Email này đã tồn tại trong hệ thống!');
    }

    currentList.add(newUser);
    await _saveLocalUsers(currentList);

    // 2. Đồng bộ lên Firebase Realtime Database
    if (_firebaseBaseUrl.isNotEmpty) {
      try {
        final key = _sanitizeKey(newUser.email);
        final url = Uri.parse('$_firebaseBaseUrl/users/$key.json');
        await http
            .put(url, body: newUser.toJson())
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Firebase sync warning: $e');
      }
    }

    // 3. Đồng bộ lên MongoDB Server (nếu chạy)
    if (_currentSource == DatabaseSource.mongodb) {
      try {
        final url = Uri.parse(_mongoBaseUrl);
        await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: newUser.toJson(),
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('MongoDB sync warning: $e');
      }
    }

    return true;
  }

  // ==========================================
  // 3. SỬA THÔNG TIN NGƯỜI DÙNG (UPDATE)
  // ==========================================
  Future<bool> updateUser(String oldEmail, UserModel updatedUser) async {
    // 1. Cập nhật trong Local Storage
    final currentList = await _getLocalUsers();
    final index = currentList
        .indexWhere((u) => u.email.toLowerCase() == oldEmail.toLowerCase());
    if (index == -1) {
      throw Exception('Không tìm thấy người dùng để cập nhật!');
    }

    // Nếu sửa email và trùng với email khác
    if (oldEmail.toLowerCase() != updatedUser.email.toLowerCase()) {
      final conflict = currentList.any((u) =>
          u.email.toLowerCase() == updatedUser.email.toLowerCase() &&
          u.email.toLowerCase() != oldEmail.toLowerCase());
      if (conflict) {
        throw Exception('Email mới đã thuộc về một tài khoản khác!');
      }
    }

    currentList[index] = updatedUser;
    await _saveLocalUsers(currentList);

    // 2. Đồng bộ lên Firebase
    if (_firebaseBaseUrl.isNotEmpty) {
      try {
        if (oldEmail.toLowerCase() != updatedUser.email.toLowerCase()) {
          // Xóa key cũ, thêm key mới
          final oldKey = _sanitizeKey(oldEmail);
          final oldUrl = Uri.parse('$_firebaseBaseUrl/users/$oldKey.json');
          await http.delete(oldUrl).timeout(const Duration(seconds: 3));
        }
        final newKey = _sanitizeKey(updatedUser.email);
        final newUrl = Uri.parse('$_firebaseBaseUrl/users/$newKey.json');
        await http
            .put(newUrl, body: updatedUser.toJson())
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Firebase update warning: $e');
      }
    }

    // 3. Đồng bộ lên MongoDB
    if (_currentSource == DatabaseSource.mongodb) {
      try {
        final url = Uri.parse('$_mongoBaseUrl/${Uri.encodeComponent(oldEmail)}');
        await http.put(
          url,
          headers: {'Content-Type': 'application/json'},
          body: updatedUser.toJson(),
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('MongoDB update warning: $e');
      }
    }

    return true;
  }

  // ==========================================
  // 4. XÓA NGƯỜI DÙNG (DELETE)
  // ==========================================
  Future<bool> deleteUser(String email) async {
    // 1. Xóa trong Local Storage
    final currentList = await _getLocalUsers();
    currentList.removeWhere(
        (u) => u.email.toLowerCase() == email.toLowerCase());
    await _saveLocalUsers(currentList);

    // 2. Đồng bộ xóa trên Firebase
    if (_firebaseBaseUrl.isNotEmpty) {
      try {
        final key = _sanitizeKey(email);
        final url = Uri.parse('$_firebaseBaseUrl/users/$key.json');
        await http.delete(url).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Firebase delete warning: $e');
      }
    }

    // 3. Đồng bộ xóa trên MongoDB
    if (_currentSource == DatabaseSource.mongodb) {
      try {
        final url = Uri.parse('$_mongoBaseUrl/${Uri.encodeComponent(email)}');
        await http.delete(url).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('MongoDB delete warning: $e');
      }
    }

    return true;
  }

  // ==========================================
  // 5. ĐĂNG NHẬP ADMIN (AUTHENTICATION)
  // ==========================================
  Future<UserModel?> login(String email, String password) async {
    // Luôn cho phép tài khoản Admin mặc định hoặc bất kỳ người dùng nào trong CSDL
    final cleanEmail = email.trim().toLowerCase();
    final cleanPass = password.trim();

    final users = await getUsers();
    for (var u in users) {
      if (u.email.toLowerCase() == cleanEmail && u.matkhau == cleanPass) {
        return u;
      }
    }

    // Kiểm tra tài khoản Quản trị viên dự phòng
    if (cleanEmail == 'admin@gmail.com' && cleanPass == 'Admin@123') {
      return UserModel(
        email: 'admin@gmail.com',
        matkhau: 'Admin@123',
        hoten: 'Trần Thị Ngọc Hà (Admin)',
        hinhanh:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=80',
      );
    }

    return null;
  }

  // ==========================================
  // 6. KHÔI PHỤC DỮ LIỆU GỐC & XUẤT DATABASE
  // ==========================================
  Future<void> resetToDefault() async {
    final list = InitialUsersData.defaultUsers;
    await _saveLocalUsers(list);

    if (_firebaseBaseUrl.isNotEmpty) {
      try {
        // Đồng bộ toàn bộ lên Firebase
        Map<String, dynamic> rootMap = {};
        for (var u in list) {
          rootMap[_sanitizeKey(u.email)] = u.toMap();
        }
        final url = Uri.parse('$_firebaseBaseUrl/users.json');
        await http
            .put(url, body: json.encode(rootMap))
            .timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('Firebase reset warning: $e');
      }
    }
  }

  /// Xuất chuỗi JSON của cơ sở dữ liệu để nộp file (Chuẩn 4 trường)
  Future<String> exportDatabaseJsonString() async {
    final users = await getUsers();
    final listMap = users.map((u) => u.toMap()).toList();
    return const JsonEncoder.withIndent('  ').convert(listMap);
  }

  // Helpers Local Storage
  Future<List<UserModel>> _getLocalUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return InitialUsersData.defaultUsers;
    }
    try {
      final decoded = json.decode(raw) as List;
      return decoded
          .map((item) => UserModel.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return InitialUsersData.defaultUsers;
    }
  }

  Future<void> _saveLocalUsers(List<UserModel> users) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = json.encode(users.map((u) => u.toMap()).toList());
    await prefs.setString(_storageKey, raw);
  }
}
