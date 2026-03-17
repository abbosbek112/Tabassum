import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/marketplace/categories_screen.dart';
import '../features/marketplace/subcategories_screen.dart';
import '../features/marketplace/category_products_screen.dart';
import '../features/marketplace/all_products_screen.dart';
import '../features/marketplace/shop_screen.dart';
import '../features/marketplace/product_screen.dart';
import '../features/pos/pos_screen.dart';
import '../features/pos/sales_reports_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/seller/dashboard_screen.dart';
import '../features/seller/products_screen.dart';
import '../features/seller/inventory_detail_screen.dart';
import '../features/subscription/subscription_screen.dart';
import '../features/admin/admin_screen.dart';
import '../features/wishlist/wishlist_screen.dart';
import '../home_shell.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerRefreshNotifierProvider);
  final authState = ref.watch(authStateProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);

  return GoRouter(
    initialLocation: '/market',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isLoggingIn = state.matchedLocation == '/auth';

      if (!authState.isAuthenticated) {
        return isLoggingIn ? null : '/auth';
      }

      if (isLoggingIn) return '/market';

      // If logged in but profile not loaded yet, keep current route.
      if (userProfileAsync.isLoading) return null;
      // If profile missing, allow app to proceed; seller features will rely on role.

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/catalog',
            builder: (context, state) => const AllProductsScreen(),
          ),
          GoRoute(
            path: '/market',
            builder: (context, state) => const ShopScreen(),
            routes: [
              GoRoute(
                path: 'products/:categoryId',
                builder: (context, state) {
                  final categoryId = state.pathParameters['categoryId']!;
                  return CategoryProductsScreen(categoryId: categoryId);
                },
              ),
              GoRoute(
                path: 'shop/:shopId',
                builder: (context, state) {
                  final shopId = state.pathParameters['shopId']!;
                  return ShopDetailScreen(shopId: shopId);
                },
              ),
              GoRoute(
                path: 'product/:productId',
                builder: (context, state) {
                  final productId = state.pathParameters['productId']!;
                  return ProductScreen(productId: productId);
                },
              ),
              GoRoute(
                path: 'wishlist',
                builder: (context, state) => const WishlistScreen(),
              ),
              GoRoute(
                path: 'categories',
                builder: (context, state) => const CategoriesScreen(),
                routes: [
                  GoRoute(
                    path: ':categoryId',
                    builder: (context, state) {
                      final categoryId = state.pathParameters['categoryId']!;
                      return SubcategoriesScreen(categoryId: categoryId);
                    },
                  ),
                ],
              ),
            ],
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/seller/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/seller/pos',
            builder: (context, state) => const PosScreen(),
            routes: [
              GoRoute(
                path: 'reports',
                builder: (context, state) => const SalesReportsScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/seller/products',
            builder: (context, state) => const ProductsScreen(),
            routes: [
              GoRoute(
                path: 'inventory/:inventoryId',
                builder: (context, state) {
                  final inventoryId = state.pathParameters['inventoryId']!;
                  return InventoryDetailScreen(inventoryId: inventoryId);
                },
              ),
            ]
          ),
          GoRoute(
            path: '/seller/subscription',
            builder: (context, state) => const SubscriptionScreen(),
          ),
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: Center(child: Text(state.error?.toString() ?? 'Route not found')),
    ),
  );
});

