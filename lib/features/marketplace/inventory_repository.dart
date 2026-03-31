import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/cloudinary_service.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../shared/models/inventory_model.dart';
import '../../shared/models/variant_model.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(
    db: ref.watch(firestoreProvider),
    storage: ref.watch(storageProvider),
  );
});

final inventoryCountByShopProvider = StreamProvider.family<int, String>((ref, shopId) {
  return ref.watch(inventoryRepositoryProvider).streamInventoryCountByShop(shopId);
});

class InventoryRepository {
  final FirebaseFirestore db;
  final FirebaseStorage storage;

  InventoryRepository({required this.db, required this.storage});

  /// --- INVENTORY METHODS ---

  /// Public-facing: only active products from shops with active subscription.
  Stream<List<InventoryModel>> streamAllInventory() {
    return db
        .collection(FirestoreCollections.inventory)
        .where('status', isEqualTo: 'active')
        .where('subscriptionActive', isEqualTo: true)
        .snapshots()
        .map((q) => q.docs
            .map((d) => InventoryModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getInventoryBatch({
    int limit = 20,
    DocumentSnapshot? startAfter,
    String? categoryId,
    String? shopId,
  }) async {
    Query<Map<String, dynamic>> query = db
        .collection(FirestoreCollections.inventory)
        .where('status', isEqualTo: 'active')
        .where('subscriptionActive', isEqualTo: true)
        .limit(limit);

    if (categoryId != null) {
      query = query.where('categoryIds', arrayContains: categoryId);
    }
    if (shopId != null) {
      query = query.where('shopId', isEqualTo: shopId);
    }

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.get();
  }

  /// Public-facing stream for a shop: only active products with active subscription.
  Stream<List<InventoryModel>> streamInventoryByShop(String shopId) {
    return db
        .collection(FirestoreCollections.inventory)
        .where('shopId', isEqualTo: shopId)
        .where('status', isEqualTo: 'active')
        .where('subscriptionActive', isEqualTo: true)
        .snapshots()
        .map((q) => q.docs
            .map((d) => InventoryModel.fromMap(d.id, d.data()))
            .toList());
  }

  /// For the seller's OWN dashboard (all products, including hidden ones).
  Stream<List<InventoryModel>> streamInventoryByShopOwner(String shopId) {
    return db
        .collection(FirestoreCollections.inventory)
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((q) => q.docs.map((d) => InventoryModel.fromMap(d.id, d.data())).toList());
  }

  Stream<int> streamInventoryCountByShop(String shopId) {
    return db
        .collection(FirestoreCollections.inventory)
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((q) => q.docs.length);
  }

  Stream<List<InventoryModel>> streamInventoryByCategory(String category) {
    return db
        .collection(FirestoreCollections.inventory)
        .where('category', isEqualTo: category)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((q) => q.docs
            .map((d) => InventoryModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<List<InventoryModel>> streamInventoryByCategoryId(String categoryId) {
    return db
        .collection(FirestoreCollections.inventory)
        .where('categoryIds', arrayContains: categoryId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((q) => q.docs
            .map((d) => InventoryModel.fromMap(d.id, d.data()))
            .toList());
  }

  Stream<InventoryModel?> streamInventory(String inventoryId) {
    return db.collection(FirestoreCollections.inventory).doc(inventoryId).snapshots().map((d) {
      final data = d.data();
      if (data == null) return null;
      return InventoryModel.fromMap(d.id, data);
    });
  }

  Future<String> addInventory(InventoryModel inventory) async {
    // Check shop subscription status to set subscriptionActive correctly
    bool isActive = true;
    try {
      final subDoc = await db
          .collection(FirestoreCollections.subscriptions)
          .doc(inventory.shopId)
          .get();

      if (subDoc.exists) {
        final data = subDoc.data()!;
        final status = data['status'] as String?;
        final endDate = (data['endDate'] as Timestamp?)?.toDate();
        // Active if status is 'active' and not expired
        isActive = status == 'active' &&
            (endDate == null || endDate.isAfter(DateTime.now()));
      } else {
        // No subscription record means not active by default for new shops
        isActive = false;
      }
    } catch (e) {
      // Fail closed: if we can't verify subscription, DO NOT make it public
      isActive = false;
    }

    final doc = db.collection(FirestoreCollections.inventory).doc();
    await doc.set(inventory.copyWith(
      id: doc.id,
      subscriptionActive: isActive,
    ).toMap());
    return doc.id;
  }

  Future<void> updateInventory(InventoryModel inventory) async {
    await db
        .collection(FirestoreCollections.inventory)
        .doc(inventory.id)
        .set(inventory.toMap(), SetOptions(merge: true));
  }

  /// Soft-delete: marks product as 'deleted' without removing data.
  Future<void> deleteInventory(String inventoryId) async {
    await db.collection(FirestoreCollections.inventory).doc(inventoryId).update({
      'status': 'deleted',
      'deletedAt': DateTime.now(),
    });
  }

  /// Archive: marks product as 'archived' (e.g., stock depleted).
  Future<void> archiveInventory(String inventoryId) async {
    await db.collection(FirestoreCollections.inventory).doc(inventoryId).update({
      'status': 'archived',
      'deletedAt': DateTime.now(),
    });
  }

  /// Restore: brings a deleted/archived product back to active.
  Future<void> restoreInventory(String inventoryId) async {
    await db.collection(FirestoreCollections.inventory).doc(inventoryId).update({
      'status': 'active',
      'deletedAt': null,
    });
  }

  /// Hard-delete: permanently removes product + variants + comments. Admin only.
  Future<void> hardDeleteInventory(String inventoryId) async {
    final batch = db.batch();
    
    final variants = await db
        .collection(FirestoreCollections.inventoryVariants)
        .where('inventoryId', isEqualTo: inventoryId)
        .get();
        
    for (final doc in variants.docs) {
      batch.delete(doc.reference);
    }

    final comments = await db
        .collection(FirestoreCollections.productComments)
        .where('productId', isEqualTo: inventoryId)
        .get();

    for (final doc in comments.docs) {
      batch.delete(doc.reference);
    }
    
    batch.delete(db.collection(FirestoreCollections.inventory).doc(inventoryId));
    
    await batch.commit();
  }

  /// Stream deleted/archived products for the seller's archive tab.
  Stream<List<InventoryModel>> streamDeletedInventory(String shopId) {
    return db
        .collection(FirestoreCollections.inventory)
        .where('shopId', isEqualTo: shopId)
        .where('status', whereIn: ['deleted', 'archived'])
        .snapshots()
        .map((q) => q.docs
            .map((d) => InventoryModel.fromMap(d.id, d.data()))
            .toList());
  }

  Future<String> uploadImageBytes({
    required String shopId,
    required String inventoryId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final url = await CloudinaryService.uploadImage(
      bytes: bytes,
      fileName: fileName,
      folder: 'shops/$shopId/inventory/$inventoryId',
    );
    return url;
  }

  /// --- VARIANT METHODS ---

  Stream<List<VariantModel>> streamVariantsByInventory(String inventoryId) {
    return db
        .collection(FirestoreCollections.inventoryVariants)
        .where('inventoryId', isEqualTo: inventoryId)
        .snapshots()
        .map((q) => q.docs.map((d) => VariantModel.fromMap(d.id, d.data())).toList());
  }

  Future<String> addVariant(String inventoryId, VariantModel variant) async {
    final doc = db
        .collection(FirestoreCollections.inventoryVariants)
        .doc();
    await doc.set(variant.toMap());
    return doc.id;
  }

  Future<void> updateVariant(String inventoryId, VariantModel variant) async {
    await db
        .collection(FirestoreCollections.inventoryVariants)
        .doc(variant.id)
        .set(variant.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteVariant(String inventoryId, String variantId) async {
    await db
        .collection(FirestoreCollections.inventoryVariants)
        .doc(variantId)
        .delete();
  }
}
