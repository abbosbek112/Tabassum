import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../shared/models/sale_model.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(db: ref.watch(firestoreProvider));
});

class SalesRepository {
  final FirebaseFirestore db;
  SalesRepository({required this.db});

  Future<void> createSaleAndUpdateStock({
    required String shopId,
    required String inventoryId,
    required String variantId,
    required int quantity,
    required int price,
    required String ownerId,
  }) async {
    final variantRef = db
        .collection(FirestoreCollections.inventoryVariants)
        .doc(variantId);
        
    final salesRef = db.collection(FirestoreCollections.sales).doc();

    await db.runTransaction((tx) async {
      final variantSnap = await tx.get(variantRef);
      final data = variantSnap.data();
      if (data == null) {
        throw StateError('Variant not found');
      }
      final currentStock = (data['stock'] as num?)?.toInt() ?? 0;
      if (currentStock < quantity) {
        throw StateError('Not enough stock for this variant');
      }
      tx.update(variantRef, {'stock': currentStock - quantity});
      tx.set(salesRef, {
        'shopId': shopId,
        'inventoryId': inventoryId,
        'variantId': variantId,
        'quantity': quantity,
        'price': price,
        'total': price * quantity,
        'ownerId': ownerId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<List<SaleModel>> streamAllSales(String shopId) {
    return db
        .collection(FirestoreCollections.sales)
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SaleModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamDailySales({
    required String shopId,
    required DateTime day,
  }) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return db
        .collection(FirestoreCollections.sales)
        .where('shopId', isEqualTo: shopId)
        .where('createdAt', isGreaterThanOrEqualTo: start)
        .where('createdAt', isLessThan: end)
        .snapshots();
  }

  Stream<List<SaleModel>> streamSalesByInventory(String inventoryId) {
    return db
        .collection(FirestoreCollections.sales)
        .where('inventoryId', isEqualTo: inventoryId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => SaleModel.fromMap(d.data(), d.id)).toList());
  }
}

final salesByShopProvider = StreamProvider.family<List<SaleModel>, String>((ref, shopId) {
  return ref.watch(salesRepositoryProvider).streamAllSales(shopId);
});

final salesByInventoryProvider = StreamProvider.family<List<SaleModel>, String>((ref, inventoryId) {
  return ref.watch(salesRepositoryProvider).streamSalesByInventory(inventoryId);
});

