class ProductModel {
  final String id;
  final String shopId;
  final String categoryId;
  final String name;
  final int price;
  final int stock;
  final String imageUrl;

  ProductModel({
    required this.id,
    required this.shopId,
    required this.categoryId,
    required this.name,
    required this.price,
    required this.stock,
    required this.imageUrl,
  });

  factory ProductModel.fromMap(String id, Map<String, dynamic> map) {
    return ProductModel(
      id: id,
      shopId: (map['shopId'] as String?) ?? '',
      categoryId: (map['categoryId'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      price: _toInt(map['price']),
      stock: _toInt(map['stock']),
      // Support both old `image` field and new `imageUrl` field for backward compat.
      imageUrl: (map['imageUrl'] as String?) ?? (map['image'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'shopId': shopId,
        'categoryId': categoryId,
        'name': name,
        'price': price,
        'stock': stock,
        'imageUrl': imageUrl,
      };
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return 0;
}
