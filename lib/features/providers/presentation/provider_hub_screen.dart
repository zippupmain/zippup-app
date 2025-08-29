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
					_online = prof.docs.first.get('availabilityOnline') == true;
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
					ListTile(leading: const Icon(Icons.inbox), title: const Text('Incoming & Active orders'), subtitle: const Text('Requests routed to you'), onTap: () => context.push('/hub/orders')),
					ListTile(leading: const Icon(Icons.bar_chart), title: const Text('Analytics'), onTap: () => context.push('/hub/analytics')),
					if (_service == 'food') ListTile(leading: const Icon(Icons.restaurant_menu), title: const Text('Food dashboard'), onTap: () => context.push('/hub/food')),
					if (_service == 'transport') ListTile(leading: const Icon(Icons.local_taxi), title: const Text('Transport dashboard'), onTap: () => context.push('/hub/transport')),
					if (_service == 'grocery') ListTile(leading: const Icon(Icons.local_grocery_store), title: const Text('Grocery dashboard'), onTap: () => context.push('/hub/grocery')),
					if (_service == 'hire') ListTile(leading: const Icon(Icons.handyman), title: const Text('Hire dashboard'), onTap: () => context.push('/hub/hire')),
					if (_service == 'emergency') ListTile(leading: const Icon(Icons.emergency), title: const Text('Emergency dashboard'), onTap: () => context.push('/hub/emergency')),
					if (_service == 'moving') ListTile(leading: const Icon(Icons.local_shipping), title: const Text('Moving dashboard'), onTap: () => context.push('/hub/moving')),
					if (_service == 'personal') ListTile(leading: const Icon(Icons.spa), title: const Text('Personal dashboard'), onTap: () => context.push('/hub/personal')),
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

