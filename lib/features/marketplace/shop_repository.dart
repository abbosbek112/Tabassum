import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/cloudinary_service.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../shared/models/shop_model.dart';

final shopRepositoryProvider = Provider<ShopRepository>((ref) {
  return ShopRepository(
    db: ref.watch(firestoreProvider),
    storage: ref.watch(storageProvider),
  );
});

final shopByIdProvider = StreamProvider.family<ShopModel?, String>((ref, shopId) {
  return ref.watch(shopRepositoryProvider).streamShop(shopId);
});

class ShopRepository {
  final FirebaseFirestore db;
  final FirebaseStorage storage;
  ShopRepository({required this.db, required this.storage});

  Stream<List<ShopModel>> streamShops() {
    return db.collection(FirestoreCollections.shops).snapshots().map(
          (q) => q.docs.map((d) => ShopModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchShopsPaginated({
    DocumentSnapshot? lastDocument,
    int limit = 12,
  }) async {
    Query<Map<String, dynamic>> query = db
        .collection(FirestoreCollections.shops)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.get();
  }

  /// Fetches top recommended shops: only active-subscription shops,
  /// ranked by quality score = rating × log(reviewCount + 1).
  Future<List<ShopModel>> fetchRecommendedShops({int limit = 8}) async {
    // Step 1: Get all currently active subscription shopIds
    final now = Timestamp.now();
    final subsSnap = await db
        .collection(FirestoreCollections.subscriptions)
        .where('status', isEqualTo: 'active')
        .where('endDate', isGreaterThan: now)
        .get();

    final activeShopIds = subsSnap.docs.map((d) => d.id).toSet();
    if (activeShopIds.isEmpty) return [];

    // Step 2: Fetch shops with good ratings (Firestore max 100 for scoring)
    final shopsSnap = await db
        .collection(FirestoreCollections.shops)
        .where(FieldPath.documentId, whereIn: activeShopIds.take(30).toList())
        .get();

    final shops = shopsSnap.docs
        .map((d) => ShopModel.fromMap(d.id, d.data()))
        .toList();

    // Step 3: Score and sort: rating × log(reviewCount + 1)
    // This rewards both high rating AND volume of reviews
    shops.sort((a, b) {
      final scoreA = a.rating * (a.reviewCount + 1).toDouble();
      final scoreB = b.rating * (b.reviewCount + 1).toDouble();
      return scoreB.compareTo(scoreA);
    });

    return shops.take(limit).toList();
  }

  Stream<List<ShopModel>> streamShopsByOwner(String ownerId) {
    return db
        .collection(FirestoreCollections.shops)
        .where('ownerId', isEqualTo: ownerId)
        .snapshots()
        .map((q) => q.docs.map((d) => ShopModel.fromMap(d.id, d.data())).toList());
  }

  Stream<ShopModel?> streamShop(String shopId) {
    return db.collection(FirestoreCollections.shops).doc(shopId).snapshots().map((d) {
      final data = d.data();
      if (data == null) return null;
      return ShopModel.fromMap(d.id, data);
    });
  }

  Future<String> createShop(ShopModel shop) async {
    final doc = db.collection(FirestoreCollections.shops).doc();
    await doc.set(shop.toMap());
    return doc.id;
  }

  Future<void> updateShop(ShopModel shop) async {
    await db.collection(FirestoreCollections.shops).doc(shop.id).set(shop.toMap(), SetOptions(merge: true));
  }

  Future<String> uploadShopImage({
    required String shopId,
    required List<int> bytes,
    required String fileName,
  }) async {
    try {
      final url = await CloudinaryService.uploadImage(
        bytes: Uint8List.fromList(bytes),
        fileName: fileName,
        folder: 'shops/$shopId',
      );
      return url;
    } catch (e) {
      rethrow;
    }
  }
}
