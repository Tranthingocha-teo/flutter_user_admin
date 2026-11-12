import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../services/report_service.dart';
import '../utils/app_theme.dart';

/// Hộp chọn định dạng và xuất báo cáo hàng hóa – tồn kho
Future<void> showReportExport(
  BuildContext context,
  List<ProductModel> products,
) async {
  final messenger = ScaffoldMessenger.of(context);

  final excel = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 520),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Xuất báo cáo hàng hóa – tồn kho',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${products.length} sản phẩm • gồm giá, số lượng, thành tiền, tỷ trọng, tình trạng và dòng tổng cộng',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              leading: const Icon(
                Icons.table_chart_rounded,
                color: Color(0xFF15803D),
              ),
              title: const Text(
                'Excel (.xlsx)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Có định dạng tiền, %, màu tình trạng'),
              onTap: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              leading: const Icon(Icons.description_outlined),
              title: const Text(
                'CSV (.csv)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Mở được bằng Excel / Google Sheets'),
              onTap: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    ),
  );
  if (excel == null) return;

  if (products.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Chưa có sản phẩm để xuất báo cáo'),
        backgroundColor: AppTheme.dangerColor,
      ),
    );
    return;
  }

  try {
    final path = await ReportService.save(products, excel: excel);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          kIsWeb || path.isEmpty
              ? 'Đã tải báo cáo ${excel ? 'Excel' : 'CSV'}'
              : 'Đã lưu báo cáo tại: $path',
        ),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Không xuất được báo cáo: $e'),
        backgroundColor: AppTheme.dangerColor,
      ),
    );
  }
}
