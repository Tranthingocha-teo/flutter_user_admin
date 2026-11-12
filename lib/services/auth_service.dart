import 'package:firebase_auth/firebase_auth.dart';

/// Đăng ký / đăng nhập bằng Firebase Authentication (Email & Mật khẩu).
///
/// - Đăng ký: tạo tài khoản, Firebase gửi email xác thực về hộp thư.
/// - Đăng nhập: chỉ cho vào khi email đã được xác thực.
/// - Quên mật khẩu: Firebase gửi email đặt lại mật khẩu.
///
/// Tài khoản được lưu trong Firebase Auth, không nằm trong Firestore,
/// nên CSDL vẫn chỉ có collection `products` với 4 trường.
class AuthService {
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static Future<void> _setLanguage() async {
    // Email do Firebase gửi sẽ viết bằng tiếng Việt
    await _auth.setLanguageCode('vi');
  }

  /// Tạo tài khoản + gửi email xác thực. Sau đó đăng xuất ngay,
  /// người dùng phải bấm link trong email rồi mới đăng nhập được.
  static Future<void> register(String email, String password) async {
    await _setLanguage();
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user!.sendEmailVerification();
    await _auth.signOut();
  }

  /// Trả về `true` nếu đăng nhập thành công và email đã xác thực.
  /// Trả về `false` nếu email chưa xác thực (người dùng vẫn đang đăng nhập
  /// để có thể gửi lại email bằng [resendVerification]).
  static Future<bool> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user!;
    await user.reload();
    if (_auth.currentUser?.emailVerified ?? false) {
      // Làm mới token để Firestore Rules nhận email_verified = true
      await _auth.currentUser!.getIdToken(true);
      return true;
    }
    return false;
  }

  static Future<void> resendVerification() async {
    await _setLanguage();
    await _auth.currentUser?.sendEmailVerification();
  }

  static Future<void> sendPasswordReset(String email) async {
    await _setLanguage();
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  static Future<void> logout() => _auth.signOut();

  /// Đổi mã lỗi Firebase sang câu thông báo tiếng Việt
  static String message(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-email':
          return 'Email không hợp lệ.';
        case 'email-already-in-use':
          return 'Email này đã được đăng ký.';
        case 'weak-password':
          return 'Mật khẩu quá yếu (tối thiểu 6 ký tự).';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email hoặc mật khẩu không chính xác.';
        case 'user-disabled':
          return 'Tài khoản đã bị khóa.';
        case 'too-many-requests':
          return 'Thao tác quá nhiều lần, vui lòng thử lại sau ít phút.';
        case 'configuration-not-found':
        case 'operation-not-allowed':
          return 'Chưa bật đăng nhập Email/Password trong Firebase Console.';
        case 'network-request-failed':
          return 'Không có kết nối mạng.';
      }
      return e.message ?? e.code;
    }
    return e.toString().replaceAll('Exception: ', '');
  }
}
