class FirestoreCollections {
  static const users = 'users';
  static const shops = 'shops';
  static const categories = 'categories';
  static const products = 'products'; // Legacy
  static const inventory = 'inventory';
  static const inventoryVariants = 'inventory_variants';
  static const productComments = 'product_comments';
  static const wishlist = 'wishlist';
  static const sales = 'sales';
  static const subscriptions = 'subscriptions';
  static const payments = 'payments';
  static const expenses = 'expenses';
  static const subscriptionHistory = 'subscription_history';
}

enum UserRole {
  customer,
  seller,
  admin;

  String get asString => switch (this) {
        UserRole.customer => 'customer',
        UserRole.seller => 'seller',
        UserRole.admin => 'admin',
      };

  static UserRole fromString(String value) => switch (value) {
        'seller' => UserRole.seller,
        'admin' => UserRole.admin,
        _ => UserRole.customer,
      };
}

enum GenderCategory {
  male,
  female,
  unisex;

  String get asString => switch (this) {
        GenderCategory.male => 'male',
        GenderCategory.female => 'female',
        GenderCategory.unisex => 'unisex',
      };

  static GenderCategory fromString(String value) => switch (value) {
        'female' => GenderCategory.female,
        'unisex' => GenderCategory.unisex,
        _ => GenderCategory.male,
      };
}

enum ShopGenre {
  auto,
  toys,
  perfumery,
  clothes,
  electronics,
  home,
  jewelry,
  other;

  String get asString => name;

  static ShopGenre fromString(String value) {
    return ShopGenre.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ShopGenre.clothes,
    );
  }

  String get label => switch (this) {
        ShopGenre.auto => 'Avto ehtiyot qismlar',
        ShopGenre.toys => 'O\'yinchoqlar',
        ShopGenre.perfumery => 'Parfumeriya',
        ShopGenre.clothes => 'Kiyim-kechak',
        ShopGenre.electronics => 'Elektronika',
        ShopGenre.home => 'Uy va ro\'zg\'or',
        ShopGenre.jewelry => 'Taqinchoqlar',
        ShopGenre.other => 'Boshqa',
      };
}

class CloudinaryConfig {
  static const String cloudName = 'doykraufo';
  static const String uploadPreset = 'tabassum_preset';
}
