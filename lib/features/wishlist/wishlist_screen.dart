import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/localization.dart';

import '../../core/providers.dart';
import '../../core/shared_providers.dart';
import 'wishlist_repository.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    if (user == null) {
      return Scaffold(
        body: Center(child: Text(context.l('not_logged_in'))),
      );
    }

    final wishlistAsync = ref.watch(_myWishlistProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.l('wishlist'),
          style: TextStyle(
            fontWeight: FontWeight.w800, 
            fontSize: MediaQuery.sizeOf(context).width < 380 ? 20 : 24, 
            letterSpacing: -0.5
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        centerTitle: false,
        elevation: 0,
        automaticallyImplyLeading: true,
        surfaceTintColor: Colors.transparent,
      ),
      body: wishlistAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 64, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text(
                    context.l('wishlist_empty'),
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.w600, 
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 140),
            itemCount: items.length,
            itemBuilder: (context, idx) {
              final w = items[idx];
              final inventoryAsync = ref.watch(singleInventoryProvider(w.productId));

              return inventoryAsync.when(
                data: (inv) {
                  if (inv == null) {
                    return _ErrorItem(
                      id: w.productId,
                      onRemove: () => _toggle(ref, w),
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () => context.push('/market/product/${inv.id}'),
                      borderRadius: BorderRadius.circular(24),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Product Image
                            Hero(
                              tag: 'wishlist_${inv.id}',
                              child: Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: inv.imageUrls.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: inv.imageUrls.first,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                            child: Icon(
                                              Icons.error_outline, 
                                              size: 24, 
                                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                                            ),
                                          ),
                                        )
                                      : Icon(
                                          Icons.image_outlined, 
                                          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5), 
                                          size: 32,
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    inv.category.toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFF6366F1),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    inv.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      letterSpacing: -0.3,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${inv.basePrice} sum',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Remove Button
                            IconButton(
                              onPressed: () => _toggle(ref, w),
                              icon: const Icon(Icons.favorite, color: Color(0xFFEF4444)),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444).withOpacity(0.1),
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                loading: () => _LoadingPlaceholder(),
                error: (e, _) => _ErrorItem(
                  id: w.productId,
                  onRemove: () => _toggle(ref, w),
                ),
              );
            },
          );
        },
        error: (e, _) => Center(child: Text('${context.l('error')}: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  void _toggle(WidgetRef ref, WishlistItem item) {
    ref.read(wishlistRepositoryProvider).toggleWishlist(
          productId: item.productId,
          shopId: item.shopId,
        );
  }
}

class _LoadingPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 114,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _ErrorItem extends StatelessWidget {
  final String id;
  final VoidCallback onRemove;

  const _ErrorItem({required this.id, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5), 
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mahsulot topilmadi', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                Text(
                  'O\'chirilgan bo\'lishi mumkin', 
                  style: TextStyle(
                    fontSize: 12, 
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove, 
            icon: Icon(
              Icons.delete_outline, 
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

final _myWishlistProvider = StreamProvider<List<WishlistItem>>((ref) {
  return ref.watch(wishlistRepositoryProvider).streamMyWishlist();
});
