import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/models/inventory_model.dart';
import '../shared/models/variant_model.dart';
import '../shared/models/shop_model.dart';
import '../features/marketplace/inventory_repository.dart';
import '../features/marketplace/shop_repository.dart';
import '../features/subscription/subscription_repository.dart';

/// Shared provider: stream shops owned by [uid].
final myShopsProvider = StreamProvider.family<List<ShopModel>, String>((ref, uid) {
  return ref.watch(shopRepositoryProvider).streamShopsByOwner(uid);
});

/// Shared provider: single shop stream by [shopId].
final singleShopProvider = StreamProvider.family<ShopModel?, String>((ref, shopId) {
  return ref.watch(shopRepositoryProvider).streamShop(shopId);
});

/// Shared provider: stream inventory in [shopId] — OWNER view (all products, including hidden).
final inventoryByShopProvider = StreamProvider.family<List<InventoryModel>, String>((ref, shopId) {
  return ref.watch(inventoryRepositoryProvider).streamInventoryByShopOwner(shopId);
});

/// Shared provider: single inventory stream by [inventoryId].
final singleInventoryProvider = StreamProvider.family<InventoryModel?, String>((ref, inventoryId) {
  return ref.watch(inventoryRepositoryProvider).streamInventory(inventoryId);
});

/// Shared provider: variants by [inventoryId].
final variantsByInventoryProvider = StreamProvider.family<List<VariantModel>, String>((ref, inventoryId) {
  return ref.watch(inventoryRepositoryProvider).streamVariantsByInventory(inventoryId);
});

/// Shared provider: subscription for [shopId].
final shopSubscriptionProvider = StreamProvider.family<SubscriptionModel?, String>((ref, shopId) {
  return ref.watch(subscriptionRepositoryProvider).streamSubscription(shopId);
});

/// Shared provider: whether subscription is active for [shopId].
final subscriptionActiveProvider = StreamProvider.family<bool, String>((ref, shopId) {
  return ref.watch(subscriptionRepositoryProvider).streamIsActive(shopId);
});
