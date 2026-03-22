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

Color _getCategoryColor(BuildContext context, String name) {
  final lower = name.toLowerCase();
  
  if (lower.contains('clothes') || lower.contains('kiyim')) return Colors.blue;
  if (lower.contains('elec') || lower.contains('phone') || lower.contains('telefon')) return Colors.indigo;
  if (lower.contains('home') || lower.contains('uy')) return Colors.green;
  if (lower.contains('beauty') || lower.contains('go\'zallik')) return Colors.pink;
  if (lower.contains('perfume') || lower.contains('atirlar')) return Colors.deepPurple;
  if (lower.contains('kids') || lower.contains('bolalar') || lower.contains('toys') || lower.contains('oyinchoq')) return Colors.orange;
  if (lower.contains('auto') || lower.contains('avto')) return Colors.blueGrey;
  if (lower.contains('tool') || lower.contains('asbob')) return Colors.grey;
  if (lower.contains('sport')) return Colors.red;
  if (lower.contains('diniy')) return Colors.amber;
  if (lower.contains('kitob')) return Colors.brown;
  if (lower.contains('xo\'jalik') || lower.contains('xojalik')) return Colors.teal;
  if (lower.contains('oziq') || lower.contains('food')) return Colors.deepOrange;
  if (lower.contains('mebel')) return Colors.brown;
  
  return Theme.of(context).colorScheme.primary;
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final catColor = _getCategoryColor(context, widget.name);
    final iconBg = catColor.withValues(alpha: widget.isDark ? 0.25 : 0.12);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      transform: Matrix4.identity()..scale(_isHovered ? 1.08 : 1.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isHovered 
            ? catColor.withValues(alpha: 0.5)
            : Theme.of(context).colorScheme.outline.withValues(alpha: widget.isDark ? 0.15 : 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: catColor.withValues(alpha: _isHovered ? 0.2 : 0.0),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.25 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: widget.onTap,
          onHover: (hovering) => setState(() => _isHovered = hovering),
          mouseCursor: SystemMouseCursors.click,
          splashColor: catColor.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: catColor.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    color: catColor.withValues(alpha: widget.isDark ? 0.9 : 0.8),
                    size: 22,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: onSurface.withOpacity(0.9),
                    letterSpacing: -0.3,
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
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final catColor = _getCategoryColor(context, widget.name);
    final iconBg = catColor.withValues(alpha: widget.isDark ? 0.25 : 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      transform: Matrix4.identity()..scale(_isHovered ? 1.04 : 1.0),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _isHovered 
            ? catColor.withValues(alpha: 0.5)
            : Theme.of(context).colorScheme.outline.withValues(alpha: widget.isDark ? 0.15 : 0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: catColor.withValues(alpha: _isHovered ? 0.25 : 0.0),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.25 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onHover: (hovering) => setState(() => _isHovered = hovering),
            mouseCursor: SystemMouseCursors.click,
            splashColor: catColor.withValues(alpha: 0.12),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    catColor.withValues(alpha: widget.isDark ? 0.05 : 0.02),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          catColor.withValues(alpha: widget.isDark ? 0.35 : 0.15),
                          catColor.withValues(alpha: widget.isDark ? 0.15 : 0.08),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: catColor.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      color: catColor.withValues(alpha: widget.isDark ? 0.95 : 0.85),
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: onSurface,
                      letterSpacing: -0.5,
                      height: 1.1,
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
