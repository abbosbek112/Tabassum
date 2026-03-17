import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../shared/models/comment_model.dart';

final commentRepositoryProvider = Provider((ref) {
  return CommentRepository(ref.watch(firestoreProvider));
});

final productCommentsProvider = StreamProvider.family<List<CommentModel>, String>((ref, productId) {
  return ref.watch(commentRepositoryProvider).streamCommentsByProduct(productId);
});

final shopOverallRatingProvider = StreamProvider.family<double, String>((ref, shopId) {
  return ref.watch(commentRepositoryProvider).streamCommentsByShop(shopId).map((comments) {
    if (comments.isEmpty) return 0.0;
    final sum = comments.fold<double>(0, (prev, element) => prev + element.rating);
    return sum / comments.length;
  });
});

class CommentRepository {
  final FirebaseFirestore _firestore;

  CommentRepository(this._firestore);

  Stream<List<CommentModel>> streamCommentsByProduct(String productId) {
    return _firestore
        .collection('product_comments')
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CommentModel.fromMap(doc.id, doc.data())).toList();
    });
  }

  Stream<List<CommentModel>> streamCommentsByShop(String shopId) {
    return _firestore
        .collection('product_comments')
        .where('shopId', isEqualTo: shopId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => CommentModel.fromMap(doc.id, doc.data())).toList();
    });
  }

  Future<void> addComment(CommentModel comment) async {
    await _firestore.collection('product_comments').add(comment.toMap());
  }
}
