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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: TextField(
                decoration: InputDecoration(
                  hintText: context.l('search_categories') ?? 'Kategoriyalarni qidirish...',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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

  IconData _getIconForCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('men') && !lower.contains('women')) return Icons.man_rounded;
    if (lower.contains('women')) return Icons.woman_rounded;
    if (lower.contains('shoe')) return Icons.snowshoeing_rounded;
    if (lower.contains('access')) return Icons.watch_outlined;
    if (lower.contains('kid')) return Icons.child_care_rounded;
    if (lower.contains('electron')) return Icons.devices_rounded;
    if (lower.contains('home')) return Icons.chair_rounded;
    if (lower.contains('beauty')) return Icons.face_retouching_natural_rounded;
    if (lower.contains('toy')) return Icons.toys_rounded;
    if (lower.contains('perfum')) return Icons.auto_fix_high_rounded;
    if (lower.contains('auto') || lower.contains('spare') || lower.contains('car')) return Icons.settings_input_component_rounded;
    if (lower.contains('tool')) return Icons.build_rounded;
    if (lower.contains('sport')) return Icons.sports_basketball_rounded;
    return Icons.category_rounded;
  }
}

class _PopularCategoryCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final iconBg = isDark
        ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.15)
        : Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1);

    return Container(
      width: MediaQuery.sizeOf(context).width < 380 ? 90 : 100,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: MediaQuery.sizeOf(context).width < 380 ? 20 : 22,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: MediaQuery.sizeOf(context).width < 380 ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: onSurface.withOpacity(0.85),
                  ),
                  maxLines: 2,
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

class _RootCategoryCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    // Icon circle: separate elevated surface
    final iconGradient = [
      Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.3 : 0.1),
      Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.1 : 0.05),
    ];

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: iconGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: isDark ? 0.3 : 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: onSurface,
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
