import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_user_admin/models/product_model.dart';
import 'package:flutter_user_admin/services/report_service.dart';

void main() {
  final products = [
    ProductModel(name: 'Kính mát', price: 650000, soluong: 32, image: 'x'),
    ProductModel(name: 'Laptop, 14"', price: 15990000, soluong: 6, image: 'x'),
    ProductModel(name: 'Máy ảnh', price: 2890000, soluong: 0, image: 'x'),
  ];

  test('Excel: có tiêu đề, bảng chi tiết sắp theo thành tiền và dòng tổng', () {
    final bytes = ReportService.buildXlsx(products, at: DateTime(2026, 11, 11, 9, 5));
    final out = Platform.environment['REPORT_OUT'];
    if (out != null) File('$out/bao_cao_test.xlsx').writeAsBytesSync(bytes);

    final book = xl.Excel.decodeBytes(bytes);
    final sh = book.tables.values.first;
    String text(int c, int r) => sh
            .cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r))
            .value
            ?.toString() ??
        '';

    expect(text(0, 0), 'BÁO CÁO HÀNG HÓA – TỒN KHO');
    // Hàng tiêu đề bảng nằm sau 5 dòng tóm tắt
    const head = 9;
    expect(text(1, head), 'Tên sản phẩm (name)');
    expect(text(1, head + 1), 'Laptop, 14"'); // thành tiền lớn nhất
    expect(text(4, head + 1), '95940000');
    expect(text(7, head + 3), 'Hết hàng');
    expect(text(1, head + 4), 'TỔNG CỘNG');
    expect(text(3, head + 4), '38');
    expect(text(4, head + 4), '${650000 * 32 + 15990000 * 6}');
  });

  test('CSV: có BOM UTF-8, escape dấu phẩy/ngoặc kép, có dòng tổng', () {
    final bytes = ReportService.buildCsv(products);
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
    final lines = utf8.decode(bytes.sublist(3)).trim().split('\n');
    expect(lines.length, 1 + products.length + 1);
    expect(lines[1], startsWith('1,"Laptop, 14""",15990000,6,95940000,'));
    expect(lines.last, startsWith(',TỔNG CỘNG,,38,'));
  });
}
