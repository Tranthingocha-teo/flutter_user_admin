import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_user_admin/models/product_model.dart';
import 'package:flutter_user_admin/utils/helpers.dart';

void main() {
  test('ProductModel chỉ lưu đúng 4 trường name, price, soluong, image', () {
    final p = ProductModel(
      key: 'docId123',
      name: 'Tai nghe',
      price: 250000,
      soluong: 10,
      image: 'https://example.com/a.jpg',
    );

    final map = p.toMap();
    expect(map.keys.toSet(), {'name', 'price', 'soluong', 'image'});
    expect(map.containsKey('key'), false);

    final back = ProductModel.fromMap(map, key: 'k1');
    expect(back.name, 'Tai nghe');
    expect(back.price, 250000);
    expect(back.soluong, 10);
    expect(back.image, 'https://example.com/a.jpg');
    expect(back.key, 'k1');
  });

  test('fromMap chấp nhận price/soluong dạng chuỗi', () {
    final p = ProductModel.fromMap(
        {'name': 'A', 'price': '1200', 'soluong': '3', 'image': 'x'});
    expect(p.price, 1200);
    expect(p.soluong, 3);
  });

  test('Định dạng giá VNĐ', () {
    expect(AppHelpers.formatPrice(7490000), '7.490.000 ₫');
    expect(AppHelpers.formatNumber(999), '999');
    expect(AppHelpers.formatNumber(0), '0');
  });

  test('Kiểm tra định dạng email', () {
    expect(AppHelpers.isValidEmail('hattn.23itb@vku.udn.vn'), true);
    expect(AppHelpers.isValidEmail('sai-email'), false);
  });
}
