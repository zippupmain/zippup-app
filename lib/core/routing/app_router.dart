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
import 'package:zippup/features/profile/presentation/profile_screen.dart';
import 'package:zippup/features/profile/presentation/apply_provider_screen.dart';
import 'package:zippup/features/admin/presentation/admin_applications_screen.dart';
import 'package:zippup/features/orders/presentation/my_bookings_screen.dart';
import 'package:zippup/features/orders/presentation/track_order_screen.dart';
import 'package:zippup/features/transport/presentation/ride_track_screen.dart';
import 'package:zippup/features/transport/presentation/courier_dashboard_screen.dart';
import 'package:zippup/features/search/presentation/search_results_screen.dart';
import 'package:zippup/features/emergency/presentation/emergency_screen.dart';
import 'package:zippup/features/others/presentation/others_screen.dart';
import 'package:zippup/features/food/presentation/vendor_detail_screen.dart';
import 'package:zippup/features/marketplace/presentation/product_detail_screen.dart';
import 'package:zippup/features/profile/presentation/provider_detail_screen.dart';

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
				path: '/courier',
				name: 'courierDashboard',
				builder: (context, state) => const CourierDashboardScreen(),
			),
      			GoRoute(
				path: '/profile',
				name: 'profile',
				builder: (context, state) => const ProfileScreen(),
			),
			GoRoute(
				path: '/profile/apply-provider',
				name: 'applyProvider',
				builder: (context, state) => const ApplyProviderScreen(),
			),
			GoRoute(
				path: '/admin/applications',
				name: 'adminApplications',
				builder: (context, state) => const AdminApplicationsScreen(),
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
			GoRoute(
				path: '/bookings',
				name: 'myBookings',
				builder: (context, state) => const MyBookingsScreen(),
			),
			GoRoute(
				path: '/track',
				name: 'trackOrder',
				builder: (context, state) => TrackOrderScreen(orderId: state.uri.queryParameters['orderId'] ?? ''),
			),
			GoRoute(
				path: '/track/ride',
				name: 'trackRide',
				builder: (context, state) => RideTrackScreen(rideId: state.uri.queryParameters['rideId'] ?? ''),
			),
			GoRoute(
				path: '/search',
				name: 'search',
				builder: (context, state) => SearchResultsScreen(query: state.uri.queryParameters['q'] ?? ''),
			),
			GoRoute(
				path: '/emergency',
				name: 'emergency',
				builder: (context, state) => const EmergencyScreen(),
			),
			GoRoute(
				path: '/others',
				name: 'others',
				builder: (context, state) => const OthersScreen(),
			),
			GoRoute(
				path: '/vendor',
				name: 'vendorDetail',
				builder: (context, state) => VendorDetailScreen(vendorId: state.uri.queryParameters['vendorId'] ?? ''),
			),
			GoRoute(
				path: '/provider',
				name: 'providerDetail',
				builder: (context, state) => ProviderDetailScreen(providerId: state.uri.queryParameters['providerId'] ?? ''),
			),
			GoRoute(
				path: '/listing',
				name: 'productDetail',
				builder: (context, state) => ProductDetailScreen(productId: state.uri.queryParameters['productId'] ?? ''),
			),
    ],
  );
});
