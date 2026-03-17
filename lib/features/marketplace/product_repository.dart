import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../shared/models/product_model.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(
    db: ref.watch(firestoreProvider),
    storage: ref.watch(storageProvider),
  );
});

class ProductRepository {
  final FirebaseFirestore db;
  final FirebaseStorage storage;

  ProductRepository({required this.db, required this.storage});

  Stream<List<ProductModel>> streamProductsByShop(String shopId) {
    return db
        .collection(FirestoreCollections.products)
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((q) => q.docs.map((d) => ProductModel.fromMap(d.id, d.data())).toList());
  }

  Stream<List<ProductModel>> streamProductsByCategory(String categoryId) {
    return db
        .collection(FirestoreCollections.products)
        .where('categoryId', isEqualTo: categoryId)
        .snapshots()
        .map((q) => q.docs.map((d) => ProductModel.fromMap(d.id, d.data())).toList());
  }

  Stream<ProductModel?> streamProduct(String productId) {
    return db.collection(FirestoreCollections.products).doc(productId).snapshots().map((d) {
      final data = d.data();
      if (data == null) return null;
      return ProductModel.fromMap(d.id, data);
    });
  }

  Future<String> addProduct(ProductModel product) async {
    final doc = db.collection(FirestoreCollections.products).doc();
    await doc.set(product.toMap());
    return doc.id;
  }

  Future<void> updateProduct(ProductModel product) async {
    await db
        .collection(FirestoreCollections.products)
        .doc(product.id)
        .set(product.toMap(), SetOptions(merge: true));
  }

  Future<String> uploadImageBytes({
    required String shopId,
    required String productId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final ref = storage.ref().child('shops/$shopId/products/$productId/$fileName');
    final meta = SettableMetadata(contentType: contentType);
    await ref.putData(bytes, meta);
    return ref.getDownloadURL();
  }

  Future<void> updateStock({required String productId, required int newStock}) {
    return db.collection(FirestoreCollections.products).doc(productId).update({'stock': newStock});
  }
}

