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
    final isTablet = screenWidth >= 600 && screenWidth <= 900;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          if (isDesktop)
            _DesktopSideBar(
              destinations: destinations,
              activeIndex: selectedIndex,
              onIndexChanged: (i) => context.go(destinations[i].path),
              compact: false,
            ),
          if (isTablet)
            _DesktopSideBar(
              destinations: destinations,
              activeIndex: selectedIndex,
              onIndexChanged: (i) => context.go(destinations[i].path),
              compact: true,
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
                      
                    // Floating nav bar pinned to bottom (Mobile only)
                    if (!isDesktop && !isTablet && isTopLevel && MediaQuery.of(context).viewInsets.bottom == 0)
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
  final int activeIndex;
  final Function(int) onIndexChanged;
  final bool compact;

  const _DesktopSideBar({
    required this.destinations,
    required this.activeIndex,
    required this.onIndexChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = Theme.of(context).dividerColor.withOpacity(isDark ? 0.08 : 0.05);

    return Container(
      width: compact ? 72 : 280,
      decoration: BoxDecoration(
        color: surface,
        border: Border(right: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 48, 24, 40),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'TABASSUM',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 48, 0, 32),
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
          const SizedBox(height: 8),
          // Dynamic nav items from destinations
          ...List.generate(destinations.length, (i) {
            final d = destinations[i];
            return _SidebarItem(
              icon: d.icon,
              label: d.label,
              isActive: activeIndex == i,
              onTap: () => onIndexChanged(i),
              compact: compact,
            );
          }),
          const Spacer(),
          if (!compact)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '@tabassum_market_bot',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool compact;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.compact = false,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    if (widget.compact) {
      // Icon-only mode for tablet
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Tooltip(
          message: widget.label,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.isActive 
                    ? colorScheme.primary.withOpacity(0.12)
                    : (_isHovered ? colorScheme.onSurface.withOpacity(0.06) : Colors.transparent),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.icon,
                  size: 24,
                  color: widget.isActive 
                    ? colorScheme.primary 
                    : colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: widget.isActive 
                ? colorScheme.primary.withOpacity(0.08)
                : (_isHovered ? colorScheme.onSurface.withOpacity(0.04) : Colors.transparent),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 24,
                  color: widget.isActive 
                    ? colorScheme.primary 
                    : colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
                const SizedBox(width: 16),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
                    color: widget.isActive 
                      ? colorScheme.primary 
                      : colorScheme.onSurfaceVariant,
                  ),
                ),
                if (widget.isActive) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
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
