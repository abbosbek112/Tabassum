import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/localization.dart';
import '../../shared/models/inventory_model.dart';
import 'inventory_repository.dart';
import 'category_repository.dart';
import 'inventory_providers.dart';

enum CategorySort { popular, newest, priceLowHigh, priceHighLow, topRated }

final categoryProductsProvider = StreamProvider.family<List<InventoryModel>, String>((ref, categoryId) {
  return ref.watch(inventoryRepositoryProvider).streamInventoryByCategoryId(categoryId);
});

class CategoryProductsScreen extends ConsumerStatefulWidget {
  final String categoryId;
  const CategoryProductsScreen({super.key, required this.categoryId});

  @override
  ConsumerState<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends ConsumerState<CategoryProductsScreen> {
  final ScrollController _scrollController = ScrollController();
  CategorySort _sort = CategorySort.popular;
  double? _minPrice;
  double? _maxPrice;
  String? _selectedBrand;
  double? _minRating;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedInventoryProvider(widget.categoryId).notifier).loadNextBatch();
    }
  }

  @override
  Widget build(BuildContext context) {
    final catAsync = ref.watch(categoryProvider(widget.categoryId));
    final paginatedState = ref.watch(paginatedInventoryProvider(widget.categoryId));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: catAsync.when(
          data: (c) => Text(
            c != null ? (context.l(c.name) ?? c.name) : '...',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: Theme.of(context).colorScheme.onSurface),
          ),
          loading: () => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          error: (e, _) => const Text('Error'),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {}, // Optional search within this category
          )
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(context),
          Expanded(
            child: Builder(
              builder: (context) {
                final items = paginatedState.items;
                var filtered = _applyFiltersAndSort(items);

                if (filtered.isEmpty && !paginatedState.isLoading) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
                         const SizedBox(height: 16),
                         Text(
                           context.l('no_products_found') ?? 'Mahsulotlar topilmadi',
                           style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
                         )
                      ],
                    ),
                  );
                }

                return ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.sizeOf(context).width > 1000 ? 5 : (MediaQuery.sizeOf(context).width > 700 ? 3 : 2),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: MediaQuery.sizeOf(context).width > 1000 ? 0.75 : 0.65,
                      ),
                      itemBuilder: (context, index) {
                        return _CategoryProductCard(item: filtered[index]);
                      },
                    ),
                    if (paginatedState.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (!paginatedState.hasMore && filtered.isNotEmpty)
                         Padding(
                           padding: const EdgeInsets.symmetric(vertical: 32),
                           child: Center(
                             child: Text(
                               context.l('end_of_list') ?? 'Ro\'yxat tugadi',
                               style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                             ),
                           ),
                         ),
                  ],
                );
              },
            ),
          )
        ],
      ),
    );
  }

  List<InventoryModel> _applyFiltersAndSort(List<InventoryModel> items) {
    var filtered = List<InventoryModel>.from(items);

    if (_minPrice != null) filtered = filtered.where((i) => i.basePrice >= _minPrice!).toList();
    if (_maxPrice != null) filtered = filtered.where((i) => i.basePrice <= _maxPrice!).toList();
    if (_selectedBrand != null && _selectedBrand!.isNotEmpty) {
      filtered = filtered.where((i) => i.brand.toLowerCase() == _selectedBrand!.toLowerCase()).toList();
    }
    if (_minRating != null) {
      filtered = filtered.where((i) => i.rating >= _minRating!).toList();
    }

    switch (_sort) {
      case CategorySort.newest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case CategorySort.priceLowHigh:
        filtered.sort((a, b) => a.basePrice.compareTo(b.basePrice));
        break;
      case CategorySort.priceHighLow:
        filtered.sort((a, b) => b.basePrice.compareTo(a.basePrice));
        break;
      case CategorySort.topRated:
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case CategorySort.popular:
        // Mock popular sorting by review count or default to newest if 0
        filtered.sort((a, b) {
           final cmp = b.reviewCount.compareTo(a.reviewCount);
           if (cmp != 0) return cmp;
           return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }
    return filtered;
  }

  Widget _buildFilterBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _showSortSheet,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sort_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(context.l('sort') ?? 'Saralash', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
            ),
          ),
          Container(height: 24, width: 1, color: Colors.black.withOpacity(0.1)),
          Expanded(
            child: InkWell(
              onTap: _showFilterSheet,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tune_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(context.l('filter') ?? 'Filtrlar', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               const SizedBox(height: 16),
               Text(context.l('sort_by') ?? 'Shu bo\'yicha saralash', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
               const SizedBox(height: 16),
               ...CategorySort.values.map((s) => ListTile(
                 title: Text(_getSortName(s)),
                 trailing: _sort == s ? Icon(Icons.check_circle_rounded, color: Theme.of(context).colorScheme.primary) : null,
                 onTap: () {
                   Navigator.of(context, rootNavigator: true).pop();
                   if (mounted) {
                     setState(() => _sort = s);
                   }
                 },
               )),
            ],
          ),
        );
      }
    );
  }

  String _getSortName(CategorySort s) {
    switch (s) {
      case CategorySort.popular: return context.l('sort_popular') ?? 'Ommabop';
      case CategorySort.newest: return context.l('sort_newest') ?? 'Eng yangilari';
      case CategorySort.priceLowHigh: return context.l('sort_price_asc') ?? 'Arzonlari oldin';
      case CategorySort.priceHighLow: return context.l('sort_price_desc') ?? 'Qimmatlari oldin';
      case CategorySort.topRated: return context.l('sort_rating') ?? 'Baho yuqori';
    }
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
         String tempBrand = _selectedBrand ?? '';
         return StatefulBuilder(
           builder: (context, setModalState) {
             return Padding(
               padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text(context.l('filters') ?? 'Filtrlar', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                       TextButton(
                         onPressed: () {
                           Navigator.of(context, rootNavigator: true).pop();
                           if (mounted) {
                             setState(() {
                               _minPrice = null;
                               _maxPrice = null;
                               _selectedBrand = null;
                               _minRating = null;
                             });
                           }
                         },
                         child: Text(context.l('reset') ?? 'Tozlash', style: const TextStyle(color: Colors.red)),
                       )
                     ],
                   ),
                   const SizedBox(height: 16),
                   TextField(
                     decoration: const InputDecoration(labelText: 'Brend (Brand)'),
                     controller: TextEditingController(text: tempBrand)..selection = TextSelection.collapsed(offset: tempBrand.length),
                     onChanged: (v) => tempBrand = v,
                   ),
                   const SizedBox(height: 16),
                   // Rating
                   Text('Rating: ${_minRating ?? 0}+', style: const TextStyle(fontWeight: FontWeight.w600)),
                   Slider(
                     value: _minRating ?? 0,
                     min: 0,
                     max: 5,
                     divisions: 5,
                     label: (_minRating ?? 0).toString(),
                     onChanged: (v) => setModalState(() => _minRating = v == 0 ? null : v),
                   ),
                   const SizedBox(height: 24),
                   FilledButton(
                     onPressed: () {
                       Navigator.of(context, rootNavigator: true).pop();
                       if (mounted) {
                         setState(() {
                           _selectedBrand = tempBrand.isEmpty ? null : tempBrand;
                         });
                       }
                     },
                     child: const Text('Qo\'llash (Apply)'),
                   ),
                   const SizedBox(height: 24),
                 ],
               ),
             );
           }
         );
      }
    );
  }
}

class _CategoryProductCard extends StatelessWidget {
  final InventoryModel item;

  const _CategoryProductCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/market/product/${item.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.light ? 0.03 : 0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: item.imageUrls.isNotEmpty 
                    ? CachedNetworkImage(imageUrl: item.imageUrls.first, fit: BoxFit.cover)
                    : Container(color: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.image_outlined, color: Colors.grey)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.brand.isNotEmpty) ...[
                    Text((context.l(item.brand) ?? item.brand).toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                  ] else ...[
                    Text((context.l(item.category) ?? item.category).toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                  ],
                  Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('${item.basePrice} sum', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            item.rating > 0 ? item.rating.toStringAsFixed(1) : '0.0',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
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
