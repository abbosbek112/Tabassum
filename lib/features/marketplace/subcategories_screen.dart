import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization.dart';
import 'category_repository.dart';

class SubcategoriesScreen extends ConsumerStatefulWidget {
  final String categoryId;
  const SubcategoriesScreen({super.key, required this.categoryId});

  @override
  ConsumerState<SubcategoriesScreen> createState() => _SubcategoriesScreenState();
}

class _SubcategoriesScreenState extends ConsumerState<SubcategoriesScreen> {
  bool _redirected = false;

  @override
  Widget build(BuildContext context) {
    final parentAsync = ref.watch(categoryProvider(widget.categoryId));
    final subcategoriesAsync = ref.watch(subcategoriesProvider(widget.categoryId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: parentAsync.when(
          data: (parent) => Text(
            parent != null ? (context.l(parent.name) ?? parent.name) : '---',
            style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface),
          ),
          loading: () => SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
          error: (e, _) => const Text('Error'),
        ),
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
      ),
      body: subcategoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            // Auto-navigate to products without showing empty state
            if (!_redirected) {
              _redirected = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  context.pushReplacement('/market/products/${widget.categoryId}');
                }
              });
            }
            // Show a minimal loading indicator while redirect happens
            return Center(child: CircularProgressIndicator(color: cs.primary));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            itemCount: categories.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _SubcategoryTile(
                  name: context.l('all_products') ?? 'Barcha mahsulotlar',
                  icon: Icons.list_alt_rounded,
                  isAll: true,
                  isDark: isDark,
                  onTap: () => context.push('/market/products/${widget.categoryId}'),
                );
              }
              final c = categories[index - 1];
              return _SubcategoryTile(
                name: context.l(c.name) ?? c.name,
                icon: _getIconForCategory(c.name),
                isDark: isDark,
                onTap: () => context.push('/market/categories/${c.id}'),
              );
            },
          );
        },
        loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  IconData _getIconForCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('men') && !lower.contains('women')) return Icons.man_rounded;
    if (lower.contains('women')) return Icons.woman_rounded;
    if (lower.contains('shirt')) return Icons.checkroom_rounded;
    if (lower.contains('hood')) return Icons.dry_cleaning_rounded;
    if (lower.contains('jacket')) return Icons.cases_rounded;
    if (lower.contains('dress')) return Icons.accessibility_new_rounded;
    if (lower.contains('top')) return Icons.vertical_align_top_rounded;
    if (lower.contains('phone')) return Icons.smartphone_rounded;
    if (lower.contains('laptop')) return Icons.laptop_mac_rounded;
    if (lower.contains('headphone')) return Icons.headphones_rounded;
    if (lower.contains('shoe')) return Icons.snowshoeing_rounded;
    return Icons.category_rounded;
  }
}

/// Premium empty state for leaf categories with no subcategories.
class _EmptyState extends StatelessWidget {
  final String categoryId;
  final bool isDark;
  const _EmptyState({required this.categoryId, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing icon container
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    cs.primaryContainer.withValues(alpha: isDark ? 0.5 : 0.3),
                    cs.secondaryContainer.withValues(alpha: isDark ? 0.3 : 0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: isDark ? 0.25 : 0.1),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 42,
                color: cs.primary.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              context.l('no_subcategories') ?? 'Ichki kategoriyalar mavjud emas',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l('view_all_in_category') ?? 'Bu kategoriya uchun barcha mahsulotlarni ko\'ring',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.38),
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.pushReplacement('/market/products/$categoryId'),
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(context.l('view_products') ?? 'Mahsulotlarni ko\'rish'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool isAll;
  final bool isDark;
  final VoidCallback onTap;

  const _SubcategoryTile({
    required this.name,
    required this.icon,
    this.isAll = false,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final iconBg = isAll
        ? cs.primary.withValues(alpha: isDark ? 0.2 : 0.1)
        : cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.8 : 0.5);
    final iconColor = isAll ? cs.primary : cs.onSurface.withOpacity(0.7);
    final textColor = isAll ? cs.primary : cs.onSurface;
    final cardColor = isDark
        ? cs.surfaceContainerLow
        : cs.surface;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isAll
              ? cs.primary.withValues(alpha: isDark ? 0.3 : 0.2)
              : cs.outline.withValues(alpha: isDark ? 0.15 : 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: isDark ? 12 : 8,
            offset: const Offset(0, 4),
          ),
          if (isAll)
            BoxShadow(
              color: cs.primary.withValues(alpha: isDark ? 0.12 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          splashColor: cs.primary.withOpacity(0.08),
          highlightColor: cs.primary.withOpacity(0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon circle
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isAll ? FontWeight.w700 : FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      if (isAll) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Barcha mahsulotlarni ko\'rsatish',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.primary.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: isDark ? 0.3 : 0.25),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
