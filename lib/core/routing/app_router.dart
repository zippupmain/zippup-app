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
import 'package:zippup/features/personal/presentation/personal_screen.dart';
import 'package:zippup/features/emergency/presentation/emergency_providers_screen.dart';
import 'package:zippup/features/profile/presentation/profile_settings_screen.dart';
import 'package:zippup/features/admin/presentation/vendor_admin_screen.dart';
import 'package:zippup/features/admin/presentation/driver_delivery_screen.dart';
import 'package:zippup/features/wallet/presentation/wallet_screen.dart';
import 'package:zippup/features/settings/presentation/languages_screen.dart';
import 'package:zippup/features/profile/presentation/business_profile_screen.dart';
import 'package:zippup/features/support/presentation/support_screen.dart';
import 'package:zippup/features/profile/presentation/manage_accounts_screen.dart';
import 'package:zippup/features/legal/presentation/privacy_screen.dart';
import 'package:zippup/features/legal/presentation/terms_screen.dart';
import 'package:zippup/features/ratings/presentation/rate_app_screen.dart';
import 'package:zippup/features/promos/presentation/promos_screen.dart';
import 'package:zippup/features/profile/presentation/emergency_contacts_screen.dart';
import 'package:zippup/features/others/presentation/others_search_screen.dart';
import 'package:zippup/features/admin/presentation/platform_admin_screen.dart';
import 'package:zippup/features/others/presentation/ticket_detail_screen.dart';
import 'package:zippup/features/admin/presentation/admin_users_screen.dart';
import 'package:zippup/features/food/presentation/vendor_menu_screen.dart';
import 'package:zippup/features/food/presentation/menu_management_screen.dart';
import 'package:zippup/features/food/presentation/kitchen_hours_screen.dart';
import 'package:zippup/features/notifications/presentation/notifications_screen.dart';
import 'package:zippup/features/navigation/map_booking_screen.dart';
import 'package:zippup/features/moving/presentation/moving_screen.dart';
import 'package:zippup/features/rentals/presentation/vehicle_rentals_screen.dart';
import 'package:zippup/features/rentals/presentation/rentals_hub_screen.dart';
import 'package:zippup/features/rentals/presentation/house_rentals_screen.dart';
import 'package:zippup/features/rentals/presentation/other_rentals_screen.dart';
// Added provider onboarding/management imports
import 'package:zippup/features/providers/presentation/kyc_onboarding_screen.dart';
import 'package:zippup/features/providers/presentation/business_profiles_screen.dart';
import 'package:zippup/features/providers/presentation/create_service_profile_screen.dart';
import 'package:zippup/features/providers/presentation/provider_hub_screen.dart';
import 'package:zippup/features/providers/presentation/provider_orders_screen.dart';
import 'package:zippup/features/providers/presentation/provider_analytics_screen.dart';
import 'package:zippup/features/food/presentation/provider_dashboard_screen.dart' as fooddash;
import 'package:zippup/features/transport/presentation/transport_provider_dashboard_screen.dart' as tp;
import 'package:zippup/features/hire/presentation/hire_provider_dashboard_screen.dart' as hiredash;
import 'package:zippup/features/emergency/presentation/emergency_provider_dashboard_screen.dart' as emergdash;
import 'package:zippup/features/personal/presentation/personal_provider_dashboard_screen.dart' as personaldash;
import 'package:zippup/features/grocery/presentation/grocery_provider_dashboard_screen.dart' as grocerydash;
import 'package:zippup/features/moving/presentation/moving_provider_dashboard_screen.dart' as movingdash;
import 'package:zippup/features/rentals/presentation/rentals_provider_dashboard_screen.dart' as rentalsdash;
import 'package:zippup/features/marketplace/presentation/marketplace_provider_dashboard_screen.dart' as mkdash;
import 'package:zippup/features/others/presentation/others_provider_dashboard_screen.dart' as othersdash;
import 'package:zippup/features/delivery/presentation/delivery_provider_dashboard_screen.dart' as deliverydash;

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
					path: '/profile/settings',
					name: 'profileSettings',
					builder: (context, state) => const ProfileSettingsScreen(),
				),
				GoRoute(
					path: '/profile/apply-provider',
					name: 'applyProvider',
					builder: (context, state) => const ApplyProviderScreen(),
				),
				GoRoute(
					path: '/profile/emergency-contacts',
					name: 'emergencyContacts',
					builder: (context, state) => const EmergencyContactsScreen(),
				),
				GoRoute(
					path: '/admin/applications',
					name: 'adminApplications',
					builder: (context, state) => const AdminApplicationsScreen(),
				),
      GoRoute(
        path: '/admin/dashboard',
        name: 'vendorAdmin',
        builder: (context, state) => const VendorAdminScreen(),
      ),
      GoRoute(
        path: '/driver/delivery',
        name: 'driverDelivery',
        builder: (context, state) => DriverDeliveryScreen(orderId: state.uri.queryParameters['orderId'] ?? ''),
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
					path: '/others/events',
					name: 'othersEvents',
					builder: (context, state) => const OthersSearchScreen(kind: 'events'),
				),
				GoRoute(
					path: '/others/tickets',
					name: 'othersTickets',
					builder: (context, state) => const OthersSearchScreen(kind: 'tickets'),
				),
				GoRoute(
					path: '/others/tutors',
					name: 'othersTutors',
					builder: (context, state) => const OthersSearchScreen(kind: 'tutors'),
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
      GoRoute(
        path: '/personal',
        name: 'personal',
        builder: (context, state) => const PersonalScreen(),
      ),
      GoRoute(
        path: '/emergency/roadside',
        name: 'roadside',
        builder: (context, state) => const HireScreen(initialCategory: 'auto'),
      ),
      GoRoute(
        path: '/emergency/providers/:type',
        name: 'emergencyProviders',
        builder: (context, state) => EmergencyProvidersScreen(type: state.pathParameters['type'] ?? 'ambulance'),
      ),
      GoRoute(
        path: '/wallet',
        name: 'wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/languages',
        name: 'languages',
        builder: (context, state) => const LanguagesScreen(),
      ),
      GoRoute(
        path: '/business',
        name: 'businessProfile',
        builder: (context, state) => const BusinessProfileScreen(),
      ),
      GoRoute(
        path: '/support',
        name: 'support',
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: '/manage-accounts',
        name: 'manageAccounts',
        builder: (context, state) => const ManageAccountsScreen(),
      ),
      GoRoute(
        path: '/privacy',
        name: 'privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/terms',
        name: 'terms',
        builder: (context, state) => const TermsScreen(),
      ),
      GoRoute(
        path: '/rate',
        name: 'rate',
        builder: (context, state) => const RateAppScreen(),
      ),
      GoRoute(
        path: '/promos',
        name: 'promos',
        builder: (context, state) => const PromosScreen(),
      ),
      GoRoute(
        path: '/admin/platform',
        name: 'platformAdmin',
        builder: (context, state) => const PlatformAdminScreen(),
      ),
      GoRoute(
        path: '/admin/promos',
        name: 'adminPromos',
        builder: (context, state) => const _AdminPromosPlaceholder(),
      ),
      GoRoute(
        path: '/admin/emergency-config',
        name: 'emergencyConfig',
        builder: (context, state) => const _AdminEmergencyConfigPlaceholder(),
      ),
      GoRoute(
        path: '/others/ticket/:id',
        name: 'ticketDetail',
        builder: (context, state) => TicketDetailScreen(ticketId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/admin/users',
        name: 'adminUsers',
        builder: (context, state) => const AdminUsersScreen(),
      ),
      GoRoute(
        path: '/food/vendor/menu',
        name: 'vendorMenu',
        builder: (context, state) => VendorMenuScreen(vendorId: state.uri.queryParameters['vendorId'] ?? ''),
      ),
      GoRoute(
        path: '/food/menu/manage',
        name: 'menuManage',
        builder: (context, state) => const MenuManagementScreen(),
      ),
      GoRoute(
        path: '/food/kitchen/hours',
        name: 'kitchenHours',
        builder: (context, state) => const KitchenHoursScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/dev/map-booking',
        name: 'mapBookingDev',
        builder: (context, state) => const MapBookingScreen(),
      ),
      GoRoute(
        path: '/live',
        name: 'liveMap',
        builder: (context, state) => const MapBookingScreen(),
      ),
      GoRoute(
        path: '/moving',
        name: 'moving',
        builder: (context, state) => const MovingScreen(),
      ),
      GoRoute(
        path: '/rentals',
        name: 'rentals',
        builder: (context, state) => const RentalsHubScreen(),
      ),
      GoRoute(
        path: '/rentals/vehicles',
        name: 'rentalVehicles',
        builder: (context, state) => const VehicleRentalsScreen(),
      ),
      GoRoute(
        path: '/rentals/houses',
        name: 'rentalHouses',
        builder: (context, state) => const HouseRentalsScreen(),
      ),
      GoRoute(
        path: '/rentals/others',
        name: 'rentalOthers',
        builder: (context, state) => const OtherRentalsScreen(),
      ),
      // New provider routes
      GoRoute(
        path: '/providers/kyc',
        name: 'providersKyc',
        builder: (context, state) => const KycOnboardingScreen(),
      ),
      GoRoute(
        path: '/hub',
        name: 'providerHub',
        builder: (context, state) => const ProviderHubScreen(),
      ),
      GoRoute(
        path: '/hub/orders',
        name: 'providerOrders',
        builder: (context, state) => const ProviderOrdersScreen(),
      ),
      GoRoute(
        path: '/hub/analytics',
        name: 'providerAnalytics',
        builder: (context, state) => const ProviderAnalyticsScreen(),
      ),
      GoRoute(
        path: '/hub/food',
        name: 'foodProviderDashboard',
        builder: (context, state) => const fooddash.ProviderDashboardScreen(),
      ),
      GoRoute(
        path: '/hub/transport',
        name: 'transportProviderDashboard',
        builder: (context, state) => const tp.TransportProviderDashboardScreen(),
      ),
      GoRoute(
        path: '/hub/hire',
        name: 'hireProviderDashboard',
        builder: (context, state) => const hiredash.HireProviderDashboardScreen(),
      ),
      GoRoute(
        path: '/hub/emergency',
        name: 'emergencyProviderDashboard',
        builder: (context, state) => const emergdash.EmergencyProviderDashboardScreen(),
      ),
      GoRoute(
        path: '/hub/personal',
        name: 'personalProviderDashboard',
        builder: (context, state) => const personaldash.PersonalProviderDashboardScreen(),
      ),
      GoRoute(
        path: '/hub/grocery',
        name: 'groceryProviderDashboard',
        builder: (context, state) => const grocerydash.GroceryProviderDashboardScreen(),
      ),
      GoRoute(
        path: '/hub/moving',
        name: 'movingProviderDashboard',
        builder: (context, state) => const movingdash.MovingProviderDashboardScreen(),
      ),
      GoRoute(
        path: '/hub/rentals',
        name: 'rentalsProviderDashboard',
        builder: (context, state) => const rentalsdash.RentalsProviderDashboardScreen(),
      ),
      GoRoute(
        path: '/hub/marketplace-provider',
        name: 'marketplaceProviderDashboard',
        builder: (context, state) => const mkdash.MarketplaceProviderDashboardScreen(),
      ),
      GoRoute(
        path: '/hub/others-provider',
        name: 'othersProviderDashboard',
        builder: (context, state) => const othersdash.OthersProviderDashboardScreen(),
      ),
      GoRoute(
        path: '/hub/delivery',
        name: 'deliveryProviderDashboard',
        builder: (context, state) => const deliverydash.DeliveryProviderDashboardScreen(),
      ),
      GoRoute(
        path: '/providers',
        name: 'businessProfiles',
        builder: (context, state) => const BusinessProfilesScreen(),
      ),
      GoRoute(
        path: '/providers/create',
        name: 'createServiceProfile',
        builder: (context, state) => CreateServiceProfileScreen(profileId: state.uri.queryParameters['profileId']),
      ),
    ],
  );
});

class _AdminPromosPlaceholder extends StatelessWidget {
  const _AdminPromosPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Manage Promos & Vouchers')), body: const Center(child: Text('Admin placeholder: add/edit promos in Firestore collection "promos"')));
  }
}

class _AdminEmergencyConfigPlaceholder extends StatelessWidget {
  const _AdminEmergencyConfigPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Emergency config')), body: const Padding(padding: EdgeInsets.all(16), child: Text('Admin placeholder: set default lines per country in _config/emergency document (e.g., { "NG": "+23411223344" })')));
  }
}
