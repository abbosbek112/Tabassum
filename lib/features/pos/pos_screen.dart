import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/localization.dart';
import '../../core/shared_providers.dart';
import '../../shared/models/inventory_model.dart';
import '../../shared/models/variant_model.dart';
import '../../shared/models/shop_model.dart';
import '../sales/sales_repository.dart';

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return Center(child: Text(context.l('not_logged_in') ?? 'Please sign in.'));

    final shopsAsync = ref.watch(myShopsProvider(uid));
    return shopsAsync.when(
      data: (shops) {
        if (shops.isEmpty) return Center(child: Text(context.l('create_shop') ?? 'Create a shop first.'));
        final shop = shops.first;
        return _PosBody(shop: shop);
      },
      error: (e, _) => Center(child: Text('Error: $e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

class _PosBody extends ConsumerStatefulWidget {
  final ShopModel shop;
  const _PosBody({required this.shop});

  @override
  ConsumerState<_PosBody> createState() => _PosBodyState();
}

class _PosBodyState extends ConsumerState<_PosBody> {
  InventoryModel? _selectedInventory;
  VariantModel? _selectedVariant;
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryByShopProvider(widget.shop.id));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.l('pos') ?? 'POS', style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.0)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width < 380 ? 16 : 24, 
        32, 
        MediaQuery.sizeOf(context).width < 380 ? 16 : 24, 
        140
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 380 ? 16 : 24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.light ? 0.03 : 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.l('record_sale') ?? 'Record Sale', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5)),
            const SizedBox(height: 24),
            inventoryAsync.when(
              data: (inventoryItems) {
                if (inventoryItems.isEmpty) return const Text('No inventory available.');
                return DropdownButtonFormField<InventoryModel>(
                  initialValue: _selectedInventory,
                  items: [for (final inv in inventoryItems) DropdownMenuItem(value: inv, child: Text(inv.name, style: TextStyle(color: Theme.of(context).colorScheme.onSurface)))],
                  onChanged: _busy ? null : (inv) => setState(() { 
                    if (inv == null) return;
                    _selectedInventory = inv; 
                    _selectedVariant = null; 
                    _priceCtrl.text = inv.basePrice.toString();
                  }),
                  decoration: _inputDeco(context.l('select_item') ?? 'Select Item'),
                  dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                );
              },
              error: (e, _) => Text('Error: $e'),
              loading: () => const LinearProgressIndicator(),
            ),
            if (_selectedInventory != null) ...[
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, child) {
                  final variantsAsync = ref.watch(variantsByInventoryProvider(_selectedInventory!.id));
                  return variantsAsync.when(
                    data: (variants) {
                      if (variants.isEmpty) return const Text('No variants found.');
                      return DropdownButtonFormField<VariantModel>(
                        initialValue: _selectedVariant,
                        items: [
                          for (final v in variants) 
                            DropdownMenuItem(
                              value: v, 
                              child: Text(
                                '${v.size} - ${v.color} (${v.stock} ${context.l("stock") ?? "left"})',
                                style: TextStyle(
                                  color: v.stock <= 0 ? Colors.redAccent : Theme.of(context).colorScheme.onSurface,
                                  fontWeight: v.stock <= 0 ? FontWeight.normal : FontWeight.w600,
                                ),
                              )
                            )
                        ],
                        onChanged: _busy ? null : (v) => setState(() {
                          if (v == null) return;
                          _selectedVariant = v;
                          final p = v.priceOverride ?? _selectedInventory!.basePrice;
                          _priceCtrl.text = p.toString();
                        }),
                        decoration: _inputDeco(context.l('select_variant') ?? 'Select Variant'),
                        dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      );
                    },
                    error: (e, _) => Text('Error: $e'),
                    loading: () => const LinearProgressIndicator(),
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco(context.l('quantity') ?? 'Quantity'),
              onTap: () => _qtyCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _qtyCtrl.text.length),
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: _inputDeco(context.l('unit_price') ?? 'Unit Price'),
              onTap: () => _priceCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _priceCtrl.text.length),
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
            ),
            if (_selectedVariant != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 14, color: _isStockValid() ? Theme.of(context).colorScheme.primary : Colors.redAccent),
                    const SizedBox(width: 8),
                    Text(
                      _isStockValid() 
                        ? '${context.l("stock") ?? "Omborda"}: ${_selectedVariant!.stock}' 
                        : '${context.l("low_stock") ?? "Yetarli emas!"} (${_selectedVariant!.stock} qolgan)',
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: FontWeight.w600, 
                        color: _isStockValid() ? Theme.of(context).colorScheme.onSurfaceVariant : Colors.redAccent
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (_selectedVariant != null) _buildTotalSection(),
            const SizedBox(height: 32),
            SizedBox(
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: _busy || _selectedInventory == null || _selectedVariant == null || !_isStockValid()
                    ? null
                    : () async {
                        final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
                        final price = int.tryParse(_priceCtrl.text.trim()) ?? 0;
                        if (qty <= 0) return;
                        setState(() => _busy = true);
                        try {
                          await ref.read(salesRepositoryProvider).createSaleAndUpdateStock(
                                shopId: widget.shop.id,
                                inventoryId: _selectedInventory!.id,
                                variantId: _selectedVariant!.id,
                                quantity: qty,
                                price: price,
                              );
                          
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l('sale_recorded') ?? 'Sale recorded successfully'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.black,
                            ),
                          );
                          setState(() {
                            _selectedInventory = null;
                            _selectedVariant = null;
                            _qtyCtrl.text = '1';
                            _priceCtrl.clear();
                          });
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
                          );
                        } finally {
                          if (mounted) setState(() => _busy = false);
                        }
                      },
                child: Text(_busy ? '${context.l("saving") ?? "PROCESSING"}...' : (context.l('complete_sale') ?? 'COMPLETE SALE').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  bool _isStockValid() {
    if (_selectedVariant == null) return true;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    return qty > 0 && qty <= _selectedVariant!.stock;
  }

  Widget _buildTotalSection() {
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final price = int.tryParse(_priceCtrl.text.trim()) ?? 0;
    final total = qty * price;
    final formattedTotal = total.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(context.l('total_amount') ?? 'Jami', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text('$formattedTotal sum', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      floatingLabelStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
    );
  }
}
