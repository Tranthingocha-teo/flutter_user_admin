import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/helpers.dart';
import 'product_list_screen.dart';

enum _Mode { login, register, forgot }

/// Đăng nhập / Đăng ký (có xác thực email) / Quên mật khẩu — Firebase Auth
class LoginScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  /// Mở thẳng màn hình Đăng ký (dùng khi chụp ảnh minh họa)
  final bool startInRegister;

  const LoginScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
    this.startInRegister = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  late _Mode _mode = widget.startInRegister ? _Mode.register : _Mode.login;
  bool _obscurePassword = true;
  bool _isLoading = false;

  /// Thông báo lỗi (đỏ) hoặc thông báo thành công (xanh)
  String? _errorMessage;
  String? _infoMessage;

  /// Hiện nút "Gửi lại email xác thực" khi đăng nhập bằng email chưa xác thực
  bool _canResend = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _switchMode(_Mode m) {
    setState(() {
      _mode = m;
      _errorMessage = null;
      _infoMessage = null;
      _canResend = false;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _infoMessage = null;
      _canResend = false;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = AuthService.message(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() => _run(() async {
    final ok = await AuthService.login(
      _emailController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ProductListScreen(
            onToggleTheme: widget.onToggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
        ),
      );
    } else {
      setState(() {
        _errorMessage =
            'Email chưa được xác thực. Hãy mở hộp thư ${_emailController.text.trim()} và bấm vào link xác thực (xem cả mục Spam).';
        _canResend = true;
      });
    }
  });

  Future<void> _handleRegister() => _run(() async {
    final email = _emailController.text.trim();
    await AuthService.register(email, _passwordController.text);
    if (!mounted) return;
    _passwordController.clear();
    _confirmController.clear();
    setState(() {
      _mode = _Mode.login;
      _infoMessage =
          'Đăng ký thành công! Đã gửi email xác thực tới $email. Hãy mở hộp thư, bấm vào link xác thực rồi quay lại đăng nhập.';
    });
  });

  Future<void> _handleForgot() => _run(() async {
    final email = _emailController.text.trim();
    await AuthService.sendPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _mode = _Mode.login;
      _infoMessage =
          'Đã gửi email đặt lại mật khẩu tới $email. Hãy kiểm tra hộp thư.';
    });
  });

  Future<void> _resend() async {
    setState(() => _isLoading = true);
    try {
      await AuthService.resendVerification();
      await AuthService.logout();
      if (!mounted) return;
      setState(() {
        _canResend = false;
        _errorMessage = null;
        _infoMessage =
            'Đã gửi lại email xác thực tới ${_emailController.text.trim()}.';
      });
    } catch (e) {
      if (mounted) setState(() => _errorMessage = AuthService.message(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _submit() {
    switch (_mode) {
      case _Mode.login:
        _handleLogin();
      case _Mode.register:
        _handleRegister();
      case _Mode.forgot:
        _handleForgot();
    }
  }

  Widget _banner(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final compact = MediaQuery.of(context).size.width < 420;

    final title = switch (_mode) {
      _Mode.login => 'Đăng Nhập Quản Trị',
      _Mode.register => 'Đăng Ký Tài Khoản',
      _Mode.forgot => 'Quên Mật Khẩu',
    };
    final buttonText = switch (_mode) {
      _Mode.login => 'Đăng Nhập',
      _Mode.register => 'Đăng Ký & Gửi Email Xác Thực',
      _Mode.forgot => 'Gửi Email Đặt Lại Mật Khẩu',
    };

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [
                        Color(0xFF0F172A),
                        Color(0xFF1E1B4B),
                        Color(0xFF0F172A),
                      ]
                    : const [
                        Color(0xFFEEF2FF),
                        Color(0xFFF8FAFC),
                        Color(0xFFE0E7FF),
                      ],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 24,
                vertical: compact ? 20 : 32,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Card(
                  elevation: isDark ? 4 : 8,
                  shadowColor: Colors.black.withValues(alpha: 0.08),
                  child: Padding(
                    padding: EdgeInsets.all(compact ? 20 : 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppTheme.primaryColor,
                                    AppTheme.accentColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                size: 38,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Phân Hệ Quản Trị Viên',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? AppTheme.darkTextPrimary
                                      : AppTheme.lightTextPrimary,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),

                          if (_infoMessage != null)
                            _banner(
                              _infoMessage!,
                              AppTheme.successColor,
                              Icons.mark_email_read_outlined,
                            ),
                          if (_errorMessage != null)
                            _banner(
                              _errorMessage!,
                              AppTheme.dangerColor,
                              Icons.error_outline,
                            ),
                          if (_canResend)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.forward_to_inbox,
                                  size: 18,
                                ),
                                label: const Text('Gửi lại email xác thực'),
                                onPressed: _isLoading ? null : _resend,
                              ),
                            ),

                          _label('Email', isDark),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'ban@gmail.com',
                              prefixIcon: Icon(Icons.email_outlined, size: 20),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Vui lòng nhập email';
                              }
                              if (!AppHelpers.isValidEmail(val)) {
                                return 'Định dạng email không hợp lệ';
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 18),

                          if (_mode != _Mode.forgot) ...[
                            _label('Mật khẩu', isDark),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                hintText: _mode == _Mode.register
                                    ? 'Tối thiểu 6 ký tự'
                                    : 'Nhập mật khẩu',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Vui lòng nhập mật khẩu';
                                }
                                if (_mode == _Mode.register && val.length < 6) {
                                  return 'Mật khẩu phải có ít nhất 6 ký tự';
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 18),
                          ],

                          if (_mode == _Mode.register) ...[
                            _label('Nhập lại mật khẩu', isDark),
                            TextFormField(
                              controller: _confirmController,
                              obscureText: _obscurePassword,
                              decoration: const InputDecoration(
                                hintText: 'Nhập lại mật khẩu',
                                prefixIcon: Icon(Icons.lock_reset, size: 20),
                              ),
                              validator: (val) =>
                                  val != _passwordController.text
                                  ? 'Mật khẩu nhập lại không khớp'
                                  : null,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            const SizedBox(height: 18),
                          ],

                          if (_mode == _Mode.login)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () => _switchMode(_Mode.forgot),
                                child: const Text('Quên mật khẩu?'),
                              ),
                            ),
                          const SizedBox(height: 6),

                          SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _submit,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor: AlwaysStoppedAnimation(
                                          Colors.white,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      buttonText,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (_mode == _Mode.login)
                            TextButton(
                              onPressed: () => _switchMode(_Mode.register),
                              child: const Text(
                                'Chưa có tài khoản? Đăng ký ngay',
                              ),
                            )
                          else
                            TextButton(
                              onPressed: () => _switchMode(_Mode.login),
                              child: const Text('← Quay lại đăng nhập'),
                            ),
                          const SizedBox(height: 12),

                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.black.withValues(alpha: 0.03),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Đề thi giữa kỳ môn Lập trình đa nền tảng (VKU)\n'
                              'Họ tên SV: Trần Thị Ngọc Hà – MSSV: 23IT.B046',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: IconButton(
              icon: Icon(
                widget.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                color: isDark ? Colors.white70 : AppTheme.primaryColor,
              ),
              onPressed: widget.onToggleTheme,
              tooltip: 'Chuyển đổi giao diện Sáng / Tối',
            ),
          ),
        ],
      ),
    );
  }
}
