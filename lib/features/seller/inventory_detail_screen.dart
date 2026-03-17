import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart'; // Added import

import 'package:image_picker/image_picker.dart';

import '../../core/shared_providers.dart';
import '../../core/localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../shared/models/inventory_model.dart';
import '../../shared/models/variant_model.dart';
import '../marketplace/inventory_repository.dart';
import '../marketplace/category_repository.dart';
import '../sales/sales_repository.dart';

class InventoryDetailScreen extends ConsumerWidget {
  final String inventoryId;

  const InventoryDetailScreen({super.key, required this.inventoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(singleInventoryProvider(inventoryId));
    final variantsAsync = ref.watch(variantsByInventoryProvider(inventoryId));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l('manage_variants') ?? 'Manage Variants'),
        actions: [
          inventoryAsync.when(
            data: (inv) {
              if (inv == null) return const SizedBox.shrink();
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(context, ref, inv),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useRootNavigator: true,
                      builder: (_) => _EditInventorySheet(inventory: inv),
                    ),
                  ),
                ],
              );
            },
            error: (_, __) => const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: inventoryAsync.when(
        data: (inv) {
          if (inv == null) return Center(child: Text(context.l('inventory_not_found') ?? 'Inventory not found'));
          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                // Product header
                Container(
                  color: Theme.of(context).cardColor,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (inv.imageUrls.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(inv.imageUrls.first, width: 80, height: 80, fit: BoxFit.cover),
                        )
                      else
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.image_outlined, color: Color(0xFFC7C7CC)),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(inv.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5)),
                            const SizedBox(height: 4),
                            Consumer(builder: (context, ref, _) {
                              final shopAsync = ref.watch(singleShopProvider(inv.shopId));
                              return shopAsync.when(
                                data: (shop) {
                                  final isClothes = shop?.genre == ShopGenre.clothes;
                                  return Text(
                                    '${inv.category}${isClothes ? " • ${inv.gender}" : ""}', 
                                    style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13)
                                  );
                                },
                                loading: () => Text(inv.category, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13)),
                                error: (_, __) => Text(inv.category, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13)),
                              );
                            }),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
                              child: Text('${inv.basePrice} sum', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Tab bar
                Container(
                  color: Theme.of(context).cardColor,
                  child: TabBar(
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
                    unselectedLabelColor: const Color(0xFF8E8E93),
                    indicatorColor: Theme.of(context).textTheme.bodyLarge?.color,
                    indicatorWeight: 2,
                    tabs: [
                      Tab(text: context.l('variants') ?? 'Variantlar'),
                      Tab(text: context.l('sales_history') ?? 'Savdo tarixi'),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Tab views
                Expanded(
                  child: TabBarView(
                    children: [
                      // ── Tab 1: Variants ──────────────────────────────
                      variantsAsync.when(
                        data: (variants) => variants.isEmpty
                            ? const Center(child: Text('Hali variant qo\'shilmagan', style: TextStyle(color: Color(0xFF8E8E93))))
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 200),
                                itemCount: variants.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, idx) {
                                  final v = variants[idx];
                                  return _VariantCard(
                                    variant: v,
                                    onEdit: () => showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      useRootNavigator: true,
                                      builder: (_) => _EditVariantSheet(variant: v),
                                    ),
                                    onDelete: () => ref.read(inventoryRepositoryProvider).deleteVariant(inventoryId, v.id),
                                  );
                                },
                              ),
                        error: (e, _) => Center(child: Text('${context.l("error") ?? "Xato"}: $e')),
                        loading: () => const Center(child: CircularProgressIndicator()),
                      ),

                      // ── Tab 2: Sales History ─────────────────────────
                      _SalesHistoryTab(inventoryId: inventoryId, inventoryName: inv.name),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        error: (e, _) => Center(child: Text('${context.l("error") ?? "Error"}: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 120),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useRootNavigator: true,
            builder: (_) => _AddVariantSheet(inventoryId: inventoryId),
          ),
          label: Text(context.l('add_color_variants') ?? 'Add Color Variants', style: const TextStyle(fontWeight: FontWeight.bold)),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, InventoryModel inv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l('delete_product') ?? 'Mahsulotni o\'chirish'),
        content: Text(context.l('confirm_delete_product') ?? 'Haqiqatan ham ushbu mahsulotni o\'chirmoqchimisiz? Ushbu amalni qaytarib bo\'lmaydi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l('cancel') ?? 'Bekor qilish'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(inventoryRepositoryProvider).deleteInventory(inv.id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l('product_deleted') ?? 'Mahsulot o\'chirildi')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: Text(context.l('delete') ?? 'O\'chirish', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _VariantCard extends StatelessWidget {
  final VariantModel variant;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VariantCard({required this.variant, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                variant.size,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Color: ${variant.color}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stock: ${variant.stock} ${variant.priceOverride != null ? "| Price: ${variant.priceOverride} sum" : ""}',
                  style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.black87, size: 20),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditVariantSheet extends ConsumerStatefulWidget {
  final VariantModel variant;
  const _EditVariantSheet({required this.variant});

  @override
  ConsumerState<_EditVariantSheet> createState() => _EditVariantSheetState();
}

class _EditVariantSheetState extends ConsumerState<_EditVariantSheet> {
  late final TextEditingController _color;
  late final TextEditingController _size;
  late final TextEditingController _stock;
  late final TextEditingController _priceOverride;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _color = TextEditingController(text: widget.variant.color);
    _size = TextEditingController(text: widget.variant.size);
    _stock = TextEditingController(text: widget.variant.stock.toString());
    _priceOverride = TextEditingController(text: widget.variant.priceOverride?.toString() ?? '');
  }

  @override
  void dispose() {
    _color.dispose();
    _size.dispose();
    _stock.dispose();
    _priceOverride.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                  'Edit Variant',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const CircleAvatar(
                    backgroundColor: Color(0xFFE5E5EA),
                    radius: 14,
                    child: Icon(Icons.close, size: 16, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 100),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSmallField(_color, 'Color', 'e.g. White'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildSmallField(_size, 'Size', 'e.g. M')),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSmallField(_stock, 'Stock', '0', keyboard: TextInputType.number)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSmallField(_priceOverride, 'Price (opt)', '', keyboard: TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSizePresets(_size),
                ],
              ),
            ),
          ),
          Container(
             padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset > 0 ? 16 : 40),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              border: const Border(top: BorderSide(color: Color(0xFFE5E5EA))),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _busy ? null : _save,
                    child: Text(
                      _busy ? 'SAVING...' : 'SAVE CHANGES',
                      style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallField(TextEditingController controller, String label, String hint, {TextInputType keyboard = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: InputBorder.none,
          labelStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 10, fontWeight: FontWeight.w600),
          isDense: true,
        ),
      ),
    );
  }

  Future<void> _save() async {
    final color = _color.text.trim();
    final size = _size.text.trim();
    final stock = int.tryParse(_stock.text.trim()) ?? 0;
    
    if (color.isEmpty || size.isEmpty) return;

    setState(() => _busy = true);
    try {
      final overrideText = _priceOverride.text.trim();
      final pOver = overrideText.isNotEmpty ? int.tryParse(overrideText) : null;

      final updatedVariant = VariantModel(
        id: widget.variant.id,
        inventoryId: widget.variant.inventoryId,
        color: color,
        size: size,
        stock: stock,
        priceOverride: pOver,
      );

      await ref.read(inventoryRepositoryProvider).updateVariant(widget.variant.inventoryId, updatedVariant);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF8E8E93), letterSpacing: 1.2)),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isSelected ? Colors.black : const Color(0xFFE5E5EA)),
                ),
                child: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : Colors.black87)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _AddVariantSheet extends ConsumerStatefulWidget {
  final String inventoryId;
  const _AddVariantSheet({required this.inventoryId});

  @override
  ConsumerState<_AddVariantSheet> createState() => _AddVariantSheetState();
}

class _AddVariantSheetState extends ConsumerState<_AddVariantSheet> {
  final _color = TextEditingController();
  final _priceOverride = TextEditingController();
  final List<({TextEditingController size, TextEditingController stock})> _variants = [
    (size: TextEditingController(), stock: TextEditingController()),
  ];
  bool _busy = false;

  @override
  void dispose() {
    _color.dispose();
    _priceOverride.dispose();
    for (final v in _variants) {
      v.size.dispose();
      v.stock.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(color: Theme.of(context).dividerColor, borderRadius: BorderRadius.circular(2.5)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l('add_color_variants') ?? 'Add Color Variants',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest, radius: 14, child: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.onSurface)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(context.l('color_details') ?? 'Color Details', [
                    _buildField(_color, context.l('color_name') ?? 'Color Name', context.l('color_hint') ?? 'e.g. White, Black, Red'),
                    _buildField(_priceOverride, context.l('price_override') ?? 'Price Override', context.l('price_override_hint') ?? 'Optional, applies to all below', keyboard: TextInputType.number),
                  ]),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(context.l('sizes_stock') ?? 'SIZES & STOCK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary.withOpacity(0.7), letterSpacing: 1)),
                  ),
                  for (int i = 0; i < _variants.length; i++)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _variants[i].size,
                              decoration: InputDecoration(labelText: context.l('size') ?? 'Size', hintText: 'L, XL...', border: InputBorder.none),
                            ),
                          ),
                          const VerticalDivider(),
                          Expanded(
                            child: TextField(
                              controller: _variants[i].stock,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(labelText: context.l('stock') ?? 'Stock', hintText: '0', border: InputBorder.none),
                            ),
                          ),
                          if (_variants.length > 1)
                            IconButton(
                              onPressed: () => setState(() => _variants.removeAt(i)),
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                            ),
                        ],
                      ),
                    ),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() => _variants.add((size: TextEditingController(), stock: TextEditingController()))),
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text(context.l('add_size_another') ?? 'ADD ANOTHER SIZE', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSizePresetsOverlay(),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset > 0 ? 16 : 40),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withOpacity(0.95),
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _busy ? null : _save,
                child: Text(_busy ? '${context.l("saving") ?? "SAVING"}...' : (context.l('save') ?? 'SAVE COLOR VARIANTS').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8E8E93), letterSpacing: 1)),
        ),
        Container(
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
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

  Widget _buildField(TextEditingController controller, String label, String hint, {TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: InputBorder.none,
      ),
    );
  }

  Future<void> _save() async {
    final color = _color.text.trim();
    if (color.isEmpty) return;
    final validVariants = _variants.where((v) => v.size.text.trim().isNotEmpty).toList();
    if (validVariants.isEmpty) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final override = _priceOverride.text.trim().isEmpty ? null : int.tryParse(_priceOverride.text.trim());
      for (final v in validVariants) {
        await repo.addVariant(
          widget.inventoryId,
          VariantModel(
            id: '',
            inventoryId: widget.inventoryId,
            color: color,
            size: v.size.text.trim(),
            stock: int.tryParse(v.stock.text.trim()) ?? 0,
            priceOverride: override,
          ),
        );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildSizePresetsOverlay() {
    const clothingSizes = ['XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL', '3XL', '4XL'];
    const shoeSizes = ['35', '36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TEZKOR TANLASH (Oxirgi qatorga)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF8E8E93), letterSpacing: 1.2)),
          const SizedBox(height: 12),
          _buildPresetWrap('KIYIM', clothingSizes),
          const SizedBox(height: 16),
          _buildPresetWrap('POYABZAL', shoeSizes),
        ],
      ),
    );
  }

  Widget _buildPresetWrap(String label, List<String> sizes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF8E8E93))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: sizes.map((s) => GestureDetector(
            onTap: () => setState(() => _variants.last.size.text = s),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          )).toList(),
        ),
      ],
    );
  }
}
class _EditInventorySheet extends ConsumerStatefulWidget {
  final InventoryModel inventory;
  const _EditInventorySheet({required this.inventory});

  @override
  ConsumerState<_EditInventorySheet> createState() => _EditInventorySheetState();
}

class _EditInventorySheetState extends ConsumerState<_EditInventorySheet> {
  late final TextEditingController _name;
  late final TextEditingController _brand;
  String? _selectedCategory;
  String _selectedGender = 'both';
  late final TextEditingController _about;
  late final TextEditingController _basePrice;
  
  bool _busy = false;
  late final List<String> _existingImages;
  final List<({XFile file, Uint8List bytes})> _pickedImages = [];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.inventory.name);
    _brand = TextEditingController(text: widget.inventory.brand);
    _selectedCategory = widget.inventory.categoryId;
    _selectedGender = widget.inventory.gender;
    _about = TextEditingController(text: widget.inventory.about);
    _basePrice = TextEditingController(text: widget.inventory.basePrice.toString());
    _existingImages = List.from(widget.inventory.imageUrls);
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _about.dispose();
    _basePrice.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 85);
    if (images.isNotEmpty) {
      final List<({XFile file, Uint8List bytes})> newImages = [];
      for (final img in images) {
        final bytes = await img.readAsBytes();
        newImages.add((file: img, bytes: bytes));
      }
      if (mounted) setState(() => _pickedImages.addAll(newImages));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF2F2F7),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFC7C7CC),
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
                  context.l('edit_inventory') ?? 'Edit Inventory',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const CircleAvatar(
                    backgroundColor: Color(0xFFE5E5EA),
                    radius: 14,
                    child: Icon(Icons.close, size: 16, color: Colors.black87),
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
                    _buildField(_brand, context.l('brand') ?? 'Brand', context.l('brand_hint') ?? 'e.g. Nike, Zara'),
                    _buildCategoryDropdown(),
                    Consumer(builder: (context, ref, _) {
                      final shopAsync = ref.watch(singleShopProvider(widget.inventory.shopId));
                      return shopAsync.when(
                        data: (shop) => shop?.genre == ShopGenre.clothes ? _buildGenderDropdown() : const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    }),
                  ]),
                  const SizedBox(height: 32),
                  _buildSection(context.l('description') ?? 'Description', [
                    _buildField(_about, context.l('shop_about') ?? 'About', context.l('about_hint') ?? 'Tell more about this item...', maxLines: 3),
                  ]),
                  const SizedBox(height: 32),
                  _buildSection(context.l('pricing') ?? 'Pricing', [
                    _buildField(_basePrice, context.l('base_price') ?? 'Base Price', 'sum', keyboard: TextInputType.number),
                  ]),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset > 0 ? 16 : 40),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              border: const Border(top: BorderSide(color: Color(0xFFE5E5EA))),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _busy ? null : _save,
                    child: Text(
                      _busy ? '${context.l("saving") ?? "SAVING"}...' : (context.l('save_changes') ?? 'SAVE CHANGES').toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8E8E93), letterSpacing: 1),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
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
          fillColor: const Color(0xFFF2F2F7),
          labelStyle: const TextStyle(color: Color(0xFF8E8E93), fontWeight: FontWeight.w500),
          hintStyle: const TextStyle(color: Color(0xFFC7C7CC), fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedGender,
        decoration: InputDecoration(labelText: context.l('role') ?? 'Gender', border: InputBorder.none, filled: true, fillColor: const Color(0xFFF2F2F7)),
        items: [
          DropdownMenuItem(value: 'male', child: Text(context.l('male'))),
          DropdownMenuItem(value: 'female', child: Text(context.l('female'))),
          DropdownMenuItem(value: 'both', child: Text(context.l('unisex'))),
        ],
        onChanged: (val) => setState(() => _selectedGender = val ?? 'both'),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    return categoriesAsync.when(
      data: (categories) {
        // Ensure _selectedCategory exists in the list to avoid dropdown error
        if (_selectedCategory != null && !categories.any((c) => c.id == _selectedCategory)) {
           _selectedCategory = null;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: InputDecoration(labelText: context.l('categories') ?? 'Category', border: InputBorder.none, filled: true, fillColor: const Color(0xFFF2F2F7)),
            items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(context.l(c.name) ?? c.name))).toList(),
            onChanged: (val) => setState(() => _selectedCategory = val),
          ),
        );
      },
      error: (_, __) => const SizedBox(),
      loading: () => const LinearProgressIndicator(),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            context.l('photos') ?? 'PHOTOS',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8E8E93), letterSpacing: 1),
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
                      const Icon(Icons.add_a_photo_outlined, size: 32, color: Color(0xFF007AFF)),
                      const SizedBox(height: 4),
                      Text(context.l('add_photo') ?? 'Add Photo', style: const TextStyle(color: Color(0xFF007AFF), fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              for (int i = 0; i < _existingImages.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          image: DecorationImage(
                            image: CachedNetworkImageProvider(_existingImages[i]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _existingImages.removeAt(i)),
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

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    setState(() => _busy = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      List<String> uploadedUrls = List.from(_existingImages);
      
      if (_pickedImages.isNotEmpty) {
        debugPrint('Inventory image upload starting for ${_pickedImages.length} images...');
        for (final picked in _pickedImages) {
          debugPrint('Uploading image: ${picked.file.name} (${picked.bytes.length} bytes)');
          try {
            final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_${picked.file.name}';
            final url = await repo.uploadImageBytes(
              shopId: widget.inventory.shopId,
              inventoryId: widget.inventory.id,
              fileName: uniqueName,
              bytes: picked.bytes,
              contentType: 'image/jpeg',
            ).timeout(const Duration(seconds: 120));
            debugPrint('Image upload success: $url');
            uploadedUrls.add(url);
          } catch (e) {
            debugPrint('Image upload FAIL for ${picked.file.name}: $e');
            rethrow;
          }
        }
        debugPrint('All inventory images uploaded successfully: ${uploadedUrls.length} total');
      }

      // Resolve Category Hierarchy
      List<String> categoryIds = List.from(widget.inventory.categoryIds);
      String? leafCategoryId = _selectedCategory ?? widget.inventory.categoryId;
      String categoryNameLegacy = widget.inventory.category;

      try {
        final allCatsOpt = ref.read(categoriesStreamProvider).valueOrNull;
        if (allCatsOpt != null && _selectedCategory != null) {
          final leaf = allCatsOpt.firstWhere((c) => c.id == _selectedCategory);
          categoryNameLegacy = leaf.name;
          categoryIds = [leaf.id];
          leafCategoryId = leaf.id;
          
          String? currentParentId = leaf.parentId;
          while (currentParentId != null) {
            categoryIds.add(currentParentId);
            try {
              final parent = allCatsOpt.firstWhere((c) => c.id == currentParentId);
              currentParentId = parent.parentId;
            } catch (_) {
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('Category resolution error in edit: $e');
      }

      final updatedInventory = InventoryModel(
        id: widget.inventory.id,
        shopId: widget.inventory.shopId,
        name: name,
        brand: _brand.text.trim(),
        category: categoryNameLegacy,
        categoryId: leafCategoryId,
        categoryIds: categoryIds,
        availableColors: widget.inventory.availableColors,
        availableSizes: widget.inventory.availableSizes,
        gender: _selectedGender, // Leave as is or update based on genre in a more complex setup
        about: _about.text.trim(),
        basePrice: int.tryParse(_basePrice.text.trim()) ?? 0,
        imageUrls: uploadedUrls,
        createdAt: widget.inventory.createdAt,
      );

      await repo.updateInventory(updatedInventory);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l('inventory_updated') ?? 'Mahsulot yangilandi!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l("error") ?? "Xato"}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ── Sales History Tab ──────────────────────────────────────────────────────
class _SalesHistoryTab extends ConsumerWidget {
  final String inventoryId;
  final String inventoryName;
  const _SalesHistoryTab({required this.inventoryId, required this.inventoryName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(salesByInventoryProvider(inventoryId));

    return salesAsync.when(
      data: (sales) {
        if (sales.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.receipt_long_outlined, size: 56, color: Color(0xFFC7C7CC)),
                SizedBox(height: 12),
                Text('Hali savdo amalga oshirilmagan', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 15)),
              ],
            ),
          );
        }

        final totalQty = sales.fold(0, (s, e) => s + e.quantity);
        final totalRev = sales.fold(0, (s, e) => s + e.total);

        return Column(
          children: [
            // Summary header
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.l("total_sales"), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('$totalQty ${context.l("items") ?? "dona"}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(context.l('total_revenue') ?? 'Jami daromad', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(
                          '${totalRev.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ')} sum',
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                          textAlign: TextAlign.right,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Sale list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 200),
                itemCount: sales.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final s = sales[idx];
                  final date = s.createdAt;
                  final dateStr = '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
                  final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                  final total = s.total.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    leading: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF8E8E93), size: 20),
                    ),
                    title: Text('${s.quantity} ${context.l("items") ?? "dona"} × ${s.price} sum', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: Text('$dateStr  $timeStr', style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12)),
                    trailing: Text(
                      '$total sum',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF22C55E)),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      error: (e, _) {
        final errStr = e.toString();
        if (errStr.contains('requires an index')) {
          final urlMatch = RegExp(r'https://console\.firebase\.google\.com[^\s]*').firstMatch(errStr);
          final url = urlMatch?.group(0);

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    context.l('firebase_index_required') ?? 'Firestore index talab qilinadi',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.l('firebase_index_required_to_view_sales') ?? 'Savdo tarixini ko\'rish uchun Firestore-da index yaratishingiz kerak. Pastdagi havolani nusxalab, brauzerda oching:',
                    textAlign: TextAlign.center,
                  ),
                  if (url != null) ...[
                    const SizedBox(height: 16),
                    SelectableText(
                      url,
                      style: const TextStyle(color: Colors.blue, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => ref.invalidate(salesByInventoryProvider(inventoryId)),
                    child: Text(context.l('refresh') ?? 'Qayta tekshirish'),
                  ),
                ],
              ),
            ),
          );
        }
        return Center(child: Text('${context.l("error") ?? "Xato"}: $e'));
      },
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}
