import 'dart:async';
import 'dart:convert';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/product_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import '../utils/helpers.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'product_detail_dialog.dart';
import 'product_form_dialog.dart';
import 'report_export.dart';

class ProductListScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  /// Dữ liệu dựng sẵn (chỉ dùng để chụp ảnh minh họa); null = đọc Firestore
  final List<ProductModel>? previewData;

  const ProductListScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
    this.previewData,
  });

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

enum SortOption { nameAsc, nameDesc, priceAsc, priceDesc, qtyAsc, qtyDesc }

const _sortLabels = {
  SortOption.nameAsc: 'Tên: A → Z',
  SortOption.nameDesc: 'Tên: Z → A',
  SortOption.priceAsc: 'Giá: thấp → cao',
  SortOption.priceDesc: 'Giá: cao → thấp',
  SortOption.qtyAsc: 'Số lượng: ít → nhiều',
  SortOption.qtyDesc: 'Số lượng: nhiều → ít',
};

/// Ngưỡng cảnh báo sắp hết hàng
const int kLowStock = 5;

class _ProductListScreenState extends State<ProductListScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<ProductModel> _all = [];
  List<ProductModel> _filtered = [];
  bool _isLoading = true;
  bool _onlyLowStock = false;
  String? _errorMessage;
  SortOption _sort = SortOption.nameAsc;

  StreamSubscription<List<ProductModel>>? _sub;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    if (widget.previewData != null) {
      _all = widget.previewData!;
      _isLoading = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyFilters());
      return;
    }
    _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Lắng nghe Firestore theo thời gian thực: thêm/sửa/xóa ở bất kỳ thiết bị
  /// nào cũng tự cập nhật bảng
  void _listen() {
    _sub?.cancel();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _sub = _api.watchProducts().listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _all = list;
          _isLoading = false;
        });
        _applyFilters();
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Lỗi nạp dữ liệu Firestore: $e';
          _isLoading = false;
        });
      },
    );
  }

  /// Khóa sắp xếp tiếng Việt: bỏ dấu, không phân biệt hoa/thường
  static String _sortKey(String text) {
    const groups = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    var result = text.toLowerCase().trim();
    groups.forEach((base, chars) {
      for (final c in chars.split('')) {
        result = result.replaceAll(c, base);
      }
    });
    return result;
  }

  void _applyFilters() {
    final query = _sortKey(_searchController.text);
    var result = _all.where((p) {
      if (_onlyLowStock && p.soluong >= kLowStock) return false;
      return query.isEmpty || _sortKey(p.name).contains(query);
    }).toList();

    switch (_sort) {
      case SortOption.nameAsc:
        result.sort((a, b) => _sortKey(a.name).compareTo(_sortKey(b.name)));
      case SortOption.nameDesc:
        result.sort((a, b) => _sortKey(b.name).compareTo(_sortKey(a.name)));
      case SortOption.priceAsc:
        result.sort((a, b) => a.price.compareTo(b.price));
      case SortOption.priceDesc:
        result.sort((a, b) => b.price.compareTo(a.price));
      case SortOption.qtyAsc:
        result.sort((a, b) => a.soluong.compareTo(b.soluong));
      case SortOption.qtyDesc:
        result.sort((a, b) => b.soluong.compareTo(a.soluong));
    }
    setState(() => _filtered = result);
  }

  void _replaceLocal(ProductModel p, {bool remove = false}) {
    final list = List<ProductModel>.from(_all)
      ..removeWhere((x) => x.key == p.key);
    if (!remove) list.add(p);
    setState(() => _all = list);
    _applyFilters();
  }

  String _err(Object e) {
    final msg = e.toString().replaceAll('Exception: ', '');
    if (msg.contains('permission-denied')) {
      return 'Không có quyền ghi Firestore (tài khoản chưa xác thực email?)';
    }
    return msg;
  }

  // ==========================================
  // THÊM / SỬA / XÓA
  // ==========================================
  Future<void> _showAddDialog() async {
    final product = await showDialog<ProductModel>(
      context: context,
      builder: (_) => const ProductFormDialog(),
    );
    if (product == null) return;
    try {
      final created = await _api.addProduct(product);
      if (!mounted) return;
      _replaceLocal(created);
      _showToast('Đã thêm sản phẩm: ${created.name}', isSuccess: true);
    } catch (e) {
      if (mounted) _showToast(_err(e), isSuccess: false);
    }
  }

  Future<void> _showEditDialog(ProductModel product) async {
    final updated = await showDialog<ProductModel>(
      context: context,
      builder: (_) => ProductFormDialog(productToEdit: product),
    );
    if (updated == null) return;
    try {
      await _api.updateProduct(updated);
      if (!mounted) return;
      _replaceLocal(updated);
      _showToast('Đã cập nhật sản phẩm: ${updated.name}', isSuccess: true);
    } catch (e) {
      if (mounted) _showToast(_err(e), isSuccess: false);
    }
  }

  Future<void> _confirmDelete(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.dangerColor,
              size: 28,
            ),
            SizedBox(width: 10),
            Text('Xác Nhận Xóa'),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa sản phẩm "${product.name}" khỏi cơ sở dữ liệu không?\nHành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerColor,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Xóa Sản Phẩm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteProduct(product);
      if (!mounted) return;
      _replaceLocal(product, remove: true);
      _showToast('Đã xóa sản phẩm ${product.name}', isSuccess: true);
    } catch (e) {
      if (mounted) _showToast('Lỗi khi xóa: ${_err(e)}', isSuccess: false);
    }
  }

  void _showDetail(ProductModel product) {
    showDialog(
      context: context,
      builder: (_) => ProductDetailDialog(
        product: product,
        onEdit: () => _showEditDialog(product),
      ),
    );
  }

  // ==========================================
  // XUẤT DATABASE JSON
  // ==========================================
  Future<void> _exportDatabaseDialog() async {
    final jsonString = await _api.exportDatabaseJsonString();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.data_object_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 10),
            Flexible(child: Text('Cơ Sở Dữ Liệu (JSON)')),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'JSON xuất ra chỉ chứa đúng 4 trường: name, price, soluong, image.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 280,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    jsonString,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Sao Chép'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonString));
              Navigator.of(context).pop();
              _showToast('Đã sao chép JSON vào khay nhớ tạm!', isSuccess: true);
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Tải file database.json'),
            onPressed: () {
              Navigator.of(context).pop();
              _downloadJson(jsonString);
            },
          ),
        ],
      ),
    );
  }

  /// Tải file database.json về máy
  /// - Web: trình duyệt tải xuống (thư mục Downloads)
  /// - Android: lưu vào thư mục Download của máy
  Future<void> _downloadJson([String? jsonString]) async {
    try {
      final data = jsonString ?? await _api.exportDatabaseJsonString();
      final path = await FileSaver.instance.saveFile(
        name: 'database',
        bytes: Uint8List.fromList(utf8.encode(data)),
        fileExtension: 'json',
        mimeType: MimeType.json,
      );
      _showToast(
        kIsWeb || path.isEmpty
            ? 'Đã tải file database.json'
            : 'Đã lưu database.json tại: $path',
        isSuccess: true,
      );
    } catch (e) {
      _showToast('Không tải được file: ${_err(e)}', isSuccess: false);
    }
  }

  Future<void> _resetDataConfirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khôi Phục Dữ Liệu Mẫu?'),
        content: const Text(
          'Toàn bộ sản phẩm hiện có sẽ bị xóa và thay bằng 6 sản phẩm mẫu. Bạn có muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Khôi Phục'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.resetToDefault();
      _showToast('Đã khôi phục dữ liệu mẫu!', isSuccess: true);
    } catch (e) {
      _showToast(_err(e), isSuccess: false);
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onToggleTheme: widget.onToggleTheme,
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );
  }

  void _showToast(String message, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? AppTheme.successColor
            : AppTheme.dangerColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==========================================
  // APP BAR ACTIONS
  // ==========================================
  void _openDashboard() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const DashboardScreen()));
  }

  List<Widget> _desktopActions() {
    return [
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilledButton.tonalIcon(
          icon: const Icon(Icons.insights_rounded, size: 18),
          label: const Text('Dashboard'),
          onPressed: _openDashboard,
        ),
      ),
      IconButton(
        icon: const Icon(Icons.table_chart_outlined),
        tooltip: 'Xuất báo cáo (Excel / CSV)',
        onPressed: () => showReportExport(context, _all),
      ),
      IconButton(
        icon: const Icon(Icons.download_rounded),
        tooltip: 'Xuất file Database JSON',
        onPressed: _exportDatabaseDialog,
      ),
      IconButton(
        icon: const Icon(Icons.restart_alt_rounded),
        tooltip: 'Khôi phục dữ liệu mẫu',
        onPressed: _resetDataConfirm,
      ),
      IconButton(
        icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
        tooltip: 'Chuyển đổi Sáng / Tối',
        onPressed: widget.onToggleTheme,
      ),
      const VerticalDivider(width: 20, indent: 12, endIndent: 12),
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primaryColor,
              child: Icon(Icons.person, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              AuthService.currentUser?.email ?? '',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            IconButton(
              icon: const Icon(
                Icons.logout_rounded,
                color: AppTheme.dangerColor,
              ),
              tooltip: 'Đăng xuất',
              onPressed: _logout,
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _mobileActions() {
    return [
      IconButton(
        icon: const Icon(Icons.insights_rounded),
        tooltip: 'Dashboard',
        onPressed: _openDashboard,
      ),
      IconButton(
        icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
        tooltip: 'Chuyển đổi Sáng / Tối',
        onPressed: widget.onToggleTheme,
      ),
      PopupMenuButton<String>(
        tooltip: 'Thêm chức năng',
        onSelected: (val) {
          switch (val) {
            case 'report':
              showReportExport(context, _all);
            case 'export':
              _exportDatabaseDialog();
            case 'reset':
              _resetDataConfirm();
            case 'logout':
              _logout();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            enabled: false,
            child: Text(
              AuthService.currentUser?.email ?? '',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'report',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.table_chart_outlined),
              title: Text('Xuất báo cáo (Excel/CSV)'),
            ),
          ),
          const PopupMenuItem(
            value: 'export',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.download_rounded),
              title: Text('Xuất database.json'),
            ),
          ),
          const PopupMenuItem(
            value: 'reset',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.restart_alt_rounded),
              title: Text('Khôi phục dữ liệu mẫu'),
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'logout',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout_rounded, color: AppTheme.dangerColor),
              title: Text(
                'Đăng xuất',
                style: TextStyle(color: AppTheme.dangerColor),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 850;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        titleSpacing: isDesktop ? null : 12,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quản Lý Sản Phẩm',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isDesktop ? 17 : 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                    ),
                  ),
                  Text(
                    'Phân hệ Admin • LTDĐ VKU',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.white60
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: isDesktop ? _desktopActions() : _mobileActions(),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _listen(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            isDesktop ? 32 : 16,
            20,
            isDesktop ? 32 : 16,
            isDesktop ? 100 : 20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildKpiSection(isDesktop, isDark),
                  const SizedBox(height: 20),
                  _buildToolbar(isDesktop),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Đang đồng bộ cơ sở dữ liệu...'),
                          ],
                        ),
                      ),
                    )
                  else if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 48,
                              color: AppTheme.dangerColor,
                            ),
                            const SizedBox(height: 12),
                            Text(_errorMessage!),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _listen,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (_filtered.isEmpty)
                    _buildEmptyState()
                  else if (isDesktop)
                    _buildWebDataTable(isDark)
                  else
                    _buildMobileCardList(isDark),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm Sản Phẩm'),
        onPressed: _showAddDialog,
      ),
    );
  }

  // ==========================================
  // KPI
  // ==========================================
  Widget _buildKpiSection(bool isDesktop, bool isDark) {
    final totalQty = _all.fold<int>(0, (s, p) => s + p.soluong);
    final totalValue = _all.fold<int>(0, (s, p) => s + p.price * p.soluong);
    final lowCount = _all.where((p) => p.soluong < kLowStock).length;

    final items = [
      (
        'Sản phẩm',
        '${_all.length}',
        Icons.inventory_2_rounded,
        AppTheme.primaryColor,
      ),
      (
        'Tổng tồn kho',
        AppHelpers.formatNumber(totalQty),
        Icons.warehouse_rounded,
        AppTheme.secondaryColor,
      ),
      (
        'Giá trị tồn kho',
        AppHelpers.formatPrice(totalValue),
        Icons.payments_rounded,
        AppTheme.successColor,
      ),
      (
        'Sắp hết hàng',
        '$lowCount',
        Icons.warning_amber_rounded,
        AppTheme.warningColor,
      ),
      (
        'Cơ sở dữ liệu',
        'Firestore',
        Icons.cloud_done_rounded,
        AppTheme.accentColor,
      ),
    ];

    Widget card((String, String, IconData, Color) it) {
      final (label, value, icon, color) = it;
      return Container(
        padding: EdgeInsets.all(isDesktop ? 16 : 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: isDesktop ? 24 : 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.white60
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isDesktop ? 17 : 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isDesktop) {
      return Row(
        children: [
          for (final it in items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: card(it),
              ),
            ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < items.length; i++)
              SizedBox(
                // ô "Giá trị tồn kho" chiếm cả hàng để không bị cắt số
                width: i == 2 ? c.maxWidth : w,
                child: card(items[i]),
              ),
          ],
        );
      },
    );
  }

  // ==========================================
  // TOOLBAR: TÌM KIẾM, SẮP XẾP, LỌC
  // ==========================================
  Widget _searchField() => TextField(
    controller: _searchController,
    decoration: InputDecoration(
      hintText: 'Tìm theo tên sản phẩm...',
      prefixIcon: const Icon(Icons.search, size: 20),
      suffixIcon: _searchController.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () => _searchController.clear(),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
    ),
  );

  Widget _lowStockChip() => FilterChip(
    avatar: const Icon(Icons.warning_amber_rounded, size: 16),
    label: const Text('Sắp hết hàng (< $kLowStock)'),
    selected: _onlyLowStock,
    onSelected: (v) {
      setState(() => _onlyLowStock = v);
      _applyFilters();
    },
  );

  Widget _buildToolbar(bool isDesktop) {
    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SizedBox(height: 46, child: _searchField())),
              const SizedBox(width: 8),
              PopupMenuButton<SortOption>(
                tooltip: 'Sắp xếp',
                initialValue: _sort,
                onSelected: (val) {
                  setState(() => _sort = val);
                  _applyFilters();
                },
                itemBuilder: (context) => _sortLabels.entries
                    .map(
                      (e) => PopupMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                child: Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.sort_rounded,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _lowStockChip(),
        ],
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            SizedBox(width: 400, height: 42, child: _searchField()),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _lowStockChip(),
                const SizedBox(width: 16),
                const Icon(Icons.sort_rounded, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                DropdownButton<SortOption>(
                  value: _sort,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(12),
                  items: _sortLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    setState(() => _sort = val);
                    _applyFilters();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockBadge(int soluong) {
    final low = soluong < kLowStock;
    final color = soluong == 0
        ? AppTheme.dangerColor
        : (low ? AppTheme.warningColor : AppTheme.successColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$soluong',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }

  // ==========================================
  // WEB DATA TABLE (8.0 ĐIỂM)
  // Cột: image | name | price | soluong | tình trạng | hành động
  // (tình trạng tính từ soluong, không phải trường trong CSDL)
  // ==========================================
  static const _colFlex = [12, 32, 17, 11, 15];
  static const double _actionsWidth = 132;

  Widget _buildWebDataTable(bool isDark) {
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    Widget header(String text, int flex, {TextAlign align = TextAlign.left}) =>
        Expanded(
          flex: flex,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              text,
              textAlign: align,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        );

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      child: Column(
        children: [
          Container(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
            child: Row(
              children: [
                header('image', _colFlex[0]),
                header('name', _colFlex[1]),
                header('price', _colFlex[2], align: TextAlign.right),
                header('soluong', _colFlex[3], align: TextAlign.center),
                header('Tình trạng', _colFlex[4], align: TextAlign.center),
                const SizedBox(
                  width: _actionsWidth,
                  child: Text(
                    'Hành động',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          for (final p in _filtered)
            InkWell(
              onTap: () => _showDetail(p),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: _colFlex[0],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AppHelpers.buildProductImage(
                            imageUrl: p.image,
                            size: 56,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: _colFlex[1],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: _colFlex[2],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          AppHelpers.formatPrice(p.price),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: _colFlex[3],
                      child: Center(child: _stockBadge(p.soluong)),
                    ),
                    Expanded(
                      flex: _colFlex[4],
                      child: Center(child: StockStatus.of(p.soluong).badge()),
                    ),
                    SizedBox(
                      width: _actionsWidth,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 19,
                            ),
                            tooltip: 'Xem chi tiết',
                            color: AppTheme.secondaryColor,
                            onPressed: () => _showDetail(p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 19),
                            tooltip: 'Chỉnh sửa',
                            color: AppTheme.primaryColor,
                            onPressed: () => _showEditDialog(p),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 19),
                            tooltip: 'Xóa sản phẩm',
                            color: AppTheme.dangerColor,
                            onPressed: () => _confirmDelete(p),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==========================================
  // MOBILE CARD LIST (0.5 ĐIỂM)
  // ==========================================
  Widget _buildMobileCardList(bool isDark) {
    final subtle = isDark ? Colors.white60 : AppTheme.lightTextSecondary;
    return Column(
      children: [
        for (final p in _filtered) ...[
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _showDetail(p),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppHelpers.buildProductImage(
                      imageUrl: p.image,
                      size: 84,
                      radius: 12,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppHelpers.formatPrice(p.price),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'SL: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: subtle,
                                    ),
                                  ),
                                  _stockBadge(p.soluong),
                                ],
                              ),
                              StockStatus.of(p.soluong).badge(fontSize: 11),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          color: AppTheme.primaryColor,
                          tooltip: 'Chỉnh sửa',
                          onPressed: () => _showEditDialog(p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          color: AppTheme.dangerColor,
                          tooltip: 'Xóa',
                          onPressed: () => _confirmDelete(p),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // chừa chỗ cho nút "Thêm Sản Phẩm"
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withValues(alpha: 0.08),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không có sản phẩm phù hợp',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Thử đổi từ khóa / bộ lọc, hoặc thêm sản phẩm mới.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Thêm Sản Phẩm'),
              onPressed: _showAddDialog,
            ),
          ],
        ),
      ),
    );
  }
}
