import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippup/features/home/presentation/home_screen.dart';
import 'package:zippup/features/panic/presentation/panic_screen.dart';
import 'package:zippup/features/marketplace/presentation/marketplace_screen.dart';
import 'package:zippup/features/marketplace/presentation/add_listing_screen.dart';
import 'package:zippup/features/transport/presentation/transport_screen.dart';
import 'package:zippup/features/food/presentation/food_screen.dart';
import 'package:zippup/features/hire/presentation/hire_screen.dart';
import 'package:zippup/features/digital/presentation/digital_screen.dart';
import 'package:zippup/features/food/presentation/vendor_list_screen.dart';
import 'package:zippup/features/auth/presentation/auth_gate.dart';
import 'package:zippup/features/cart/presentation/cart_screen.dart';
import 'package:zippup/features/chat/presentation/chat_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: <RouteBase>[
      			GoRoute(
				path: '/',
				name: 'home',
				builder: (context, state) => const AuthGate(child: HomeScreen()),
			),
      GoRoute(
        path: '/panic',
        name: 'panic',
        builder: (context, state) => const PanicScreen(),
      ),
      			GoRoute(
				path: '/transport',
				name: 'transport',
				builder: (context, state) => const TransportScreen(),
			),
      			GoRoute(
				path: '/food',
				name: 'food',
				builder: (context, state) => const FoodScreen(),
			),
      			GoRoute(
				path: '/hire',
				name: 'hire',
				builder: (context, state) => const HireScreen(),
			),
      			GoRoute(
				path: '/marketplace',
				name: 'marketplace',
				builder: (context, state) => const MarketplaceScreen(),
			),
			GoRoute(
				path: '/cart',
				name: 'cart',
				builder: (context, state) => const CartScreen(),
			),
			GoRoute(
				path: '/marketplace/add',
				name: 'addListing',
				builder: (context, state) => const AddListingScreen(),
			),
      			GoRoute(
				path: '/digital',
				name: 'digital',
				builder: (context, state) => const DigitalScreen(),
			),
      			GoRoute(
				path: '/profile',
				name: 'profile',
				builder: (context, state) => const Placeholder(),
			),
			GoRoute(
				path: '/chat/:threadId',
				name: 'chat',
				builder: (context, state) => ChatScreen(threadId: state.pathParameters['threadId']!, title: state.uri.queryParameters['title'] ?? 'Chat'),
			),
			GoRoute(
				path: '/food/vendors/:category',
				name: 'foodVendors',
				builder: (context, state) => VendorListScreen(category: state.pathParameters['category'] ?? 'fast_food'),
			),
    ],
  );
});
