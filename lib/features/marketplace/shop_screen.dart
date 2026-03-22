import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants.dart';
import '../../core/shared_providers.dart';
import '../../core/twa_service.dart';
import '../../core/localization.dart';
import '../auth/auth_controller.dart';
import '../../shared/models/shop_model.dart';
import 'shop_repository.dart';
import 'inventory_repository.dart';
import '../../shared/models/inventory_model.dart';
import '../wishlist/wishlist_repository.dart';
import '../seller/products_screen.dart';
import 'shop_notifier.dart';
import '../../shared/widgets/loading_widgets.dart';
import '../../core/utils.dart';

// Deleted shopsProvider - now using shopPaginationProvider

class ShopScreen extends ConsumerStatefulWidget {
  const ShopScreen({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  ShopGenre? _filterGenre;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final _debouncer = Debouncer(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(shopPaginationProvider.notifier).fetchNextPage();
    }
  }

  void _onSearchChanged(String query) {
    _debouncer.run(() {
      if (mounted) {
        setState(() {
          _searchQuery = query.toLowerCase().trim();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pagination = ref.watch(shopPaginationProvider);
    final shops = pagination.items;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── App header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(context.l('market'),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.5,
                              color: Theme.of(context).textTheme.titleLarge?.color,
                            )),
                        Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: Theme.of(context).dividerColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.notifications_none_rounded, color: Theme.of(context).textTheme.bodyMedium?.color, size: 22),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Search bar
                    TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: context.l('search_shops'),
                        prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).textTheme.bodySmall?.color),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () { 
                                  _searchCtrl.clear(); 
                                  _onSearchChanged('');
                                },
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _GenreChip(label: context.l('all'), selected: _filterGenre == null, onTap: () => setState(() => _filterGenre = null)),
                          ...ShopGenre.values.map((genre) => Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: _GenreChip(
                              label: genre.label, 
                              selected: _filterGenre == genre, 
                              onTap: () => setState(() => _filterGenre = genre)
                            ),
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // New Shops horizontal section
                    _buildNewShopsSection(context, ref),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Shops list ──────────────────────────────────────────────
            ...() {
                var filtered = shops
                    .where((s) => _filterGenre == null || s.genre == _filterGenre)
                    .where((s) => _searchQuery.isEmpty || s.name.toLowerCase().contains(_searchQuery) || s.about.toLowerCase().contains(_searchQuery))
                    .toList();

                if (filtered.isEmpty) {
                  if (pagination.isLoading && shops.isEmpty) {
                    return [
                      const SliverLoadingIndicator()
                    ];
                  }
                  return [
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.storefront_outlined, size: 72, color: Theme.of(context).dividerColor),
                            const SizedBox(height: 16),
                            Text(context.l('no_products_found'), style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodyMedium?.color)),
                          ],
                        ),
                      ),
                    )
                  ];
                }

                // Feature the first shop as a prominent banner if no search
                final showFeatured = _searchQuery.isEmpty && _filterGenre == null && filtered.isNotEmpty;

                return [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          if (i < filtered.length) {
                             if (showFeatured && i == 0) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _FeaturedShopCard(shop: filtered[0]),
                              );
                            }
                            final shop = filtered[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _ShopCard(shop: shop),
                            );
                          } else {
                            // Loading indicator at the bottom
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 32),
                              child: AppLoadingIndicator(size: 32),
                            );
                          }
                        },
                        childCount: filtered.length + (pagination.hasMore && _searchQuery.isEmpty ? 1 : 0),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 140)),
                ];
            }(),
          ],
        ),
      ),
    );
  }

  Widget _buildNewShopsSection(BuildContext context, WidgetRef ref) {
    final shops = ref.watch(shopPaginationProvider).items;
    if (shops.isEmpty) return const SizedBox.shrink();
        final newShops = shops.length > 5 ? shops.sublist(0, 5) : shops;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l('new_shops'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(context.l('see_all'), style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                scrollDirection: Axis.horizontal,
                itemCount: newShops.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final shop = newShops[index];
                  return GestureDetector(
                    onTap: () => context.go('/market/shop/${shop.id}'),
                          child: Column(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).cardColor,
                                  border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1), width: 1),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05),
                                      blurRadius: 15,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                  image: shop.image.isNotEmpty 
                                      ? DecorationImage(image: CachedNetworkImageProvider(shop.image), fit: BoxFit.cover)
                                      : null,
                                ),
                                child: shop.image.isEmpty 
                                    ? Icon(Icons.storefront_outlined, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)) 
                                    : null,
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: 80,
                                child: Column(
                                  children: [
                                    Text(
                                      shop.name,
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11, 
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).textTheme.bodyMedium?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  );
                },
              ),
            ),
          ],
        );
  }
}

// ── Helper: Genre filter chip ──────────────────────────────────────────
class _GenreChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;
  const _GenreChip({required this.label, required this.selected, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ], 
                  begin: Alignment.topLeft, 
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? Colors.transparent : Theme.of(context).dividerColor.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: selected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color)),
          ],
        ),
      ),
    );
  }
}

// ── Featured/Hero shop card (full-width, large) ─────────────────────────
class _FeaturedShopCard extends ConsumerWidget {
  final ShopModel shop;
  const _FeaturedShopCard({required this.shop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(inventoryCountByShopProvider(shop.id));
    return GestureDetector(
      onTap: () => context.go('/market/shop/${shop.id}'),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 30, offset: const Offset(0, 12)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            shop.image.isNotEmpty
                ? CachedNetworkImage(imageUrl: shop.image, fit: BoxFit.cover)
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withOpacity(0.8),
                          Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft, 
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withOpacity(0), 
                    Colors.black.withOpacity(Theme.of(context).brightness == Brightness.dark ? 0.9 : 0.75),
                  ],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
            ),
            // Subtle Glass Highlight (Global reflection)
            Positioned(
              top: -100, left: -50,
              child: Transform.rotate(
                angle: -0.5,
                child: Container(
                  width: 300, height: 150,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.0),
                        Colors.white.withOpacity(0.03),
                        Colors.white.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            // Featured badge
            Positioned(
              top: 20, left: 20,
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withRed(255).withGreen(100),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.4), 
                        blurRadius: 15, 
                        offset: const Offset(0, 6)
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        (context.l('featured') ?? 'Featured').toUpperCase(), 
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.w900, 
                          fontSize: 10,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  ),
            ),
            // Shop info at bottom
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: ClipRRect(
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0), Colors.black],
                      stops: const [0.0, 0.4],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context).brightness == Brightness.dark 
                                ? Colors.black.withOpacity(0.15) 
                                : Colors.white.withOpacity(0.1),
                            Theme.of(context).brightness == Brightness.dark 
                                ? Colors.black.withOpacity(0.55) 
                                : Colors.white.withOpacity(0.3),
                          ],
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.18),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Logo
                          Container(
                            width: 64, height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle, 
                              color: Colors.white,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                              image: shop.image.isNotEmpty 
                                  ? DecorationImage(image: CachedNetworkImageProvider(shop.image), fit: BoxFit.cover) 
                                  : null,
                            ),
                            child: shop.image.isEmpty 
                                ? Icon(Icons.storefront_outlined, color: Theme.of(context).colorScheme.primary, size: 28) 
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  shop.name, 
                                  style: const TextStyle(
                                    color: Colors.white, 
                                    fontSize: 22, 
                                    fontWeight: FontWeight.w900, 
                                    letterSpacing: -0.8,
                                    shadows: [
                                      Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 4),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.star_rounded, color: Colors.amber.shade400, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      shop.rating.toStringAsFixed(1),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    countAsync.when(
                                      data: (count) => Text(
                                        '$count ${context.l("products_count")}', 
                                        style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                      error: (_, __) => const SizedBox.shrink(),
                                      loading: () => const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 42, height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2), 
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                            ),
                            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class ShopDetailScreen extends ConsumerStatefulWidget {
  final String shopId;
  const ShopDetailScreen({super.key, required this.shopId});

  @override
  ConsumerState<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends ConsumerState<ShopDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final twa = ref.read(twaServiceProvider);
      if (twa.isSupported) {
        twa.showBackButton(() {
          if (mounted) Navigator.of(context).pop();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(_shopProvider(widget.shopId));
    final inventoryAsync = ref.watch(_inventoryByShopProvider(widget.shopId));
    final currentUser = ref.watch(currentUserProfileProvider).valueOrNull;
    final twa = ref.watch(twaServiceProvider);

    return shopAsync.when(
      data: (shop) {
        if (shop == null) return Scaffold(body: Center(child: Text(context.l('no_products_found'))));
        final isOwner = currentUser?.uid == shop.ownerId;
        
        // Dynamic subscription check
        final subscriptionActive = ref.watch(subscriptionActiveProvider(widget.shopId)).valueOrNull ?? false;
        final hideProducts = !subscriptionActive && !isOwner;

        if (hideProducts) {
          return Scaffold(
            appBar: AppBar(elevation: 0, backgroundColor: Colors.transparent),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.store_outlined, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
                    const SizedBox(height: 24),
                    Text(
                      context.l('shop_not_found'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: () => context.go('/market'),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(context.l('go_shopping')),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildUltimateSliverAppBar(context, shop, isOwner, ref, twa),
              if (false) // Removed lock screen UI
                SliverToBoxAdapter(child: SizedBox.shrink())
              else ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l('products'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            shop.genre.label,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (!hideProducts)
                inventoryAsync.when(
                  data: (items) {
                  if (items.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              context.l('no_products_yet') ?? 'Hali mahsulot yo\'q',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              context.l('shop_empty_desc') ?? 'Bu do\'konda hozircha sotuvda mahsulotlar mavjud emas.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (isOwner) ...[
                              const SizedBox(height: 32),
                              FilledButton.icon(
                                onPressed: () => _showAddInventorySheet(context, ref, shop),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                icon: const Icon(Icons.add_rounded),
                                label: Text(context.l('add_first_product') ?? 'MAHSULOT QO\'SHISH'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.sizeOf(context).width > 1000 ? 5 : (MediaQuery.sizeOf(context).width > 700 ? 3 : 2),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: MediaQuery.sizeOf(context).width > 1000 ? 0.8 : 0.7,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _UltimateProductCard(
                          inv: items[index],
                          isOwner: isOwner,
                        ),
                        childCount: items.length,
                      ),
                    ),
                  );
                },
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Center(child: Text('${context.l("error") ?? "Error"}: $e')),
                  ),
                ),
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(80),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          ),
          floatingActionButton: isOwner 
            ? Padding(
                padding: const EdgeInsets.only(bottom: 120),
                child: FloatingActionButton.extended(
                  onPressed: () => _showAddInventorySheet(context, ref, shop),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  icon: const Icon(Icons.add),
                  label: Text(context.l('add_inventory').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              )
            : (shop.telegram.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: FloatingActionButton.extended(
                    onPressed: () async {
                      final uri = Uri.parse('https://t.me/${shop.telegram}');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    icon: const Icon(Icons.telegram, color: Colors.white),
                    label: Text(
                      '@${shop.telegram}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                  ),
                )
              : null),
        );
      },
      error: (e, _) => Scaffold(body: Center(child: Text('${context.l("error") ?? "Error"}: $e'))),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }

  Widget _buildUltimateSliverAppBar(BuildContext context, ShopModel shop, bool isOwner, WidgetRef ref, TWAService twa) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.7),
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface, size: 20),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/catalog');
              }
            },
          ),
        ),
      ),
      actions: [
        if (isOwner)
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 16),
            child: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.7),
              child: IconButton(
                icon: Icon(Icons.edit_outlined, color: Theme.of(context).colorScheme.onSurface, size: 20),
                onPressed: () => _showEditShopSheet(context, ref, shop),
              ),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Banner Background
            if (shop.image.isNotEmpty)
              CachedNetworkImage(
                imageUrl: shop.image,
                fit: BoxFit.cover,
              )
            else
              Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
            
            // Overlays
            Container(color: Colors.black.withOpacity(0.2)),
            
            // Bottom Information
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipRRect(
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0), Colors.black],
                      stops: const [0.0, 0.4],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.1),
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                            width: 0.8,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 25,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                              image: shop.image.isNotEmpty
                                  ? DecorationImage(image: CachedNetworkImageProvider(shop.image), fit: BoxFit.cover)
                                  : null,
                            ),
                            child: shop.image.isEmpty
                                ? const Icon(Icons.storefront_outlined, color: Colors.white, size: 32)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      shop.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            shop.rating > 0 ? shop.rating.toStringAsFixed(1) : '0.0',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (shop.about.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    shop.about,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditShopSheet(BuildContext context, WidgetRef ref, ShopModel shop) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditShopSheetAtShop(shop: shop),
    );
  }

  void _showAddInventorySheet(BuildContext context, WidgetRef ref, ShopModel shop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddInventorySheet(shop: shop),
    );
  }
}

class _UltimateProductCard extends ConsumerStatefulWidget {
  final InventoryModel inv;
  final bool isOwner;
  const _UltimateProductCard({required this.inv, this.isOwner = false});

  @override
  ConsumerState<_UltimateProductCard> createState() => _UltimateProductCardState();
}

class _UltimateProductCardState extends ConsumerState<_UltimateProductCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final inv = widget.inv;
    final isOwner = widget.isOwner;
    final wishedAsync = ref.watch(isWishedProvider(inv.id));
    final wished = wishedAsync.valueOrNull ?? false;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () => context.push('/market/product/${inv.id}'),
      onHover: (hovering) => setState(() => _isHovered = hovering),
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isHovered ? 1.02 : 1.0),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _isHovered 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
              : Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_isHovered ? 0.15 : (isDark ? 0.2 : 0.04)),
              blurRadius: _isHovered ? 28 : 20,
              offset: Offset(0, _isHovered ? 12 : 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Hero(
                      tag: 'product-${inv.id}',
                      child: inv.imageUrls.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: inv.imageUrls.first,
                              fit: BoxFit.cover,
                            )
                          : Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          color: Theme.of(context).cardColor.withOpacity(0.7),
                          child: IconButton(
                            icon: Icon(
                              isOwner ? Icons.edit : (wished ? Icons.favorite : Icons.favorite_border),
                              size: 18,
                              color: isOwner ? Theme.of(context).iconTheme.color : (wished ? Colors.red : Theme.of(context).iconTheme.color?.withOpacity(0.7)),
                            ),
                            onPressed: () async {
                              if (isOwner) {
                                context.push('/seller/products/inventory/${inv.id}');
                              } else {
                                await ref.read(wishlistRepositoryProvider).toggleWishlist(
                                      productId: inv.id,
                                      shopId: inv.shopId,
                                    );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.3)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${inv.basePrice} сум',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Theme.of(context).textTheme.bodyLarge?.color),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              inv.rating > 0 ? inv.rating.toStringAsFixed(1) : '0.0',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).textTheme.bodySmall?.color),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditShopSheetAtShop extends ConsumerStatefulWidget {
  final ShopModel shop;
  const _EditShopSheetAtShop({required this.shop});

  @override
  ConsumerState<_EditShopSheetAtShop> createState() => _EditShopSheetAtShopState();
}

class _EditShopSheetAtShopState extends ConsumerState<_EditShopSheetAtShop> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _aboutCtrl;
  late final TextEditingController _tgCtrl;
  late final TextEditingController _phoneCtrl;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  bool _busy = false;
  late ShopGenre _selectedGenre;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.shop.name);
    _aboutCtrl = TextEditingController(text: widget.shop.about);
    _tgCtrl = TextEditingController(text: widget.shop.telegram);
    _phoneCtrl = TextEditingController(text: widget.shop.phone);
    _selectedGenre = widget.shop.genre;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _aboutCtrl.dispose();
    _tgCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickShopImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImage = picked;
        _pickedImageBytes = bytes;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(shopRepositoryProvider);
      String imageUrl = widget.shop.image;

      // Upload new image if picked
      if (_pickedImage != null && _pickedImageBytes != null) {
        debugPrint('Shop image upload starting... (Bytes: ${_pickedImageBytes!.length})');
        try {
          imageUrl = await repo.uploadShopImage(
            shopId: widget.shop.id,
            bytes: _pickedImageBytes!,
            fileName: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ).timeout(const Duration(seconds: 120));
          debugPrint('Shop image upload successful: $imageUrl');
        } catch (e) {
          debugPrint('Shop image upload FAILED: $e');
          rethrow;
        }
      }

      final updatedShop = ShopModel(
        id: widget.shop.id,
        name: _nameCtrl.text.trim(),
        about: _aboutCtrl.text.trim(),
        telegram: _tgCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        genre: _selectedGenre,
        ownerId: widget.shop.ownerId,
        image: imageUrl,
        rating: widget.shop.rating,
        reviewCount: widget.shop.reviewCount,
        createdAt: widget.shop.createdAt,
      );

      await repo.updateShop(updatedShop);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l('shop_updated') ?? 'Do\'kon yangilandi'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l('error') ?? 'Xato'}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        top: 32,
        left: 24,
        right: 24,
        bottom: 32 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.l('edit_shop'),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: Theme.of(context).textTheme.titleLarge?.color)),
                if (_busy) const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 24),
            // ── Profile Photo Picker ──
            Center(
              child: GestureDetector(
                onTap: _busy ? null : _pickShopImage,
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Theme.of(context).dividerColor.withOpacity(0.1),
                        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3), width: 2),
                        image: _pickedImageBytes != null
                            ? DecorationImage(image: MemoryImage(_pickedImageBytes!), fit: BoxFit.cover)
                            : (widget.shop.image.isNotEmpty
                                ? DecorationImage(image: CachedNetworkImageProvider(widget.shop.image), fit: BoxFit.cover)
                                : null),
                      ),
                      child: (_pickedImage == null && widget.shop.image.isEmpty)
                          ? Icon(Icons.storefront_outlined, color: Theme.of(context).textTheme.bodySmall?.color, size: 40)
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                        ),
                        child: Icon(Icons.camera_alt_rounded, color: Theme.of(context).colorScheme.onPrimary, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildInput(context.l('shop_name'), _nameCtrl, Icons.storefront),
            const SizedBox(height: 16),
            _buildInput(context.l('shop_about'), _aboutCtrl, Icons.info_outline, maxLines: 3),
            const SizedBox(height: 16),
            _buildInput(context.l('telegram_username'), _tgCtrl, Icons.telegram),
            const SizedBox(height: 16),
            _buildInput(context.l('phone'), _phoneCtrl, Icons.phone_outlined),
            const SizedBox(height: 24),
            Text(context.l('shop_genre') ?? 'Do\'kon turi', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ShopGenre.values.map((genre) {
                final isSelected = _selectedGenre == genre;
                return ChoiceChip(
                  label: Text(context.l(genre.name)),
                  selected: isSelected,
                  onSelected: _busy ? null : (selected) {
                    if (selected) setState(() => _selectedGenre = genre);
                  },
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  selectedColor: Colors.black,
                  backgroundColor: Theme.of(context).dividerColor.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _busy ? Theme.of(context).disabledColor : Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _busy 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(context.l('save_changes').toUpperCase() ?? 'SAVE CHANGES',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          icon: Icon(icon, color: Theme.of(context).textTheme.bodySmall?.color, size: 20),
          labelText: label,
          labelStyle: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12, fontWeight: FontWeight.w600),
          border: InputBorder.none,
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
    );
  }
}

final _shopProvider = StreamProvider.family<ShopModel?, String>((ref, shopId) {
  return ref.watch(shopRepositoryProvider).streamShop(shopId);
});

final _inventoryByShopProvider = StreamProvider.family<List<InventoryModel>, String>((ref, shopId) {
  return ref.watch(inventoryRepositoryProvider).streamInventoryByShop(shopId);
});

class _ShopCard extends ConsumerWidget {
  final ShopModel shop;
  const _ShopCard({required this.shop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(inventoryCountByShopProvider(shop.id));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/market/shop/${shop.id}'),
        child: Stack(
          children: [
            // Background Banner Blur Effect
            Positioned(
              left: 0, right: 0, top: 0, height: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: Theme.of(context).dividerColor.withOpacity(0.05),
                    child: shop.image.isNotEmpty
                        ? CachedNetworkImage(imageUrl: shop.image, fit: BoxFit.cover)
                        : null,
                  ),
                  ShaderMask(
                    shaderCallback: (rect) {
                      return LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black, Colors.black.withOpacity(0)],
                        stops: const [0.7, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Theme.of(context).cardColor.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Shop Logo
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).cardColor,
                          border: Border.all(color: Theme.of(context).cardColor, width: 3),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4)),
                          ],
                          image: shop.image.isNotEmpty
                            ? DecorationImage(image: CachedNetworkImageProvider(shop.image), fit: BoxFit.cover)
                            : null,
                        ),
                        child: shop.image.isEmpty
                          ? Icon(Icons.storefront_outlined, color: Theme.of(context).textTheme.bodySmall?.color, size: 32)
                          : null,
                      ),
                      const Spacer(),
                      _Badge(text: context.l(shop.genre.name)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Shop Name
                  Text(
                    shop.name.isEmpty ? '(Nomsiz do\'kon)' : shop.name,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5, color: tt.titleLarge?.color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Product Count & Rating
                  Row(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star_rounded, color: cs.tertiary, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            shop.rating > 0 ? shop.rating.toStringAsFixed(1) : '0.0',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: tt.bodyMedium?.color),
                          ),
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: tt.bodySmall?.color, fontSize: 13)),
                          const SizedBox(width: 8),
                        ],
                      ),
                      countAsync.when(
                        data: (count) => Text(
                          '$count ${context.l("products_count")}',
                          style: TextStyle(color: tt.bodyMedium?.color, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        error: (_, __) => const SizedBox.shrink(),
                        loading: () => const SizedBox(
                          width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (shop.about.isNotEmpty)
                    Text(
                      shop.about,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tt.bodyMedium?.color, fontSize: 13, height: 1.3),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.bodySmall?.color)),
    );
  }
}

