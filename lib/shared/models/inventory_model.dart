import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryModel {
  final String id;
  final String shopId;
  final String name;
  final String category;
  final String? categoryId;
  final List<String> categoryIds;
  final String brand;
  final double rating;
  final int reviewCount;
  final List<String> availableSizes;
  final List<String> availableColors;
  final String gender;
  final String about;
  final int basePrice;
  final List<String> imageUrls;
  final DateTime createdAt;
  /// Whether the owning shop's subscription is active.
  final bool subscriptionActive;
  /// Product lifecycle status: 'active', 'archived', or 'deleted'
  final String status;
  /// When the product was soft-deleted or archived
  final DateTime? deletedAt;

  InventoryModel({
    required this.id,
    required this.shopId,
    required this.name,
    required this.category,
    this.categoryId,
    this.categoryIds = const [],
    this.brand = '',
    this.rating = 0.0,
    this.reviewCount = 0,
    this.availableSizes = const [],
    this.availableColors = const [],
    required this.gender,
    required this.about,
    required this.basePrice,
    required this.imageUrls,
    required this.createdAt,
    this.subscriptionActive = false, // Fail-closed: hidden by default unless verified
    this.status = 'active',
    this.deletedAt,
  });

  bool get isActive => status == 'active';
  bool get isDeleted => status == 'deleted';
  bool get isArchived => status == 'archived';
  /// Visible to public ONLY if shop has active subscription AND product is active
  bool get isVisibleToPublic => status == 'active' && subscriptionActive;


  factory InventoryModel.fromMap(String id, Map<String, dynamic> map) {
    // Handle migration from single imageUrl to List<String> imageUrls
    List<String> images = [];
    if (map['imageUrls'] is List) {
      images = List<String>.from(map['imageUrls']);
    } else if (map['imageUrl'] is String && (map['imageUrl'] as String).isNotEmpty) {
      images = [map['imageUrl'] as String];
    }

    return InventoryModel(
      id: id,
      shopId: (map['shopId'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      category: (map['category'] as String?) ?? '',
      categoryId: map['categoryId'] as String?,
      categoryIds: map['categoryIds'] != null ? List<String>.from(map['categoryIds']) : [],
      brand: (map['brand'] as String?) ?? '',
      rating: _toDouble(map['rating']),
      reviewCount: _toInt(map['reviewCount']),
      availableSizes: map['availableSizes'] != null ? List<String>.from(map['availableSizes']) : [],
      availableColors: map['availableColors'] != null ? List<String>.from(map['availableColors']) : [],
      gender: (map['gender'] as String?) ?? '',
      about: (map['about'] as String?) ?? '',
      basePrice: _toInt(map['basePrice']),
      imageUrls: images,
      createdAt: _parseDate(map['createdAt']),
      subscriptionActive: (map['subscriptionActive'] as bool?) ?? false, // Fail-closed default
      status: (map['status'] as String?) ?? 'active',
      deletedAt: map['deletedAt'] != null ? _parseDate(map['deletedAt']) : null,
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  Map<String, dynamic> toMap() => {
        'shopId': shopId,
        'name': name,
        'category': category,
        'categoryId': categoryId,
        'categoryIds': categoryIds,
        'brand': brand,
        'rating': rating,
        'reviewCount': reviewCount,
        'availableSizes': availableSizes,
        'availableColors': availableColors,
        'gender': gender,
        'about': about,
        'basePrice': basePrice,
        'imageUrls': imageUrls,
        'createdAt': createdAt,
        'subscriptionActive': subscriptionActive,
        'status': status,
        if (deletedAt != null) 'deletedAt': deletedAt,
      };

  InventoryModel copyWith({
    String? id,
    String? shopId,
    String? name,
    String? category,
    String? categoryId,
    List<String>? categoryIds,
    String? brand,
    double? rating,
    int? reviewCount,
    List<String>? availableSizes,
    List<String>? availableColors,
    String? gender,
    String? about,
    int? basePrice,
    List<String>? imageUrls,
    DateTime? createdAt,
    bool? subscriptionActive,
    String? status,
    DateTime? deletedAt,
  }) {
    return InventoryModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      name: name ?? this.name,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      categoryIds: categoryIds ?? this.categoryIds,
      brand: brand ?? this.brand,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      availableSizes: availableSizes ?? this.availableSizes,
      availableColors: availableColors ?? this.availableColors,
      gender: gender ?? this.gender,
      about: about ?? this.about,
      basePrice: basePrice ?? this.basePrice,
      imageUrls: imageUrls ?? this.imageUrls,
      createdAt: createdAt ?? this.createdAt,
      subscriptionActive: subscriptionActive ?? this.subscriptionActive,
      status: status ?? this.status,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _toDouble(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  return 0.0;
}
