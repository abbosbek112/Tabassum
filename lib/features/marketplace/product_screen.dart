import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/twa_service.dart';
import '../../shared/widgets/full_screen_image_viewer.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../shared/models/inventory_model.dart';
import '../../core/localization.dart';
import '../../shared/models/variant_model.dart';
import '../marketplace/inventory_repository.dart';
import '../wishlist/wishlist_repository.dart';
import '../../shared/models/shop_model.dart';
import '../marketplace/shop_repository.dart';
import '../../shared/models/comment_model.dart';
import 'comment_repository.dart';
import '../../shared/models/notification_model.dart';
import '../notifications/notification_repository.dart';
import '../auth/auth_controller.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _inventoryStreamProvider = StreamProvider.family<InventoryModel?, String>((ref, id) {
  return ref.watch(inventoryRepositoryProvider).streamInventory(id);
});

final _variantsStreamProvider = StreamProvider.family<List<VariantModel>, String>((ref, inventoryId) {
  return ref.watch(inventoryRepositoryProvider).streamVariantsByInventory(inventoryId);
});

final _shopStreamProvider = StreamProvider.family<ShopModel?, String>((ref, shopId) {
  return ref.watch(shopRepositoryProvider).streamShop(shopId);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ProductScreen extends ConsumerWidget {
  final String productId;
  const ProductScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(_inventoryStreamProvider(productId));

    return inventoryAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(context.l('about_product'))),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(context.l('about_product'))),
        body: Center(child: Text('${context.l('error') ?? "Error"}: $e')),
      ),
      data: (inv) {
        if (inv == null) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l('about_product'))),
            body: Center(child: Text(context.l('no_products_found'))),
          );
        }
        return _InventoryBody(inventory: inv);
      },
    );
  }
}

class _InventoryBody extends ConsumerStatefulWidget {
  final InventoryModel inventory;
  const _InventoryBody({required this.inventory});

  @override
  ConsumerState<_InventoryBody> createState() => _InventoryBodyState();
}

class _InventoryBodyState extends ConsumerState<_InventoryBody> {
  VariantModel? _selectedVariant;
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) setState(() => _currentPage = page);
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final twa = ref.read(twaServiceProvider);
      if (twa.isSupported) {
        twa.showBackButton(() {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopAsync = ref.watch(_shopStreamProvider(widget.inventory.shopId));
    final variantsAsync = ref.watch(_variantsStreamProvider(widget.inventory.id));
    final wishedAsync = ref.watch(isWishedProvider(widget.inventory.id));
    final wished = wishedAsync.valueOrNull ?? false;
    final telegram = shopAsync.value?.telegram ?? '';
    final price = _selectedVariant?.priceOverride ?? widget.inventory.basePrice;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth > 900;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            Row(
              children: [
                // Left: Images
                Expanded(
                  flex: 3,
                  child: Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 800),
                        child: _buildHeroImage(),
                      ),
                    ),
                  ),
                ),
                // Right: Details
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(wished),
                        const SizedBox(height: 32),
                        if (widget.inventory.about.isNotEmpty) ...[
                          Text(context.l('about_product').toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary.withOpacity(0.7), letterSpacing: 1)),
                          const SizedBox(height: 12),
                          Text(widget.inventory.about, style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface, height: 1.6)),
                          const SizedBox(height: 40),
                        ],
                        _buildVariantSelector(variantsAsync),
                        const SizedBox(height: 40),
                        _buildDesktopPriceAction(price, telegram),
                        const SizedBox(height: 48),
                        _ReviewsSection(inventory: widget.inventory),
                        const SizedBox(height: 40),
                        if (telegram.isNotEmpty) _buildContactSection(telegram),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _buildAppBar(context, ref.watch(twaServiceProvider)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeroImage(),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    MediaQuery.sizeOf(context).width < 380 ? 16 : 24, 
                    24, 
                    MediaQuery.sizeOf(context).width < 380 ? 16 : 24, 
                    140
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(wished),
                      const SizedBox(height: 24),
                      if (widget.inventory.about.isNotEmpty) ...[
                        Text(context.l('about_product').toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary.withOpacity(0.7), letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Text(widget.inventory.about, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface, height: 1.5)),
                        const SizedBox(height: 32),
                      ],
                      _buildVariantSelector(variantsAsync),
                      const SizedBox(height: 32),
                      _ReviewsSection(inventory: widget.inventory),
                      const SizedBox(height: 32),
                      if (telegram.isNotEmpty) _buildContactSection(telegram),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildAppBar(context, ref.watch(twaServiceProvider)),
          _buildBottomAction(),
        ],
      ),
    );
  }

  Widget _buildDesktopPriceAction(num price, String telegram) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l('payment') ?? 'Price', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text('$price sum', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
          const Spacer(),
          if (telegram.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () async {
                String handle = telegram.replaceAll('https://t.me/', '').replaceAll('t.me/', '').replaceAll('@', '');
                final botUsername = 'tabassum_market_bot';
                final appLink = 'https://t.me/$botUsername/app?startapp=product_${widget.inventory.id}';
                final message = Uri.encodeComponent('Assalomu alaykum! Men Tabassum ilovasida ko\'rgan mana bu mahsulotingizga qiziqib qoldim: ${widget.inventory.name}\n\nHavola: $appLink');
                final uri = Uri.parse('https://t.me/$handle?text=$message');
                if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.telegram),
              label: Text(context.l('contact_tg') ?? 'CONTACT'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    final images = widget.inventory.imageUrls;
    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 0.9,
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(Icons.image_outlined, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
        ),
      );
    }

    return SizedBox(
      height: MediaQuery.of(context).size.width / 0.9,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => FullScreenImageViewer(
                        imageUrls: images,
                        initialIndex: index,
                        heroTagPrefix: 'product-image-${widget.inventory.id}',
                      ),
                    ),
                  );
                },
                child: Hero(
                  tag: 'product-image-${widget.inventory.id}-$index',
                  child: CachedNetworkImage(
                    imageUrl: images[index],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_outlined, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
                          const SizedBox(height: 8),
                          Text(context.l('error_loading_image') ?? 'Rasm yuklanmadi', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (images.length > 1)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: _CarouselIndicators(
                count: images.length,
                current: _currentPage,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, TWAService twa) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        height: 110, // Increased height for TWA
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withOpacity(0.4), Colors.transparent],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (!twa.isSupported)
                  _CircleNavButton(
                    icon: Icons.chevron_left,
                    onTap: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/market');
                      }
                    },
                  ),
                const Spacer(),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _CircleNavButton(
                    icon: Icons.share_outlined,
                    onTap: () async {
                    final botUsername = 'tabassum_market_bot';
                    final telegramUrl = 'https://t.me/$botUsername?startapp=product_${widget.inventory.id}';
                    final text = Uri.encodeComponent('Men ajoyib mahsulot topdim! 😎\nKo\'rib chiqing:');
                    
                    final shareUrl = Uri.parse('https://t.me/share/url?url=$telegramUrl&text=$text');
                    
                    try {
                      if (await canLaunchUrl(shareUrl)) {
                        await launchUrl(shareUrl, mode: LaunchMode.externalApplication);
                      } else {
                        Clipboard.setData(ClipboardData(text: telegramUrl));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Havola nusxalandi!'), behavior: SnackBarBehavior.floating),
                          );
                        }
                      }
                    } catch (e) {
                      Clipboard.setData(ClipboardData(text: telegramUrl));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Havola nusxalandi!'), behavior: SnackBarBehavior.floating),
                        );
                      }
                    }
                  },
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool wished) {
    final shopAsync = ref.watch(_shopStreamProvider(widget.inventory.shopId));
    final shop = shopAsync.valueOrNull;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.inventory.category.toUpperCase(),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary, letterSpacing: 1),
              ),
              const SizedBox(height: 4),
              Text(
                widget.inventory.name,
                style: TextStyle(
                  fontSize: MediaQuery.sizeOf(context).width < 380 ? 22 : 26, 
                  fontWeight: FontWeight.w800, 
                  letterSpacing: -1.0
                ),
              ),
              if (shop != null) ...[ 
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => context.go('/market/shop/${widget.inventory.shopId}'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_outlined, size: 13, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                shop.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              ),
                            ),
                            Row(
                              children: [
                                const SizedBox(width: 8),
                                Container(
                                  width: 1,
                                  height: 10,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.2),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                const SizedBox(width: 2),
                                Text(
                                  shop.rating > 0 ? shop.rating.toStringAsFixed(1) : '0.0',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.chevron_right, size: 13, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          onPressed: () => ref.read(wishlistRepositoryProvider).toggleWishlist(productId: widget.inventory.id, shopId: widget.inventory.shopId),
          icon: Icon(wished ? Icons.favorite : Icons.favorite_border, color: wished ? Colors.red : Theme.of(context).colorScheme.onSurface, size: 28),
        ),
      ],
    );
  }

  Widget _buildVariantSelector(AsyncValue<List<VariantModel>> variantsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l('select_size').toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1)),
        const SizedBox(height: 12),
        variantsAsync.when(
          data: (variants) {
            if (variants.isEmpty) return Text(context.l('no_variants_available') ?? 'No variants available.', style: const TextStyle(color: Colors.red));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: variants.map((v) {
                      final isSelected = _selectedVariant?.id == v.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedVariant = v),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline.withOpacity(0.5), 
                              width: 1.5
                            ),
                            boxShadow: isSelected ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))] : [],
                          ),
                          child: Column(
                            children: [
                              Text(v.size, style: TextStyle(fontWeight: FontWeight.w800, color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface, fontSize: 16)),
                              Text(v.color, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isSelected ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7) : Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (_selectedVariant != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Text('${_selectedVariant!.stock} ${context.l("stock_count")}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
          error: (e, _) {
            final errorStr = e.toString();
            final isIndexError = errorStr.contains('FAILED_PRECONDITION') || errorStr.contains('index');
            
            return Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        context.l('error_loading_variants') ?? 'Variantlarni yuklashda xato',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.error, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isIndexError 
                      ? (context.l('firebase_index_required') ?? 'Firebase-da indeks yaratish kerak:') 
                      : errorStr,
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                  if (isIndexError) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48).withOpacity(0.1),
                        foregroundColor: const Color(0xFFE11D48),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final regex = RegExp(r'https://console\.firebase\.google\.com[^\s]+');
                        final match = regex.firstMatch(errorStr);
                        if (match != null) {
                          final uri = Uri.parse(match.group(0)!);
                          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Text(context.l('create_index') ?? 'Indeks yaratish', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            );
          },
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(12.0),
            child: LinearProgressIndicator(),
          )),
        ),
      ],
    );
  }

  Widget _buildContactSection(String telegram) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l('contact_tg').toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
          ),
          child: ListTile(
            leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primary, child: const Icon(Icons.telegram, color: Colors.white, size: 20)),
            title: Text(
              telegram.startsWith('http') ? telegram.split('/').last : '@$telegram', 
              style: const TextStyle(fontWeight: FontWeight.w700)
            ),
            subtitle: Text(context.l('contact_tg') ?? 'Contact', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
            onTap: () async {
              String handle = telegram.replaceAll('https://t.me/', '').replaceAll('t.me/', '').replaceAll('@', '');
              final botUsername = 'tabassum_market_bot';
              final appLink = 'https://t.me/$botUsername/app?startapp=product_${widget.inventory.id}';
              final message = Uri.encodeComponent('Assalomu alaykum! Men Tabassum ilovasida ko\'rgan mana bu mahsulotingizga qiziqib qoldim: ${widget.inventory.name}\n\nHavola: $appLink');
              final uri = Uri.parse('https://t.me/$handle?text=$message');
              
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction() {
    final price = _selectedVariant?.priceOverride ?? widget.inventory.basePrice;
    final shopAsync = ref.watch(_shopStreamProvider(widget.inventory.shopId));
    final telegram = shopAsync.value?.telegram ?? '';

    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          24, 20, 24, 
          MediaQuery.viewPaddingOf(context).bottom + 12
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.light ? 0.05 : 0.2), blurRadius: 20, offset: const Offset(0, -5))],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outline.withOpacity(0.1))),
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l('payment') ?? 'Payment', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1)),
                Text(
                  '$price sum', 
                  style: TextStyle(
                    fontSize: MediaQuery.sizeOf(context).width < 340 ? 16 : 20, 
                    fontWeight: FontWeight.w900
                  )
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleNavButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.light ? 0.1 : 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 22),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: EdgeInsets.zero,
        splashRadius: 24,
      ),
    );
  }
}

class _CarouselIndicators extends StatelessWidget {
  final int count;
  final int current;
  const _CarouselIndicators({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: active ? 20 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: active ? Colors.white : Colors.white.withOpacity(0.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Reviews Section
// ---------------------------------------------------------------------------

class _ReviewsSection extends ConsumerWidget {
  final InventoryModel inventory;
  const _ReviewsSection({required this.inventory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(productCommentsProvider(inventory.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(context.l('reviews').toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1))),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => _showAddReviewSheet(context),
              child: Text(context.l('write_review') ?? 'Write a Review', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        commentsAsync.when(
          data: (comments) {
            if (comments.isEmpty) {
              return Text(context.l('no_reviews_yet') ?? 'No reviews yet. Be the first to review!', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13));
            }

            final avgRating = comments.fold(0.0, (sum, item) => sum + item.rating) / comments.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(avgRating.toStringAsFixed(1), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1)),
                    const SizedBox(width: 4),
                    const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 28),
                    const SizedBox(width: 8),
                    Text('(${comments.length} ${context.l("reviews")})', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 16),
                ...comments.take(3).map((c) => Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Text(
                                  c.userName.isNotEmpty ? c.userName[0].toUpperCase() : 'A',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(c.userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                              Row(
                                children: List.generate(5, (index) => Icon(
                                  Icons.star_rounded,
                                  size: 14,
                                  color: index < c.rating ? const Color(0xFFFBBF24) : Theme.of(context).colorScheme.surfaceContainerHighest,
                                )),
                              ),
                            ],
                          ),
                          if (c.comment.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(c.comment, style: TextStyle(fontSize: 13, height: 1.4, color: Theme.of(context).colorScheme.onSurface)),
                          ],
                        ],
                      ),
                    )),
                if (comments.length > 3) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _showAllCommentsSheet(context, comments.cast<CommentModel>().toList()),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    ),
                    child: Center(
                      child: Text(
                        'Barcha ${comments.length} ta sharhni ko\'rish',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
          error: (e, _) {
            final errorStr = e.toString();
            final isIndexError = errorStr.contains('FAILED_PRECONDITION') || errorStr.contains('index');
            
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFE11D48), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isIndexError ? (context.l('firebase_index_required') ?? 'Firebase Index Talab Qilinadi') : (context.l('error_occurred') ?? 'Xatolik yuz berdi'),
                        style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFE11D48)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isIndexError 
                      ? (context.l('firebase_index_required') ?? 'Reviewlarni ko\'rish uchun Firebase-da indeks yaratish kerak. Pastdagi havolani bosing:') 
                      : errorStr,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF9F1239)),
                  ),
                  if (isIndexError) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFE11D48).withOpacity(0.1),
                        foregroundColor: const Color(0xFFE11D48),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final regex = RegExp(r'https://console\.firebase\.google\.com[^\s]+');
                        final match = regex.firstMatch(errorStr);
                        if (match != null) {
                          final uri = Uri.parse(match.group(0)!);
                          if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      child: Text(context.l('create_index') ?? 'Indeks yaratish', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      ref.invalidate(productCommentsProvider(inventory.id));
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: Text(context.l('retry') ?? 'Qayta urinish', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(),
          )),
        ),
      ],
    );
  }

  void _showAllCommentsSheet(BuildContext context, List<CommentModel> comments) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 5, decoration: BoxDecoration(color: Theme.of(ctx).colorScheme.onSurfaceVariant.withOpacity(0.3), borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 20),
            Text('Barcha sharhlar (${comments.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(24),
                itemCount: comments.length,
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (ctx, i) {
                  final c = comments[i];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Theme.of(context).colorScheme.surface,
                              child: Text(
                                c.userName.isNotEmpty ? c.userName[0].toUpperCase() : 'A',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(c.userName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                            Row(
                              children: List.generate(5, (index) => Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: index < c.rating ? const Color(0xFFFBBF24) : Theme.of(context).colorScheme.surfaceContainerHighest,
                              )),
                            ),
                          ],
                        ),
                        if (c.comment.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(c.comment, style: TextStyle(fontSize: 13, height: 1.5, color: Theme.of(context).colorScheme.onSurface)),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddReviewSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddReviewSheet(inventory: inventory),
    );
  }
}

class _AddReviewSheet extends ConsumerStatefulWidget {
  final InventoryModel inventory;
  const _AddReviewSheet({required this.inventory});

  @override
  ConsumerState<_AddReviewSheet> createState() => _AddReviewSheetState();
}

class _AddReviewSheetState extends ConsumerState<_AddReviewSheet> {
  final _commentCtrl = TextEditingController();
  int _rating = 5;
  bool _busy = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final navBarHeight = 140.0;
    final bottomPadding = bottomInset > 0 ? bottomInset + 24 : navBarHeight;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l('add_review') ?? 'Add Review', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest, 
                  radius: 14, 
                  child: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(context.l('tap_to_rate') ?? 'Tap to rate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => setState(() => _rating = index + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.star_rounded,
                    size: 40,
                    color: index < _rating 
                      ? const Color(0xFFFBBF24) 
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5), 
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _commentCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: context.l('share_experience') ?? 'Share your experience with this product...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5)),
              ),
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submitReview,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                _busy ? '${context.l("submitting") ?? "SUBMITTING"}...' : (context.l('submit_review') ?? 'SUBMIT REVIEW'), 
                style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitReview() async {
    setState(() => _busy = true);
    try {
      final user = ref.read(currentUserProfileProvider).valueOrNull;
      final userId = user?.uid ?? 'anonymous';
      final userName = (user != null && user.email.isNotEmpty) ? user.email.split('@').first : 'User';

      final comment = CommentModel(
        id: '',
        productId: widget.inventory.id,
        shopId: widget.inventory.shopId,
        userId: userId,
        userName: userName,
        rating: _rating.toDouble(),
        comment: _commentCtrl.text.trim(),
        createdAt: DateTime.now(),
      );

      await ref.read(commentRepositoryProvider).addComment(comment);

      // Aggregating ratings for the product
      final productComments = await ref.read(commentRepositoryProvider).streamCommentsByProduct(widget.inventory.id).first;
      final productAvgRating = productComments.isEmpty ? 0.0 : productComments.map((e) => e.rating).reduce((a, b) => a + b) / productComments.length;
      
      final updatedInv = widget.inventory.toMap();
      updatedInv['rating'] = productAvgRating;
      updatedInv['reviewCount'] = productComments.length;
      
      await ref.read(inventoryRepositoryProvider).updateInventory(
        InventoryModel.fromMap(widget.inventory.id, updatedInv)
      );

      // Aggregating ratings for the shop
      final shopId = widget.inventory.shopId;
      final shopComments = await ref.read(commentRepositoryProvider).streamCommentsByShop(shopId).first;
      final shopAvgRating = shopComments.isEmpty ? 0.0 : shopComments.map((e) => e.rating).reduce((a, b) => a + b) / shopComments.length;
      
      final shop = await ref.read(shopRepositoryProvider).streamShop(shopId).first;
      if (shop != null) {
        final updatedShop = shop.toMap();
        updatedShop['rating'] = shopAvgRating;
        updatedShop['reviewCount'] = shopComments.length;
        await ref.read(shopRepositoryProvider).updateShop(ShopModel.fromMap(shopId, updatedShop));
      }

      final notification = NotificationModel(
        id: '',
        shopId: widget.inventory.shopId,
        title: 'New Review on ${widget.inventory.name}',
        body: '$userName left a $_rating-star review.',
        isRead: false,
        createdAt: DateTime.now(),
      );
      await ref.read(notificationRepositoryProvider).addNotification(notification);

      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.l("error") ?? "Error"}: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}


