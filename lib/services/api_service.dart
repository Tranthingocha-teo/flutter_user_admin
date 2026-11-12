import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/product_model.dart';
import 'mock_data.dart';

/// CRUD sản phẩm trên Cloud Firestore, collection `products`.
/// Mỗi document chỉ có đúng 4 trường: name, price, soluong, image.
/// ID của document do Firestore tự sinh, không phải là một trường dữ liệu.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('products');

  ProductModel _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) =>
      ProductModel.fromMap(d.data() ?? {}, key: d.id);

  /// Danh sách sản phẩm, cập nhật theo thời gian thực khi CSDL thay đổi
  Stream<List<ProductModel>> watchProducts() =>
      _col.snapshots().map((s) => s.docs.map(_fromDoc).toList());

  Future<List<ProductModel>> getProducts() async {
    final snap = await _col.get();
    return snap.docs.map(_fromDoc).toList();
  }

  Future<ProductModel> addProduct(ProductModel product) async {
    final ref = await _col.add(product.toMap());
    return product.copyWith(key: ref.id);
  }

  Future<void> updateProduct(ProductModel product) async {
    if (product.key.isEmpty) {
      throw Exception('Sản phẩm không có ID để cập nhật');
    }
    await _col.doc(product.key).set(product.toMap());
  }

  Future<void> deleteProduct(ProductModel product) async {
    await _col.doc(product.key).delete();
  }

  /// Xóa toàn bộ và nạp lại sản phẩm mẫu
  Future<void> resetToDefault() async {
    final batch = FirebaseFirestore.instance.batch();
    for (final d in (await _col.get()).docs) {
      batch.delete(d.reference);
    }
    for (final p in InitialProductsData.defaultProducts) {
      batch.set(_col.doc(), p.toMap());
    }
    await batch.commit();
  }

  /// JSON của CSDL để nộp bài: chỉ có 4 trường, không kèm ID
  Future<String> exportDatabaseJsonString() async {
    final products = await getProducts();
    return const JsonEncoder.withIndent('  ')
        .convert(products.map((p) => p.toMap()).toList());
  }
}
