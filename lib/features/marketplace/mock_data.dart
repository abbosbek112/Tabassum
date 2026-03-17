class MockShop {
  final String id;
  final String name;
  final String imageUrl;
  final String telegram;
  final String location;

  const MockShop({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.telegram,
    required this.location,
  });
}

class MockProduct {
  final String id;
  final String shopId;
  final String name;
  final String imageUrl;
  final int price;
  final String size;
  final String color;
  final int stock;
  final String telegram;

  const MockProduct({
    required this.id,
    required this.shopId,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.size,
    required this.color,
    required this.stock,
    required this.telegram,
  });
}

const mockShops = <MockShop>[
  MockShop(
    id: 'shop1',
    name: 'Tabassum Boutique',
    imageUrl:
        'https://images.pexels.com/photos/3735641/pexels-photo-3735641.jpeg?auto=compress&cs=tinysrgb&w=600',
    telegram: 'tabassum_boutique',
    location: 'Tashkent, Chilonzor',
  ),
  MockShop(
    id: 'shop2',
    name: 'Classic Men',
    imageUrl:
        'https://images.pexels.com/photos/298863/pexels-photo-298863.jpeg?auto=compress&cs=tinysrgb&w=600',
    telegram: 'classic_men_uz',
    location: 'Tashkent, Yunusobod',
  ),
];

const mockProducts = <MockProduct>[
  MockProduct(
    id: 'p1',
    shopId: 'shop1',
    name: 'Floral Dress',
    imageUrl:
        'https://images.pexels.com/photos/6311578/pexels-photo-6311578.jpeg?auto=compress&cs=tinysrgb&w=600',
    price: 350000,
    size: 'M',
    color: 'Beige',
    stock: 8,
    telegram: 'tabassum_boutique',
  ),
  MockProduct(
    id: 'p2',
    shopId: 'shop1',
    name: 'Silk Scarf',
    imageUrl:
        'https://images.pexels.com/photos/3760851/pexels-photo-3760851.jpeg?auto=compress&cs=tinysrgb&w=600',
    price: 120000,
    size: 'One size',
    color: 'Blue',
    stock: 15,
    telegram: 'tabassum_boutique',
  ),
  MockProduct(
    id: 'p3',
    shopId: 'shop2',
    name: 'Men\'s Suit',
    imageUrl:
        'https://images.pexels.com/photos/2897883/pexels-photo-2897883.jpeg?auto=compress&cs=tinysrgb&w=600',
    price: 750000,
    size: 'L',
    color: 'Navy',
    stock: 5,
    telegram: 'classic_men_uz',
  ),
];

MockShop? findShopById(String id) {
  return mockShops.where((s) => s.id == id).cast<MockShop?>().firstWhere(
        (s) => s != null,
        orElse: () => null,
      );
}

List<MockProduct> findProductsByShop(String shopId) {
  return mockProducts.where((p) => p.shopId == shopId).toList();
}

MockProduct? findProductById(String id) {
  return mockProducts.where((p) => p.id == id).cast<MockProduct?>().firstWhere(
        (p) => p != null,
        orElse: () => null,
      );
}

