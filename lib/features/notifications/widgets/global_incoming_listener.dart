import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:zippup/services/notifications/reliable_sound_service.dart';
import 'package:zippup/services/notifications/simple_beep_service.dart';
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
		print('✅ Setting up ride notification listener for user: $uid');
		
		// Listen for ride requests assigned to this driver OR unassigned rides for available drivers
		_ridesSub = db.collection('rides')
			.where('status', isEqualTo: 'requested')
			.snapshots()
			.listen((snap) async {
				print('📡 Received ${snap.docs.length} ride requests from Firestore');
				
				// Check if user has active transport provider profile AND is online
				bool isActiveTransportProvider = false;
				bool isOnline = false;
				try {
					print('🔍 Checking transport provider profile for user: $uid');
					final providerSnap = await db.collection('provider_profiles')
						.where('userId', isEqualTo: uid)
						.where('service', isEqualTo: 'transport')
						.where('status', isEqualTo: 'active')
						.limit(1)
						.get();
					
					if (providerSnap.docs.isNotEmpty) {
						final providerData = providerSnap.docs.first.data();
						isOnline = providerData['availabilityOnline'] == true;
						isActiveTransportProvider = true;
						print('✅ Found transport provider - Online: $isOnline');
					} else {
						print('❌ No active transport provider profile found');
					}
				} catch (e) {
					print('❌ Error checking transport provider profile: $e');
				}
				
				for (final d in snap.docs) {
					final data = d.data();
					final assignedDriverId = data['driverId']?.toString();
					
					// Proper targeting: Only show to relevant online transport providers
					bool shouldShow = false;
					if (assignedDriverId == uid) {
						shouldShow = true; // Directly assigned to this driver
						print('✅ Ride ${d.id} assigned to this driver');
					} else if ((assignedDriverId == null || assignedDriverId.isEmpty) && isActiveTransportProvider && isOnline) {
						// Simple targeting: just check if provider is active and online
						shouldShow = true;
						print('✅ Ride ${d.id} available for active online transport provider');
					} else {
						print('🚫 Ride ${d.id} not for this user - Provider: $isActiveTransportProvider, Online: $isOnline, Assigned: $assignedDriverId');
					}
					
					if (shouldShow && !_shown.contains('ride:${d.id}')) {
						print('🚨 SHOWING RIDE NOTIFICATION for ride: ${d.id}');
						print('📋 Ride data: ${data}');
						print('👤 Customer ID: ${data['riderId']}');
						print('🚗 Ride type: ${data['type']}');
						print('📍 From: ${data['pickupAddress']}');
						_shown.add('ride:${d.id}');
						
						// Create notification record for bell icon
						_createNotificationRecord(
							'🚗 New Ride Request',
							'From: ${data['pickupAddress'] ?? 'Unknown location'}',
							'/driver/ride?rideId=${d.id}',
						);
						
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
		// Play AUDIBLE notification sound
		try { 
			print('🔊 Playing AUDIBLE RIDE REQUEST notification...');
			final success = await SimpleBeepService.instance.playUrgentBeep();
			print(success ? '🎉 AUDIBLE ride request sound SUCCESS' : '💥 AUDIBLE ride request sound FAILED');
		} catch (e) {
			print('❌ Critical error playing audible ride notification: $e');
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
						title: Text(riderName ?? 'Customer'),
						subtitle: Text('Rides: ${riderRides ?? 0}'),
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
		try { 
			final success = await SimpleBeepService.instance.playUrgentBeep(); 
			print(success ? '🎉 AUDIBLE order notification SUCCESS' : '💥 AUDIBLE order notification FAILED');
		} catch (_) {}
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
		try { 
			final success = await SimpleBeepService.instance.playSimpleBeep(); 
			print(success ? '🎉 AUDIBLE delivery notification SUCCESS' : '💥 AUDIBLE delivery notification FAILED');
		} catch (_) {}
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
		try { 
			final success = await SimpleBeepService.instance.playUrgentBeep(); 
			print(success ? '🎉 AUDIBLE moving notification SUCCESS' : '💥 AUDIBLE moving notification FAILED');
		} catch (_) {}
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
			print('🔗 Setting up $service notification listener');
			
			// Check if user has active provider profile for this service
			final providerSnap = await db.collection('provider_profiles')
				.where('userId', isEqualTo: uid)
				.where('service', isEqualTo: service)
				.where('status', isEqualTo: 'active')
				.limit(1)
				.get();
				
			if (providerSnap.docs.isEmpty) {
				print('❌ No active $service provider profile found - skipping notifications');
				return;
			}
			
			final providerData = providerSnap.docs.first.data();
			final isOnline = providerData['availabilityOnline'] == true;
			print('✅ Found $service provider - Online: $isOnline');
			
			// Listen for requests
			db.collection(collection)
				.where('status', isEqualTo: 'requested')
				.snapshots()
				.listen((snap) async {
					print('📡 Received ${snap.docs.length} $service requests for $service provider');
					
					// Re-check online status for each batch of requests
					final currentProviderSnap = await db.collection('provider_profiles')
						.where('userId', isEqualTo: uid)
						.where('service', isEqualTo: service)
						.where('status', isEqualTo: 'active')
						.limit(1)
						.get();
					
					bool currentlyOnline = false;
					if (currentProviderSnap.docs.isNotEmpty) {
						currentlyOnline = currentProviderSnap.docs.first.data()['availabilityOnline'] == true;
					}
					
					print('🔍 $service provider current online status: $currentlyOnline');
					
					for (final d in snap.docs) {
						final data = d.data();
						final assignedProviderId = data['providerId']?.toString();
						
						// Proper targeting: Only show to online providers in this service
						bool shouldShow = false;
						if (assignedProviderId == uid) {
							shouldShow = true; // Directly assigned
							print('✅ $service request ${d.id} assigned to this provider');
						} else if ((assignedProviderId == null || assignedProviderId.isEmpty) && currentlyOnline) {
							// Simple targeting: just check if provider is active and online
							shouldShow = true;
							print('✅ $service request ${d.id} available for active online $service provider');
						} else {
							print('🚫 $service request ${d.id} not for this user - Online: $currentlyOnline, Assigned: $assignedProviderId');
						}
						
						if (shouldShow && !_shown.contains('$service:${d.id}')) {
							_shown.add('$service:${d.id}');
							
							// Create notification record for bell icon first
							final serviceEmoji = {
								'hire': '🔧',
								'emergency': '🚨',
								'moving': '📦',
								'personal': '💆',
								'rentals': '🏠',
								'marketplace': '🛒',
								'others': '📋',
							}[service] ?? '💼';
							
							_createNotificationRecord(
								'$serviceEmoji New ${service.toUpperCase()} Request',
								data['description']?.toString() ?? 'Service request received',
								_routeForService(service),
							);
							
							// Show floating notification
							
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

	/// Create a notification record that will show in the bell icon
	Future<void> _createNotificationRecord(String title, String body, String route) async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) return;
			
			await FirebaseFirestore.instance.collection('notifications').add({
				'userId': uid,
				'title': title,
				'body': body,
				'route': route,
				'read': false,
				'createdAt': FieldValue.serverTimestamp(),
			});
			
			print('✅ Created notification record: $title');
		} catch (e) {
			print('❌ Failed to create notification record: $e');
		}
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
		
		// Play AUDIBLE notification sound
		try { 
			final success = await SimpleBeepService.instance.playUrgentBeep(); 
			print(success ? '🎉 AUDIBLE service notification SUCCESS' : '💥 AUDIBLE service notification FAILED');
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
					if (data['description'] != null && data['description'].toString().isNotEmpty) 
						Text('Service: ${data['description'].toString()}'),
					if (data['serviceAddress'] != null && data['serviceAddress'].toString().isNotEmpty) 
						Text('Location: ${data['serviceAddress'].toString()}'),
					if (data['pickupAddress'] != null && data['pickupAddress'].toString().isNotEmpty) 
						Text('From: ${data['pickupAddress'].toString()}'),
					if (data['destinationAddress'] != null && data['destinationAddress'].toString().isNotEmpty) 
						Text('To: ${data['destinationAddress'].toString()}'),
					if (data['emergencyAddress'] != null && data['emergencyAddress'].toString().isNotEmpty) 
						Text('Emergency at: ${data['emergencyAddress'].toString()}'),
					if (data['feeEstimate'] != null) 
						Text('Fee: ${data['currency']?.toString() ?? 'NGN'} ${_safeNumberFormat(data['feeEstimate'])}'),
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

	/// Safe number formatting to prevent null errors
	String _safeNumberFormat(dynamic value) {
		try {
			if (value == null) return '0.00';
			if (value is num) return value.toStringAsFixed(2);
			if (value is String) {
				final parsed = double.tryParse(value);
				return parsed?.toStringAsFixed(2) ?? '0.00';
			}
			return '0.00';
		} catch (e) {
			print('❌ Number format error: $e');
			return '0.00';
		}
	}

	/// Check if transport ride type matches provider subcategory (legacy method)
	bool _doesTransportTypeMatch(String? rideType, String? providerSubcategory) {
		return _doesTransportTypeMatchGranular(rideType, providerSubcategory, null, null, {});
	}

	/// Granular transport type matching with passenger count and vehicle specifications
	bool _doesTransportTypeMatchGranular(
		String? rideType, 
		String? providerSubcategory, 
		String? providerServiceType,
		String? providerServiceSubtype,
		Map<String, dynamic> rideData,
	) {
		if (rideType == null || providerSubcategory == null) return false;
		
		print('🔍 GRANULAR Transport matching:');
		print('   Ride Type: $rideType');
		print('   Provider Subcategory: $providerSubcategory');
		print('   Provider Service Type: $providerServiceType');
		print('   Provider Service Subtype: $providerServiceSubtype');
		
		// First check basic category matching
		final basicCategoryMapping = {
			'car': ['Taxi'],
			'sedan': ['Taxi'],
			'suv': ['Taxi'],
			'motorbike': ['Bike'],
			'bike': ['Bike'],
			'motorcycle': ['Bike'],
			'bus': ['Bus'],
			'charter': ['Bus'],
			'tricycle': ['Tricycle'],
			// Note: Courier moved to moving category
		};
		
		final matchingCategories = basicCategoryMapping[rideType.toLowerCase()] ?? [];
		if (!matchingCategories.contains(providerSubcategory)) {
			print('❌ Basic category mismatch');
			return false;
		}
		
		// If no specific service type, allow basic category match
		if (providerServiceType == null) {
			print('✅ Basic category match (no specific service type)');
			return true;
		}
		
		// Granular matching based on specific requirements
		final passengerCount = rideData['passengerCount'] as int? ?? 1;
		
		switch (providerSubcategory) {
			case 'Taxi':
				return _matchTaxiType(rideType, providerServiceType, passengerCount);
			case 'Bike':
				return _matchBikeType(rideType, providerServiceType);
			case 'Bus':
				return _matchBusType(rideType, providerServiceType, passengerCount);
			// Note: Courier moved to moving category
			default:
				print('✅ Default category match');
				return true;
		}
	}

	/// Match taxi service types based on passenger count
	bool _matchTaxiType(String rideType, String providerServiceType, int passengerCount) {
		final taxiCapacity = {
			'2 Seater Car': 2,
			'4 Seater Car': 4,
			'6 Seater Car': 6,
			'8+ Seater Car': 8,
			'Luxury Car': 4, // Assume 4 seats unless specified
			'Economy Car': 4,
		};
		
		final providerCapacity = taxiCapacity[providerServiceType] ?? 4;
		final matches = passengerCount <= providerCapacity;
		
		print('🚗 Taxi match: Passengers=$passengerCount, Provider Capacity=$providerCapacity, Matches=$matches');
		return matches;
	}

	/// Match bike service types
	bool _matchBikeType(String rideType, String providerServiceType) {
		final bikeTypeMapping = {
			'motorbike': ['Standard Motorbike', 'Power Bike'],
			'bike': ['Standard Motorbike', 'Power Bike', 'Scooter'],
			'scooter': ['Scooter'],
			'power_bike': ['Power Bike'],
		};
		
		final matchingTypes = bikeTypeMapping[rideType.toLowerCase()] ?? [];
		final matches = matchingTypes.contains(providerServiceType);
		
		print('🏍️ Bike match: Ride=$rideType, Provider=$providerServiceType, Matches=$matches');
		return matches;
	}

	/// Match bus service types based on passenger count
	bool _matchBusType(String rideType, String providerServiceType, int passengerCount) {
		final busCapacity = {
			'Mini Bus (14 seats)': 14,
			'Standard Bus (25 seats)': 25,
			'Large Bus (40+ seats)': 40,
			'Charter Bus': 50,
		};
		
		final providerCapacity = busCapacity[providerServiceType] ?? 25;
		final matches = passengerCount <= providerCapacity;
		
		print('🚌 Bus match: Passengers=$passengerCount, Provider Capacity=$providerCapacity, Matches=$matches');
		return matches;
	}

	/// Match courier service types
	bool _matchCourierType(String rideType, String providerServiceType) {
		final courierTypeMapping = {
			'courier': ['Motorbike Courier', 'Car Courier', 'Bicycle Courier'],
			'delivery': ['Motorbike Courier', 'Car Courier'],
			'express': ['Motorbike Courier'],
		};
		
		final matchingTypes = courierTypeMapping[rideType.toLowerCase()] ?? [];
		final matches = matchingTypes.contains(providerServiceType);
		
		print('📦 Courier match: Ride=$rideType, Provider=$providerServiceType, Matches=$matches');
		return matches;
	}

	/// Check if service request type matches provider subcategory for any service
	bool _doesServiceTypeMatch(String service, String? requestType, String? providerSubcategory) {
		if (requestType == null || providerSubcategory == null) return false;
		
		switch (service) {
			case 'transport':
				return _doesTransportTypeMatch(requestType, providerSubcategory);
				
			case 'hire':
				return _doesHireTypeMatch(requestType, providerSubcategory);
				
			case 'emergency':
				return _doesEmergencyTypeMatch(requestType, providerSubcategory);
				
			case 'moving':
				return _doesMovingTypeMatch(requestType, providerSubcategory);
				
			case 'personal':
				return _doesPersonalTypeMatch(requestType, providerSubcategory);
				
			default:
				// For other services, match exact subcategory
				final matches = requestType.toLowerCase() == providerSubcategory.toLowerCase();
				print('🔍 $service type match check: Request=$requestType, Provider=$providerSubcategory, Matches=$matches');
				return matches;
		}
	}

	/// Check hire service type matching
	bool _doesHireTypeMatch(String? requestType, String? providerSubcategory) {
		if (requestType == null || providerSubcategory == null) return false;
		
		final typeMapping = {
			// Home services
			'plumber': ['Home Services'],
			'electrician': ['Home Services'],
			'carpenter': ['Home Services'],
			'painter': ['Home Services'],
			'cleaner': ['Home Services'],
			
			// Tech services
			'phone_repair': ['Tech Services'],
			'computer_repair': ['Tech Services'],
			'tv_repair': ['Tech Services'],
			'appliance_repair': ['Tech Services'],
			
			// Construction
			'builder': ['Construction'],
			'mason': ['Construction'],
			'welder': ['Construction'],
			
			// Auto services
			'mechanic': ['Auto Services'],
			'auto_electrician': ['Auto Services'],
			'panel_beater': ['Auto Services'],
			
			// Personal care
			'barber': ['Personal Care'],
			'hairdresser': ['Personal Care'],
			'makeup_artist': ['Personal Care'],
		};
		
		final matchingProviderTypes = typeMapping[requestType.toLowerCase()] ?? [];
		final matches = matchingProviderTypes.contains(providerSubcategory);
		
		print('🔍 Hire type match check: Request=$requestType, Provider=$providerSubcategory, Matches=$matches');
		return matches;
	}

	/// Check emergency service type matching
	bool _doesEmergencyTypeMatch(String? requestType, String? providerSubcategory) {
		if (requestType == null || providerSubcategory == null) return false;
		
		final typeMapping = {
			// Medical emergencies
			'medical': ['Ambulance'],
			'ambulance': ['Ambulance'],
			'health_emergency': ['Ambulance'],
			
			// Fire emergencies
			'fire': ['Fire Service'],
			'fire_emergency': ['Fire Service'],
			
			// Security emergencies
			'security': ['Security'],
			'theft': ['Security'],
			'break_in': ['Security'],
			
			// Vehicle emergencies
			'breakdown': ['Towing', 'Towing Van', 'Roadside'],
			'accident': ['Towing', 'Towing Van'],
			'towing_van': ['Towing Van'],
			'emergency_towing': ['Towing Van'],
			'heavy_towing': ['Towing Van'],
			'flat_tire': ['Roadside'],
			'battery': ['Roadside'],
		};
		
		final matchingProviderTypes = typeMapping[requestType.toLowerCase()] ?? [];
		final matches = matchingProviderTypes.contains(providerSubcategory);
		
		print('🔍 Emergency type match check: Request=$requestType, Provider=$providerSubcategory, Matches=$matches');
		return matches;
	}

	/// Check moving service type matching
	bool _doesMovingTypeMatch(String? requestType, String? providerSubcategory) {
		if (requestType == null || providerSubcategory == null) return false;
		
		final typeMapping = {
			// Large moves
			'house_moving': ['Truck'],
			'office_moving': ['Truck'],
			'furniture': ['Truck'],
			
			// Small moves
			'small_items': ['Backie/Pickup', 'Courier'],
			'appliances': ['Backie/Pickup'],
			'boxes': ['Courier'],
			
			// Delivery
			'delivery': ['Courier'],
			'pickup': ['Backie/Pickup'],
		};
		
		final matchingProviderTypes = typeMapping[requestType.toLowerCase()] ?? [];
		final matches = matchingProviderTypes.contains(providerSubcategory);
		
		print('🔍 Moving type match check: Request=$requestType, Provider=$providerSubcategory, Matches=$matches');
		return matches;
	}

	/// Check personal service type matching
	bool _doesPersonalTypeMatch(String? requestType, String? providerSubcategory) {
		if (requestType == null || providerSubcategory == null) return false;
		
		final typeMapping = {
			// Beauty services
			'haircut': ['Beauty Services'],
			'manicure': ['Beauty Services'],
			'facial': ['Beauty Services'],
			'makeup': ['Beauty Services'],
			
			// Wellness services
			'massage': ['Wellness Services'],
			'spa': ['Wellness Services'],
			'therapy': ['Wellness Services'],
			
			// Fitness services
			'personal_trainer': ['Fitness Services'],
			'yoga': ['Fitness Services'],
			'gym': ['Fitness Services'],
			
			// Tutoring services
			'tutoring': ['Tutoring Services'],
			'lessons': ['Tutoring Services'],
			'teaching': ['Tutoring Services'],
			
			// Cleaning services
			'house_cleaning': ['Cleaning Services'],
			'office_cleaning': ['Cleaning Services'],
			'deep_cleaning': ['Cleaning Services'],
			
			// Childcare services
			'babysitting': ['Childcare Services'],
			'nanny': ['Childcare Services'],
			'childcare': ['Childcare Services'],
		};
		
		final matchingProviderTypes = typeMapping[requestType.toLowerCase()] ?? [];
		final matches = matchingProviderTypes.contains(providerSubcategory);
		
		print('🔍 Personal type match check: Request=$requestType, Provider=$providerSubcategory, Matches=$matches');
		return matches;
	}

	/// Comprehensive provider targeting check: type + radius + class toggles
	Future<bool> _shouldShowToProvider(String uid, String service, Map<String, dynamic> requestData) async {
		try {
			print('🔍 Comprehensive targeting check for $service provider $uid');
			
			// Get provider profile with operational settings
			final providerSnap = await FirebaseFirestore.instance
				.collection('provider_profiles')
				.where('userId', isEqualTo: uid)
				.where('service', isEqualTo: service)
				.where('status', isEqualTo: 'active')
				.limit(1)
				.get();
			
			if (providerSnap.docs.isEmpty) {
				print('❌ No provider profile found');
				return false;
			}
			
			final providerData = providerSnap.docs.first.data();
			
			// 1. Check service type matching
			final requestType = requestData['type']?.toString() ?? requestData['subcategory']?.toString();
			final providerSubcategory = providerData['subcategory']?.toString();
			final providerServiceType = providerData['serviceType']?.toString();
			
			bool typeMatches = false;
			if (service == 'transport') {
				typeMatches = _doesTransportTypeMatchGranular(
					requestType, 
					providerSubcategory, 
					providerServiceType, 
					providerData['serviceSubtype']?.toString(),
					requestData,
				);
			} else {
				typeMatches = _doesServiceTypeMatch(service, requestType, providerSubcategory);
			}
			
			if (!typeMatches) {
				print('❌ Service type mismatch (service: $service, requestType: $requestType, providerSubcategory: $providerSubcategory)');
				return false;
			}
			
			// 2. Check class toggle (if provider has enabled this specific class)
			final enabledClasses = providerData['enabledClasses'] as Map<String, dynamic>? ?? {};
			final requestClass = requestData['class']?.toString() ?? providerServiceType;
			
			if (requestClass != null && enabledClasses.isNotEmpty) {
				final classEnabled = enabledClasses[requestClass] == true;
				if (!classEnabled) {
					print('❌ Class $requestClass not enabled by provider (enabled: ${enabledClasses.keys.join(", ")})');
					return false;
				}
			}
			
			// 3. Check operational radius
			final hasRadiusLimit = providerData['hasRadiusLimit'] == true;
			if (hasRadiusLimit) {
				final operationalRadius = (providerData['operationalRadius'] as num?)?.toDouble() ?? 10.0;
				final requestLat = (requestData['pickupLat'] as num?)?.toDouble();
				final requestLng = (requestData['pickupLng'] as num?)?.toDouble();
				final providerLat = (providerData['lat'] as num?)?.toDouble();
				final providerLng = (providerData['lng'] as num?)?.toDouble();
				
				if (requestLat != null && requestLng != null && providerLat != null && providerLng != null) {
					final distance = _calculateDistance(requestLat, requestLng, providerLat, providerLng);
					if (distance > operationalRadius) {
						print('❌ Request outside operational radius: ${distance.toStringAsFixed(1)}km > ${operationalRadius}km');
						return false;
					}
					print('✅ Request within operational radius: ${distance.toStringAsFixed(1)}km ≤ ${operationalRadius}km');
				}
			}
			
			print('✅ All targeting criteria met');
			return true;
			
		} catch (e) {
			print('❌ Error in comprehensive targeting: $e');
			return false;
		}
	}

	/// Calculate distance between two points in kilometers
	double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
		const double earthRadius = 6371; // Earth's radius in kilometers
		final double dLat = _degreesToRadians(lat2 - lat1);
		final double dLng = _degreesToRadians(lng2 - lng1);
		final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
			math.cos(_degreesToRadians(lat1)) * math.cos(_degreesToRadians(lat2)) * 
			math.sin(dLng / 2) * math.sin(dLng / 2);
		final double c = 2 * math.asin(math.sqrt(a));
		return earthRadius * c;
	}

	double _degreesToRadians(double degrees) {
		return degrees * (math.pi / 180);
	}

	@override
	Widget build(BuildContext context) {
		return widget.child;
	}
}