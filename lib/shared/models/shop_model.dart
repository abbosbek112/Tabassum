import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/constants.dart';

class ShopModel {
  final String id;
  final String name;
  final String ownerId;
  final ShopGenre genre;
  final String telegram;
  final String about;
  final String phone;
  final String image;
  final double rating;
  final int reviewCount;
  final bool subscriptionActive;
  final DateTime createdAt;

  ShopModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.genre,
    required this.telegram,
    required this.about,
    required this.phone,
    required this.image,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.subscriptionActive = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? _epoch;

  static final _epoch = DateTime.fromMillisecondsSinceEpoch(0);

  factory ShopModel.fromMap(String id, Map<String, dynamic> map) {
    return ShopModel(
      id: id,
      name: (map['name'] as String?) ?? '',
      ownerId: (map['ownerId'] as String?) ?? '',
      genre: ShopGenre.fromString((map['genre'] as String?) ?? (map['gender'] as String?) ?? 'clothes'),
      telegram: (map['telegram'] as String?) ?? '',
      about: (map['about'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      image: (map['image'] as String?) ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviewCount: (map['reviewCount'] ?? 0).toInt(),
      subscriptionActive: (map['subscriptionActive'] as bool?) ?? false,
      createdAt: _readDt(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'ownerId': ownerId,
        'genre': genre.asString,
        'telegram': telegram,
        'about': about,
        'phone': phone,
        'image': image,
        'rating': rating,
        'reviewCount': reviewCount,
        'subscriptionActive': subscriptionActive,
        'createdAt': createdAt,
      };

  ShopModel copyWith({
    String? id,
    String? name,
    String? ownerId,
    ShopGenre? genre,
    String? telegram,
    String? about,
    String? phone,
    String? image,
    double? rating,
    int? reviewCount,
    bool? subscriptionActive,
    DateTime? createdAt,
  }) {
    return ShopModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      genre: genre ?? this.genre,
      telegram: telegram ?? this.telegram,
      about: about ?? this.about,
      phone: phone ?? this.phone,
      image: image ?? this.image,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      subscriptionActive: subscriptionActive ?? this.subscriptionActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

DateTime _readDt(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return DateTime.fromMillisecondsSinceEpoch(0);
}
