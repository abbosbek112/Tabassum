import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/localization.dart';
import 'category_repository.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootAsync = ref.watch(rootCategoriesProvider);
    final popularAsync = ref.watch(popularCategoriesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l('categories') ?? 'Kategoriyalar',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: MediaQuery.sizeOf(context).width < 380 ? 22 : 26,
            letterSpacing: -1.0,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: context.l('search_categories') ?? 'Kategoriyalarni qidirish...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 15,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 22,
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.1 : 0.05),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          popularAsync.when(
            data: (popular) {
              if (popular.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
              return SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        context.l('popular_categories') ?? 'Ommabop kategoriyalar',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: -0.5,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: MediaQuery.sizeOf(context).width < 380 ? 110 : 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: popular.length,
                        itemBuilder: (ctx, i) {
                          final c = popular[i];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _PopularCategoryCard(
                              name: context.l(c.name) ?? c.name,
                              icon: _getIconForCategory(c.name),
                              onTap: () => context.push('/market/categories/${c.id}'),
                              isDark: isDark,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverToBoxAdapter(child: Text('Error: $e')),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                context.l('all_categories') ?? 'Barcha kategoriyalar',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          rootAsync.when(
            data: (categories) {
              if (categories.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () => ref.read(categoryRepositoryProvider).seedInitialCategories(),
                      child: const Text('Seed Test Categories'),
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final c = categories[index];
                      return _RootCategoryCard(
                        name: context.l(c.name) ?? c.name,
                        icon: _getIconForCategory(c.name),
                        onTap: () => context.push('/market/categories/${c.id}'),
                        isDark: isDark,
                      );
                    },
                    childCount: categories.length,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.sizeOf(context).width > 1000 ? 5 : (MediaQuery.sizeOf(context).width > 700 ? 4 : (MediaQuery.sizeOf(context).width > 500 ? 3 : 2)),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: MediaQuery.sizeOf(context).width > 1000 ? 1.2 : (MediaQuery.sizeOf(context).width < 380 ? 1.05 : 1.1),
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverFillRemaining(child: Center(child: Text('Error: $e'))),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 140)),
        ],
      ),
    );
  }
}

IconData _getIconForCategory(String name) {
  final lower = name.toLowerCase();
  
  // Specific Uzbek/English keywords for unique icons
  if (lower.contains('diniy') || lower.contains('islam') || lower.contains('religious')) return Icons.auto_awesome_rounded;
  if (lower.contains('kitob') || lower.contains('book')) return Icons.menu_book_rounded;
  if (lower.contains('xo\'jalik') || lower.contains('xojalik') || lower.contains('household') || lower.contains('ro\'zg\'or')) return Icons.home_repair_service_rounded;
  if (lower.contains('salomatlik') || lower.contains('health') || lower.contains('medical')) return Icons.health_and_safety_rounded;
  if (lower.contains('bog\'') || lower.contains('bog') || lower.contains('garden')) return Icons.yard_rounded;
  if (lower.contains('mebel') || lower.contains('furniture') || lower.contains('stul') || lower.contains('stol')) return Icons.chair_rounded;
  if (lower.contains('oziq') || lower.contains('ovqat') || lower.contains('food') || lower.contains('ichimlik')) return Icons.restaurant_rounded;
  if (lower.contains('o\'yinchoq') || lower.contains('oyinchoq') || lower.contains('toy')) return Icons.smart_toy_rounded;
  if (lower.contains('sport') || lower.contains('fitness') || lower.contains('mashg\'ulot')) return Icons.fitness_center_rounded;
  if (lower.contains('avto') || lower.contains('car') || lower.contains('mashina')) return Icons.directions_car_filled_rounded;
  if (lower.contains('ehtiyot') || lower.contains('spare') || lower.contains('qismlar')) return Icons.handyman_rounded;

  // Clothing & Fashion
  if (lower.contains('men_clothes') || lower.contains('erkaklar')) return Icons.man_rounded;
  if (lower.contains('women_clothes') || lower.contains('ayollar')) return Icons.woman_rounded;
  if (lower.contains('shoes') || lower.contains('oyoq') || lower.contains('poyabzal')) return Icons.straighten_rounded;
  if (lower.contains('clothes') || lower.contains('kiyim')) return Icons.checkroom_rounded;
  if (lower.contains('accessories') || lower.contains('aksessuar')) return Icons.watch_outlined;
  
  // Electronics
  if (lower.contains('phone') || lower.contains('telefon') || lower.contains('smartphone')) return Icons.smartphone_rounded;
  if (lower.contains('laptop') || lower.contains('noutbuk') || lower.contains('kompyuter')) return Icons.laptop_mac_rounded;
  if (lower.contains('headphone') || lower.contains('quloqchin')) return Icons.headphones_rounded;
  if (lower.contains('electronics') || lower.contains('elektronika')) return Icons.memory_rounded;
  
  // Home & Beauty
  if (lower.contains('home_garden') || lower.contains('home') || lower.contains('uy')) return Icons.home_work_rounded;
  if (lower.contains('beauty') || lower.contains('go\'zallik') || lower.contains('gozallik')) return Icons.spa_rounded;
  if (lower.contains('perfume_men')) return Icons.flare_rounded;
  if (lower.contains('perfume_women')) return Icons.brush_rounded;
  if (lower.contains('perfume') || lower.contains('atirlar') || lower.contains('fragrance')) return Icons.auto_fix_high_rounded;
  
  // Kids & Education
  if (lower.contains('educational') || lower.contains('rivojlantiruvchi') || lower.contains('ta\'lim')) return Icons.psychology_rounded;
  if (lower.contains('kids') || lower.contains('bolalar')) return Icons.child_friendly_rounded;
  
  // Tech & Tools
  if (lower.contains('construction') || lower.contains('qurilish')) return Icons.construction_rounded;
  if (lower.contains('tool') || lower.contains('asbob')) return Icons.build_rounded;
  
  return Icons.grid_view_rounded;
}

/// Returns a muted, theme-consistent accent color for each category.
/// Uses a fixed palette of 8 carefully chosen colors that all work
/// with both light (#0F172A base) and dark (#818CF8 base) themes.
Color _getCategoryColor(BuildContext context, String name) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final lower = name.toLowerCase();

  // Palette: muted tones harmonious with slate/indigo primary
  const colors = [
    Color(0xFF6366F1), // indigo  – electronics, phones
    Color(0xFF3B82F6), // blue    – clothes, fashion
    Color(0xFF10B981), // emerald – home, garden
    Color(0xFFF59E0B), // amber   – books, religious
    Color(0xFF8B5CF6), // violet  – beauty, perfume
    Color(0xFF64748B), // slate   – auto, tools
    Color(0xFFEC4899), // pink    – kids, toys
    Color(0xFF14B8A6), // teal    – household
  ];

  if (lower.contains('elec') || lower.contains('phone') || lower.contains('telefon') || lower.contains('laptop')) return colors[0];
  if (lower.contains('clothes') || lower.contains('kiyim') || lower.contains('sport') || lower.contains('shoes') || lower.contains('poyabzal')) return colors[1];
  if (lower.contains('home') || lower.contains('uy') || lower.contains('bog') || lower.contains('mebel')) return colors[2];
  if (lower.contains('kitob') || lower.contains('book') || lower.contains('diniy') || lower.contains('ta\'lim') || lower.contains('educational')) return colors[3];
  if (lower.contains('beauty') || lower.contains('go\'zallik') || lower.contains('perfume') || lower.contains('atir') || lower.contains('salomatlik')) return colors[4];
  if (lower.contains('avto') || lower.contains('auto') || lower.contains('car') || lower.contains('ehtiyot') || lower.contains('tool') || lower.contains('asbob')) return colors[5];
  if (lower.contains('kids') || lower.contains('bolalar') || lower.contains('oyinchoq') || lower.contains('toy')) return colors[6];
  if (lower.contains('xo\'jalik') || lower.contains('xojalik') || lower.contains('oziq') || lower.contains('food')) return colors[7];

  // Deterministic fallback: hash name to pick from palette
  final hash = lower.codeUnits.fold(0, (a, b) => a + b);
  return colors[hash % colors.length];
}

class _PopularCategoryCard extends StatefulWidget {
  final String name;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _PopularCategoryCard({
    required this.name,
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_PopularCategoryCard> createState() => _PopularCategoryCardState();
}

class _PopularCategoryCardState extends State<_PopularCategoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _getCategoryColor(context, widget.name);
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isHovered
              ? accent.withOpacity(0.35)
              : Theme.of(context).colorScheme.outline.withOpacity(isDark ? 0.12 : 0.07),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onTap,
          onHover: (h) => setState(() => _isHovered = h),
          mouseCursor: SystemMouseCursors.click,
          splashColor: accent.withOpacity(0.08),
          highlightColor: accent.withOpacity(0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(isDark ? 0.18 : 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    color: accent.withOpacity(isDark ? 1.0 : 0.85),
                    size: 20,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: onSurface.withOpacity(0.85),
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RootCategoryCard extends StatefulWidget {
  final String name;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _RootCategoryCard({
    required this.name,
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_RootCategoryCard> createState() => _RootCategoryCardState();
}

class _RootCategoryCardState extends State<_RootCategoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _getCategoryColor(context, widget.name);
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final outlineColor = Theme.of(context).colorScheme.outline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      transform: Matrix4.identity()..scale(_isHovered ? 1.03 : 1.0),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isHovered
              ? accent.withOpacity(0.4)
              : outlineColor.withOpacity(isDark ? 0.12 : 0.07),
          width: 1,
        ),
        boxShadow: [
          if (_isHovered)
            BoxShadow(
              color: accent.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (h) => setState(() => _isHovered = h),
            mouseCursor: SystemMouseCursors.click,
            splashColor: accent.withOpacity(0.08),
            highlightColor: accent.withOpacity(0.04),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(isDark ? 0.18 : 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      color: accent.withOpacity(isDark ? 1.0 : 0.85),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: onSurface.withOpacity(0.9),
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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


