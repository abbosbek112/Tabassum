import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../core/constants.dart';
import '../../core/providers.dart';
import '../../core/shared_providers.dart';
import '../../shared/models/shop_model.dart';
import '../subscription/subscription_repository.dart';
import '../auth/models/user_model.dart';
import '../auth/auth_repository.dart';
import '../auth/auth_controller.dart';
import '../../core/localization.dart';
import '../../core/twa_service.dart';

// ─── Provider: all users stream ──────────────────────────────────────────────
final _allUsersStreamProvider = StreamProvider<List<UserModel>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection(FirestoreCollections.users)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((q) => q.docs.map((d) => UserModel.fromMap(d.id, d.data())).toList());
});

// ─── Provider: all shops stream ──────────────────────────────────────────────
final _allShopsStreamProvider = StreamProvider<List<ShopModel>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection(FirestoreCollections.shops)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((q) => q.docs.map((d) => ShopModel.fromMap(d.id, d.data())).toList());
});

// ─── Provider: All Subscription History ──────────────────────────────────────
final _allHistoryStreamProvider = StreamProvider<List<SubscriptionHistoryModel>>((ref) {
  return ref.watch(subscriptionRepositoryProvider).streamSubscriptionHistory();
});

// ─── Admin Screen ─────────────────────────────────────────────────────────────
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).user;
    final isAdmin = user?.role == UserRole.admin;
    
    if (!isAdmin) {
      return _AccessDenied();
    }
    return const DefaultTabController(
      length: 3,
      child: _AdminBody(),
    );
  }
}

// ─── Access Denied ──────────────────────────────────────────────────────────
class _AccessDenied extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, color: Colors.red, size: 40),
                ),
                const SizedBox(height: 24),
                Text('Ruxsat yo\'q', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: cs.onSurface)),
                const SizedBox(height: 8),
                Text(
                  'Bu sahifa faqat adminlar uchun.',
                  style: TextStyle(fontSize: 14, color: cs.onSurface.withOpacity(0.5)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.go('/market'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('Asosiy sahifaga qaytish', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// ─── Admin Body ───────────────────────────────────────────────────────────────
class _AdminBody extends ConsumerStatefulWidget {
  const _AdminBody();

  @override
  ConsumerState<_AdminBody> createState() => _AdminBodyState();
}

class _AdminBodyState extends ConsumerState<_AdminBody> {
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
    final cs = Theme.of(context).colorScheme;
    final twa = ref.watch(twaServiceProvider);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        leading: twa.isSupported ? const SizedBox.shrink() : null,
        title: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: cs.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.admin_panel_settings_rounded, color: cs.primary, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Admin Panel', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            ],
          ),
        ),
        bottom: TabBar(
          indicatorColor: cs.primary,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurface.withOpacity(0.4),
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: const [
            Tab(text: 'Dashboard', icon: Icon(Icons.analytics_rounded, size: 20)),
            Tab(text: 'Do\'konlar', icon: Icon(Icons.storefront_rounded, size: 20)),
            Tab(text: 'Foydalanuvchilar', icon: Icon(Icons.people_rounded, size: 20)),
          ],
        ),
        backgroundColor: cs.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: const TabBarView(
        children: [
          _DashboardTab(),
          _ShopsTab(),
          _UsersTab(),
        ],
      ),
    );
  }
}

class _ShopsTab extends ConsumerWidget {
  const _ShopsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(_allShopsStreamProvider);
    final cs = Theme.of(context).colorScheme;

    return shopsAsync.when(
      data: (shops) {
        if (shops.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_outlined, size: 56, color: cs.onSurface.withOpacity(0.2)),
                const SizedBox(height: 12),
                Text('Hech qanday do\'kon topilmadi', style: TextStyle(color: cs.onSurface.withOpacity(0.4))),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_allShopsStreamProvider),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            itemCount: shops.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) => _ShopSubscriptionCard(shop: shops[i]),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Xato: $e')),
    );
  }
}

// ─── Shop Card ────────────────────────────────────────────────────────────────
class _ShopSubscriptionCard extends ConsumerWidget {
  final ShopModel shop;
  const _ShopSubscriptionCard({required this.shop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(shopSubscriptionProvider(shop.id));
    final cs = Theme.of(context).colorScheme;

    return subAsync.when(
      data: (sub) {
        final isActive = sub != null &&
            sub.status == 'active' &&
            sub.endDate.isAfter(DateTime.now());
        final daysLeft = isActive ? sub.endDate.difference(DateTime.now()).inDays : 0;

        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF10B981).withOpacity(0.25)
                  : cs.outline.withOpacity(0.15),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Shop logo OR initial
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          shop.name.isNotEmpty ? shop.name[0].toUpperCase() : '?',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: cs.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop.name.isEmpty ? '(Nomsiz do\'kon)' : shop.name,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          Text(
                            'ID: ${shop.id}',
                            style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.35), fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Status badge
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatusBadge(isActive: isActive, daysLeft: daysLeft),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: () => _showShopHistory(context, ref, shop),
                          icon: const Icon(Icons.history_rounded, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          style: IconButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (sub != null && isActive) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Tugash: ${_fmt(sub.endDate)}',
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.45), fontWeight: FontWeight.w600),
                  ),
                ],

                const SizedBox(height: 14),
                Row(
                  children: [
                    // Activate button
                    Expanded(
                      child: _ActivateButton(shop: shop, isActive: isActive),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: 10),
                      // Expire button
                      OutlinedButton.icon(
                        onPressed: () => _confirmExpire(context, ref, shop),
                        icon: Icon(Icons.block_rounded, size: 16, color: cs.error),
                        label: Text('Bloklash', style: TextStyle(color: cs.error, fontWeight: FontWeight.w700)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: cs.error.withOpacity(0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Xato: $e'),
    );
  }


  void _showShopHistory(BuildContext context, WidgetRef ref, ShopModel shop) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _ShopHistorySheet(shop: shop),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';

  void _confirmExpire(BuildContext context, WidgetRef ref, ShopModel shop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Obunani bekor qilish', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('${shop.name} do\'konining obunasi bekor qilinadi. Mahsulotlari marketplace dan yo\'qoladi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Yoq')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(subscriptionRepositoryProvider).expire(shop.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${shop.name} obunasi bekor qilindi'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Ha, bekor qil'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  final int daysLeft;

  const _StatusBadge({required this.isActive, required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF10B981).withOpacity(0.12)
            : cs.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF10B981) : cs.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? '$daysLeft kun' : 'Faol emas',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isActive ? const Color(0xFF10B981) : cs.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopHistorySheet extends ConsumerWidget {
  final ShopModel shop;
  const _ShopHistorySheet({required this.shop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_allHistoryStreamProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.history_rounded, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${shop.name} — To\'lovlar tarixi', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        Expanded(
          child: historyAsync.when(
            data: (history) {
              final shopHistory = history.where((h) => h.shopId == shop.id).toList();
              if (shopHistory.isEmpty) {
                return Center(child: Text('Tarix bo\'sh', style: TextStyle(color: cs.onSurface.withOpacity(0.4))));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: shopHistory.length,
                itemBuilder: (ctx, i) => _HistoryListItem(item: shopHistory[i]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Xato: $e')),
          ),
        ),
      ],
    );
  }
}

// ─── Activate Button (with duration picker) ──────────────────────────────────
class _ActivateButton extends ConsumerWidget {
  final ShopModel shop;
  final bool isActive;
  const _ActivateButton({required this.shop, required this.isActive});

  static const _durations = [
    ('30 kun (1 oy)', Duration(days: 30)),
    ('90 kun (3 oy)', Duration(days: 90)),
    ('180 kun (6 oy)', Duration(days: 180)),
    ('365 kun (1 yil)', Duration(days: 365)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    return FilledButton.icon(
      onPressed: () => _showDurationPicker(context, ref),
      icon: Icon(isActive ? Icons.refresh_rounded : Icons.star_rounded, size: 18),
      label: Text(
        isActive ? 'Uzaytirish' : 'Faollashtirish',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: isActive ? cs.secondaryContainer : cs.primary,
        foregroundColor: isActive ? cs.onSecondaryContainer : cs.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  void _showDurationPicker(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: cs.onSurface.withOpacity(0.15),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            Text(
              shop.name.isEmpty ? 'Do\'kon' : shop.name,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text('Necha kunlik obuna bermoqchisiz?', style: TextStyle(color: cs.onSurface.withOpacity(0.5), fontSize: 13)),
            const SizedBox(height: 20),
            ..._durations.map((d) => _DurationTile(
                  label: d.$1,
                  duration: d.$2,
                  shop: shop,
                  onSelected: () => Navigator.pop(ctx),
                )),
          ],
        ),
      ),
    );
  }
}

class _DurationTile extends ConsumerStatefulWidget {
  final String label;
  final Duration duration;
  final ShopModel shop;
  final VoidCallback onSelected;
  const _DurationTile({required this.label, required this.duration, required this.shop, required this.onSelected});

  @override
  ConsumerState<_DurationTile> createState() => _DurationTileState();
}

class _DurationTileState extends ConsumerState<_DurationTile> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _loading ? null : _activate,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 20, color: cs.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                if (_loading)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: cs.onSurface.withOpacity(0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _activate() async {
    // 1. Show amount picker dialog
    final amountController = TextEditingController();
    final amount = await showDialog<int?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('To\'lov summasini kiriting', style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Masalan: 50000',
            suffixText: 'UZS',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Bekor qilish')),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(amountController.text);
              Navigator.pop(ctx, val);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );

    if (amount == null) return;

    setState(() => _loading = true);
    try {
      await ref.read(subscriptionRepositoryProvider).activate(
            shopId: widget.shop.id,
            duration: widget.duration,
            amount: amount,
          );
      widget.onSelected();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${widget.shop.name} — ${widget.label} obuna berildi'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xato: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─── Dashboard Tab ───────────────────────────────────────────────────────────
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_allHistoryStreamProvider);
    final cs = Theme.of(context).colorScheme;

    return historyAsync.when(
      data: (history) {
        if (history.isEmpty) {
          return Center(
            child: Text('Hozircha hech qanday to\'lov yo\'q', style: TextStyle(color: cs.onSurface.withOpacity(0.4))),
          );
        }

        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final monthStart = DateTime(now.year, now.month, 1);
        final yearStart = DateTime(now.year, 1, 1);

        int revenueToday = 0;
        int revenueMonth = 0;
        int revenueYear = 0;

        for (final item in history) {
          if (item.activatedAt.isAfter(todayStart)) revenueToday += item.amount;
          if (item.activatedAt.isAfter(monthStart)) revenueMonth += item.amount;
          if (item.activatedAt.isAfter(yearStart)) revenueYear += item.amount;
        }

        final activeSubs = history.where((h) => h.activatedAt.add(h.duration).isAfter(now)).length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(child: _SummaryCard(title: 'Barcha Foyda', value: '${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(history.fold<int>(0, (sum, item) => sum + item.amount))} so\'m', color: Colors.indigo, icon: Icons.account_balance_wallet_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _SummaryCard(title: 'Faol Do\'konlar', value: activeSubs.toString(), color: Colors.teal, icon: Icons.store_mall_directory_rounded)),
              ],
            ),
            const SizedBox(height: 24),
            Text('Tushumlar (Vaqt bo\'yicha)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: cs.onSurface)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _RevenueCard(title: 'Bugun', amount: revenueToday, color: Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _RevenueCard(title: 'Shu oy', amount: revenueMonth, color: Colors.green)),
              ],
            ),
            const SizedBox(height: 12),
            _RevenueCard(title: 'Shu yil', amount: revenueYear, color: Colors.orange, isFullWidth: true),
            const SizedBox(height: 24),
            // --- REPAIR TOOL ---
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.primary.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.build_circle_rounded, color: cs.primary, size: 20),
                      const SizedBox(width: 8),
                      const Text('Tizimni sozlash', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agar obunasi bor do\'konlar yoki mahsulotlar Marketda ko\'rinmayotgan bo\'lsa, ushbu tugmani bosing.',
                    style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _repairAllSubscriptionData(context, ref),
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                      label: const Text('Barcha ma\'lumotlarni yangilash (Fix All)', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('So\'nggi tranzaksiyalar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface)),
                TextButton(
                  onPressed: () => _showAllHistory(context, history),
                  child: const Text('Hammasini ko\'rish'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...history.take(15).map((h) => _HistoryListItem(item: h)),
            const SizedBox(height: 100),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Xato: $e')),
    );
  }

  void _showAllHistory(BuildContext context, List<SubscriptionHistoryModel> history) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => _AllHistorySheet(history: history),
    );
  }

  Future<void> _repairAllSubscriptionData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ma\'lumotlarni tuzatish'),
        content: const Text('Ushbu amal barcha do\'konlar va mahsulotlarning obuna holatini qayta tekshirib chiqadi. Bu bir necha soniya vaqt olishi mumkin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Bekor qilish')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Davom etish')),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Ma\'lumotlar yangilanmoqda, iltimos kuting...')),
          ],
        ),
      ),
    );

    try {
      final db = ref.read(firestoreProvider);
      
      // Fetch active subscription shop IDs
      final subSnap = await db.collection(FirestoreCollections.subscriptions).get();
      final activeShopIds = <String>{};
      final now = DateTime.now();

      for (var doc in subSnap.docs) {
        final data = doc.data();
        if (data['status'] == 'active') {
          activeShopIds.add(doc.id);
        }
      }

      // Update ALL shops
      final shopSnap = await db.collection(FirestoreCollections.shops).get();
      final batch = db.batch();
      for (var doc in shopSnap.docs) {
        final isActive = activeShopIds.contains(doc.id);
        batch.update(doc.reference, {'subscriptionActive': isActive});
      }
      await batch.commit();

      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Tayyor!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xato: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5), fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _AllHistorySheet extends StatelessWidget {
  final List<SubscriptionHistoryModel> history;
  const _AllHistorySheet({required this.history});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.onSurface.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text('Barcha to\'lovlar (${history.length})', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: history.length,
            itemBuilder: (ctx, i) => _HistoryListItem(item: history[i]),
          ),
        ),
      ],
    );
  }
}

class _RevenueCard extends StatelessWidget {
  final String title;
  final int amount;
  final Color color;
  final bool isFullWidth;

  const _RevenueCard({required this.title, required this.amount, required this.color, this.isFullWidth = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(locale: 'uz_UZ', symbol: 'so\'m', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: isFullWidth ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 8),
          Text(
            fmt.format(amount),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}

class _HistoryListItem extends ConsumerWidget {
  final SubscriptionHistoryModel item;
  const _HistoryListItem({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shopsAsync = ref.watch(_allShopsStreamProvider);
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0);
    final dateFmt = DateFormat('dd.MM.yyyy HH:mm');

    final shopName = shopsAsync.when(
      data: (shops) {
        try {
          return shops.firstWhere((s) => s.id == item.shopId).name;
        } catch (_) {
          return 'Nomalum do\'kon';
        }
      },
      loading: () => '...',
      error: (_, __) => 'Error',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.add_shopping_cart_rounded, color: Color(0xFF10B981), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shopName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(dateFmt.format(item.activatedAt), style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.4))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('+${fmt.format(item.amount)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF10B981))),
              Text('${item.duration.inDays} kun', style: TextStyle(fontSize: 11, color: cs.onSurface.withOpacity(0.4))),
            ],
          ),
        ],
      ),
    );
  }
}
// ─── Users Tab ────────────────────────────────────────────────────────────────
class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();
  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  final _searchCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(_allUsersStreamProvider);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Ism yoki email bo\'yicha qidirish...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              filled: true,
              fillColor: cs.surfaceContainerLow,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
        Expanded(
          child: usersAsync.when(
            data: (users) {
              final query = _searchCtrl.text.toLowerCase();
              final filtered = users.where((u) {
                return u.displayName.toLowerCase().contains(query) || u.email.toLowerCase().contains(query);
              }).toList();

              if (filtered.isEmpty) return const Center(child: Text('Foydalanuvchilar topilmadi'));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filtered.length,
                itemBuilder: (ctx, i) => _UserListItem(user: filtered[i]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Xato: $e')),
          ),
        ),
      ],
    );
  }
}

class _UserListItem extends ConsumerWidget {
  final UserModel user;
  const _UserListItem({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isSeller = user.role == UserRole.seller;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: (isSeller ? cs.primary : cs.secondary).withOpacity(0.1),
            child: Text(
              (user.displayName.isNotEmpty ? user.displayName[0] : user.email[0]).toUpperCase(),
              style: TextStyle(color: isSeller ? cs.primary : cs.secondary, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName.isNotEmpty ? user.displayName : 'Ismsiz', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Row(
                  children: [
                    Text(user.email, style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5))),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (user.role == UserRole.admin ? Colors.purple : (user.role == UserRole.seller ? cs.primary : cs.secondary)).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        context.l(user.role.asString).toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: user.role == UserRole.admin ? Colors.purple : (user.role == UserRole.seller ? cs.primary : cs.secondary),
                        ),
                      ),
                    ),
                  ],
                ),
                if (user.phoneNumber.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.phone_rounded, size: 10, color: cs.primary),
                        const SizedBox(width: 4),
                        Text(user.phoneNumber, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (user.telegramUsername.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: () => launchUrl(Uri.parse('https://t.me/${user.telegramUsername}')),
                icon: const Icon(Icons.send_rounded, color: Color(0xFF0088CC), size: 20),
                tooltip: 'Telegram',
              ),
            ),
          _RoleToggleButton(user: user),
        ],
      ),
    );
  }
}

class _RoleToggleButton extends ConsumerStatefulWidget {
  final UserModel user;
  const _RoleToggleButton({required this.user});

  @override
  ConsumerState<_RoleToggleButton> createState() => _RoleToggleButtonState();
}

class _RoleToggleButtonState extends ConsumerState<_RoleToggleButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final isSeller = widget.user.role == UserRole.seller;
    final cs = Theme.of(context).colorScheme;

    return _busy
        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
        : FilledButton(
            onPressed: () async {
              setState(() => _busy = true);
              try {
                final newRole = isSeller ? UserRole.customer : UserRole.seller;
                await ref.read(authRepositoryProvider).updateUserRole(uid: widget.user.uid, role: newRole);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xato: $e')));
                }
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: isSeller ? cs.errorContainer : cs.primaryContainer,
              foregroundColor: isSeller ? cs.error : cs.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isSeller ? 'MIJOZ QILISH' : 'SOTUVCHI QILISH',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
            ),
          );
  }
}
