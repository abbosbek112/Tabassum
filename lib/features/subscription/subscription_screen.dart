import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/shared_providers.dart';
import '../../core/providers.dart';
import '../subscription/subscription_repository.dart';
import '../auth/models/user_model.dart';

// ─── Config (o'zingiznikini kiriting) ───────────────────────────────────────
const _adminCardNumber = '9860 0301 2070 9966'; // ← admin karta raqami
const _adminCardHolder = 'Azizov Abbosbek';     // ← karta egasi ismi
const _adminTelegramUsername = 'abboc19';     // ← admin telegram username

const _plans = [
  _PlanOption(
    title: '1 Oy',
    subtitle: '30 kunlik to\'liq kirish',
    price: '49 000 so\'m',
    duration: Duration(days: 30),
    badge: null,
  ),
  _PlanOption(
    title: '3 Oy',
    subtitle: '90 kunlik to\'liq kirish',
    price: '129 000 so\'m',
    duration: Duration(days: 90),
    badge: 'TEJAMLI',
  ),
  _PlanOption(
    title: '1 Yil',
    subtitle: '365 kunlik to\'liq kirish',
    price: '399 000 so\'m',
    duration: Duration(days: 365),
    badge: 'ENG FOYDALI',
  ),
];

class _PlanOption {
  final String title;
  final String subtitle;
  final String price;
  final Duration duration;
  final String? badge;

  const _PlanOption({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.duration,
    this.badge,
  });
}

// ─── Screen ─────────────────────────────────────────────────────────────────
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  int _selectedPlan = 0;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final shopsAsync = ref.watch(myShopsProvider(uid));
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text(
          'Obuna',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.8),
        ),
        backgroundColor: cs.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: shopsAsync.when(
        data: (shops) {
          final shop = shops.isEmpty ? null : shops.first;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              // Hero banner
              _HeroBanner(isDark: isDark),
              const SizedBox(height: 28),

              // Active subscription card (if any)
              if (shop != null) ...[
                _ActiveSubscriptionCard(shopId: shop.id),
                const SizedBox(height: 28),
              ],

              // Plan selector
              Text(
                'TARIF REJASINI TANLANG',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: cs.onSurface.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 12),
              ..._plans.asMap().entries.map((e) => _PlanCard(
                    plan: e.value,
                    isSelected: _selectedPlan == e.key,
                    onTap: () => setState(() => _selectedPlan = e.key),
                  )),
              const SizedBox(height: 28),

              // Payment instructions
              _PaymentCard(isDark: isDark),
              const SizedBox(height: 28),

              // Steps
              _StepsSection(),
              const SizedBox(height: 28),

              // CTA button
              _TelegramButton(
                plan: _plans[_selectedPlan],
                shopName: shop?.name ?? '',
                uid: uid,
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Xato: $e')),
      ),
    );
  }
}

// ─── Hero Banner ─────────────────────────────────────────────────────────────
class _HeroBanner extends StatelessWidget {
  final bool isDark;
  const _HeroBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary,
            cs.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '⭐ PREMIUM',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Do\'koningizni\nokuvchilarga ko\'rsating',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Obuna bilan mahsulotlaringiz barcha xaridorlarga ko\'rinadi',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }
}

// ─── Current subscription status ─────────────────────────────────────────────
class _ActiveSubscriptionCard extends ConsumerWidget {
  final String shopId;
  const _ActiveSubscriptionCard({required this.shopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subAsync = ref.watch(shopSubscriptionProvider(shopId));
    final cs = Theme.of(context).colorScheme;

    return subAsync.when(
      data: (sub) {
        if (sub == null) return const SizedBox.shrink();
        final isActive = sub.status == 'active' && sub.endDate.isAfter(DateTime.now());
        if (!isActive) return const SizedBox.shrink();

        final remaining = sub.endDate.difference(DateTime.now()).inDays;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Obuna faol',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF10B981)),
                    ),
                    Text(
                      '$remaining kun qoldi (${_formatDate(sub.endDate)})',
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.55), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  String _formatDate(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
}

// ─── Plan Card ───────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final _PlanOption plan;
  final bool isSelected;
  final VoidCallback onTap;
  const _PlanCard({required this.plan, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withOpacity(0.08)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: cs.primary.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 4))]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  // Radio circle
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? cs.primary : cs.outline.withOpacity(0.4),
                        width: isSelected ? 2 : 1.5,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              plan.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: isSelected ? cs.primary : cs.onSurface,
                              ),
                            ),
                            if (plan.badge != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  plan.badge!,
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          plan.subtitle,
                          style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    plan.price,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isSelected ? cs.primary : cs.onSurface,
                      letterSpacing: -0.3,
                    ),
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

// ─── Payment Card ─────────────────────────────────────────────────────────────
class _PaymentCard extends StatelessWidget {
  final bool isDark;
  const _PaymentCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TO\'LOV REKVIZITLARI',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: cs.onSurface.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 12),
        // Bank card visual
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1E2E), const Color(0xFF2D2D44)]
                  : [const Color(0xFF1A1A2E), const Color(0xFF16213E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('HUMO', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('BANK KARTASI', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Card number
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _adminCardNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _adminCardNumber.replaceAll(' ', '')));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Karta raqam nusxalandi'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _adminCardHolder,
                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Steps ───────────────────────────────────────────────────────────────────
class _StepsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final steps = [
      ('1', Icons.credit_card_rounded, 'To\'lov qiling', 'Yuqoridagi karta raqamiga tanlangan tarif miqdorini o\'tkazing'),
      ('2', Icons.screenshot_monitor_rounded, 'Screenshot oling', 'To\'lov chekini yoki bank ilovasidagi screenshot ni saqlang'),
      ('3', Icons.send_rounded, 'Telegramga yuboring', 'Adminga screenshot va do\'kon nomingizni yuboring'),
      ('4', Icons.check_circle_rounded, 'Obuna faollashadi', 'Admin tasdiqlagandan so\'ng 5–30 daqiqa ichida faollashadi'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TO\'LOV JARAYONI',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: cs.onSurface.withOpacity(0.4),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: cs.outline.withOpacity(0.12)),
          ),
          child: Column(
            children: steps.asMap().entries.map((e) {
              final isLast = e.key == steps.length - 1;
              return _StepTile(
                number: e.value.$1,
                icon: e.value.$2,
                title: e.value.$3,
                subtitle: e.value.$4,
                showDivider: !isLast,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool showDivider;

  const _StepTile({
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: cs.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                          child: Center(
                            child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.55), height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: cs.outline.withOpacity(0.1)),
          ),
      ],
    );
  }
}

// ─── Telegram Button ─────────────────────────────────────────────────────────
class _TelegramButton extends StatelessWidget {
  final _PlanOption plan;
  final String shopName;
  final String uid;

  const _TelegramButton({required this.plan, required this.shopName, required this.uid});

  Future<void> _openTelegram(BuildContext context) async {
    final msg = Uri.encodeComponent(
      '🏪 Obuna so\'rovi\n'
      '━━━━━━━━━━━━━━━\n'
      '📦 Do\'kon: $shopName\n'
      '🆔 UID: $uid\n'
      '📅 Tarif: ${plan.title} — ${plan.price}\n'
      '━━━━━━━━━━━━━━━\n'
      '📎 [To\'lov cheki screenshotini shu yerga qo\'shing]',
    );
    final url = Uri.parse('https://t.me/$_adminTelegramUsername?text=$msg');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Telegram ilovasi topilmadi'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _openTelegram(context),
            icon: const Icon(Icons.send_rounded),
            label: const Text(
              'Telegramga screenshot yuborish',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              backgroundColor: const Color(0xFF0088CC), // Telegram blue
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline_rounded, size: 14, color: cs.onSurface.withOpacity(0.4)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Obuna admin tasdiqlagan so\'ng faollashadi',
                style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.4)),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
