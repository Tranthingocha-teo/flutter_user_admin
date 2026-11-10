import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_user_admin/main.dart';
import 'package:flutter_user_admin/models/user_model.dart';
import 'package:flutter_user_admin/utils/helpers.dart';

void main() {
  test('UserModel strictly holds only 4 required fields', () {
    final user = UserModel(
      email: 'test@gmail.com',
      matkhau: '123456',
      hoten: 'Trần Thị Ngọc Hà',
      hinhanh: 'https://example.com/avatar.jpg',
    );

    final map = user.toMap();
    expect(map.keys.length, 4);
    expect(map.containsKey('email'), true);
    expect(map.containsKey('matkhau'), true);
    expect(map.containsKey('hoten'), true);
    expect(map.containsKey('hinhanh'), true);

    final fromMap = UserModel.fromMap(map);
    expect(fromMap.email, 'test@gmail.com');
    expect(fromMap.matkhau, '123456');
    expect(fromMap.hoten, 'Trần Thị Ngọc Hà');
    expect(fromMap.hinhanh, 'https://example.com/avatar.jpg');
  });

  test('Email validator correctly validates RFC regex formats', () {
    expect(AppHelpers.isValidEmail('admin@gmail.com'), true);
    expect(AppHelpers.isValidEmail('hattn.23itb@vku.udn.vn'), true);
    expect(AppHelpers.isValidEmail('invalid-email'), false);
    expect(AppHelpers.isValidEmail('test@'), false);
    expect(AppHelpers.isValidEmail(''), false);
  });

  testWidgets('App renders login screen with admin fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(const UserAdminApp());
    await tester.pumpAndSettle();

    expect(find.text('Phân Hệ Quản Trị Viên'), findsOneWidget);
    expect(find.text('Đăng Nhập Quản Trị'), findsOneWidget);
  });
}
