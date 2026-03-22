import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'twa_service.dart';

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

bool _hasHandledStartParam = false;

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerRefreshNotifierProvider);
  final authState = ref.watch(authStateProvider);
  final userProfileAsync = ref.watch(currentUserProfileProvider);
  final twa = ref.read(twaServiceProvider);

  return GoRouter(
    initialLocation: '/market',
    refreshListenable: notifier,
    redirect: (context, state) {
      // TWA Fix: Telegram appends #tgWebAppData=... which GoRouter might try to parse as a path.
      if (state.uri.toString().contains('tgWebAppData')) {
        return '/market';
      }

      final isLoggingIn = state.matchedLocation == '/auth';

      if (!authState.isAuthenticated) {
        if (!isLoggingIn) {
          final from = state.uri.toString();
          if (from != '/' && from != '/market') {
             return '/auth?from=${Uri.encodeQueryComponent(from)}';
          }
        }
        return isLoggingIn ? null : '/auth';
      }

      final profile = userProfileAsync.valueOrNull;
      final hasProfile = profile != null;

      // If logged in but profile not loaded yet or errored, keep current route.
      if (userProfileAsync.isLoading || userProfileAsync.hasError) return null;

      // If authenticated but NO profile in Firestore, force them to /auth (registration)
      if (authState.isAuthenticated && !hasProfile) {
        if (!isLoggingIn) {
          final from = state.uri.toString();
          if (from != '/' && from != '/market') {
             return '/auth?from=${Uri.encodeQueryComponent(from)}';
          }
        }
        return isLoggingIn ? null : '/auth';
      }

      if (isLoggingIn) {
        final from = state.uri.queryParameters['from'];
        if (from != null && from.isNotEmpty) {
           return Uri.decodeQueryComponent(from);
        }
        return '/market';
      }

      // Handle Telegram start_param deep linking right after auth is established
      if (!_hasHandledStartParam && authState.isAuthenticated && !userProfileAsync.isLoading) {
        _hasHandledStartParam = true; // only handle once per session
        final param = twa.startParam;
        if (param != null && param.startsWith('product_')) {
          final productId = param.replaceFirst('product_', '');
          if (productId.isNotEmpty) {
            return '/market/product/$productId'; // Differentiate the path based on deep link format
          }
        }
      }

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

