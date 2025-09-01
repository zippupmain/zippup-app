import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProviderHubScreen extends StatefulWidget {
	const ProviderHubScreen({super.key});
	@override
	State<ProviderHubScreen> createState() => _ProviderHubScreenState();
}

class _ProviderHubScreenState extends State<ProviderHubScreen> {
	bool _loading = true;
	bool _isProviderMode = false;
	bool _online = false;
	String _service = '';

	@override
	void initState() {
		super.initState();
		_init();
	}

	Future<void> _init() async {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		if (uid == null) { setState(() { _loading = false; }); return; }
		try {
			final user = await FirebaseFirestore.instance.collection('users').doc(uid).get();
			final role = (user.data()?['activeRole']?.toString() ?? 'customer');
			_isProviderMode = role.startsWith('provider:');
			_service = _isProviderMode ? role.split(':').last : '';
			if (_isProviderMode) {
				final prof = await FirebaseFirestore.instance.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: _service).limit(1).get();
				if (prof.docs.isNotEmpty) {
					// Default to online/active, providers can toggle offline
					_online = prof.docs.first.get('availabilityOnline') ?? true;
				} else {
					// Default to online for new providers
					_online = true;
				}
			}
		} catch (_) {}
		if (mounted) setState(() { _loading = false; });
	}

	Future<void> _toggleOnline(bool v) async {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		if (uid == null) return;
		setState(() => _online = v);
		try {
			await FirebaseFirestore.instance.collection('provider_profiles')
				.where('userId', isEqualTo: uid)
				.where('service', isEqualTo: _service)
				.limit(1)
				.get().then((snap) async {
					if (snap.docs.isNotEmpty) {
						await snap.docs.first.reference.set({'availabilityOnline': v}, SetOptions(merge: true));
					}
				});
			if (v) {
				// Auto-switch to provider mode for this service
				await FirebaseFirestore.instance.collection('users').doc(uid).set({'activeRole': 'provider:${_service}'}, SetOptions(merge: true));
			} else {
				// If no active jobs, auto-switch back to customer
				final hasActive = await _hasActiveJobs(uid);
				if (!hasActive) {
					await FirebaseFirestore.instance.collection('users').doc(uid).set({'activeRole': 'customer'}, SetOptions(merge: true));
				}
			}
		} catch (e) {
			if (mounted) setState(() => _online = !v);
		}
	}

	Future<bool> _hasActiveJobs(String uid) async {
		try {
			const activeRide = ['accepted', 'arriving', 'arrived', 'enroute'];
			const activeOrder = ['accepted', 'assigned', 'preparing', 'dispatched', 'enroute', 'arriving', 'arrived'];
			final rideQ = await FirebaseFirestore.instance
				.collection('rides')
				.where('driverId', isEqualTo: uid)
				.where('status', whereIn: activeRide)
				.limit(1)
				.get();
			if (rideQ.docs.isNotEmpty) return true;
			final orderQ = await FirebaseFirestore.instance
				.collection('orders')
				.where('providerId', isEqualTo: uid)
				.where('status', whereIn: activeOrder)
				.limit(1)
				.get();
			return orderQ.docs.isNotEmpty;
		} catch (_) { return false; }
	}

	@override
	Widget build(BuildContext context) {
		if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
		return Scaffold(
			appBar: AppBar(title: const Text('Provider Hub'), actions: [
				IconButton(icon: const Icon(Icons.home_outlined), onPressed: () => context.go('/')),
				IconButton(icon: const Icon(Icons.close), onPressed: () { if (Navigator.of(context).canPop()) { Navigator.pop(context); } else { context.go('/'); } }),
			]),
			body: !_isProviderMode
				? _BecomeProvider()
				: ListView(children: [
					Padding(
						padding: const EdgeInsets.all(16),
						child: Row(children: [
							Expanded(child: Text('$_service • ${_online ? 'Online' : 'Offline'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
							Switch(value: _online, onChanged: _toggleOnline),
						]),
					),
					const Divider(),
					// Global notifications and analytics
					ListTile(leading: const Icon(Icons.inbox), title: const Text('Incoming & Active orders'), subtitle: const Text('All requests routed to you'), onTap: () => context.push('/hub/orders')),
					ListTile(leading: const Icon(Icons.bar_chart), title: const Text('Analytics & Earnings'), subtitle: const Text('Performance insights'), onTap: () => context.push('/hub/analytics')),
					
					const Divider(),
					const Padding(
						padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
						child: Text('Service Dashboards', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
					),
					
					// Core Services
					if (_service == 'transport') ListTile(
						leading: const Icon(Icons.local_taxi, color: Colors.blue),
						title: const Text('🚗 Transport Dashboard'),
						subtitle: const Text('Ride requests, navigation, earnings'),
						onTap: () => context.push('/hub/transport'),
					),
					if (_service == 'food') ListTile(
						leading: const Icon(Icons.restaurant_menu, color: Colors.orange),
						title: const Text('🍽️ Food Dashboard'),
						subtitle: const Text('Orders, menu management, delivery'),
						onTap: () => context.push('/hub/food'),
					),
					if (_service == 'grocery') ListTile(
						leading: const Icon(Icons.local_grocery_store, color: Colors.green),
						title: const Text('🥬 Grocery Dashboard'),
						subtitle: const Text('Grocery orders, inventory, delivery'),
						onTap: () => context.push('/hub/grocery'),
					),
					
					// New Enhanced Services
					if (_service == 'hire') ListTile(
						leading: const Icon(Icons.handyman, color: Colors.blue),
						title: const Text('👥 Hire Services Dashboard'),
						subtitle: const Text('Home services, scheduling, tools'),
						onTap: () => context.push('/hub/hire'),
					),
					if (_service == 'emergency') ListTile(
						leading: const Icon(Icons.emergency, color: Colors.red),
						title: const Text('🚨 Emergency Dashboard'),
						subtitle: const Text('Priority responses, vehicle tracking'),
						onTap: () => context.push('/hub/emergency'),
					),
					if (_service == 'moving') ListTile(
						leading: const Icon(Icons.local_shipping, color: Colors.orange),
						title: const Text('📦 Moving Dashboard'),
						subtitle: const Text('Moving requests, vehicle details, routes'),
						onTap: () => context.push('/hub/moving'),
					),
					if (_service == 'personal') ListTile(
						leading: const Icon(Icons.spa, color: Colors.purple),
						title: const Text('👤 Personal Services Dashboard'),
						subtitle: const Text('Beauty, wellness, fitness bookings'),
						onTap: () => context.push('/hub/personal'),
					),
					
					// Marketplace Services
					if (_service == 'rentals') ListTile(
						leading: const Icon(Icons.home_work, color: Colors.brown),
						title: const Text('🏠 Rentals Dashboard'),
						subtitle: const Text('Vehicle, house, equipment rentals'),
						onTap: () => context.push('/hub/rentals'),
					),
					if (_service == 'marketplace') ListTile(
						leading: const Icon(Icons.store, color: Colors.indigo),
						title: const Text('🛍️ Marketplace Dashboard'),
						subtitle: const Text('Product listings, sales, inventory'),
						onTap: () => context.push('/hub/marketplace-provider'),
					),
					if (_service == 'others') ListTile(
						leading: const Icon(Icons.business_center, color: Colors.teal),
						title: const Text('📅 Others Services Dashboard'),
						subtitle: const Text('Events, tutoring, creative, business'),
						onTap: () => context.push('/hub/others-provider'),
					),
					if (_service == 'delivery') ListTile(
						leading: const Icon(Icons.delivery_dining, color: Colors.cyan),
						title: const Text('🚚 Delivery Dashboard'),
						subtitle: const Text('Delivery requests, routes, codes'),
						onTap: () => context.push('/hub/delivery'),
					),
					

					ListTile(leading: const Icon(Icons.settings_suggest), title: const Text('Manage service profiles'), onTap: () => context.push('/providers')),
					const SizedBox(height: 24),
				]),
		);
	}
}

class _BecomeProvider extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return Center(
			child: Padding(
				padding: const EdgeInsets.all(24),
				child: Column(mainAxisSize: MainAxisSize.min, children: [
					const Text('Become a provider and start earning on ZippUp'),
					const SizedBox(height: 12),
					FilledButton.icon(onPressed: () => context.push('/providers/kyc'), icon: const Icon(Icons.verified_user), label: const Text('Apply as Provider / Vendor')),
				]),
			),
		);
	}
}

