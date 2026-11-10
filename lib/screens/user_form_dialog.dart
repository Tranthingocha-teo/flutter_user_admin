import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../services/mock_data.dart';
import '../utils/app_theme.dart';
import '../utils/helpers.dart';

class UserFormDialog extends StatefulWidget {
  final UserModel? userToEdit;

  const UserFormDialog({super.key, this.userToEdit});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _emailController;
  late TextEditingController _matkhauController;
  late TextEditingController _hotenController;
  late TextEditingController _hinhanhController;

  bool _obscurePassword = true;
  bool _isEditing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isEditing = widget.userToEdit != null;
    _emailController =
        TextEditingController(text: widget.userToEdit?.email ?? '');
    _matkhauController =
        TextEditingController(text: widget.userToEdit?.matkhau ?? '');
    _hotenController =
        TextEditingController(text: widget.userToEdit?.hoten ?? '');
    _hinhanhController = TextEditingController(
      text: widget.userToEdit?.hinhanh ??
          InitialUsersData.presetAvatars.first,
    );

    _hinhanhController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _matkhauController.dispose();
    _hotenController.dispose();
    _hinhanhController.dispose();
    super.dispose();
  }

  /// Chọn ảnh từ máy (Thư viện ảnh) hoặc Camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        final base64String = base64Encode(bytes);
        final mimeType = pickedFile.mimeType ?? 'image/jpeg';
        final dataUri = 'data:$mimeType;base64,$base64String';

        setState(() {
          _hinhanhController.text = dataUri;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã tải ảnh lên thành công!'),
              backgroundColor: AppTheme.successColor,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi chọn ảnh: $e'),
            backgroundColor: AppTheme.dangerColor,
          ),
        );
      }
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final user = UserModel(
      email: _emailController.text.trim(),
      matkhau: _matkhauController.text,
      hoten: _hotenController.text.trim(),
      hinhanh: _hinhanhController.text.trim(),
    );

    Navigator.of(context).pop(user);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dialog Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditing
                          ? 'Cập Nhật Người Dùng'
                          : 'Thêm Người Dùng Mới',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12),

                // Scrollable Form content
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar Preview & Picker Actions
                        Center(
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  AppHelpers.buildAvatar(
                                    imageUrl: _hinhanhController.text,
                                    name: _hotenController.text.isNotEmpty
                                        ? _hotenController.text
                                        : 'U',
                                    radius: 46,
                                  ),
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AppTheme.primaryColor,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.photo_camera,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      onPressed: () =>
                                          _pickImage(ImageSource.gallery),
                                      tooltip: 'Chọn ảnh từ thiết bị',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children: [
                                  ActionChip(
                                    avatar: const Icon(Icons.image, size: 16),
                                    label: const Text('Thư viện ảnh',
                                        style: TextStyle(fontSize: 12)),
                                    onPressed: () =>
                                        _pickImage(ImageSource.gallery),
                                  ),
                                  if (!kIsWeb)
                                    ActionChip(
                                      avatar:
                                          const Icon(Icons.camera_alt, size: 16),
                                      label: const Text('Chụp ảnh',
                                          style: TextStyle(fontSize: 12)),
                                      onPressed: () =>
                                          _pickImage(ImageSource.camera),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Preset Avatar Selector
                        const Text(
                          'Hoặc chọn nhanh Avatar có sẵn:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 44,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: InitialUsersData.presetAvatars.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final avatar =
                                  InitialUsersData.presetAvatars[index];
                              final isSelected =
                                  _hinhanhController.text == avatar;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _hinhanhController.text = avatar;
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppTheme.primaryColor
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: CircleAvatar(
                                    radius: 18,
                                    backgroundImage: NetworkImage(avatar),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Trường 1: hoten
                        const Text(
                          'Họ và tên (hoten) *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _hotenController,
                          decoration: const InputDecoration(
                            hintText: 'Ví dụ: Nguyễn Văn An',
                            prefixIcon: Icon(Icons.person_outline, size: 20),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Họ tên không được để trống';
                            }
                            if (val.trim().length < 2) {
                              return 'Họ tên phải có ít nhất 2 ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Trường 2: email
                        const Text(
                          'Email (email) *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'nguyenvanan@gmail.com',
                            prefixIcon: Icon(Icons.mail_outline, size: 20),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Email không được để trống';
                            }
                            if (!AppHelpers.isValidEmail(val)) {
                              return 'Định dạng email không hợp lệ (cần @ và domain)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Trường 3: matkhau
                        const Text(
                          'Mật khẩu (matkhau) *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _matkhauController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Nhập mật khẩu (tối thiểu 6 ký tự)',
                            prefixIcon:
                                const Icon(Icons.lock_outline, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Mật khẩu không được để trống';
                            }
                            if (val.length < 6) {
                              return 'Mật khẩu phải có ít nhất 6 ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Trường 4: hinhanh
                        const Text(
                          'Hình ảnh (hinhanh - URL hoặc Base64) *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _hinhanhController,
                          decoration: const InputDecoration(
                            hintText: 'https://... hoặc data:image/...',
                            prefixIcon: Icon(Icons.link_rounded, size: 20),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Đường dẫn hình ảnh không được để trống';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),

                        // Note on 4 fields
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: AppTheme.primaryColor, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Tuân thủ đề thi: Chỉ lưu đúng 4 trường email, matkhau, hoten, hinhanh.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Hủy Bỏ'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: Icon(_isEditing ? Icons.save : Icons.add, size: 18),
                      label: Text(_isEditing ? 'Lưu Thay Đổi' : 'Thêm Mới'),
                      onPressed: _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
