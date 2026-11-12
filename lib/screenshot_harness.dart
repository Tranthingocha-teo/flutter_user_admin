import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'screens/product_detail_dialog.dart';
import 'screens/product_form_dialog.dart';
import 'screens/product_list_screen.dart';
import 'services/mock_data.dart';
import 'utils/app_theme.dart';

/// Màn hình dựng sẵn để chụp ảnh minh họa cho báo cáo (không dùng khi chạy thật).
///   Web:     flutter run -d chrome -t lib/screenshot_harness.dart   rồi mở ?view=list
///   Android: flutter run -t lib/screenshot_harness.dart --dart-define=VIEW=list
/// view: login | register | list | add | form | detail | dashboard   (&dark=1)
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  const defined = String.fromEnvironment('VIEW');
  final view = defined.isNotEmpty
      ? defined
      : (Uri.base.queryParameters['view'] ?? 'list');
  final dark =
      Uri.base.queryParameters['dark'] == '1' ||
      const String.fromEnvironment('DARK') == '1';
  final samples = [
    for (final (i, p) in InitialProductsData.defaultProducts.indexed)
      p.copyWith(key: 'p$i'),
  ];

  Widget dialogPage(Widget child) => Builder(
    builder: (context) => Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      body: Center(child: child),
    ),
  );

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: switch (view) {
        'login' => LoginScreen(onToggleTheme: () {}, isDarkMode: dark),
        'register' => LoginScreen(
          onToggleTheme: () {},
          isDarkMode: dark,
          startInRegister: true,
        ),
        'add' => dialogPage(const ProductFormDialog()),
        'form' => dialogPage(ProductFormDialog(productToEdit: samples[0])),
        'detail' => dialogPage(
          ProductDetailDialog(product: samples[3], onEdit: () {}),
        ),
        'dashboard' || 'dashboard2' => DashboardScreen(previewData: samples),
        _ => ProductListScreen(
          onToggleTheme: () {},
          isDarkMode: dark,
          previewData: samples,
        ),
      },
    ),
  );
}
