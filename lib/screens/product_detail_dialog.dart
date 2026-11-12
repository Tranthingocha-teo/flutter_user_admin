import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product_model.dart';
import '../utils/app_theme.dart';
import '../utils/helpers.dart';

/// Xem chi tiết sản phẩm: ảnh lớn, tên, giá, số lượng, tình trạng, thành tiền.
/// "Tình trạng" và "Thành tiền" được TÍNH từ soluong/price, không lưu vào CSDL.
class ProductDetailDialog extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onEdit;

  const ProductDetailDialog({
    super.key,
    required this.product,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtle = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final panel = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final status = StockStatus.of(product.soluong);
    final total = product.price * product.soluong;

    // Ô thông số nhỏ: nhãn + giá trị + tên trường
    Widget stat({
      required IconData icon,
      required String label,
      required String value,
      String? field,
      Color? color,
    }) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: color ?? subtle),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 12, color: subtle),
                  ),
                ),
                if (field != null)
                  Text(
                    field,
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: subtle.withValues(alpha: 0.8),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---------- Ảnh lớn + nút đóng + nhãn tình trạng ----------
              Stack(
                children: [
                  Container(
                    height: 260,
                    color: panel,
                    child: LayoutBuilder(
                      builder: (_, c) => AppHelpers.buildProductImage(
                        imageUrl: product.image,
                        size: c.maxWidth,
                        radius: 0,
                      ),
                    ),
                  ),
                  // lớp mờ dưới đáy ảnh cho dễ đọc
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.25),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkCardBg : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: status.badge(fontSize: 12),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.45),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'CHI TIẾT SẢN PHẨM',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: subtle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      product.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppHelpers.formatPrice(product.price),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ---------- Lưới thông số ----------
                    LayoutBuilder(
                      builder: (_, c) {
                        final w = (c.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: w,
                              child: stat(
                                icon: Icons.inventory_2_outlined,
                                label: 'Số lượng',
                                field: 'soluong',
                                value: AppHelpers.formatNumber(product.soluong),
                              ),
                            ),
                            SizedBox(
                              width: w,
                              child: stat(
                                icon: status.icon,
                                label: 'Tình trạng',
                                value: status.label,
                                color: status.color,
                              ),
                            ),
                            SizedBox(
                              width: c.maxWidth,
                              child: stat(
                                icon: Icons.payments_outlined,
                                label: 'Giá trị tồn kho (giá × số lượng)',
                                value: AppHelpers.formatPrice(total),
                                color: AppTheme.successColor,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    if (status != StockStatus.inStock) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: status.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(status.icon, color: status.color, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                product.soluong <= 0
                                    ? 'Sản phẩm đã hết hàng, cần nhập thêm.'
                                    : 'Chỉ còn ${product.soluong} sản phẩm '
                                          '(dưới ${StockStatus.lowStock}), nên nhập thêm.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: status.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    // ---------- Link ảnh ----------
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                      decoration: BoxDecoration(
                        color: panel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.link_rounded, size: 18, color: subtle),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              product.image,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: subtle,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            tooltip: 'Sao chép link ảnh',
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: product.image),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã sao chép link ảnh!'),
                                  backgroundColor: AppTheme.successColor,
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Đóng'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Chỉnh sửa'),
                            onPressed: () {
                              Navigator.of(context).pop();
                              onEdit();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
