import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:zippup/services/notifications/sound_service.dart';
import 'package:zippup/features/notifications/widgets/floating_notification.dart';

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
		print('✅ Setting up AGGRESSIVE ride notification listener for user: $uid');
		print('🚨 NOTIFICATION DEBUG MODE: Will show all ride requests for testing');
		
		// Listen for ride requests assigned to this driver OR unassigned rides for available drivers
		_ridesSub = db.collection('rides')
			.where('status', isEqualTo: 'requested')
			.snapshots()
			.listen((snap) async {
				print('📡 Received ${snap.docs.length} ride requests from Firestore');
				// TESTING MODE: Show notifications to ALL logged-in users
				bool isActiveTransportProvider = true; // Force true for testing
				print('🚨 TESTING MODE: Showing ALL ride requests to ANY logged-in user');
				print('🔍 User $uid will receive ALL ride notifications for testing purposes');
				
				for (final d in snap.docs) {
					final data = d.data();
					final assignedDriverId = data['driverId']?.toString();
					
					// TESTING MODE: Show ALL ride requests to ALL users
					bool shouldShow = true; // Force true for testing
					print('🚨 TESTING: Will show ride ${d.id} to user $uid (assignedDriverId: $assignedDriverId)');
					
					if (shouldShow && !_shown.contains('ride:${d.id}')) {
						print('🚨 SHOWING RIDE NOTIFICATION for ride: ${d.id}');
						print('📋 Ride data: ${data}');
						print('👤 Customer ID: ${data['riderId']}');
						print('🚗 Ride type: ${data['type']}');
						print('📍 From: ${data['pickupAddress']}');
						_shown.add('ride:${d.id}');
						
						// Show floating notification first
						NotificationOverlay.show(
							context,
							title: '🚗 New Ride Request',
							message: 'From: ${data['pickupAddress'] ?? 'Unknown location'}',
							backgroundColor: Colors.blue.shade600,
							icon: Icons.directions_car,
							onTap: () => _showRideDialog(d.id, data),
						);
						
						// Also show dialog
						_showRideDialog(d.id, data);
					} else if (!shouldShow) {
						print('🚫 Not showing ride ${d.id} - shouldShow: $shouldShow, assignedDriverId: $assignedDriverId, isActiveProvider: $isActiveTransportProvider');
					} else if (_shown.contains('ride:${d.id}')) {
						print('⏭️ Already showed ride ${d.id}, skipping...');
					}
				}
			});
		// Enhanced listeners for all service types
		_setupServiceListener(db, uid, 'hire_bookings', 'hire');
		_setupServiceListener(db, uid, 'emergency_bookings', 'emergency');
		_setupServiceListener(db, uid, 'moving_bookings', 'moving');
		_setupServiceListener(db, uid, 'personal_bookings', 'personal');
		_setupServiceListener(db, uid, 'rental_bookings', 'rentals');
		_setupServiceListener(db, uid, 'marketplace_orders', 'marketplace');
		_setupServiceListener(db, uid, 'others_bookings', 'others');
		
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
				print('🔍 Starting name resolution for rider: $riderId');
				print('📄 Public profile data keys: ${pu.keys.toList()}');
				print('👤 User profile data keys: ${u.keys.toList()}');
				
				if (pu['name'] != null && pu['name'].toString().trim().isNotEmpty) {
					riderName = pu['name'].toString().trim();
					print('✅ Found name in public profile: $riderName');
				} else if (u['name'] != null && u['name'].toString().trim().isNotEmpty) {
					riderName = u['name'].toString().trim();
					print('✅ Found name in user profile: $riderName');
				} else if (u['displayName'] != null && u['displayName'].toString().trim().isNotEmpty) {
					riderName = u['displayName'].toString().trim();
					print('✅ Found displayName: $riderName');
				} else if (u['firstName'] != null || u['lastName'] != null) {
					final firstName = (u['firstName'] ?? '').toString().trim();
					final lastName = (u['lastName'] ?? '').toString().trim();
					if (firstName.isNotEmpty || lastName.isNotEmpty) {
						riderName = '$firstName $lastName'.trim();
						print('✅ Found firstName/lastName: $riderName');
					}
				} else if (u['email'] != null) {
					// Extract name from email as last resort
					final email = u['email'].toString();
					final atIndex = email.indexOf('@');
					if (atIndex > 0) {
						riderName = email.substring(0, atIndex).replaceAll('.', ' ').replaceAll('_', ' ');
						riderName = riderName.split(' ').map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : '').join(' ');
						print('✅ Extracted name from email: $riderName');
					}
				}
				
				print('🎯 Final rider name: $riderName');
				if (riderName == 'Customer') {
					print('⚠️ WARNING: Still showing default "Customer" name - check user profile data');
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
		// Play notification sound with enhanced error handling
		try { 
			print('🔔 Attempting to play RIDE REQUEST notification sound...');
			await SoundService.instance.playCall();
			print('✅ Ride request notification sound played successfully');
		} catch (e) {
			print('❌ Failed to play ride notification sound: $e');
			// Fallback: try system beep
			try {
				await SystemSound.play(SystemSoundType.alert);
				await HapticFeedback.mediumImpact();
				print('✅ Fallback ride notification sound played');
			} catch (fallbackError) {
				print('❌ Even fallback ride notification sound failed: $fallbackError');
			}
		}
		
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
					Card(
						color: Colors.blue.shade50,
						child: Padding(
							padding: const EdgeInsets.all(12),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Row(
										children: [
											Icon(Icons.directions_car, color: Colors.blue.shade700, size: 20),
											const SizedBox(width: 8),
											Text('${(m['type'] ?? 'ride').toString().toUpperCase()} REQUEST', 
												style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
										],
									),
									const SizedBox(height: 8),
									Row(
										children: [
											const Icon(Icons.my_location, color: Colors.green, size: 16),
											const SizedBox(width: 4),
											Expanded(child: Text('From: ${(m['pickupAddress'] ?? '').toString()}', style: const TextStyle(fontSize: 12))),
										],
									),
									const SizedBox(height: 4),
									Row(
										children: [
											const Icon(Icons.location_on, color: Colors.red, size: 16),
											const SizedBox(width: 4),
											Expanded(child: Text('To: ${(m['destinationAddresses'] is List && (m['destinationAddresses'] as List).isNotEmpty) ? (m['destinationAddresses'] as List).first.toString() : 'Not specified'}', style: const TextStyle(fontSize: 12))),
										],
									),
								],
							),
						),
					),
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

	Future<void> _setupServiceListener(FirebaseFirestore db, String uid, String collection, String service) async {
		try {
			print('🔗 Setting up AGGRESSIVE $service notification listener');
			print('🚨 TESTING MODE: Will show ALL $service requests to user $uid');
			
			// Listen for requests
			db.collection(collection)
				.where('status', isEqualTo: 'requested')
				.snapshots()
				.listen((snap) async {
					print('📡 Received ${snap.docs.length} $service requests');
					for (final d in snap.docs) {
						final data = d.data();
						final assignedProviderId = data['providerId']?.toString();
						
						// TESTING MODE: Show ALL requests to ALL users
						bool shouldShow = true; // Force true for testing
						print('🚨 TESTING: Will show $service request ${d.id} to user $uid (assignedProviderId: $assignedProviderId)');
						
						if (shouldShow && !_shown.contains('$service:${d.id}')) {
							_shown.add('$service:${d.id}');
							
							// Show floating notification first
							final serviceEmoji = {
								'hire': '🔧',
								'emergency': '🚨',
								'moving': '📦',
								'personal': '💆',
							}[service] ?? '💼';
							
							NotificationOverlay.show(
								context,
								title: '$serviceEmoji New ${service.toUpperCase()} Request',
								message: data['description']?.toString() ?? 'Service request received',
								backgroundColor: service == 'emergency' ? Colors.red.shade600 : Colors.green.shade600,
								icon: service == 'emergency' ? Icons.emergency : Icons.work,
								onTap: () => _showServiceDialog(d.id, data, service),
							);
							
							// Also show dialog
							_showServiceDialog(d.id, data, service);
						}
					}
				});
		} catch (e) {
			print('❌ Error setting up $service listener: $e');
		}
	}

	bool _shouldShowHere() {
		// Show popups globally regardless of current page
		print('🌍 _shouldShowHere() called - returning true for global notifications');
		return true;
	}

	Future<void> _showServiceDialog(String id, Map<String, dynamic> data, String service) async {
		final shouldShow = _shouldShowHere();
		print('🔍 _shouldShowHere() returned: $shouldShow for $service');
		if (!shouldShow) {
			print('❌ Not showing $service dialog due to _shouldShowHere() = false');
			return;
		}
		final ctx = context;
		print('✅ Showing $service dialog for booking: $id');
		
		// Fetch client profile
		String clientName = 'Customer';
		String clientPhoto = '';
		try {
			final clientId = (data['clientId'] ?? '').toString();
			if (clientId.isNotEmpty) {
				final results = await Future.wait([
					FirebaseFirestore.instance.collection('public_profiles').doc(clientId).get(),
					FirebaseFirestore.instance.collection('users').doc(clientId).get(),
				]);
				
				final pu = results[0].data() ?? const {};
				final u = results[1].data() ?? const {};
				
				// Create public profile if missing
				if (!results[0].exists && results[1].exists && u['name'] != null) {
					FirebaseFirestore.instance.collection('public_profiles').doc(clientId).set({
						'name': u['name'],
						'photoUrl': u['photoUrl'] ?? '',
						'createdAt': DateTime.now().toIso8601String(),
					}).then((_) {
						print('✅ Created missing public profile for $service client: ${u['name']}');
					}).catchError((e) {
						print('❌ Failed to create public profile: $e');
					});
				}
				
				// Get client name
				if (pu['name'] != null && pu['name'].toString().trim().isNotEmpty) {
					clientName = pu['name'].toString().trim();
				} else if (u['name'] != null && u['name'].toString().trim().isNotEmpty) {
					clientName = u['name'].toString().trim();
				}
				
				// Get client photo
				if (pu['photoUrl'] != null && pu['photoUrl'].toString().trim().isNotEmpty) {
					clientPhoto = pu['photoUrl'].toString().trim();
				} else if (u['photoUrl'] != null && u['photoUrl'].toString().trim().isNotEmpty) {
					clientPhoto = u['photoUrl'].toString().trim();
				}
			}
		} catch (_) {}
		
		// Play notification sound
		try { 
			await SoundService.instance.playCall(); 
		} catch (_) {}
		
		// Show dialog based on service type
		final serviceEmoji = {
			'hire': '🔧',
			'emergency': '🚨',
			'moving': '📦',
			'personal': '💆',
			'rentals': '🏠',
			'marketplace': '🛒',
			'others': '📋',
		}[service] ?? '💼';
		
		await showDialog(context: ctx, builder: (_) => AlertDialog(
			title: Text('$serviceEmoji New ${service.toUpperCase()} Request'),
			content: Column(
				mainAxisSize: MainAxisSize.min,
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					ListTile(
						contentPadding: EdgeInsets.zero,
						leading: CircleAvatar(
							backgroundImage: clientPhoto.isNotEmpty ? NetworkImage(clientPhoto) : null,
							child: clientPhoto.isEmpty ? const Icon(Icons.person) : null,
						),
						title: Text(clientName),
						subtitle: Text('${service.toUpperCase()} request'),
					),
					const SizedBox(height: 8),
					if (data['description'] != null) Text('Service: ${data['description']}'),
					if (data['serviceAddress'] != null) Text('Location: ${data['serviceAddress']}'),
					if (data['pickupAddress'] != null) Text('From: ${data['pickupAddress']}'),
					if (data['destinationAddress'] != null) Text('To: ${data['destinationAddress']}'),
					if (data['emergencyAddress'] != null) Text('Emergency at: ${data['emergencyAddress']}'),
					if (data['feeEstimate'] != null) Text('Fee: ${data['currency'] ?? 'NGN'} ${(data['feeEstimate'] as num).toStringAsFixed(2)}'),
				],
			),
			actions: [
				TextButton(
					onPressed: () { 
						Navigator.pop(ctx); 
						_declineServiceBooking(id, service);
					}, 
					child: const Text('Decline')
				),
				FilledButton(
					onPressed: () { 
						Navigator.pop(ctx); 
						_acceptServiceBooking(id, service);
						_go(_routeForService(service));
					}, 
					child: const Text('Accept')
				),
			],
		));
	}

	Future<void> _acceptRide(String id) async {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		await FirebaseFirestore.instance.collection('rides').doc(id).set({'status': 'accepted', if (uid != null) 'driverId': uid}, SetOptions(merge: true));
	}
	Future<void> _declineRide(String id) async {
		await FirebaseFirestore.instance.collection('rides').doc(id).set({'status': 'cancelled', 'cancelReason': 'declined_by_driver', 'cancelledAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
	}

	Future<void> _acceptServiceBooking(String id, String service) async {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		final collection = '${service}_bookings';
		await FirebaseFirestore.instance.collection(collection).doc(id).set({
			'status': 'accepted', 
			if (uid != null) 'providerId': uid,
			'acceptedAt': FieldValue.serverTimestamp(),
		}, SetOptions(merge: true));
	}

	Future<void> _declineServiceBooking(String id, String service) async {
		final collection = '${service}_bookings';
		await FirebaseFirestore.instance.collection(collection).doc(id).set({
			'status': 'cancelled', 
			'cancelReason': 'declined_by_provider', 
			'cancelledAt': FieldValue.serverTimestamp()
		}, SetOptions(merge: true));
	}

	String _routeForService(String service) {
		switch (service) {
			case 'hire':
				return '/hub/hire';
			case 'emergency':
				return '/hub/emergency';
			case 'moving':
				return '/hub/moving';
			case 'personal':
				return '/hub/personal';
			case 'rentals':
				return '/hub/rentals';
			case 'marketplace':
				return '/hub/marketplace-provider';
			case 'others':
				return '/hub/others-provider';
			default:
				return '/hub';
		}
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