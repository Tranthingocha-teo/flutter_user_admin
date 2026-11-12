import '../models/product_model.dart';

String _img(String id) =>
    'https://images.unsplash.com/photo-$id?w=500&auto=format&fit=crop&q=80';

/// Dữ liệu mẫu ban đầu — chỉ gồm 4 trường: name, price, soluong, image
class InitialProductsData {
  static List<ProductModel> get defaultProducts => [
    ProductModel(
      name: 'Tai nghe Bluetooth Sony WH-1000XM5',
      price: 7490000,
      soluong: 15,
      image: _img('1505740420928-5e560c06d30e'),
    ),
    ProductModel(
      name: 'Đồng hồ nam dây da cổ điển',
      price: 2350000,
      soluong: 8,
      image: _img('1523275335684-37898b6baf30'),
    ),
    ProductModel(
      name: 'Giày thể thao Nike Air Đỏ',
      price: 3290000,
      soluong: 20,
      image: _img('1542291026-7eec264c27ff'),
    ),
    ProductModel(
      name: 'Máy ảnh chụp lấy liền Polaroid',
      price: 2890000,
      soluong: 4,
      image: _img('1526170375885-4d8ecf77b99f'),
    ),
    ProductModel(
      name: 'Kính mát thời trang UV400',
      price: 650000,
      soluong: 32,
      image: _img('1572635196237-14b3f281503f'),
    ),
    ProductModel(
      name: 'Laptop văn phòng 14 inch',
      price: 15990000,
      soluong: 6,
      image: _img('1496181133206-80ce9b88a853'),
    ),
  ];

  /// Ảnh sản phẩm mẫu để chọn nhanh khi thêm/sửa
  static final List<String> presetImages = [
    _img('1505740420928-5e560c06d30e'),
    _img('1523275335684-37898b6baf30'),
    _img('1542291026-7eec264c27ff'),
    _img('1526170375885-4d8ecf77b99f'),
    _img('1572635196237-14b3f281503f'),
    _img('1585386959984-a4155224a1ad'),
    _img('1546868871-7041f2a55e12'),
    _img('1496181133206-80ce9b88a853'),
    _img('1511707171634-5f897ff02aa9'),
    _img('1491553895911-0055eca6402d'),
  ];
}
