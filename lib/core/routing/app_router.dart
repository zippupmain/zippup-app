import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
	return GoRouter(
		routes: <RouteBase>[
			GoRoute(
				path: '/',
				name: 'home',
				builder: (context, state) => const Placeholder(),
			),
			GoRoute(
				path: '/panic',
				name: 'panic',
				builder: (context, state) => const Placeholder(),
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
				builder: (context, state) => const Placeholder(key: ValueKey('marketplace')), // replaced in main with actual screen
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