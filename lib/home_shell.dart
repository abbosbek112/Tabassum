import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/constants.dart';
import 'core/localization.dart';
import 'features/auth/auth_controller.dart';
import 'core/shared_providers.dart';

class HomeShell extends ConsumerWidget {
  final Widget child;
  const HomeShell({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    final role = profileAsync.maybeWhen(
      data: (u) => u?.role ?? UserRole.customer,
      orElse: () => UserRole.customer,
    );

    final uid = profileAsync.maybeWhen(data: (u) => u?.uid, orElse: () => null);
    final shopsAsync = uid != null ? ref.watch(myShopsProvider(uid)) : null;
    final myShopId = shopsAsync?.maybeWhen(data: (shops) => shops.isNotEmpty ? shops.first.id : null, orElse: () => null);

    final destinations = role == UserRole.seller
        ? <_NavDest>[
            _NavDest(label: context.l('market'), icon: Icons.store_mall_directory_outlined, path: '/market'),
            _NavDest(label: context.l('products'), icon: Icons.auto_awesome_motion_outlined, path: '/catalog'),
            _NavDest(label: context.l('categories'), icon: Icons.grid_view_outlined, path: '/market/categories'),
            if (myShopId != null)
              _NavDest(label: context.l('my_shop'), icon: Icons.storefront_outlined, path: '/market/shop/$myShopId'),
            _NavDest(label: context.l('dashboard'), icon: Icons.dashboard_outlined, path: '/seller/dashboard'),
            _NavDest(label: context.l('pos'), icon: Icons.point_of_sale_outlined, path: '/seller/pos'),
            _NavDest(label: context.l('my_profile'), icon: Icons.person_outline, path: '/profile'),
          ]
        : <_NavDest>[
            _NavDest(label: context.l('market'), icon: Icons.store_mall_directory_outlined, path: '/market'),
            _NavDest(label: context.l('products'), icon: Icons.auto_awesome_motion_outlined, path: '/catalog'),
            _NavDest(label: context.l('categories'), icon: Icons.grid_view_outlined, path: '/market/categories'),
            _NavDest(label: context.l('my_profile'), icon: Icons.person_outline, path: '/profile'),
          ];

    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _selectedIndex(destinations, location);

    // Hide nav bar on detail pages
    final isTopLevel = location == '/market' || 
                       location == '/catalog' || 
                       location == '/market/categories' || 
                       location == '/profile' || 
                       location == '/seller/dashboard' || 
                       location == '/seller/pos';

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          if (isDesktop)
            _DesktopSideBar(
              destinations: destinations,
              selectedIndex: selectedIndex,
              onTap: (path) => context.go(path),
            ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Stack(
                  children: [
                    // Main page content
                    Positioned.fill(child: child),
                    
                    // Loading indicator
                    if (profileAsync.isLoading)
                      const Align(
                        alignment: Alignment.topCenter,
                        child: LinearProgressIndicator(minHeight: 2),
                      ),
                      
                    // Floating nav bar pinned to bottom (Mobile/Tablet only)
                    if (!isDesktop && isTopLevel && MediaQuery.of(context).viewInsets.bottom == 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 24,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 600),
                              child: _NavBar(
                                destinations: destinations,
                                selectedIndex: selectedIndex,
                                onTap: (path) => context.go(path),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _selectedIndex(List<_NavDest> dests, String location) {
    final exact = dests.indexWhere((d) => location == d.path);
    if (exact != -1) return exact;
    final prefix = dests.indexWhere((d) => location.startsWith('${d.path}/'));
    return prefix == -1 ? 0 : prefix;
  }
}

class _DesktopSideBar extends StatelessWidget {
  final List<_NavDest> destinations;
  final int selectedIndex;
  final void Function(String path) onTap;

  const _DesktopSideBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Logo or App Name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Text(
                  'TABASSUM',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: -1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: destinations.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final d = destinations[index];
                final isSelected = selectedIndex == index;
                
                return InkWell(
                  onTap: () => onTap(d.path),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                        : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          d.icon,
                          size: 24,
                          color: isSelected 
                            ? Theme.of(context).colorScheme.primary 
                            : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          d.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected 
                              ? Theme.of(context).colorScheme.primary 
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final List<_NavDest> destinations;
  final int selectedIndex;
  final void Function(String path) onTap;

  const _NavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isSmallScreen = screenWidth < 380;
    final manyItems = destinations.length > 5;
    final hideLabels = isSmallScreen && manyItems;

    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.white.withOpacity(0.88)
                : const Color(0xFF0F172A).withOpacity(0.88),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.white.withOpacity(0.4)
                  : Colors.white.withOpacity(0.1),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(destinations.length, (idx) {
              final d = destinations[idx];
              final isSelected = selectedIndex == idx;
              final showLabel = !hideLabels && (isSelected || !isSmallScreen);

              return Flexible(
                child: InkWell(
                  onTap: () => onTap(d.path),
                  borderRadius: BorderRadius.circular(24),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: showLabel ? 14 : 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          d.icon,
                          size: isSelected ? 24 : 22,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                        if (showLabel) ...[
                          const SizedBox(height: 4),
                          Text(
                            d.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavDest {
  final String label;
  final IconData icon;
  final String path;
  const _NavDest({required this.label, required this.icon, required this.path});
}
