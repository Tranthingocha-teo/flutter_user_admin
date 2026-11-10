import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../utils/app_theme.dart';
import '../utils/helpers.dart';
import 'login_screen.dart';
import 'user_detail_dialog.dart';
import 'user_form_dialog.dart';

class UserListScreen extends StatefulWidget {
  final UserModel currentUser;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const UserListScreen({
    super.key,
    required this.currentUser,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

enum SortOption {
  nameAsc,
  nameDesc,
  emailAsc,
  emailDesc,
}

class _UserListScreenState extends State<UserListScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  SortOption _selectedSort = SortOption.nameAsc;

  // Bản đồ theo dõi trạng thái hiển thị mật khẩu từng hàng
  final Map<String, bool> _visiblePasswords = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _apiService.getUsers();
      if (!mounted) return;
      setState(() {
        _allUsers = list;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Lỗi nạp dữ liệu: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    List<UserModel> result = List.from(_allUsers);

    if (query.isNotEmpty) {
      result = result.where((u) {
        final nameMatch = u.hoten.toLowerCase().contains(query);
        final emailMatch = u.email.toLowerCase().contains(query);
        return nameMatch || emailMatch;
      }).toList();
    }

    switch (_selectedSort) {
      case SortOption.nameAsc:
        result.sort((a, b) => a.hoten.compareTo(b.hoten));
        break;
      case SortOption.nameDesc:
        result.sort((a, b) => b.hoten.compareTo(a.hoten));
        break;
      case SortOption.emailAsc:
        result.sort((a, b) => a.email.compareTo(b.email));
        break;
      case SortOption.emailDesc:
        result.sort((a, b) => b.email.compareTo(a.email));
        break;
    }

    setState(() {
      _filteredUsers = result;
    });
  }

  // ==========================================
  // HÀNH ĐỘNG: THÊM NGƯỜI DÙNG
  // ==========================================
  Future<void> _showAddUserDialog() async {
    final newUser = await showDialog<UserModel>(
      context: context,
      builder: (context) => const UserFormDialog(),
    );

    if (newUser != null) {
      try {
        await _apiService.addUser(newUser);
        if (!mounted) return;
        _showToast(
          'Đã thêm thành công người dùng: ${newUser.hoten}',
          isSuccess: true,
        );
        _loadUsers();
      } catch (e) {
        if (!mounted) return;
        _showToast(e.toString().replaceAll('Exception: ', ''), isSuccess: false);
      }
    }
  }

  // ==========================================
  // HÀNH ĐỘNG: SỬA NGƯỜI DÙNG
  // ==========================================
  Future<void> _showEditUserDialog(UserModel user) async {
    final updatedUser = await showDialog<UserModel>(
      context: context,
      builder: (context) => UserFormDialog(userToEdit: user),
    );

    if (updatedUser != null) {
      try {
        await _apiService.updateUser(user.email, updatedUser);
        if (!mounted) return;
        _showToast(
          'Đã cập nhật thông tin thành công: ${updatedUser.hoten}',
          isSuccess: true,
        );
        _loadUsers();
      } catch (e) {
        if (!mounted) return;
        _showToast(e.toString().replaceAll('Exception: ', ''), isSuccess: false);
      }
    }
  }

  // ==========================================
  // HÀNH ĐỘNG: XÓA NGƯỜI DÙNG
  // ==========================================
  Future<void> _confirmDeleteUser(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppTheme.dangerColor, size: 28),
            SizedBox(width: 10),
            Text('Xác Nhận Xóa'),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa người dùng "${user.hoten}" (${user.email}) khỏi cơ sở dữ liệu không?\nHành động này không thể hoàn tác.',
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
            child: const Text('Xóa Người Dùng'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiService.deleteUser(user.email);
        if (!mounted) return;
        _showToast('Đã xóa người dùng ${user.hoten}', isSuccess: true);
        _loadUsers();
      } catch (e) {
        if (!mounted) return;
        _showToast('Lỗi khi xóa: $e', isSuccess: false);
      }
    }
  }

  // ==========================================
  // HÀNH ĐỘNG: XEM CHI TIẾT
  // ==========================================
  void _showUserDetail(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => UserDetailDialog(
        user: user,
        onEdit: () => _showEditUserDialog(user),
      ),
    );
  }

  // ==========================================
  // XUẤT DATABASE JSON
  // ==========================================
  Future<void> _exportDatabaseDialog() async {
    final jsonString = await _apiService.exportDatabaseJsonString();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.data_object_rounded, color: AppTheme.primaryColor),
            SizedBox(width: 10),
            Text('Dữ Liệu Cơ Sở Dữ Liệu (JSON)'),
          ],
        ),
        content: SizedBox(
          width: 580,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tuân thủ đề thi: JSON xuất ra CHỈ chứa đúng 4 trường: email, matkhau, hoten, hinhanh.',
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
          ElevatedButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Sao Chép JSON'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonString));
              Navigator.of(context).pop();
              _showToast(
                'Đã sao chép toàn bộ JSON vào khay nhớ tạm!',
                isSuccess: true,
              );
            },
          ),
        ],
      ),
    );
  }

  // ==========================================
  // CÀI ĐẶT CƠ SỞ DỮ LIỆU
  // ==========================================
  void _showDatabaseSettingsDialog() {
    final urlController =
        TextEditingController(text: _apiService.firebaseUrl);
    DatabaseSource selectedSource = _apiService.currentSource;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.storage_rounded, color: AppTheme.primaryColor),
              SizedBox(width: 10),
              Text('Cấu Hình Cơ Sở Dữ Liệu'),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chọn cơ sở dữ liệu hoạt động theo yêu cầu đề thi:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                RadioListTile<DatabaseSource>(
                  title: const Text('Firebase Realtime Database (Mặc định)'),
                  subtitle: const Text('Cloud DB, đồng bộ thời gian thực'),
                  value: DatabaseSource.firebase,
                  groupValue: selectedSource,
                  onChanged: (val) {
                    setDialogState(() => selectedSource = val!);
                  },
                ),
                RadioListTile<DatabaseSource>(
                  title: const Text('MongoDB API (Node.js Backend)'),
                  subtitle: const Text('Localhost:5000/api/users'),
                  value: DatabaseSource.mongodb,
                  groupValue: selectedSource,
                  onChanged: (val) {
                    setDialogState(() => selectedSource = val!);
                  },
                ),
                RadioListTile<DatabaseSource>(
                  title: const Text('Local Storage Sync (Nội bộ thiết bị)'),
                  subtitle: const Text('Đảm bảo app chạy 100% không cần mạng'),
                  value: DatabaseSource.localStorage,
                  groupValue: selectedSource,
                  onChanged: (val) {
                    setDialogState(() => selectedSource = val!);
                  },
                ),
                const SizedBox(height: 12),
                if (selectedSource == DatabaseSource.firebase) ...[
                  const Text(
                    'Firebase Realtime Database URL:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      hintText: 'https://your-app-default-rtdb.firebaseio.com',
                      isDense: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await _apiService.setDatabaseSource(
                  selectedSource,
                  customUrl: urlController.text.trim(),
                );
                navigator.pop();
                _showToast('Đã lưu cấu hình cơ sở dữ liệu!', isSuccess: true);
                _loadUsers();
              },
              child: const Text('Lưu & Áp Dụng'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // KHÔI PHỤC DỮ LIỆU GỐC
  // ==========================================
  Future<void> _resetDataConfirm() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Khôi Phục Dữ Liệu Ban Đầu?'),
        content: const Text(
          'Hệ thống sẽ nạp lại danh sách 5 người dùng mẫu ban đầu (gồm admin Trần Thị Ngọc Hà và các user mẫu). Bạn có muốn tiếp tục?',
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

    if (confirmed == true) {
      await _apiService.resetToDefault();
      _showToast('Đã khôi phục dữ liệu ban đầu thành công!', isSuccess: true);
      _loadUsers();
    }
  }

  // ==========================================
  // ĐĂNG XUẤT
  // ==========================================
  void _logout() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => LoginScreen(
          onToggleTheme: widget.onToggleTheme,
          isDarkMode: widget.isDarkMode,
        ),
      ),
    );
  }

  void _showToast(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isSuccess ? AppTheme.successColor : AppTheme.dangerColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 850;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quản Trị Người Dùng',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                  ),
                ),
                Text(
                  'Phân hệ Admin • LTDĐ VKU',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white60 : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Database settings button
          IconButton(
            icon: const Icon(Icons.storage_rounded),
            tooltip: 'Cài đặt CSDL (Firebase / MongoDB)',
            onPressed: _showDatabaseSettingsDialog,
          ),
          // Export JSON button
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Xuất file Database JSON',
            onPressed: _exportDatabaseDialog,
          ),
          // Reset data button
          IconButton(
            icon: const Icon(Icons.restart_alt_rounded),
            tooltip: 'Khôi phục dữ liệu mẫu',
            onPressed: _resetDataConfirm,
          ),
          // Theme toggle
          IconButton(
            icon: Icon(widget.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Chuyển đổi Sáng / Tối',
            onPressed: widget.onToggleTheme,
          ),
          const VerticalDivider(width: 20, indent: 12, endIndent: 12),
          // Admin Profile Avatar
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                AppHelpers.buildAvatar(
                  imageUrl: widget.currentUser.hinhanh,
                  name: widget.currentUser.hoten,
                  radius: 18,
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.currentUser.hoten,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.dangerColor),
                  tooltip: 'Đăng xuất',
                  onPressed: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32 : 16,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stat Cards KPI
              _buildKpiSection(isDesktop),
              const SizedBox(height: 20),

              // Search & Filter Toolbar
              _buildToolbar(isDesktop),
              const SizedBox(height: 20),

              // Content Area: Loading / Error / Empty / List
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
                        const Icon(Icons.error_outline,
                            size: 48, color: AppTheme.dangerColor),
                        const SizedBox(height: 12),
                        Text(_errorMessage!),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadUsers,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_filteredUsers.isEmpty)
                _buildEmptyState()
              else if (isDesktop)
                _buildWebDataTable()
              else
                _buildMobileCardList(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Thêm Người Dùng'),
        onPressed: _showAddUserDialog,
      ),
    );
  }

  // ==========================================
  // WIDGET: KPI STATISTICS CARDS
  // ==========================================
  Widget _buildKpiSection(bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String dbName;
    switch (_apiService.currentSource) {
      case DatabaseSource.firebase:
        dbName = 'Firebase RTDB';
        break;
      case DatabaseSource.mongodb:
        dbName = 'MongoDB Server';
        break;
      case DatabaseSource.localStorage:
        dbName = 'Local Storage Sync';
        break;
    }

    final cards = [
      _buildStatCard(
        title: 'Tổng Người Dùng',
        value: '${_allUsers.length}',
        icon: Icons.people_alt_rounded,
        color: AppTheme.primaryColor,
        isDark: isDark,
      ),
      _buildStatCard(
        title: 'Đang Hiển Thị',
        value: '${_filteredUsers.length}',
        icon: Icons.filter_list_rounded,
        color: AppTheme.secondaryColor,
        isDark: isDark,
      ),
      _buildStatCard(
        title: 'Cơ Sở Dữ Liệu',
        value: dbName,
        icon: Icons.cloud_done_rounded,
        color: AppTheme.successColor,
        isDark: isDark,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: c,
        ))).toList(),
      );
    } else {
      return Column(
        children: cards.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: c,
        )).toList(),
      );
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Card(
      elevation: 0,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET: SEARCH & SORT TOOLBAR
  // ==========================================
  Widget _buildToolbar(bool isDesktop) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            // Search Input
            SizedBox(
              width: isDesktop ? 340 : double.infinity,
              height: 42,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm theo họ tên hoặc email...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),

            // Sort Dropdown
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort_rounded, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                DropdownButton<SortOption>(
                  value: _selectedSort,
                  underline: const SizedBox(),
                  borderRadius: BorderRadius.circular(12),
                  items: const [
                    DropdownMenuItem(
                      value: SortOption.nameAsc,
                      child: Text('Tên: A → Z'),
                    ),
                    DropdownMenuItem(
                      value: SortOption.nameDesc,
                      child: Text('Tên: Z → A'),
                    ),
                    DropdownMenuItem(
                      value: SortOption.emailAsc,
                      child: Text('Email: A → Z'),
                    ),
                    DropdownMenuItem(
                      value: SortOption.emailDesc,
                      child: Text('Email: Z → A'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedSort = val;
                      });
                      _applyFilters();
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET: WEB DATA TABLE (8.0 ĐIỂM)
  // ==========================================
  Widget _buildWebDataTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          ),
          dataRowMaxHeight: 72,
          horizontalMargin: 20,
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('hinhanh (Ảnh)', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('hoten (Họ và tên)', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('email (Email)', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('matkhau (Mật khẩu)', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Hành động', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: _filteredUsers.map((user) {
            final isPasswordVisible = _visiblePasswords[user.email] ?? false;

            return DataRow(
              cells: [
                // hinhanh
                DataCell(
                  AppHelpers.buildAvatar(
                    imageUrl: user.hinhanh,
                    name: user.hoten,
                    radius: 22,
                  ),
                  onTap: () => _showUserDetail(user),
                ),
                // hoten
                DataCell(
                  Text(
                    user.hoten,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  onTap: () => _showUserDetail(user),
                ),
                // email
                DataCell(
                  Text(
                    user.email,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : AppTheme.lightTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                  onTap: () => _showUserDetail(user),
                ),
                // matkhau
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isPasswordVisible ? user.matkhau : '••••••••',
                        style: TextStyle(
                          fontFamily: isPasswordVisible ? null : 'monospace',
                          fontSize: 13,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isPasswordVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _visiblePasswords[user.email] = !isPasswordVisible;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                // Actions (Xem, Sửa, Xóa)
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        tooltip: 'Xem chi tiết',
                        color: AppTheme.secondaryColor,
                        onPressed: () => _showUserDetail(user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Chỉnh sửa',
                        color: AppTheme.primaryColor,
                        onPressed: () => _showEditUserDialog(user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Xóa người dùng',
                        color: AppTheme.dangerColor,
                        onPressed: () => _confirmDeleteUser(user),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ==========================================
  // WIDGET: MOBILE CARD LIST (0.5 ĐIỂM MOBILE VIEW)
  // ==========================================
  Widget _buildMobileCardList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredUsers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        final isPasswordVisible = _visiblePasswords[user.email] ?? false;

        return Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Avatar + Name & Email + More Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AppHelpers.buildAvatar(
                      imageUrl: user.hinhanh,
                      name: user.hoten,
                      radius: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.hoten,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (val) {
                        if (val == 'view') _showUserDetail(user);
                        if (val == 'edit') _showEditUserDialog(user);
                        if (val == 'delete') _confirmDeleteUser(user);
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'view',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Xem chi tiết'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Chỉnh sửa'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: AppTheme.dangerColor),
                              SizedBox(width: 8),
                              Text('Xóa',
                                  style: TextStyle(color: AppTheme.dangerColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Password toggle row
                Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 15, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'matkhau: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    Text(
                      isPasswordVisible ? user.matkhau : '••••••••',
                      style: TextStyle(
                        fontFamily: isPasswordVisible ? null : 'monospace',
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 16,
                      ),
                      onPressed: () {
                        setState(() {
                          _visiblePasswords[user.email] = !isPasswordVisible;
                        });
                      },
                    ),
                    const Spacer(),
                    // Quick Action Buttons
                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('Sửa', style: TextStyle(fontSize: 12)),
                      onPressed: () => _showEditUserDialog(user),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: AppTheme.dangerColor),
                      onPressed: () => _confirmDeleteUser(user),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================
  // WIDGET: EMPTY STATE
  // ==========================================
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
                color: AppTheme.primaryColor.withOpacity(0.08),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Không tìm thấy người dùng phù hợp',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hãy thử thay đổi từ khóa tìm kiếm hoặc nhấn nút thêm người dùng mới.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Thêm Người Dùng'),
              onPressed: _showAddUserDialog,
            ),
          ],
        ),
      ),
    );
  }
}
