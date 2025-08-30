import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GlobalIncomingListener extends StatefulWidget {
	final Widget child;
	const GlobalIncomingListener({super.key, required this.child});
	@override
	State<GlobalIncomingListener> createState() => _GlobalIncomingListenerState();
}

class _GlobalIncomingListenerState extends State<GlobalIncomingListener> {
	StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ridesSub;
	StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ordersSub;
	StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _deliverySub;
	StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _movingSub;
	final Set<String> _shown = <String>{};

	@override
	void initState() {
		super.initState();
		_bind();
	}

	@override
	void didUpdateWidget(covariant GlobalIncomingListener oldWidget) {
		super.didUpdateWidget(oldWidget);
	}

	void _bind() {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		_unbind();
		if (uid == null) return;
		final db = FirebaseFirestore.instance;
		_ridesSub = db.collection('rides')
			.where('driverId', isEqualTo: uid)
			.where('status', isEqualTo: 'requested')
			.snapshots()
			.listen((snap) {
				for (final d in snap.docs) {
					if (_shown.contains('ride:${d.id}')) continue;
					_shown.add('ride:${d.id}');
					_showRideDialog(d.id, d.data());
				}
			});
		_ordersSub = db.collection('orders')
			.where('providerId', isEqualTo: uid)
			.where('status', isEqualTo: 'pending')
			.snapshots()
			.listen((snap) {
				for (final d in snap.docs) {
					if (_shown.contains('order:${d.id}')) continue;
					_shown.add('order:${d.id}');
					_showOrderDialog(d.id, d.data());
				}
			});
		_deliverySub = db.collection('orders')
			.where('deliveryId', isEqualTo: uid)
			.where('status', whereIn: ['assigned','dispatched'])
			.snapshots()
			.listen((snap) {
				for (final d in snap.docs) {
					if (_shown.contains('delivery:${d.id}')) continue;
					_shown.add('delivery:${d.id}');
					_showDeliveryDialog(d.id, d.data());
				}
			});
		_movingSub = db.collection('moving_requests')
			.where('assignedProviderId', isEqualTo: uid)
			.where('status', isEqualTo: 'requested')
			.snapshots()
			.listen((snap) {
				for (final d in snap.docs) {
					if (_shown.contains('moving:${d.id}')) continue;
					_shown.add('moving:${d.id}');
					_showMovingDialog(d.id, d.data());
				}
			});
	}

	@override
	void dispose() {
		_unbind();
		super.dispose();
	}

	void _unbind() {
		try { _ridesSub?.cancel(); } catch (_) {}
		try { _ordersSub?.cancel(); } catch (_) {}
		try { _deliverySub?.cancel(); } catch (_) {}
		try { _movingSub?.cancel(); } catch (_) {}
		_ridesSub = null; _ordersSub = null; _deliverySub = null; _movingSub = null;
	}

	Future<void> _showRideDialog(String id, Map<String, dynamic> m) async {
		if (!_shouldShowHere()) return;
		final ctx = context;
		// Fetch rider profile and total rides count for richer context
		String riderName = 'Customer';
		String riderPhoto = '';
		int riderRides = 0;
		try {
			final riderId = (m['riderId'] ?? '').toString();
			if (riderId.isNotEmpty) {
				final userDoc = await FirebaseFirestore.instance.collection('users').doc(riderId).get();
				final u = userDoc.data() ?? const {};
				riderName = (u['name'] ?? '').toString().trim().isNotEmpty ? u['name'].toString() : riderName;
				riderPhoto = (u['photoUrl'] ?? '').toString();
				try {
					final agg = await FirebaseFirestore.instance
						.collection('rides')
						.where('riderId', isEqualTo: riderId)
						.count()
						.get();
					riderRides = agg.count ?? 0;
				} catch (_) {}
			}
		} catch (_) {}
		await showDialog(context: ctx, builder: (_) => AlertDialog(
			title: const Text('New ride request'),
			content: Column(
				mainAxisSize: MainAxisSize.min,
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					ListTile(
						contentPadding: EdgeInsets.zero,
						leading: CircleAvatar(
							backgroundImage: riderPhoto.isNotEmpty ? NetworkImage(riderPhoto) : null,
							child: riderPhoto.isEmpty ? const Icon(Icons.person) : null,
						),
						title: Text(riderName),
						subtitle: Text('Rides: $riderRides'),
					),
					const SizedBox(height: 8),
					Text('${(m['type'] ?? 'ride').toString().toUpperCase()}\nFrom: ${(m['pickupAddress'] ?? '').toString()}\nTo: ${(m['destinationAddresses'] is List && (m['destinationAddresses'] as List).isNotEmpty) ? (m['destinationAddresses'] as List).first.toString() : ''}'),
				],
			),
			actions: [
				TextButton(onPressed: () { Navigator.pop(ctx); _declineRide(id); }, child: const Text('Decline')),
				FilledButton(onPressed: () { Navigator.pop(ctx); _acceptRide(id); _go('/driver/ride?rideId=' + id); }, child: const Text('Accept')),
			],
		));
	}

	Future<void> _showOrderDialog(String id, Map<String, dynamic> m) async {
		if (!_shouldShowHere()) return;
		final ctx = context;
		final category = (m['category'] ?? '').toString();
		String buyerName = 'Customer';
		String buyerPhoto = '';
		int buyerOrders = 0;
		try {
			final buyerId = (m['buyerId'] ?? '').toString();
			if (buyerId.isNotEmpty) {
				final userDoc = await FirebaseFirestore.instance.collection('users').doc(buyerId).get();
				final u = userDoc.data() ?? const {};
				buyerName = (u['name'] ?? '').toString().trim().isNotEmpty ? u['name'].toString() : buyerName;
				buyerPhoto = (u['photoUrl'] ?? '').toString();
				try {
					final agg = await FirebaseFirestore.instance
						.collection('orders')
						.where('buyerId', isEqualTo: buyerId)
						.count()
						.get();
					buyerOrders = agg.count ?? 0;
				} catch (_) {}
			}
		} catch (_) {}
		await showDialog(context: ctx, builder: (_) => AlertDialog(
			title: const Text('New job request'),
			content: Column(
				mainAxisSize: MainAxisSize.min,
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					ListTile(
						contentPadding: EdgeInsets.zero,
						leading: CircleAvatar(
							backgroundImage: buyerPhoto.isNotEmpty ? NetworkImage(buyerPhoto) : null,
							child: buyerPhoto.isEmpty ? const Icon(Icons.person) : null,
						),
						title: Text(buyerName),
						subtitle: Text('Orders: $buyerOrders'),
					),
					const SizedBox(height: 8),
					Text('Order ${id.substring(0,6)} • ${category.isEmpty ? 'order' : category}')
				],
			),
			actions: [
				TextButton(onPressed: () { Navigator.pop(ctx); _declineOrder(id, category); }, child: const Text('Decline')),
				FilledButton(onPressed: () { Navigator.pop(ctx); _acceptOrder(id, category); _go(_routeForCategory(category)); }, child: const Text('Accept')),
			],
		));
	}

	Future<void> _showDeliveryDialog(String id, Map<String, dynamic> m) async {
		if (!_shouldShowHere()) return;
		final ctx = context;
		await showDialog(context: ctx, builder: (_) => AlertDialog(
			title: const Text('New delivery assigned'),
			content: Text('Order ${id.substring(0,6)} • ${(m['category'] ?? '').toString()}'),
			actions: [
				TextButton(onPressed: () { Navigator.pop(ctx); }, child: const Text('Later')),
				FilledButton(onPressed: () { Navigator.pop(ctx); _acceptDelivery(id); _go('/hub/delivery'); }, child: const Text('View')),
			],
		));
	}

	Future<void> _showMovingDialog(String id, Map<String, dynamic> m) async {
		if (!_shouldShowHere()) return;
		final ctx = context;
		await showDialog(context: ctx, builder: (_) => AlertDialog(
			title: const Text('New moving request'),
			content: Text('${(m['subcategory'] ?? 'moving').toString().toUpperCase()}\nFrom: ${(m['pickupAddress'] ?? '').toString()}'),
			actions: [
				TextButton(onPressed: () { Navigator.pop(ctx); _updateMoving(id, 'cancelled'); }, child: const Text('Decline')),
				FilledButton(onPressed: () { Navigator.pop(ctx); _updateMoving(id, 'accepted'); _go('/hub/moving'); }, child: const Text('Accept')),
			],
		));
	}

	bool _shouldShowHere() {
		// Show popups globally regardless of current page
		return true;
	}

	Future<void> _acceptRide(String id) async {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		await FirebaseFirestore.instance.collection('rides').doc(id).set({'status': 'accepted', if (uid != null) 'driverId': uid}, SetOptions(merge: true));
	}
	Future<void> _declineRide(String id) async {
		await FirebaseFirestore.instance.collection('rides').doc(id).set({'status': 'cancelled', 'cancelReason': 'declined_by_driver', 'cancelledAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
	}

	Future<void> _acceptOrder(String id, String category) async {
		final next = _nextStatusForCategory(category);
		await FirebaseFirestore.instance.collection('orders').doc(id).set({'status': next}, SetOptions(merge: true));
	}
	Future<void> _declineOrder(String id, String category) async {
		await FirebaseFirestore.instance.collection('orders').doc(id).set({'status': 'cancelled', 'cancelReason': 'declined_by_provider', 'cancelledAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
	}

	Future<void> _acceptDelivery(String id) async {
		await FirebaseFirestore.instance.collection('orders').doc(id).set({'status': 'enroute'}, SetOptions(merge: true));
	}

	Future<void> _updateMoving(String id, String status) async {
		await FirebaseFirestore.instance.collection('moving_requests').doc(id).set({'status': status}, SetOptions(merge: true));
	}

	String _nextStatusForCategory(String c) {
		switch (c) {
			case 'food':
				return 'preparing';
			case 'groceries':
				return 'preparing';
			case 'marketplace':
				return 'accepted';
			case 'hire':
				return 'accepted';
			case 'emergency':
				return 'accepted';
			case 'personal':
				return 'accepted';
			case 'rentals':
				return 'accepted';
			case 'others':
				return 'accepted';
			default:
				return 'accepted';
		}
	}

	String _routeForCategory(String c) {
		switch (c) {
			case 'food':
				return '/hub/food';
			case 'groceries':
				return '/hub/grocery';
			case 'marketplace':
				return '/hub/marketplace-provider';
			case 'hire':
				return '/hub/hire';
			case 'emergency':
				return '/hub/emergency';
			case 'personal':
				return '/hub/personal';
			case 'rentals':
				return '/hub/rentals';
			case 'others':
				return '/hub/others-provider';
			default:
				return '/hub';
		}
	}

	void _go(String route) {
		if (!mounted) return;
		context.push(route);
	}

	@override
	Widget build(BuildContext context) {
		return widget.child;
	}
}