import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';

import '../models/product_model.dart';

/// Báo cáo hàng hóa – tồn kho, xuất ra Excel (.xlsx) hoặc CSV.
///
/// Đề chỉ có 4 trường name, price, soluong, image nên báo cáo được tính
/// hoàn toàn từ các trường này: thành tiền = price × soluong, tỷ trọng,
/// tình trạng tồn kho và dòng tổng cộng. Không ghi thêm gì vào CSDL.
class ReportService {
  static const int lowStock = 5;

  static String _status(int q) =>
      q == 0 ? 'Hết hàng' : (q < lowStock ? 'Sắp hết' : 'Đủ hàng');

  static String _stamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.day)}/${two(t.month)}/${t.year} ${two(t.hour)}:${two(t.minute)}';
  }

  static String _fileStamp(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}_${two(t.hour)}${two(t.minute)}';
  }

  /// Sắp theo thành tiền giảm dần
  static List<ProductModel> _sorted(List<ProductModel> list) =>
      List<ProductModel>.from(list)
        ..sort((a, b) => (b.price * b.soluong).compareTo(a.price * a.soluong));

  // ==========================================================
  // EXCEL (.xlsx)
  // ==========================================================
  static Uint8List buildXlsx(List<ProductModel> products, {DateTime? at}) {
    final now = at ?? DateTime.now();
    final rows = _sorted(products);
    final totalQty = rows.fold<int>(0, (s, p) => s + p.soluong);
    final totalValue = rows.fold<int>(0, (s, p) => s + p.price * p.soluong);
    final low = rows.where((p) => p.soluong < lowStock).length;

    final excel = xl.Excel.createExcel();
    const sheetName = 'Bao cao ton kho';
    excel.rename(excel.getDefaultSheet()!, sheetName);
    final sh = excel[sheetName];

    final money = xl.NumFormat.custom(formatCode: '#,##0" ₫"');
    final integer = xl.NumFormat.custom(formatCode: '#,##0');
    final percent = xl.NumFormat.custom(formatCode: '0.0%');
    final thin = xl.Border(
      borderStyle: xl.BorderStyle.Thin,
      borderColorHex: xl.ExcelColor.fromHexString('#D4D4D8'),
    );

    xl.CellStyle style({
      bool bold = false,
      int size = 11,
      String? bg,
      String fg = '#09090B',
      xl.HorizontalAlign align = xl.HorizontalAlign.Left,
      xl.NumFormat? fmt,
      bool border = true,
    }) => xl.CellStyle(
      bold: bold,
      fontSize: size,
      fontFamily: 'Arial',
      fontColorHex: xl.ExcelColor.fromHexString(fg),
      backgroundColorHex: bg == null
          ? xl.ExcelColor.none
          : xl.ExcelColor.fromHexString(bg),
      horizontalAlign: align,
      verticalAlign: xl.VerticalAlign.Center,
      numberFormat: fmt ?? xl.NumFormat.standard_0,
      leftBorder: border ? thin : null,
      rightBorder: border ? thin : null,
      topBorder: border ? thin : null,
      bottomBorder: border ? thin : null,
    );

    void put(int col, int row, xl.CellValue v, xl.CellStyle s) => sh.updateCell(
      xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
      v,
      cellStyle: s,
    );

    const cols = 8;
    // Tiêu đề
    sh.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      xl.CellIndex.indexByColumnRow(columnIndex: cols - 1, rowIndex: 0),
    );
    put(
      0,
      0,
      xl.TextCellValue('BÁO CÁO HÀNG HÓA – TỒN KHO'),
      style(bold: true, size: 15, border: false),
    );
    sh.merge(
      xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      xl.CellIndex.indexByColumnRow(columnIndex: cols - 1, rowIndex: 1),
    );
    put(
      0,
      1,
      xl.TextCellValue(
        'Ngày xuất: ${_stamp(now)}  •  Phân hệ Admin quản lý sản phẩm',
      ),
      style(fg: '#71717A', border: false),
    );

    // Tóm tắt
    final summary = <(String, xl.CellValue, xl.NumFormat?)>[
      ('Số sản phẩm', xl.IntCellValue(rows.length), integer),
      ('Tổng số lượng tồn', xl.IntCellValue(totalQty), integer),
      ('Tổng giá trị tồn kho', xl.IntCellValue(totalValue), money),
      (
        'Giá bình quân / đơn vị',
        xl.IntCellValue(totalQty == 0 ? 0 : (totalValue / totalQty).round()),
        money,
      ),
      ('Số SP sắp hết / hết hàng (< $lowStock)', xl.IntCellValue(low), integer),
    ];
    for (var i = 0; i < summary.length; i++) {
      final r = 3 + i;
      sh.merge(
        xl.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r),
        xl.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r),
      );
      put(0, r, xl.TextCellValue(summary[i].$1), style(bg: '#F4F4F5'));
      put(
        3,
        r,
        summary[i].$2,
        style(bold: true, align: xl.HorizontalAlign.Right, fmt: summary[i].$3),
      );
    }

    // Bảng chi tiết
    final head = 3 + summary.length + 1;
    const headers = [
      'STT',
      'Tên sản phẩm (name)',
      'Giá (price)',
      'Số lượng (soluong)',
      'Thành tiền',
      '% giá trị',
      '% số lượng',
      'Tình trạng',
    ];
    for (var c = 0; c < headers.length; c++) {
      put(
        c,
        head,
        xl.TextCellValue(headers[c]),
        style(
          bold: true,
          bg: '#09090B',
          fg: '#FFFFFF',
          align: c >= 2 && c <= 6
              ? xl.HorizontalAlign.Right
              : xl.HorizontalAlign.Left,
        ),
      );
    }
    for (var i = 0; i < rows.length; i++) {
      final p = rows[i];
      final r = head + 1 + i;
      final v = p.price * p.soluong;
      final zebra = i.isOdd ? '#FAFAFA' : null;
      final st = _status(p.soluong);
      put(
        0,
        r,
        xl.IntCellValue(i + 1),
        style(bg: zebra, align: xl.HorizontalAlign.Center),
      );
      put(1, r, xl.TextCellValue(p.name), style(bg: zebra));
      put(
        2,
        r,
        xl.IntCellValue(p.price),
        style(bg: zebra, align: xl.HorizontalAlign.Right, fmt: money),
      );
      put(
        3,
        r,
        xl.IntCellValue(p.soluong),
        style(bg: zebra, align: xl.HorizontalAlign.Right, fmt: integer),
      );
      put(
        4,
        r,
        xl.IntCellValue(v),
        style(bg: zebra, align: xl.HorizontalAlign.Right, fmt: money),
      );
      put(
        5,
        r,
        xl.DoubleCellValue(totalValue == 0 ? 0 : v / totalValue),
        style(bg: zebra, align: xl.HorizontalAlign.Right, fmt: percent),
      );
      put(
        6,
        r,
        xl.DoubleCellValue(totalQty == 0 ? 0 : p.soluong / totalQty),
        style(bg: zebra, align: xl.HorizontalAlign.Right, fmt: percent),
      );
      put(
        7,
        r,
        xl.TextCellValue(st),
        style(
          bg: zebra,
          bold: st != 'Đủ hàng',
          fg: st == 'Hết hàng'
              ? '#B91C1C'
              : (st == 'Sắp hết' ? '#B45309' : '#15803D'),
        ),
      );
    }

    // Dòng tổng cộng
    final tr = head + 1 + rows.length;
    put(0, tr, xl.TextCellValue(''), style(bg: '#F4F4F5'));
    put(1, tr, xl.TextCellValue('TỔNG CỘNG'), style(bold: true, bg: '#F4F4F5'));
    put(2, tr, xl.TextCellValue(''), style(bg: '#F4F4F5'));
    put(
      3,
      tr,
      xl.IntCellValue(totalQty),
      style(
        bold: true,
        bg: '#F4F4F5',
        align: xl.HorizontalAlign.Right,
        fmt: integer,
      ),
    );
    put(
      4,
      tr,
      xl.IntCellValue(totalValue),
      style(
        bold: true,
        bg: '#F4F4F5',
        align: xl.HorizontalAlign.Right,
        fmt: money,
      ),
    );
    put(
      5,
      tr,
      xl.DoubleCellValue(rows.isEmpty ? 0 : 1),
      style(
        bold: true,
        bg: '#F4F4F5',
        align: xl.HorizontalAlign.Right,
        fmt: percent,
      ),
    );
    put(
      6,
      tr,
      xl.DoubleCellValue(rows.isEmpty ? 0 : 1),
      style(
        bold: true,
        bg: '#F4F4F5',
        align: xl.HorizontalAlign.Right,
        fmt: percent,
      ),
    );
    put(7, tr, xl.TextCellValue(''), style(bg: '#F4F4F5'));

    const widths = [6.0, 36.0, 16.0, 20.0, 18.0, 11.0, 12.0, 13.0];
    for (var c = 0; c < widths.length; c++) {
      sh.setColumnWidth(c, widths[c]);
    }

    return Uint8List.fromList(excel.encode()!);
  }

  // ==========================================================
  // CSV (UTF-8 có BOM để Excel đọc đúng tiếng Việt)
  // ==========================================================
  static Uint8List buildCsv(List<ProductModel> products, {DateTime? at}) {
    final rows = _sorted(products);
    final totalQty = rows.fold<int>(0, (s, p) => s + p.soluong);
    final totalValue = rows.fold<int>(0, (s, p) => s + p.price * p.soluong);

    String q(Object v) {
      final s = v.toString();
      return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    String pct(num part, num whole) =>
        whole == 0 ? '0' : (part * 100 / whole).toStringAsFixed(1);

    final b = StringBuffer()
      ..writeln(
        'STT,Tên sản phẩm (name),Giá (price),Số lượng (soluong),Thành tiền,% giá trị,% số lượng,Tình trạng',
      );
    for (var i = 0; i < rows.length; i++) {
      final p = rows[i];
      final v = p.price * p.soluong;
      b.writeln(
        [
          i + 1,
          q(p.name),
          p.price,
          p.soluong,
          v,
          pct(v, totalValue),
          pct(p.soluong, totalQty),
          _status(p.soluong),
        ].join(','),
      );
    }
    b.writeln(',TỔNG CỘNG,,$totalQty,$totalValue,100,100,');

    return Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(b.toString())]);
  }

  // ==========================================================
  // LƯU FILE (Web: tải xuống • Android: thư mục Download)
  // ==========================================================
  static Future<String> save(
    List<ProductModel> products, {
    required bool excel,
  }) {
    final now = DateTime.now();
    return FileSaver.instance.saveFile(
      name: 'bao_cao_ton_kho_${_fileStamp(now)}',
      bytes: excel ? buildXlsx(products, at: now) : buildCsv(products, at: now),
      fileExtension: excel ? 'xlsx' : 'csv',
      mimeType: excel ? MimeType.microsoftExcel : MimeType.csv,
    );
  }
}
