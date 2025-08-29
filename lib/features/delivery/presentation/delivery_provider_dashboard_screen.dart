import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeliveryProviderDashboardScreen extends StatefulWidget {
	const DeliveryProviderDashboardScreen({super.key});
	@override
	State<DeliveryProviderDashboardScreen> createState() => _DeliveryProviderDashboardScreenState();
}

class _DeliveryProviderDashboardScreenState extends State<DeliveryProviderDashboardScreen> {
	final _db = FirebaseFirestore.instance;
	final _auth = FirebaseAuth.instance;
	bool _online = false;
	StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _activeSub;
	Map<String, dynamic>? _activeOrder; String? _activeOrderId;

	Stream<QuerySnapshot<Map<String, dynamic>>> _incoming() {
		final uid = _auth.currentUser?.uid ?? '';
		return _db.collection('orders')
			.where('deliveryId', isEqualTo: uid)
			.where('status', whereIn: ['assigned','dispatched'])
			.snapshots();
	}

	Stream<QuerySnapshot<Map<String, dynamic>>> _active() {
		final uid = _auth.currentUser?.uid ?? '';
		return _db.collection('orders')
			.where('deliveryId', isEqualTo: uid)
			.where('status', whereIn: ['assigned','enroute','arrived'])
			.limit(1)
			.snapshots();
	}

	Future<void> _setOnline(bool v) async {
		setState(() => _online = v);
		final uid = _auth.currentUser?.uid; if (uid == null) return;
		await _db.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: 'delivery').limit(1).get().then((snap) async {
			if (snap.docs.isNotEmpty) await snap.docs.first.reference.set({'availabilityOnline': v}, SetOptions(merge: true));
		});
	}

	Future<void> _updateStatus(String id, String status) => _db.collection('orders').doc(id).set({'status': status}, SetOptions(merge: true));

	@override
	void initState() {
		super.initState();
		_activeSub = _active().listen((snap) {
			if (snap.docs.isNotEmpty) {
				setState(() { _activeOrderId = snap.docs.first.id; _activeOrder = snap.docs.first.data(); });
			} else {
				setState(() { _activeOrderId = null; _activeOrder = null; });
			}
		});
	}

	@override
	void dispose() {
		_activeSub?.cancel();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		final uid = _auth.currentUser?.uid ?? '';
		return DefaultTabController(
			length: 2,
			child: Scaffold(
				appBar: AppBar(title: const Text('Delivery Dashboard'), actions: [
					IconButton(icon: const Icon(Icons.home_outlined), onPressed: () => context.go('/')),
					IconButton(icon: const Icon(Icons.close), onPressed: () { if (Navigator.of(context).canPop()) { Navigator.pop(context); } else { context.go('/'); } }),
				], bottom: const TabBar(tabs: [
					Tab(icon: Icon(Icons.inbox), text: 'Incoming'),
					Tab(icon: Icon(Icons.local_shipping), text: 'Active'),
				])),
				body: Column(children: [
					SwitchListTile(title: const Text('Go Online'), value: _online, onChanged: _setOnline),
					Expanded(child: TabBarView(children: [
						// Incoming
						StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
							stream: _incoming(),
							builder: (context, s) {
								if (!s.hasData) return const Center(child: CircularProgressIndicator());
								final docs = s.data!.docs;
								if (docs.isEmpty) return const Center(child: Text('No incoming deliveries'));
								return ListView.separated(
									itemCount: docs.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, i) {
										final id = docs[i].id; final d = docs[i].data();
										return ListTile(
											title: Text('Order ${id.substring(0,6)} • ${(d['category'] ?? '').toString()}'),
											subtitle: Text('Status: ${(d['status'] ?? '').toString()}'),
											trailing: FilledButton(onPressed: () => _updateStatus(id, 'enroute'), child: const Text('Accept')),
										);
									},
								);
							},
						),
						// Active
						Builder(builder: (_) {
							final d = _activeOrder; final id = _activeOrderId;
							if (d == null || id == null) return const Center(child: Text('No active delivery'));
							return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
								Text('Order ${id.substring(0,6)} • ${(d['category'] ?? '').toString()}', style: Theme.of(context).textTheme.titleMedium),
								const SizedBox(height: 8),
								Text('Status: ${(d['status'] ?? '').toString()}'),
								const SizedBox(height: 12),
								Wrap(spacing: 8, children: [
									OutlinedButton(onPressed: () => _updateStatus(id, 'arrived'), child: const Text('Arrived at dropoff')),
									FilledButton(onPressed: () => context.push('/driver/delivery?orderId=$id'), child: const Text('Enter code')),
								]),
							]));
						}),
					]))
				]),
			),
		);
	}
}

