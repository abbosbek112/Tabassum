import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';

final wishlistRepositoryProvider = Provider<WishlistRepository>((ref) {
  return WishlistRepository(
    db: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

class WishlistItem {
  final String id;
  final String userId;
  final String productId;
  final String shopId;

  const WishlistItem({
    required this.id,
    required this.userId,
    required this.productId,
    required this.shopId,
  });

  factory WishlistItem.fromMap(String id, Map<String, dynamic> map) {
    return WishlistItem(
      id: id,
      userId: (map['userId'] as String?) ?? '',
      productId: (map['productId'] as String?) ?? '',
      shopId: (map['shopId'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'productId': productId,
        'shopId': shopId,
      };
}

class WishlistRepository {
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  WishlistRepository({required this.db, required this.auth});

  String? get _uid => auth.currentUser?.uid;

  Stream<List<WishlistItem>> streamMyWishlist() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return db
        .collection(FirestoreCollections.wishlist)
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((q) => q.docs.map((d) => WishlistItem.fromMap(d.id, d.data())).toList());
  }

  Stream<bool> isWished(String productId) {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    final docId = '${uid}_$productId';
    return db.collection(FirestoreCollections.wishlist).doc(docId).snapshots().map((d) => d.exists);
  }

  Future<void> toggleWishlist({required String productId, required String shopId}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Not signed in.');

    final docId = '${uid}_$productId';
    final ref = db.collection(FirestoreCollections.wishlist).doc(docId);
    final snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set(
        WishlistItem(id: docId, userId: uid, productId: productId, shopId: shopId).toMap(),
      );
    }
  }
}

final isWishedProvider = StreamProvider.family<bool, String>((ref, productId) {
  return ref.watch(wishlistRepositoryProvider).isWished(productId);
});

