import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../core/shared_providers.dart';
import '../../shared/models/expense_model.dart';
import '../../shared/models/inventory_model.dart';
import '../../core/localization.dart';
import '../../shared/models/sale_model.dart';
import '../../shared/models/shop_model.dart';
import '../marketplace/shop_repository.dart';
import '../sales/sales_repository.dart';
import 'expense_repository.dart';
import '../auth/auth_repository.dart';

import '../notifications/notification_repository.dart';
import '../../shared/models/notification_model.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return Center(child: Text(context.l('not_logged_in') ?? 'Please sign in.'));

    final myShopsAsync = ref.watch(myShopsProvider(uid));

    return myShopsAsync.when(
      data: (shops) {
        final shop = shops.isEmpty ? null : shops.first;
        if (shop == null) return _CreateShopCard(ownerId: uid);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text(context.l('dashboard') ?? 'Dashboard'),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            actions: [
              _NotificationBell(shopId: shop.id),
              IconButton(
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout, color: Colors.red),
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/auth');
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push('/seller/settings'),
              ),
            ],
          ),
          body: _SubscriptionGatedDashboard(shop: shop),
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(bottom: 150),
            child: FloatingActionButton.extended(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useRootNavigator: true,
                builder: (_) => _AddExpenseSheet(shopId: shop.id),
              ),
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.money_off),
              label: Text(context.l('add_expense') ?? 'Add Expense', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        );
      },
      error: (e, _) => Center(child: Text('${context.l("error") ?? "Error"}: $e')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

/// Wraps the dashboard with a subscription check.
/// If inactive → shows blur overlay + upgrade card on top.
class _SubscriptionGatedDashboard extends ConsumerWidget {
  final ShopModel shop;
  const _SubscriptionGatedDashboard({required this.shop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(subscriptionActiveProvider(shop.id));

    return subAsync.when(
      data: (isActive) {
        if (isActive) return _DashboardContent(shop: shop);

        // Inactive: show blurred dashboard + lock overlay
        return Stack(
          children: [
            // Blurred real content underneath
            IgnorePointer(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: _DashboardContent(shop: shop),
              ),
            ),
            // Dark overlay
            Container(color: Colors.black.withOpacity(0.45)),
            // Upgrade card
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 40,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 32),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Obuna kerak',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Dashboard va barcha seller funksiyalaridan foydalanish uchun obuna oling.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.65),
                            ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => context.push('/seller/subscription'),
                          icon: const Icon(Icons.star_rounded),
                          label: const Text('Obuna olish', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _DashboardContent(shop: shop),
    );
  }
}

class _DashboardContent extends ConsumerStatefulWidget {
  final ShopModel shop;
  const _DashboardContent({required this.shop});

  @override
  ConsumerState<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<_DashboardContent> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    end: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59),
  );
  String _filterLabel = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filterLabel == '' || _filterLabel == 'Bugun' || _filterLabel == 'Сегодня') {
      _filterLabel = context.l('today');
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(salesByShopProvider(widget.shop.id));
    final expensesAsync = ref.watch(expensesByShopProvider(widget.shop.id));
    final inventoryItemsAsync = ref.watch(inventoryByShopProvider(widget.shop.id));

    final bool fullyLoading = salesAsync.isLoading && expensesAsync.isLoading;
    if (fullyLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (salesAsync.hasError || expensesAsync.hasError) {
      final error = salesAsync.error ?? expensesAsync.error;
      final errStr = error.toString();
      if (errStr.contains('requires an index')) {
        final urlMatch = RegExp(r'https://console\.firebase\.google\.com[^\s]*').firstMatch(errStr);
        final url = urlMatch?.group(0);

        return Scaffold(
          backgroundColor: const Color(0xFFFCFCFD),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Firestore index talab qilinadi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Dashboard hisob-kitoblarini ko\'rish uchun Firestore-da quyidagi indexni yaratishingiz kerak:',
                    textAlign: TextAlign.center,
                  ),
                  if (url != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E5EA))),
                      child: SelectableText(
                        url,
                        style: const TextStyle(color: Colors.blue, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(context.l('copy_link') ?? 'Yuqoridagi havolani nusxalab brauzerda oching.', style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                  ],
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () {
                      ref.invalidate(salesByShopProvider(widget.shop.id));
                      ref.invalidate(expensesByShopProvider(widget.shop.id));
                      setState(() {});
                    },
                    child: Text(context.l('refresh') ?? 'Qayta tekshirish'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      return Center(child: Text('${context.l("error") ?? "Error"}: $error'));
    }

    final sales = salesAsync.asData?.value ?? [];
    final expenses = expensesAsync.asData?.value ?? [];
    final inventories = inventoryItemsAsync.asData?.value ?? [];

    int revenue = 0, exp = 0;

    for (final s in sales) {
      if (!s.createdAt.isBefore(_dateRange.start) && !s.createdAt.isAfter(_dateRange.end)) {
        revenue += s.total.toInt();
      }
    }
    for (final e in expenses) {
      if (!e.createdAt.isBefore(_dateRange.start) && !e.createdAt.isAfter(_dateRange.end)) {
        exp += e.amount.toInt();
      }
    }

    final profit = revenue - exp;

    // Top Products
    final Map<String, int> productSales = {};
    for (final s in sales) {
      productSales[s.inventoryId] = (productSales[s.inventoryId] ?? 0) + s.quantity.toInt();
    }
    final top3 = (productSales.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 200),
      children: [
        // ── Tab Toggle ──────────────────────────────────────────────
        // ── Filter Selector ──────────────────────────────────────
        GestureDetector(
          onTap: () => _showFilterSheet(context),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _filterLabel,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
                Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Stat Cards ──────────────────────────────────────────────
        Row(children: [
          Expanded(child: _StatCard(title: context.l('revenue') ?? 'Daromad', value: revenue, type: _CardType.revenue)),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(title: context.l('expenses') ?? 'Xarajat', value: exp,     type: _CardType.expense)),
        ]),
        const SizedBox(height: 12),
        _StatCard(
          title: profit >= 0 ? (context.l('profit') ?? 'Foyda') : (context.l('loss') ?? 'Kamomad'),
          value: profit.abs(),
          type: profit >= 0 ? _CardType.profit : _CardType.loss,
          isNegative: profit < 0,
          wide: true,
        ),

        const SizedBox(height: 32),
        Text(context.l('revenue_7_days') ?? 'So\'nggi 7 kun daromad', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5)),
        const SizedBox(height: 16),
        _buildRevenueChart(sales),
        const SizedBox(height: 32),
        Text(context.l('top_selling') ?? 'Eng ko\'p sotilgan', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5)),
        const SizedBox(height: 16),
        _buildTopProducts(context, top3, inventories),
        const SizedBox(height: 32),
        Text(context.l('low_stock_items') ?? 'Kam qolgan mahsulotlar', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Colors.redAccent, letterSpacing: -0.5)),
        const SizedBox(height: 16),
        _buildLowStockAlerts(context, ref, inventories),
        const SizedBox(height: 32),
        Text(context.l('recent_sales') ?? 'So\'nggi savdolar', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5)),
        const SizedBox(height: 16),
        _buildRecentSales(sales, inventories),
      ],
    );
  }

  Widget _buildRecentSales(List<SaleModel> sales, List<InventoryModel> inventories) {
    if (sales.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor, 
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
        ),
        child: Center(child: Text(context.l('no_recent_sales') ?? 'Hali savdo yo\'q', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
      );
    }

    final recent = sales.take(10).toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.light ? 0.05 : 0.2), 
            blurRadius: 20, 
            offset: const Offset(0, 4)
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recent.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, idx) {
          final s = recent[idx];
          final inv = inventories.cast<InventoryModel?>().firstWhere((i) => i?.id == s.inventoryId, orElse: () => null);
          final date = s.createdAt;
          final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
          
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest, 
                borderRadius: BorderRadius.circular(12)
              ),
              child: Icon(Icons.receipt_outlined, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
            ),
            title: Text(inv?.name ?? 'Mahsulot', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Theme.of(context).colorScheme.onSurface)),
            subtitle: Text('${s.quantity} ${context.l("items") ?? "dona"} • $timeStr', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            trailing: Text('${s.price * s.quantity} sum', style: TextStyle(fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurface)),
          );
        },
      ),
    );
  }




  Widget _buildRevenueChart(List<SaleModel> sales) {
    final now = DateTime.now();
    // 7 days ago, normalized to midnight
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    
    // Aggregate by day diff from start
    final Map<int, int> dailyTotals = {for (var i = 0; i < 7; i++) i: 0};
    
    for (final s in sales) {
      if (s.createdAt.isAfter(start)) {
        final diff = s.createdAt.difference(start).inDays;
        if (diff >= 0 && diff <= 6) {
          dailyTotals[diff] = (dailyTotals[diff] ?? 0) + s.total;
        }
      }
    }

    final barGroups = dailyTotals.entries.map((e) {
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: e.value.toDouble(),
            color: Theme.of(context).colorScheme.primary,
            width: 16,
            borderRadius: BorderRadius.circular(4),
          )
        ],
      );
    }).toList();

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(Theme.of(context).brightness == Brightness.light ? 0.05 : 0.2), 
            blurRadius: 20, 
            offset: const Offset(0, 4)
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide y axis to keep it clean, or format
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value > 6) return const SizedBox.shrink();
                  final date = start.add(Duration(days: value.toInt()));
                  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(days[date.weekday - 1], style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  );
                },
              ),
            ),
          ),
          barGroups: barGroups,
        ),
      ),
    );
  }

  Widget _buildTopProducts(BuildContext context, List<MapEntry<String, int>> topItems, List<InventoryModel> inventories) {
    if (topItems.isEmpty) {
      return Text(context.l('no_recent_sales') ?? 'No sales yet.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));
    }
    
    return Column(
      children: topItems.map((entry) {
        final inv = inventories.where((i) => i.id == entry.key).firstOrNull;
        if (inv == null) return const SizedBox.shrink();
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.05)),
          ),
          child: Row(
            children: [
               if (inv.imageUrls.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(inv.imageUrls.first, width: 48, height: 48, fit: BoxFit.cover),
                  )
                else
                  Container(
                    width: 48, height: 48, 
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(Icons.image, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(inv.name, style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                    Text('${entry.value} ${context.l("items") ?? "dona"}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l('select_range'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 24),
            _FilterOption(
              label: context.l('today') ?? 'Bugun',
              icon: Icons.today_rounded,
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                if (mounted) {
                  setState(() {
                    _dateRange = DateTimeRange(
                      start: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
                      end: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59),
                    );
                    _filterLabel = context.l('today');
                  });
                }
              },
            ),
            _FilterOption(
              label: context.l('this_month'),
              icon: Icons.calendar_month_rounded,
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                if (mounted) {
                  setState(() {
                    final now = DateTime.now();
                    _dateRange = DateTimeRange(
                      start: DateTime(now.year, now.month, 1),
                      end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
                    );
                    _filterLabel = context.l('this_month');
                  });
                }
              },
            ),
            _FilterOption(
              label: context.l('custom_range'),
              icon: Icons.date_range_rounded,
              onTap: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2023),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                          surface: Theme.of(context).cardColor,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() {
                    _dateRange = DateTimeRange(
                      start: picked.start,
                      end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59),
                    );
                    _filterLabel = '${picked.start.day}.${picked.start.month} - ${picked.end.day}.${picked.end.month}';
                  });
                }
                if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockAlerts(BuildContext context, WidgetRef ref, List<InventoryModel> inventories) {
    // For low stock, we need to find variants across all inventories.
    // Instead of querying all variants upfront for all inventories (which could be heavy), 
    // we use a Consumer to fetch variants for each inventory efficiently via caching.
    // However, a simpler way is a custom widget that streams variants internally.
    
    if (inventories.isEmpty) return Text(context.l('no_products_found') ?? 'No items in inventory.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant));

    return Column(
      children: inventories.map((inv) => _InventoryStockAlert(inventory: inv)).toList(),
    );
  }
}

class _InventoryStockAlert extends ConsumerWidget {
  final InventoryModel inventory;
  const _InventoryStockAlert({required this.inventory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final variantsAsync = ref.watch(variantsByInventoryProvider(inventory.id));
    
    return variantsAsync.when(
      data: (variants) {
        final lowStockVariants = variants.where((v) => v.stock <= 5).toList();
        if (lowStockVariants.isEmpty) return const SizedBox.shrink();
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withOpacity(Theme.of(context).brightness == Brightness.light ? 0.05 : 0.1), 
                blurRadius: 10, 
                offset: const Offset(0, 4)
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(inventory.name, style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: 8),
              ...lowStockVariants.map((v) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${v.color} - ${v.size}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                  Text('${v.stock} ${context.l("stock") ?? "left"}', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              )),
            ],
          ),
        );
      },
      error: (_, __) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }
}


class _FilterOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _FilterOption({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

enum _CardType { revenue, expense, profit, loss }



class _StatCard extends StatelessWidget {
  final String title;
  final int value;
  final _CardType type;
  final bool isNegative;
  final bool wide;

  const _StatCard({
    required this.title,
    required this.value,
    required this.type,
    this.isNegative = false,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    // Color palette by card type
    final (Color baseColor, IconData icon) = switch (type) {
      _CardType.revenue => (const Color(0xFF3B82F6), Icons.trending_up_rounded),
      _CardType.expense => (const Color(0xFFF97316), Icons.receipt_long_outlined),
      _CardType.profit  => (const Color(0xFF22C55E), Icons.account_balance_wallet_outlined),
      _CardType.loss    => (const Color(0xFFEF4444), Icons.trending_down_rounded),
    };

    final formattedValue = value
        .toString()
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

    return Container(
      width: wide ? double.infinity : null,
      padding: EdgeInsets.all(wide ? 20 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withOpacity(0.85),
            baseColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -8,
            child: Icon(icon, size: 72, color: Colors.white.withOpacity(0.12)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      '$formattedValue sum',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: wide ? 26 : 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (isNegative) ...[
                const SizedBox(height: 4),
                const Text('⚠ Zarar — xarajat daromaddan yuqori', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}


class _AddExpenseSheet extends ConsumerStatefulWidget {
  final String shopId;
  const _AddExpenseSheet({required this.shopId});

  @override
  ConsumerState<_AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends ConsumerState<_AddExpenseSheet> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _category = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(width: 36, height: 5, decoration: BoxDecoration(color: const Color(0xFFC7C7CC), borderRadius: BorderRadius.circular(2.5))),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(context.l('add_expense') ?? 'Add Expense', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1.0)),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest, radius: 14, child: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.onSurface)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 80),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _buildSmallField(_title, 'Title', 'e.g. Rent, Electricity'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                       Expanded(child: _buildSmallField(_amount, 'Amount', 'сум', keyboard: TextInputType.number)),
                       const SizedBox(width: 8),
                       Expanded(child: _buildSmallField(_category, 'Category', 'e.g. Utility')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
             padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset > 0 ? 16 : 40),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
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
                    onPressed: _busy ? _save : _save,
                    child: Text(_busy ? '${context.l("saving") ?? "SAVING"}...' : (context.l('save') ?? 'SAVE EXPENSE').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)),
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
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label, hintText: hint, border: InputBorder.none,
          labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.w600),
          isDense: true,
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final amount = int.tryParse(_amount.text.trim()) ?? 0;
    
    if (title.isEmpty || amount <= 0) return;

    setState(() => _busy = true);
    try {
      final expense = ExpenseModel(
        id: '',
        shopId: widget.shopId,
        title: title,
        amount: amount,
        category: _category.text.trim(),
        createdAt: DateTime.now(),
      );

      await ref.read(expenseRepositoryProvider).addExpense(expense);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// -------------------------------------------------------------
// The below code is a modified version of the _CreateShopCard
// migrated from the previous simplified dashboard setup.
// -------------------------------------------------------------
class _CreateShopCard extends ConsumerStatefulWidget {
  final String ownerId;
  const _CreateShopCard({required this.ownerId});

  @override
  ConsumerState<_CreateShopCard> createState() => _CreateShopCardState();
}

class _CreateShopCardState extends ConsumerState<_CreateShopCard> {
  final _name = TextEditingController();
  final _telegram = TextEditingController();
  final _about = TextEditingController();
  final _phone = TextEditingController();
  ShopGenre _genre = ShopGenre.clothes;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;
  bool _busy = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImage = picked;
        _pickedImageBytes = bytes;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _telegram.dispose();
    _about.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: _busy ? null : _pickImage,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.3)),
                image: _pickedImageBytes != null 
                    ? DecorationImage(image: MemoryImage(_pickedImageBytes!), fit: BoxFit.cover) 
                    : null,
              ),
              child: _pickedImageBytes == null 
                  ? const Icon(Icons.add_a_photo_outlined, size: 32, color: Colors.blue) 
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Shop name')),
        const SizedBox(height: 12),
        DropdownButtonFormField<ShopGenre>(
          value: _genre,
          items: ShopGenre.values.map((g) => DropdownMenuItem(
            value: g,
            child: Text(g.label),
          )).toList(),
          onChanged: _busy ? null : (v) => setState(() => _genre = v ?? ShopGenre.clothes),
          decoration: const InputDecoration(labelText: 'Genre'),
        ),
        const SizedBox(height: 12),
        TextField(controller: _telegram, decoration: const InputDecoration(labelText: 'Telegram')),
        const SizedBox(height: 12),
        TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
        const SizedBox(height: 12),
        TextField(
          controller: _about,
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'About'),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy
              ? null
              : () async {
                  if (_name.text.trim().isEmpty) return;
                  setState(() => _busy = true);
                  try {
                    String imageUrl = '';
                    if (_pickedImage != null && _pickedImageBytes != null) {
                      final shopIdPre = 'shop_${DateTime.now().millisecondsSinceEpoch}';
                      imageUrl = await ref.read(shopRepositoryProvider).uploadShopImage(
                        shopId: shopIdPre,
                        bytes: _pickedImageBytes!,
                        fileName: 'profile.jpg',
                      );
                    }

                    final shop = ShopModel(
                      id: '',
                      name: _name.text.trim(),
                      ownerId: widget.ownerId,
                      genre: _genre,
                      telegram: _telegram.text.trim(),
                      about: _about.text.trim(),
                      phone: _phone.text.trim(),
                      image: imageUrl,
                      createdAt: DateTime.now(),
                    );
                    await ref.read(shopRepositoryProvider).createShop(shop);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Shop created')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: Text(_busy ? 'Creating...' : 'Create shop'),
        ),
      ],
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  final String shopId;
  const _NotificationBell({required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(unreadNotificationsProvider(shopId));

    return notificationsAsync.when(
      data: (notifications) {
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: Colors.black87),
              onPressed: () => _showNotifications(context, notifications),
            ),
            if (notifications.isNotEmpty)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text(
                    notifications.length > 9 ? '9+' : '${notifications.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
      error: (_, __) => IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
      loading: () => IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
    );
  }

  void _showNotifications(BuildContext context, List<NotificationModel> notifications) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NotificationSheet(notifications: notifications),
    );
  }
}

class _NotificationSheet extends ConsumerWidget {
  final List<NotificationModel> notifications;
  const _NotificationSheet({required this.notifications});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l('notifications') ?? 'Notifications', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest, radius: 14, child: Icon(Icons.close, size: 16, color: Theme.of(context).colorScheme.onSurface)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (notifications.isEmpty)
            Expanded(child: Center(child: Text(context.l('no_products_found') ?? 'No new notifications', style: const TextStyle(color: Color(0xFF8E8E93)))))
          else
            Expanded(
              child: ListView.separated(
                itemCount: notifications.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final n = notifications[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest, child: const Icon(Icons.star, color: Color(0xFFFBBF24), size: 18)),
                    title: Text(n.title, style: TextStyle(fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(n.body, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
                      onPressed: () => ref.read(notificationRepositoryProvider).markAsRead(n.id),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
