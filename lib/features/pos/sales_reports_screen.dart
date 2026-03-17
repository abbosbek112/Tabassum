import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../../core/localization.dart';
import '../../core/shared_providers.dart';
import '../sales/sales_repository.dart';

class SalesReportsScreen extends ConsumerWidget {
  const SalesReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return Center(child: Text(context.l('not_logged_in') ?? 'Please sign in.'));

    final shopsAsync = ref.watch(myShopsProvider(uid));

    return shopsAsync.when(
      data: (shops) {
        if (shops.isEmpty) return Center(child: Text(context.l('create_shop') ?? 'Create a shop first.'));
        final shop = shops.first;
        final salesAsync = ref.watch(_todaySalesProvider(shop.id));

        return Scaffold(
          appBar: AppBar(title: Text('${shop.name} – ${context.l('sales_reports') ?? "Sales Reports"}')),
          body: salesAsync.when(
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
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Color(0xFFE5E5EA), width: 1)),
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
                                    color: const Color(0xFF8E8E93),
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${NumberFormat('#,###').format(totalRevenue)} sum',
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
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
                                  color: const Color(0xFF8E8E93),
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 200),
                      itemCount: snap.docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
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
                            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                            child: Text(
                              'x$quantity',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          title: Text(productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(
                            '${NumberFormat('#,###').format(price)} sum × $quantity',
                            style: const TextStyle(color: Color(0xFF8E8E93)),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${NumberFormat('#,###').format(total)} sum',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                timeStr,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: const Color(0xFF8E8E93)),
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
          ),
        );
      },
      error: (e, _) => Center(child: Text('${context.l("error") ?? "Error"}: $e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

final _todaySalesProvider =
    StreamProvider.family<QuerySnapshot<Map<String, dynamic>>, String>((ref, shopId) {
  return ref
      .watch(salesRepositoryProvider)
      .streamDailySales(shopId: shopId, day: DateTime.now());
});
