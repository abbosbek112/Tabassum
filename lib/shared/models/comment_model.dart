import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String productId;
  final String shopId;
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.productId,
    required this.shopId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'shopId': shopId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory CommentModel.fromMap(String id, Map<String, dynamic> map) {
    return CommentModel(
      id: id,
      productId: map['productId'] ?? '',
      shopId: map['shopId'] ?? '',
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Anonymous',
      rating: (map['rating'] ?? 0).toDouble(),
      comment: map['comment'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
