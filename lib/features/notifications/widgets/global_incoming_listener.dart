import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:zippup/services/notifications/sound_service.dart';
import 'package:flutter/services.dart';

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
		print('🚀 GlobalIncomingListener initialized');
		_bind();
		// Listen for auth state changes to re-bind listeners
		FirebaseAuth.instance.authStateChanges().listen((user) {
			print('🔄 Auth state changed, rebinding listeners for user: ${user?.uid}');
			_bind();
		});
	}

	@override
	void didUpdateWidget(covariant GlobalIncomingListener oldWidget) {
		super.didUpdateWidget(oldWidget);
	}

	void _bind() {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		print('🔗 Binding notification listeners for user: $uid');
		_unbind();
		if (uid == null) {
			print('❌ No user authenticated, skipping notification binding');
			return;
		}
		final db = FirebaseFirestore.instance;
		print('✅ Setting up ride notification listener for user: $uid');
		
		// Listen for ride requests assigned to this driver OR unassigned rides for available drivers
		_ridesSub = db.collection('rides')
			.where('status', isEqualTo: 'requested')
			.snapshots()
			.listen((snap) async {
				print('📡 Received ${snap.docs.length} ride requests from Firestore');
				// Check if user has active transport provider profile AND is online
				bool isActiveTransportProvider = false;
				try {
					print('🔍 Checking provider profile for user: $uid');
					final providerSnap = await db.collection('provider_profiles')
						.where('userId', isEqualTo: uid)
						.where('service', isEqualTo: 'transport')
						.where('status', isEqualTo: 'active')
						.limit(1)
						.get();
					print('📋 Found ${providerSnap.docs.length} transport provider profiles');
					if (providerSnap.docs.isNotEmpty) {
						final providerData = providerSnap.docs.first.data();
						final isOnline = providerData['availabilityOnline'] == true;
						print('🟢 Provider online status: $isOnline');
						// Only show requests if provider is online/available
						isActiveTransportProvider = isOnline;
					}
				} catch (e) {
					print('❌ Error checking provider profile: $e');
				}
				
				for (final d in snap.docs) {
					final data = d.data();
					final assignedDriverId = data['driverId']?.toString();
					
					// Show if: assigned to this driver OR (no driver assigned AND user is active provider)
					bool shouldShow = false;
					if (assignedDriverId == uid) {
						shouldShow = true; // Directly assigned
					} else if ((assignedDriverId == null || assignedDriverId.isEmpty) && isActiveTransportProvider) {
						shouldShow = true; // Available for active providers
					}
					
					if (shouldShow && !_shown.contains('ride:${d.id}')) {
						print('🚨 Showing ride notification for ride: ${d.id}');
						_shown.add('ride:${d.id}');
						_showRideDialog(d.id, data);
					} else if (!shouldShow) {
						print('🚫 Not showing ride ${d.id} - shouldShow: $shouldShow, assignedDriverId: $assignedDriverId, isActiveProvider: $isActiveTransportProvider');
					}
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
		final shouldShow = _shouldShowHere();
		print('🔍 _shouldShowHere() returned: $shouldShow');
		if (!shouldShow) {
			print('❌ Not showing ride dialog due to _shouldShowHere() = false');
			return;
		}
		final ctx = context;
		print('✅ Showing ride dialog for ride: $id');
		// Fetch rider profile and total rides count for richer context
		String riderName = 'Customer';
		String riderPhoto = '';
		int riderRides = 0;
		try {
			final riderId = (m['riderId'] ?? '').toString();
			if (riderId.isNotEmpty) {
				// Fetch both profiles simultaneously for better performance
				final results = await Future.wait([
					FirebaseFirestore.instance.collection('public_profiles').doc(riderId).get(),
					FirebaseFirestore.instance.collection('users').doc(riderId).get(),
				]);
				
				final pu = results[0].data() ?? const {};
				final u = results[1].data() ?? const {};
				
				// Debug: Print profile data
				print('🔍 Customer Profile Debug:');
				print('Public profile exists: ${results[0].exists}');
				print('User profile exists: ${results[1].exists}');
				print('Public profile data: $pu');
				print('User profile data: $u');
				
				// Create public profile if missing but user profile exists
				if (!results[0].exists && results[1].exists && u['name'] != null) {
					// Fire and forget - create profile in background
					FirebaseFirestore.instance.collection('public_profiles').doc(riderId).set({
						'name': u['name'],
						'photoUrl': u['photoUrl'] ?? '',
						'createdAt': DateTime.now().toIso8601String(),
					}).then((_) {
						print('✅ Created missing public profile for customer: ${u['name']}');
					}).catchError((e) {
						print('❌ Failed to create public profile: $e');
					});
				}
				
				// Better name resolution with multiple fallbacks
				if (pu['name'] != null && pu['name'].toString().trim().isNotEmpty) {
					riderName = pu['name'].toString().trim();
					print('✅ Found name in public profile: $riderName');
				} else if (u['name'] != null && u['name'].toString().trim().isNotEmpty) {
					riderName = u['name'].toString().trim();
					print('✅ Found name in user profile: $riderName');
				} else if (u['displayName'] != null && u['displayName'].toString().trim().isNotEmpty) {
					riderName = u['displayName'].toString().trim();
				} else if (u['firstName'] != null || u['lastName'] != null) {
					final firstName = (u['firstName'] ?? '').toString().trim();
					final lastName = (u['lastName'] ?? '').toString().trim();
					if (firstName.isNotEmpty || lastName.isNotEmpty) {
						riderName = '$firstName $lastName'.trim();
					}
				} else if (u['email'] != null) {
					// Extract name from email as last resort
					final email = u['email'].toString();
					final atIndex = email.indexOf('@');
					if (atIndex > 0) {
						riderName = email.substring(0, atIndex).replaceAll('.', ' ').replaceAll('_', ' ');
						riderName = riderName.split(' ').map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : '').join(' ');
					}
				}
				
				// Better photo resolution
				if (pu['photoUrl'] != null && pu['photoUrl'].toString().trim().isNotEmpty) {
					riderPhoto = pu['photoUrl'].toString().trim();
				} else if (u['photoUrl'] != null && u['photoUrl'].toString().trim().isNotEmpty) {
					riderPhoto = u['photoUrl'].toString().trim();
				} else if (u['profilePicture'] != null && u['profilePicture'].toString().trim().isNotEmpty) {
					riderPhoto = u['profilePicture'].toString().trim();
				}
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
		try { await SoundService.instance.playCall(); } catch (_) {}
		await showDialog(context: ctx, builder: (_) => AlertDialog(
			title: const Text('🚗 New Ride Request'),
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
				final pub = await FirebaseFirestore.instance.collection('public_profiles').doc(buyerId).get();
				final pu = pub.data() ?? const {};
				buyerName = (pu['name'] ?? '').toString().trim().isNotEmpty ? pu['name'].toString() : buyerName;
				buyerPhoto = (pu['photoUrl'] ?? '').toString();
				if (buyerName == 'Customer') {
					final userDoc = await FirebaseFirestore.instance.collection('users').doc(buyerId).get();
					final u = userDoc.data() ?? const {};
					buyerName = (u['name'] ?? buyerName).toString();
					buyerPhoto = buyerPhoto.isNotEmpty ? buyerPhoto : (u['photoUrl'] ?? '').toString();
				}
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
		try { await SoundService.instance.playCall(); } catch (_) {}
		await showDialog(context: ctx, builder: (_) => AlertDialog(
			title: const Text('💼 New Job Request'),
			content: Column(
				mainAxisSize: MainAxisSize.min,
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					ListTile(
						contentPadding: EdgeInsets.zero,
						leading: CircleAvatar(backgroundImage: buyerPhoto.isNotEmpty ? NetworkImage(buyerPhoto) : null, child: buyerPhoto.isEmpty ? const Icon(Icons.person) : null),
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
		try { await SoundService.instance.playChirp(); } catch (_) {}
		await showDialog(context: ctx, builder: (_) => AlertDialog(
			title: const Text('🚚 New Delivery Assigned'),
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
		try { await SoundService.instance.playCall(); } catch (_) {}
		await showDialog(context: ctx, builder: (_) => AlertDialog(
			title: const Text('📦 New Moving Request'),
			content: Text('${(m['subcategory'] ?? 'moving').toString().toUpperCase()}\nFrom: ${(m['pickupAddress'] ?? '').toString()}'),
			actions: [
				TextButton(onPressed: () { Navigator.pop(ctx); _updateMoving(id, 'cancelled'); }, child: const Text('Decline')),
				FilledButton(onPressed: () { Navigator.pop(ctx); _updateMoving(id, 'accepted'); _go('/hub/moving'); }, child: const Text('Accept')),
			],
		));
	}

	bool _shouldShowHere() {
		// Show popups globally regardless of current page
		print('🌍 _shouldShowHere() called - returning true for global notifications');
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