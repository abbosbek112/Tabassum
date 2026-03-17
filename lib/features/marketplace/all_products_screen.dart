import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/localization.dart';
import '../../shared/models/inventory_model.dart';
import 'inventory_repository.dart';
import 'shop_repository.dart';
import 'category_repository.dart';
import 'inventory_providers.dart';
import '../../core/utils.dart';

final allInventoryProvider = StreamProvider<List<InventoryModel>>((ref) {
  return ref.watch(inventoryRepositoryProvider).streamAllInventory();
});

enum ProductSort { newest, priceLowHigh, priceHighLow }

class AllProductsScreen extends ConsumerStatefulWidget {
  const AllProductsScreen({super.key});

  @override
  ConsumerState<AllProductsScreen> createState() => _AllProductsScreenState();
}

class _AllProductsScreenState extends ConsumerState<AllProductsScreen> {
  final ScrollController _scrollController = ScrollController();
  final _debouncer = Debouncer(milliseconds: 500);
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedGender;
  ProductSort _sort = ProductSort.newest;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedInventoryProvider(_selectedCategory).notifier).loadNextBatch();
    }
  }


  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(allInventoryProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l('products'),
            style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.0)),
        actions: [
          IconButton(
            onPressed: () => context.push('/market/wishlist'),
            icon: Icon(Icons.favorite_border_rounded, color: Theme.of(context).colorScheme.error),
          ),
          IconButton(
            onPressed: () => _showSortSheet(context),
            icon: const Icon(Icons.sort_rounded),
          ),
          IconButton(
            onPressed: () => _showFilterSheet(context),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: context.l('search'),
                prefixIcon: Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              onChanged: (val) {
                _debouncer.run(() {
                   if (mounted) setState(() => _searchQuery = val.trim().toLowerCase());
                });
              },
            ),
          ),

          // Categories Scroll - Real-time & Dynamic
          SizedBox(
            height: 44,
            child: categoriesAsync.when(
              data: (categories) {
                final displayCats = ['all', ...categories.map((c) => c.name)];
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: displayCats.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = displayCats[index];
                    final isSelected = (_selectedCategory == cat) ||
                        (_selectedCategory == null && cat == 'all');

                    return InkWell(
                      onTap: () {
                        setState(() => _selectedCategory = cat == 'all' ? null : cat);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary 
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected 
                                ? Colors.transparent 
                                : Theme.of(context).dividerColor.withOpacity(0.5),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          context.l(cat) ?? cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              error: (_, __) => const SizedBox(),
              loading: () => const Center(child: LinearProgressIndicator(minHeight: 1)),
            ),
          ),

          const SizedBox(height: 16),

          // Products Grid
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final state = ref.watch(paginatedInventoryProvider(_selectedCategory));
                final items = state.items;

                var filtered = items
                    .where((i) => i.subscriptionActive) // obunasiz seller ko'rinmaydi
                    .where((i) => i.name.toLowerCase().contains(_searchQuery))
                    .toList();

                if (_selectedGender != null) {
                   filtered = filtered
                      .where((i) =>
                          i.gender.toLowerCase() == _selectedGender!.toLowerCase() || i.gender.toLowerCase() == 'both')
                      .toList();
                }

                // Sorting (Local for now to avoid indexing complexity)
                switch (_sort) {
                  case ProductSort.newest:
                    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    break;
                  case ProductSort.priceLowHigh:
                    filtered.sort((a, b) => a.basePrice.compareTo(b.basePrice));
                    break;
                  case ProductSort.priceHighLow:
                    filtered.sort((a, b) => b.basePrice.compareTo(a.basePrice));
                    break;
                }

                if (filtered.isEmpty && !state.isLoading) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 64, color: Theme.of(context).dividerColor),
                        const SizedBox(height: 16),
                        Text(context.l('no_products_found'),
                            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }

                return ListView(
                   controller: _scrollController,
                   padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                   children: [
                     GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: MediaQuery.sizeOf(context).width < 380 ? 0.62 : 0.68,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          return _ProductCard(item: filtered[index]);
                        },
                      ),
                      if (state.isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (!state.hasMore && filtered.isNotEmpty)
                         Padding(
                           padding: const EdgeInsets.symmetric(vertical: 32),
                           child: Center(
                             child: Text(
                               context.l('end_of_list') ?? 'Ro\'yxat tugadi',
                               style: TextStyle(color: Theme.of(context).dividerColor, fontWeight: FontWeight.w600),
                             ),
                           ),
                         ),
                   ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(width: 36, height: 5, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(100))),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(context.l('sort'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          _buildSortOption(context, ProductSort.newest, context.l('newest_first'), Icons.new_releases_outlined),
          _buildSortOption(context, ProductSort.priceLowHigh, context.l('price_low_to_high'), Icons.arrow_downward_rounded),
          _buildSortOption(context, ProductSort.priceHighLow, context.l('price_high_to_low'), Icons.arrow_upward_rounded),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSortOption(BuildContext context, ProductSort s, String label, IconData icon) {
    final isSelected = _sort == s;
    return ListTile(
      onTap: () {
        Navigator.of(context, rootNavigator: true).pop();
        if (mounted) setState(() => _sort = s);
      },
      leading: Icon(icon, color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: Theme.of(context).colorScheme.onSurface)),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.black) : null,
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.l('filter'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  TextButton(
                    onPressed: () {
                      setState(() { _selectedGender = null; });
                      setModalState(() {});
                    },
                    child: Text(context.l('reset')),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(context.l('filter').toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 0.5)),
              const SizedBox(height: 12),
              Row(
                children: [
                  _filterChip(context, 'both', context.l('both_genders'), _selectedGender == null, (val) {
                    setState(() { _selectedGender = null; });
                    setModalState(() {});
                  }),
                  const SizedBox(width: 8),
                  _filterChip(context, 'male', context.l('male_gender'), _selectedGender == 'male', (val) {
                    setState(() { _selectedGender = 'male'; });
                    setModalState(() {});
                  }),
                  const SizedBox(width: 8),
                  _filterChip(context, 'female', context.l('female_gender'), _selectedGender == 'female', (val) {
                    setState(() { _selectedGender = 'female'; });
                    setModalState(() {});
                  }),
                ],
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(context.l('apply').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(BuildContext context, String value, String label, bool isSelected, Function(String) onTap) {
    return Expanded(
      child: InkWell(
        onTap: () => onTap(value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: isSelected ? null : Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  final InventoryModel item;
  const _ProductCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopAsync = ref.watch(shopByIdProvider(item.shopId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;
    final surfacePlaceholder = isDark
        ? const Color(0xFF252930)
        : const Color(0xFFF1F5F9);

    return GestureDetector(
      onTap: () => context.push('/market/product/${item.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.4),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            if (item.imageUrls.isNotEmpty)
              CachedNetworkImage(
                imageUrl: item.imageUrls.first,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: surfacePlaceholder,
                  child: Center(
                    child: Icon(
                      Icons.image_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                      size: 40,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: surfacePlaceholder,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: isDark ? const Color(0xFF4B5563) : const Color(0xFF94A3B8),
                    size: 40,
                  ),
                ),
              )
            else
              Container(
                color: surfacePlaceholder,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.image_outlined,
                      color: isDark ? const Color(0xFF4B5563) : const Color(0xFF94A3B8),
                      size: 48,
                    ),
                  ],
                ),
              ),

            // Gradient Overlay for text readability
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 110,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Floating Price Tag (Top Right)
            if (item.basePrice > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                  child: Text(
                    '${item.basePrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]} ')} sum',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),

            // Bottom Info (Title & Shop)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: shopAsync.when(
                          data: (shop) => Text(
                            shop?.name ?? context.l('unknown_shop') ?? 'Unknown Shop',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          error: (_, __) => const SizedBox(),
                          loading: () => const SizedBox(),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFBBF24), size: 13),
                          const SizedBox(width: 3),
                          Text(
                            item.rating > 0 ? item.rating.toStringAsFixed(1) : '0.0',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: Colors.white,
                            ),
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
