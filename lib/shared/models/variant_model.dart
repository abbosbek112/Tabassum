class VariantModel {
  final String id;
  final String inventoryId;
  final String color;
  final String size;
  final int stock;
  final int? priceOverride;

  VariantModel({
    required this.id,
    required this.inventoryId,
    required this.color,
    required this.size,
    required this.stock,
    this.priceOverride,
  });

  factory VariantModel.fromMap(String id, Map<String, dynamic> map) {
    return VariantModel(
      id: id,
      inventoryId: (map['inventoryId'] as String?) ?? '',
      color: (map['color'] as String?) ?? '',
      size: (map['size'] as String?) ?? '',
      stock: _toInt(map['stock']),
      priceOverride: map['priceOverride'] != null ? _toInt(map['priceOverride']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'inventoryId': inventoryId,
        'color': color,
        'size': size,
        'stock': stock,
        'priceOverride': priceOverride,
      };
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
