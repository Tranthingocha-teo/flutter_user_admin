import 'package:flutter/material.dart';
import 'models/user_model.dart';
import 'screens/user_list_screen.dart';
import 'screens/user_form_dialog.dart';
import 'screens/user_detail_dialog.dart';
import 'services/api_service.dart';
import 'services/mock_data.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService().init();
  
  final uri = Uri.base;
  final view = uri.queryParameters['view'] ?? 'dashboard';
  
  final admin = UserModel(
    email: 'admin@gmail.com',
    matkhau: 'Admin@123',
    hoten: 'Trần Thị Ngọc Hà (Admin)',
    hinhanh: InitialUsersData.presetAvatars[0],
  );

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme(),
    home: Builder(
      builder: (context) {
        if (view == 'form') {
          return Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            body: Center(
              child: UserFormDialog(
                userToEdit: InitialUsersData.defaultUsers[1],
              ),
            ),
          );
        } else if (view == 'detail') {
          return Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            body: Center(
              child: UserDetailDialog(
                user: InitialUsersData.defaultUsers[0],
                onEdit: () {},
              ),
            ),
          );
        }
        return UserListScreen(
          currentUser: admin,
          onToggleTheme: () {},
          isDarkMode: false,
        );
      },
    ),
  ));
}
