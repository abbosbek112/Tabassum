import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../core/localization.dart';
import '../../core/shared_providers.dart';
import '../../shared/models/inventory_model.dart';
import '../../shared/models/shop_model.dart';
import '../../shared/models/variant_model.dart';
import '../marketplace/inventory_repository.dart';
import '../marketplace/category_repository.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return Center(child: Text(context.l('not_logged_in') ?? 'Please sign in.'));

    final shopsAsync = ref.watch(myShopsProvider(uid));
    return shopsAsync.when(
      data: (shops) {
        if (shops.isEmpty) return Center(child: Text(context.l('create_shop') ?? 'Create a shop first.'));
        final shop = shops.first;
        final isActiveAsync = ref.watch(subscriptionActiveProvider(shop.id));

        return isActiveAsync.when(
          data: (active) => _ProductsBody(shop: shop, subscriptionActive: active),
          error: (e, _) => Center(child: Text('${context.l("error") ?? "Error"}: $e')),
          loading: () => const Center(child: CircularProgressIndicator()),
        );
      },
      error: (e, _) => Center(child: Text('${context.l("error") ?? "Error"}: $e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ProductsBody extends ConsumerWidget {
  final ShopModel shop;
  final bool subscriptionActive;

  const _ProductsBody({required this.shop, required this.subscriptionActive});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryByShopProvider(shop.id));

    return Scaffold(
      backgroundColor: const Color(0xFFFCFCFD),
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(context.l('inventory') ?? 'Inventory', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.0)),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 110),
        child: FloatingActionButton.extended(
          onPressed: subscriptionActive
              ? () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useRootNavigator: true,
                    builder: (_) => AddInventorySheet(shop: shop),
                  )
              : null,
          label: Text(subscriptionActive ? (context.l('add_inventory') ?? 'Add inventory') : (context.l('subscription_required') ?? 'Subscription required')),
          icon: const Icon(Icons.add),
        ),
      ),
      body: Column(
        children: [
          if (!subscriptionActive)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFFF4D4D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4D4D).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_off_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Mahsulotlaringiz ko\'rinmaydi',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Xaridorlarga ko\'rinishi uchun obuna oling',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/seller/subscription'),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Obuna', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: inventoryAsync.when(
              data: (inventoryItems) {
                if (inventoryItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inbox_outlined, size: 48, color: Color(0xFFC7C7CC)),
                        const SizedBox(height: 16),
                        Text(
                          context.l('no_products_found') ?? 'No inventory added yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: const Color(0xFF8E8E93),
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 140),
                  itemCount: inventoryItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, idx) {
                    final inv = inventoryItems[idx];
                    return _InventoryCard(inv: inv);
                  },
                );
              },
              error: (e, _) => Center(child: Text('${context.l("error") ?? "Error"}: $e')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryCard extends ConsumerWidget {
  final InventoryModel inv;
  const _InventoryCard({required this.inv});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variantsAsync = ref.watch(variantsByInventoryProvider(inv.id));
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: InkWell(
            onTap: () => context.push('/seller/products/inventory/${inv.id}'),
            child: Padding(
              padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 380 ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _InventoryImage(imageUrls: inv.imageUrls),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              inv.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.7,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F2F7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Consumer(builder: (context, ref, _) {
                                final shopAsync = ref.watch(singleShopProvider(inv.shopId));
                                return shopAsync.when(
                                  data: (shop) {
                                    final isClothes = shop?.genre == ShopGenre.clothes;
                                    return Text(
                                      '${inv.category}${isClothes ? " • ${context.l(inv.gender.toLowerCase())}" : ""}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                      ),
                                    );
                                  },
                                  loading: () => Text(inv.category, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11, fontWeight: FontWeight.w600)),
                                  error: (_, __) => Text(inv.category, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11, fontWeight: FontWeight.w600)),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${inv.basePrice}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                            ),
                          ),
                          const Text(
                            'sum',
                            style: TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: Color(0xFFF2F2F7)),
                  const SizedBox(height: 16),
                  variantsAsync.when(
                    data: (variants) {
                      if (variants.isEmpty) {
                        return Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange.shade700),
                            const SizedBox(width: 6),
                            Text(
                              'Variant qo\'shilmagan. Sozlash uchun bosing.',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      }

                      final Map<String, List<VariantModel>> grouped = {};
                      for (final v in variants) {
                        grouped.putIfAbsent(v.color, () => []).add(v);
                      }

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final entry in grouped.entries)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFF2F2F7)),
                              ),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(color: Colors.black87, fontSize: 12),
                                  children: [
                                    TextSpan(text: '${entry.key}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    for (int i = 0; i < entry.value.length; i++) ...[
                                      TextSpan(text: '${entry.value[i].size}(${entry.value[i].stock})'),
                                      if (i < entry.value.length - 1) const TextSpan(text: ', '),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                    error: (e, _) => Text(context.l('error') ?? 'Error loading variants', style: const TextStyle(color: Colors.red, fontSize: 11)),
                    loading: () => const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InventoryImage extends StatelessWidget {
  final List<String> imageUrls;
  const _InventoryImage({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.light ? 0.05 : 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: imageUrls.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrls.first,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                errorWidget: (context, url, error) => Icon(Icons.broken_image_outlined, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
              )
            : Icon(Icons.inventory_2_outlined, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
      ),
    );
  }
}

class AddInventorySheet extends ConsumerStatefulWidget {
  final ShopModel shop;
  const AddInventorySheet({super.key, required this.shop});

  @override
  ConsumerState<AddInventorySheet> createState() => _AddInventorySheetState();
}

class _AddInventorySheetState extends ConsumerState<AddInventorySheet> {
  final _name = TextEditingController();
  final List<String> _selectedCategoryIds = [];
  String? _categoryToAdd;
  String _selectedGender = 'unisex'; // Target audience for clothing
  final _about = TextEditingController();
  final _basePrice = TextEditingController();
  final _brand = TextEditingController();
  
  // New: Manage variants in the sheet
  final List<({TextEditingController color, List<({TextEditingController size, TextEditingController stock})> variants})> _colorGroups = [
    (
      color: TextEditingController(),
      variants: [(size: TextEditingController(), stock: TextEditingController())]
    )
  ];

  bool _busy = false;
  final List<({XFile file, Uint8List bytes})> _pickedImages = [];
  static const int _maxPickedImages = 8;
  static const int _uploadConcurrency = 3;

  @override
  void dispose() {
    _name.dispose();
    _about.dispose();
    _basePrice.dispose();
    _brand.dispose();
    for (final group in _colorGroups) {
      group.color.dispose();
      for (final v in group.variants) {
        v.size.dispose();
        v.stock.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header & Handle
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l('add_inventory') ?? 'New Inventory',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    radius: 14,
                    child: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 100),
              child: Column(
                children: [
                   _buildImagePicker(),
                  const SizedBox(height: 24),
                  _buildSection(context.l('basic_info') ?? 'Basic Info', [
                    _buildField(_name, context.l('name') ?? 'Name', context.l('name_hint') ?? 'e.g. Adidas T-Shirt'),
                    _buildField(_brand, context.l('brand') ?? 'Brand', context.l('brand_hint') ?? 'e.g. Nike, Zara, Samsung'),
                    _buildCategoryDropdown(),
                    if (widget.shop.genre == ShopGenre.clothes)
                      _buildTargetAudienceDropdown(),
                  ]),
                  const SizedBox(height: 32),
                  _buildSection(context.l('description') ?? 'Description', [
                    _buildField(_about, context.l('description') ?? 'About', context.l('about_hint') ?? 'Tell more about this item...', maxLines: 3),
                  ]),
                  const SizedBox(height: 32),
                  _buildSection(context.l('pricing') ?? 'Pricing', [
                    _buildField(_basePrice, context.l('base_price') ?? 'Base Price', 'сум', keyboard: TextInputType.number),
                  ]),
                  const SizedBox(height: 32),
                  _buildVariantSection(),
                ],
              ),
            ),
          ),
          // Sticky Bottom Action
          Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset > 0 ? 16 : 40),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _busy ? Theme.of(context).disabledColor : Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _busy ? null : _save,
                  child: _busy
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text((context.l('save') ?? 'SAVE PRODUCT').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    return categoriesAsync.when(
      data: (categories) {
        final mainCatId = switch (widget.shop.genre) {
          ShopGenre.auto => 'avto_qismlar',
          ShopGenre.toys => 'bolalar_kiyimi',
          ShopGenre.perfumery => 'gozallik_salomatlik',
          ShopGenre.clothes => 'kiyim_kechak',
          ShopGenre.electronics => 'elektronika',
          ShopGenre.home => 'xojalik_mollari',
          ShopGenre.jewelry => 'taqinchoqlar',
          ShopGenre.other => 'boshqa',
        };

        var filteredItems = categories.where((c) => c.parentId == mainCatId).toList();
        if (filteredItems.isEmpty) {
          filteredItems = categories.where((c) => c.id == mainCatId).toList();
        }
        
        // If shop genre is 'other', or no items were found, show all main categories
        if (filteredItems.isEmpty || widget.shop.genre == ShopGenre.other) {
          filteredItems = categories.where((c) => c.parentId == null).toList();
        }

        final categoriesById = {for (final c in categories) c.id: c};
        final options = filteredItems.map((e) => e.id).toList();
        final dropdownValue = (_categoryToAdd != null && options.contains(_categoryToAdd))
            ? _categoryToAdd
            : (options.isNotEmpty ? options.first : null);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedCategoryIds.isNotEmpty)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedCategoryIds.map((catId) {
                    final cat = categoriesById[catId];
                    final label = cat == null ? catId : (context.l(cat.name) ?? cat.name);
                    return InputChip(
                      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      selected: true,
                      onDeleted: () => setState(() => _selectedCategoryIds.remove(catId)),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 8),
              if (options.isEmpty)
                _buildField(TextEditingController(), 'Category', 'Error loading')
              else
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: dropdownValue,
                        decoration: InputDecoration(
                          labelText: context.l('categories') ?? 'Category',
                          border: InputBorder.none,
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        items: filteredItems
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(context.l(c.name) ?? c.name),
                                ))
                            .toList(),
                        onChanged: (newVal) => setState(() => _categoryToAdd = newVal),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: (dropdownValue == null || _selectedCategoryIds.contains(dropdownValue))
                          ? null
                          : () => setState(() => _selectedCategoryIds.add(dropdownValue)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        minimumSize: Size.zero,
                      ),
                      child: const Text('Qo‘shish', style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
      error: (_, __) => _buildField(TextEditingController(), 'Category', 'Error loading'),
      loading: () => const LinearProgressIndicator(),
    );
  }

  Widget _buildTargetAudienceDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedGender,
        decoration: InputDecoration(
          labelText: 'Kimga mo\'ljallangan', 
          border: InputBorder.none, 
          filled: true, 
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.w600, fontSize: 13),
        ),
        items: [
          DropdownMenuItem(value: 'male', child: Text('Erkaklar')),
          DropdownMenuItem(value: 'female', child: Text('Ayollar')),
          DropdownMenuItem(value: 'children', child: Text('Bolalar')),
          DropdownMenuItem(value: 'unisex', child: Text('Hammaga (Uniseks)')),
        ],
        onChanged: (val) => setState(() => _selectedGender = val ?? 'unisex'),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (images.isEmpty) return;

      final remaining = _maxPickedImages - _pickedImages.length;
      if (remaining <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l('max_images_reached') ?? 'Maksimal 8 ta rasm qo\'shish mumkin')),
          );
        }
        return;
      }

      final imagesToAdd = images.take(remaining);

      final List<({XFile file, Uint8List bytes})> newImages = [];
      for (final img in imagesToAdd) {
        final bytes = await img.readAsBytes();
        newImages.add((file: img, bytes: bytes));
      }

      if (mounted) {
        setState(() => _pickedImages.addAll(newImages));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rasm tanlashda xato: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            context.l('photos') ?? 'PHOTOS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary.withOpacity(0.7), letterSpacing: 1),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, size: 32, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 4),
                      Text(context.l('add_photo') ?? 'Add Photo', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              for (int i = 0; i < _pickedImages.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.memory(
                            _pickedImages[i].bytes,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _pickedImages.removeAt(i)),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVariantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            context.l('variants_title') ?? 'VARIANTS (COLORS & SIZES)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8E8E93), letterSpacing: 1),
          ),
        ),
        for (int i = 0; i < _colorGroups.length; i++) ...[
          _buildColorGroup(i, isClothes: widget.shop.genre == ShopGenre.clothes),
          const SizedBox(height: 16),
        ],
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() {
              _colorGroups.add((
                color: TextEditingController(),
                variants: [(size: TextEditingController(), stock: TextEditingController())]
              ));
            }),
            icon: const Icon(Icons.add_circle_outline),
            label: Text(context.l('add_color') ?? 'ADD ANOTHER COLOR', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ),
      ],
    );
  }

  Widget _buildColorGroup(int groupIdx, {bool isClothes = true}) {
    final group = _colorGroups[groupIdx];
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: group.color,
                  enableInteractiveSelection: true,
                  style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
                  decoration: InputDecoration(
                    labelText: context.l('color_name') ?? 'COLOR NAME',
                    hintText: context.l('color_hint') ?? 'e.g. White',
                    border: InputBorder.none,
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              if (_colorGroups.length > 1)
                IconButton(
                  onPressed: () => setState(() => _colorGroups.removeAt(groupIdx)),
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.1)),
          ),
          for (int i = 0; i < group.variants.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildSmallField(group.variants[i].size, isClothes ? (context.l('size') ?? 'Size') : 'O\'lcham/Model', isClothes ? 'M' : 'Default'),
                      ),
                      if (isClothes) ...[
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        flex: 2,
                        child: _buildSmallField(group.variants[i].stock, context.l('stock') ?? 'Stock', '0', keyboard: TextInputType.number),
                      ),
                      if (group.variants.length > 1)
                        IconButton(
                          padding: EdgeInsets.zero,
                          onPressed: () => setState(() => group.variants.removeAt(i)),
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (isClothes) ...[
                    _buildSizePresets(group.variants[i].size),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => group.variants.add((size: TextEditingController(), stock: TextEditingController()))),
              style: TextButton.styleFrom(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              icon: Icon(Icons.add, size: 16, color: Theme.of(context).colorScheme.primary),
              label: Text(
                context.l('add_size') ?? 'ADD SIZE',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizePresets(TextEditingController controller) {
    const clothingSizes = ['XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', '4XL'];
    const shoeSizes = ['35', '36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPresetGroup('KIYIM', clothingSizes, controller),
        const SizedBox(height: 12),
        _buildPresetGroup('POYABZAL', shoeSizes, controller),
      ],
    );
  }

  Widget _buildPresetGroup(String label, List<String> sizes, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9, 
            fontWeight: FontWeight.w800, 
            color: Color(0xFF8E8E93), 
            letterSpacing: 1.2
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: sizes.map((s) {
            final isSelected = controller.text == s;
            return GestureDetector(
              onTap: () => setState(() => controller.text = s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.black : const Color(0xFFE5E5EA),
                    width: 1,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ] : null,
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary.withOpacity(0.7), letterSpacing: 1),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) const Divider(height: 1, indent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildField(TextEditingController controller, String label, String hint, {int maxLines = 1, TextInputType keyboard = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboard,
        enableInteractiveSelection: true,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontWeight: FontWeight.w500),
          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildSmallField(TextEditingController controller, String label, String hint, {TextInputType keyboard = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        enableInteractiveSelection: true,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: InputBorder.none,
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.w600),
          isDense: true,
        ),
      ),
    );
  }

  Future<void> _save() async {
    final isClothes = widget.shop.genre == ShopGenre.clothes;
    
    // Check if any color group has a non-empty color and at least one variant with a non-empty size
    bool hasValidColorAndVariant = false;
    for (final group in _colorGroups) {
      final color = group.color.text.trim();
      if (color.isNotEmpty) {
        final validVariantsInGroup = group.variants.where((v) => v.size.text.trim().isNotEmpty).toList();
        if (validVariantsInGroup.isNotEmpty) {
          hasValidColorAndVariant = true;
          break;
        }
      }
    }

    if (isClothes && !hasValidColorAndVariant) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kiyim-kecha do\'koni uchun kamida bitta rang va o\'lcham kiriting!'), backgroundColor: Colors.red),
      );
      return;
    }
    
    final name = _name.text.trim();
    if (name.isEmpty) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      
      // 1. Upload Images FIRST (blocking)
      List<String> uploadedUrls = [];
      if (_pickedImages.isNotEmpty) {
        final uploadTs = DateTime.now().millisecondsSinceEpoch;
        final tempUploadId = 'temp_$uploadTs';

        debugPrint('Product image upload starting for ${_pickedImages.length} images...');

        Future<String?> uploadOne(int index, ({XFile file, Uint8List bytes}) picked) async {
          const maxAttempts = 2;
          final fileName = '${uploadTs}_${index}_${picked.file.name}';
          final lower = picked.file.name.toLowerCase();
          final contentType = lower.endsWith('.png')
              ? 'image/png'
              : lower.endsWith('.webp')
                  ? 'image/webp'
                  : 'image/jpeg';

          for (var attempt = 1; attempt <= maxAttempts; attempt++) {
            try {
              debugPrint('Uploading image #${index + 1} (attempt $attempt): ${picked.file.name} (${picked.bytes.length} bytes)');
              final url = await repo
                  .uploadImageBytes(
                    shopId: widget.shop.id,
                    inventoryId: tempUploadId,
                    fileName: fileName,
                    bytes: picked.bytes,
                    contentType: contentType,
                  )
                  .timeout(const Duration(seconds: 120));

              debugPrint('Image upload success #${index + 1}');
              return url;
            } catch (e) {
              debugPrint('Image upload FAIL #${index + 1} (attempt $attempt) for ${picked.file.name}: $e');
              if (attempt == maxAttempts) {
                return null; // allow partial success
              }

              // Small backoff to avoid burst rate-limit issues.
              await Future<void>.delayed(Duration(milliseconds: 300 * attempt));
            }
          }

          return null;
        }

        // Upload in small batches to avoid Cloudinary/network overload and timeouts.
        for (var start = 0; start < _pickedImages.length; start += _uploadConcurrency) {
          final end = (start + _uploadConcurrency).clamp(0, _pickedImages.length);
          final batch = _pickedImages.sublist(start, end);

          final batchResults = await Future.wait(
            List.generate(batch.length, (i) => uploadOne(start + i, batch[i])),
          );

          uploadedUrls.addAll(batchResults.whereType<String>());
        }

        debugPrint('All product images upload done. Success: ${uploadedUrls.length}/${_pickedImages.length}');
      }

      // 2. Aggregate Colors & Sizes and Variant Info
      final Set<String> availableColors = {};
      final Set<String> availableSizes = {};
      int totalStock = 0;
      
      final List<VariantModel> rawVariants = [];
      for (final group in _colorGroups) {
        final color = group.color.text.trim();
        if (color.isEmpty) continue;
        availableColors.add(color);
        
        for (final v in group.variants) {
          final size = v.size.text.trim();
          if (size.isEmpty) continue;
          availableSizes.add(size);
          final stock = int.tryParse(v.stock.text.trim()) ?? 0;
          totalStock += stock;
          
          rawVariants.add(VariantModel(
            id: '',
            inventoryId: '', // placeholder, will set after getting id
             color: color,
             size: size,
             stock: stock,
          ));
        }
      }

      // 3. Resolve Category Hierarchy
      Set<String> categoryIdsSet = {};
      String? primaryLeafCategoryId;
      String categoryNameLegacy = 'Unknown';

      // Safe hierarchy resolution
      try {
        final allCatsOpt = ref.read(categoriesStreamProvider).valueOrNull;
        if (allCatsOpt != null && _selectedCategoryIds.isNotEmpty) {
          for (final leafCategoryId in _selectedCategoryIds) {
            final leaf = allCatsOpt.firstWhere((c) => c.id == leafCategoryId);
            if (primaryLeafCategoryId == null) {
              primaryLeafCategoryId = leaf.id;
              categoryNameLegacy = leaf.name;
            }

            categoryIdsSet.add(leaf.id);

            String? currentParentId = leaf.parentId;
            while (currentParentId != null) {
              categoryIdsSet.add(currentParentId);
              try {
                final parent = allCatsOpt.firstWhere((c) => c.id == currentParentId);
                currentParentId = parent.parentId;
              } catch (_) {
                break;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Category resolution error: $e');
      }

      // 4. Create Inventory
      final inventoryId = await repo.addInventory(
        InventoryModel(
          id: '',
          shopId: widget.shop.id,
          name: _name.text.trim(),
          brand: _brand.text.trim(),
          category: categoryNameLegacy,
          categoryId: primaryLeafCategoryId,
          categoryIds: categoryIdsSet.toList(),
          availableColors: availableColors.toList(),
          availableSizes: availableSizes.toList(),
          gender: widget.shop.genre == ShopGenre.clothes ? _selectedGender : 'unisex',
          about: _about.text.trim(),
          basePrice: int.tryParse(_basePrice.text.trim()) ?? 0,
          imageUrls: uploadedUrls,
          createdAt: DateTime.now(),
        ),
      );

      // 5. Create Variants
      final List<Future> variantTasks = [];
      for (final v in rawVariants) {
        variantTasks.add(repo.addVariant(
          inventoryId,
          VariantModel(
            id: '',
            inventoryId: inventoryId,
            color: v.color,
            size: v.size,
            stock: v.stock,
          ),
        ));
      }
      if (variantTasks.isNotEmpty) {
        await Future.wait(variantTasks);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l('product_created') ?? 'Mahsulot yaratildi!')),
        );
      }
    } catch (e) {
      debugPrint('Product save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l("error") ?? "Xato"}: $e'), 
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
