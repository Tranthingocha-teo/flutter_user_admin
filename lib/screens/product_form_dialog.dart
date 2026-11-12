import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/product_model.dart';
import '../services/image_upload_service.dart';
import '../services/mock_data.dart';
import '../utils/app_theme.dart';
import '../utils/helpers.dart';

/// Form Thêm / Sửa sản phẩm với 4 trường: name, price, soluong, image
class ProductFormDialog extends StatefulWidget {
  final ProductModel? productToEdit;

  const ProductFormDialog({super.key, this.productToEdit});

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _soluongController;
  late final TextEditingController _imageController;

  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  bool get _isEditing => widget.productToEdit != null;

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _nameController = TextEditingController(text: p?.name ?? '');
    _priceController = TextEditingController(
      text: p != null ? '${p.price}' : '',
    );
    _soluongController = TextEditingController(
      text: p != null ? '${p.soluong}' : '',
    );
    _imageController = TextEditingController(text: p?.image ?? '');
    _imageController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _soluongController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  /// Chọn ảnh từ Thư viện / Camera, upload lên Cloudinary,
  /// rồi tự điền link ảnh vào trường image
  Future<void> _pickImage(ImageSource source) async {
    if (_isUploading) return;
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (picked == null) return;

      setState(() => _isUploading = true);
      final bytes = await picked.readAsBytes();
      final url = await ImageUploadService.uploadImage(bytes, picked.name);
      if (!mounted) return;
      setState(() {
        _imageController.text = url;
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tải ảnh lên, link ảnh đã được điền tự động!'),
          backgroundColor: AppTheme.successColor,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lỗi tải ảnh: ${e.toString().replaceAll('Exception: ', '')}',
          ),
          backgroundColor: AppTheme.dangerColor,
        ),
      );
    }
  }

  void _submit() {
    if (_isUploading) return;
    if (!_formKey.currentState!.validate()) return;

    final product = ProductModel(
      key: widget.productToEdit?.key ?? '',
      name: _nameController.text.trim(),
      price: int.parse(_priceController.text.trim()),
      soluong: int.parse(_soluongController.text.trim()),
      image: _imageController.text.trim(),
    );
    Navigator.of(context).pop(product);
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 740),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEditing ? 'Cập Nhật Sản Phẩm' : 'Thêm Sản Phẩm Mới',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Xem trước ảnh + nút chọn ảnh
                        Center(
                          child: Column(
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  AppHelpers.buildProductImage(
                                    imageUrl: _imageController.text,
                                    size: 120,
                                    radius: 16,
                                  ),
                                  if (_isUploading)
                                    const CircularProgressIndicator(),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_isUploading)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    'Đang tải ảnh lên...',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  ActionChip(
                                    avatar: const Icon(Icons.image, size: 16),
                                    label: const Text(
                                      'Chọn ảnh từ máy',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    onPressed: () =>
                                        _pickImage(ImageSource.gallery),
                                  ),
                                  if (!kIsWeb)
                                    ActionChip(
                                      avatar: const Icon(
                                        Icons.camera_alt,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Chụp ảnh',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                      onPressed: () =>
                                          _pickImage(ImageSource.camera),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'Hoặc chọn nhanh ảnh mẫu:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: InitialProductsData.presetImages.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final img =
                                  InitialProductsData.presetImages[index];
                              final selected = _imageController.text == img;
                              return GestureDetector(
                                onTap: () => _imageController.text = img,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected
                                          ? AppTheme.primaryColor
                                          : Colors.transparent,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: AppHelpers.buildProductImage(
                                    imageUrl: img,
                                    size: 38,
                                    radius: 7,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Trường 1: name
                        _label('Tên sản phẩm (name) *'),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            hintText: 'Ví dụ: Tai nghe Bluetooth',
                            prefixIcon: Icon(
                              Icons.inventory_2_outlined,
                              size: 20,
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Tên sản phẩm không được để trống';
                            }
                            if (val.trim().length < 2) {
                              return 'Tên sản phẩm phải có ít nhất 2 ký tự';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Trường 2: price
                        _label('Giá sản phẩm - VNĐ (price) *'),
                        TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            hintText: 'Ví dụ: 250000',
                            prefixIcon: Icon(Icons.sell_outlined, size: 20),
                            suffixText: '₫',
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Giá không được để trống';
                            }
                            final n = int.tryParse(val.trim());
                            if (n == null || n <= 0) {
                              return 'Giá phải là số nguyên lớn hơn 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Trường 3: soluong
                        _label('Số lượng (soluong) *'),
                        TextFormField(
                          controller: _soluongController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            hintText: 'Ví dụ: 10',
                            prefixIcon: Icon(Icons.numbers_rounded, size: 20),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Số lượng không được để trống';
                            }
                            if (int.tryParse(val.trim()) == null) {
                              return 'Số lượng phải là số nguyên ≥ 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Trường 4: image
                        _label('Hình ảnh (image - link ảnh) *'),
                        TextFormField(
                          controller: _imageController,
                          decoration: const InputDecoration(
                            hintText: 'Chọn ảnh ở trên để tự điền, hoặc dán link https://...',
                            prefixIcon: Icon(Icons.link_rounded, size: 20),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Vui lòng chọn ảnh hoặc nhập link ảnh';
                            }
                            final v = val.trim();
                            if (!v.startsWith('http://') &&
                                !v.startsWith('https://') &&
                                !AppHelpers.isBase64Image(v)) {
                              return 'Link ảnh phải bắt đầu bằng http:// hoặc https://';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppTheme.primaryColor,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Chỉ lưu đúng 4 trường: name, price, soluong, image.',
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
                      onPressed: _isUploading ? null : _submit,
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
