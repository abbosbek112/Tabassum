import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:go_router/go_router.dart';
import '../../core/twa_service.dart';
import '../auth/auth_controller.dart';
import '../../shared/models/shop_model.dart';
import '../../core/providers.dart';
import '../../core/localization.dart';
import '../../core/shared_providers.dart';
import '../sales/sales_repository.dart';

class SalesReportsScreen extends ConsumerStatefulWidget {
  const SalesReportsScreen({super.key});

  @override
  ConsumerState<SalesReportsScreen> createState() => _SalesReportsScreenState();
}

class _SalesReportsScreenState extends ConsumerState<SalesReportsScreen> {
  String? _selectedShopId;

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
    final authState = ref.watch(authStateProvider);
    final uid = authState.user?.uid ?? ref.watch(firebaseAuthProvider).currentUser?.uid;
    final twa = ref.watch(twaServiceProvider);
    
    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l('sales_reports') ?? 'Sales Reports')),
        body: Center(child: Text(context.l('not_logged_in') ?? 'Please sign in.')),
      );
    }

    final shopsAsync = ref.watch(myShopsProvider(uid));

    return Scaffold(
      appBar: AppBar(
        leading: twa.isSupported ? const SizedBox.shrink() : null,
        title: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(context.l('sales_reports') ?? 'Sales Reports'),
        ),
        actions: [
          shopsAsync.maybeWhen(
            data: (shops) {
              if (shops.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8, right: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedShopId ?? shops.first.id,
                    icon: const Icon(Icons.swap_horiz, size: 20),
                    items: shops.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)))).toList(),
                    onChanged: (val) => setState(() => _selectedShopId = val),
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: shopsAsync.when(
        data: (shops) {
          if (shops.isEmpty) return Center(child: Text(context.l('create_shop') ?? 'Create a shop first.'));
          
          final shopId = _selectedShopId ?? shops.first.id;
          final shop = shops.firstWhere((s) => s.id == shopId, orElse: () => shops.first);
          
          // Check subscription
          final subActiveAsync = ref.watch(subscriptionActiveProvider(shopId));
          
          return subActiveAsync.when(
            data: (isActive) {
              if (!isActive) return _buildBlockedScreen(shop);
              
              final salesAsync = ref.watch(_todaySalesProvider(shopId));
              return _buildReportsBody(context, shop, salesAsync);
            },
            error: (e, _) => Center(child: Text('Error checking subscription: $e')),
            loading: () => const Center(child: CircularProgressIndicator()),
          );
        },
        error: (e, _) => Center(child: Text('${context.l("error") ?? "Error"}: $e')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildReportsBody(BuildContext context, ShopModel shop, AsyncValue<QuerySnapshot<Map<String, dynamic>>> salesAsync) {
    return salesAsync.when(
      data: (snap) {
        if (snap.docs.isEmpty) {
          return Center(child: Text(context.l('no_sales_today') ?? 'No sales for today.'));
        }

        int totalRevenue = 0;
        for (final doc in snap.docs) {
          final data = doc.data();
          totalRevenue += (data['total'] as num? ??
                  (data['price'] as num? ?? 0) * (data['quantity'] as num? ?? 0))
              .toInt();
        }

        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1), width: 1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l('todays_revenue') ?? 'Today\'s Revenue',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${NumberFormat('#,###').format(totalRevenue)} sum',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.0,
                            ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${snap.docs.length} ${context.l('sales_count') ?? "sales"}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: snap.docs.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.1)),
                itemBuilder: (context, idx) {
                  final data = snap.docs[idx].data();
                  final inventoryId = (data['inventoryId'] as String?) ?? '';
                  final quantity = (data['quantity'] as num? ?? 0).toInt();
                  final price = (data['price'] as num? ?? 0).toInt();
                  final total = (data['total'] as num? ?? price * quantity).toInt();
                  final rawDate = data['createdAt'] ?? data['date'];
                  final date = rawDate is Timestamp ? rawDate.toDate() : DateTime.now();
                  final timeStr =
                      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

                  // Look up inventory name from shared provider
                  final productAsync = ref.watch(singleInventoryProvider(inventoryId));
                  final productName = productAsync.valueOrNull?.name ?? inventoryId;

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Text(
                        'x$quantity',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${NumberFormat('#,###').format(price)} sum × $quantity',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${NumberFormat('#,###').format(total)} sum',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          timeStr,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      error: (e, _) => Center(child: Text('${context.l("error") ?? "Error"}: $e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildBlockedScreen(ShopModel shop) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_person_outlined, size: 80, color: Theme.of(context).colorScheme.error.withOpacity(0.5)),
            const SizedBox(height: 24),
            Text(
              'Tahlillar bloklangan',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              '${shop.name} do\'koni uchun tahlillarni ko\'rish uchun faol obuna talab qilinadi. Iltimos, obunani faollashtiring yoki yangilang.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/subscription/${shop.id}'),
              icon: const Icon(Icons.star_rounded),
              label: const Text('OBUNA BO\'LISH'),
            ),
          ],
        ),
      ),
    );
  }
}

final _todaySalesProvider =
    StreamProvider.family<QuerySnapshot<Map<String, dynamic>>, String>((ref, shopId) {
  return ref
      .watch(salesRepositoryProvider)
      .streamDailySales(shopId: shopId, day: DateTime.now());
});
