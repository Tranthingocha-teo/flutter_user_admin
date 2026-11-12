import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/product_list_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Trên Web, phiên đăng nhập được khôi phục bất đồng bộ -> chờ lần phát đầu tiên
  final user = await FirebaseAuth.instance.authStateChanges().first;
  runApp(ProductAdminApp(loggedIn: user != null && user.emailVerified));
}

class ProductAdminApp extends StatefulWidget {
  final bool loggedIn;
  const ProductAdminApp({super.key, this.loggedIn = false});

  @override
  State<ProductAdminApp> createState() => _ProductAdminAppState();
}

class _ProductAdminAppState extends State<ProductAdminApp> {
  bool _isDarkMode = false;

  void _toggleTheme() => setState(() => _isDarkMode = !_isDarkMode);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phân Hệ Admin Quản Lý Sản Phẩm - LTDĐ VKU',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: widget.loggedIn
          ? ProductListScreen(
              onToggleTheme: _toggleTheme,
              isDarkMode: _isDarkMode,
            )
          : LoginScreen(onToggleTheme: _toggleTheme, isDarkMode: _isDarkMode),
    );
  }
}
