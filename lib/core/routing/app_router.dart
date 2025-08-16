import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippup/features/home/presentation/home_screen.dart';
import 'package:zippup/features/panic/presentation/panic_screen.dart';
import 'package:zippup/features/marketplace/presentation/marketplace_screen.dart';
import 'package:zippup/features/marketplace/presentation/add_listing_screen.dart';
import 'package:zippup/features/auth/presentation/auth_gate.dart';

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
        builder: (context, state) => const Placeholder(),
      ),
      GoRoute(
        path: '/food',
        name: 'food',
        builder: (context, state) => const Placeholder(),
      ),
      GoRoute(
        path: '/hire',
        name: 'hire',
        builder: (context, state) => const Placeholder(),
      ),
      			GoRoute(
				path: '/marketplace',
				name: 'marketplace',
				builder: (context, state) => const MarketplaceScreen(),
			),
			GoRoute(
				path: '/marketplace/add',
				name: 'addListing',
				builder: (context, state) => const AddListingScreen(),
			),
      GoRoute(
        path: '/digital',
        name: 'digital',
        builder: (context, state) => const Placeholder(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const Placeholder(),
      ),
    ],
  );
});
