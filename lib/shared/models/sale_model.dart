import 'package:cloud_firestore/cloud_firestore.dart';

class SaleModel {
  final String id;
  final String shopId;
  final String inventoryId;
  final String variantId;
  final int quantity;
  final int price;
  final int total;
  final DateTime createdAt;

  const SaleModel({
    required this.id,
    required this.shopId,
    required this.inventoryId,
    required this.variantId,
    required this.quantity,
    required this.price,
    required this.total,
    required this.createdAt,
  });

  factory SaleModel.fromMap(Map<String, dynamic> map, String id) {
    return SaleModel(
      id: id,
      shopId: map['shopId'] ?? '',
      inventoryId: map['inventoryId'] ?? '',
      variantId: map['variantId'] ?? '',
      quantity: map['quantity']?.toInt() ?? 0,
      price: map['price']?.toInt() ?? 0,
      total: map['total']?.toInt() ?? 0,
      createdAt: _parseDate(map['createdAt']),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }
}
