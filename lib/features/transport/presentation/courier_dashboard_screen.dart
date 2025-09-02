import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/ride.dart';
import 'package:zippup/features/transport/providers/ride_service.dart';
import 'package:zippup/services/location/location_service.dart';
import 'package:zippup/features/providers/widgets/provider_header.dart';

class CourierDashboardScreen extends StatefulWidget {
	const CourierDashboardScreen({super.key});
	@override
	State<CourierDashboardScreen> createState() => _CourierDashboardScreenState();
}

class _CourierDashboardScreenState extends State<CourierDashboardScreen> with SingleTickerProviderStateMixin {
	bool _online = true;
	final _rideService = RideService();
	StreamSubscription<Map<String, dynamic>?>? _activeSub;
	String? _activeRideId;
	Map<String, dynamic>? _activeRide;
	Timer? _locTimer;
	RideStatus? _filterStatus;

	Stream<List<Map<String, dynamic>>> _waitingRides() {
		return FirebaseFirestore.instance
			.collection('rides')
			.where('status', isEqualTo: 'requested')
			.snapshots()
			.map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
	}

	Stream<List<Map<String, dynamic>>> _allRidesHistory() {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		if (uid == null) return const Stream.empty();
		return FirebaseFirestore.instance
			.collection('rides')
			.where('driverId', isEqualTo: uid)
			.orderBy('createdAt', descending: true)
			.snapshots()
			.map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
	}

	Stream<Map<String, dynamic>?> _activeRideStream() {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		if (uid == null) return const Stream.empty();
		return FirebaseFirestore.instance
			.collection('rides')
			.where('driverId', isEqualTo: uid)
			.where('status', whereIn: ['accepted', 'arriving', 'arrived', 'enroute'])
			.limit(1)
			.snapshots()
			.map((snap) => snap.docs.isEmpty ? null : {'id': snap.docs.first.id, ...snap.docs.first.data()});
	}

	Future<void> _toggleOnline(bool v) async {
		setState(() => _online = v);
		final uid = FirebaseAuth.instance.currentUser?.uid;
		if (uid != null) await FirebaseFirestore.instance.collection('drivers').doc(uid).set({'online': v}, SetOptions(merge: true));
		if (!v) {
			_stopLocationTimer();
		}
	}

	Future<void> _sendLocationOnce() async {
		final rideId = _activeRideId;
		if (rideId == null) return;
		final pos = await LocationService.getCurrentPosition();
		if (pos == null) return;
		await _rideService.updateDriverLocation(rideId, lat: pos.latitude, lng: pos.longitude);
	}

	void _startLocationTimer() {
		_stopLocationTimer();
		// 5-second interval; tune as needed
		_locTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sendLocationOnce());
	}

	void _stopLocationTimer() {
		_locTimer?.cancel();
		_locTimer = null;
	}

	Future<void> _updateRideStatus(RideStatus status) async {
		final rideId = _activeRideId;
		if (rideId == null) return;
		await _rideService.updateStatus(rideId, status);
		if (status == RideStatus.completed || status == RideStatus.cancelled) {
			_stopLocationTimer();
		}
	}

	@override
	void initState() {
		super.initState();
		_initializeDriverOnline();
		_activeSub = _activeRideStream().listen((ride) {
			setState(() {
				_activeRide = ride;
				_activeRideId = ride?['id'] as String?;
			});
			if (ride != null && _online) {
				_startLocationTimer();
			} else {
				_stopLocationTimer();
			}
		});
	}

	Future<void> _initializeDriverOnline() async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid != null) {
				// Set driver online by default
				await FirebaseFirestore.instance
					.collection('drivers')
					.doc(uid)
					.set({'online': true}, SetOptions(merge: true));
				
				// Also update provider profile
				final providerProfile = await FirebaseFirestore.instance
					.collection('provider_profiles')
					.where('userId', isEqualTo: uid)
					.where('service', isEqualTo: 'transport')
					.limit(1)
					.get();

				if (providerProfile.docs.isNotEmpty) {
					await FirebaseFirestore.instance
						.collection('provider_profiles')
						.doc(providerProfile.docs.first.id)
						.update({'availabilityOnline': true});
				}
			}
		} catch (e) {
			// Ignore errors during initialization
		}
	}

	@override
	void dispose() {
		_activeSub?.cancel();
		_stopLocationTimer();
		super.dispose();
	}

	Widget _buildActiveRideCard() {
		final r = _activeRide;
		if (r == null) return const SizedBox.shrink();
		final status = (r['status'] ?? '') as String;
		return Card(
			margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
			child: Padding(
				padding: const EdgeInsets.all(12.0),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						Text('Active ride • ${r['id'].toString().substring(0, 6)}', style: Theme.of(context).textTheme.titleMedium),
						const SizedBox(height: 6),
						Text('Status: $status'),
						const SizedBox(height: 12),
						Wrap(
							spacing: 8,
							runSpacing: 8,
							children: [
								OutlinedButton(onPressed: () => _updateRideStatus(RideStatus.arriving), child: const Text('Arriving')),
								OutlinedButton(onPressed: () => _updateRideStatus(RideStatus.arrived), child: const Text('Arrived')),
								OutlinedButton(onPressed: () => _updateRideStatus(RideStatus.enroute), child: const Text('En route')),
								FilledButton(onPressed: () => _updateRideStatus(RideStatus.completed), child: const Text('Complete')),
							],
						),
						const SizedBox(height: 8),
						Row(children: [
							Expanded(child: OutlinedButton.icon(onPressed: _sendLocationOnce, icon: const Icon(Icons.my_location), label: const Text('Send location now'))),
							const SizedBox(width: 8),
							Text(_locTimer == null ? 'Auto: off' : 'Auto: on'),
						]),
					],
				),
			),
		);
	}

	@override
	Widget build(BuildContext context) {
		final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
		
		return DefaultTabController(
			length: 2,
			child: Scaffold(
				appBar: AppBar(
					title: const Text('🚗 Transport Dashboard'),
					backgroundColor: Colors.blue.shade50,
					iconTheme: const IconThemeData(color: Colors.black),
					titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
					actions: [
						IconButton(
							icon: const Icon(Icons.settings),
							onPressed: () => context.push('/operational-settings/transport'),
							tooltip: 'Operational Settings',
						),
						PopupMenuButton<String>(
							icon: const Icon(Icons.more_vert),
							onSelected: (value) {
								switch (value) {
									case 'roles':
										// Get subcategory for transport provider
										_navigateToServiceRoles();
										break;
									case 'settings':
										context.push('/operational-settings/transport');
										break;
									case 'earnings':
										context.push('/transport/earnings');
										break;
								}
							},
							itemBuilder: (context) => [
								const PopupMenuItem(
									value: 'roles',
									child: ListTile(
										leading: Icon(Icons.tune),
										title: Text('Service Roles'),
										dense: true,
									),
								),
								const PopupMenuItem(
									value: 'settings',
									child: ListTile(
										leading: Icon(Icons.settings),
										title: Text('Operational Settings'),
										dense: true,
									),
								),
								const PopupMenuItem(
									value: 'earnings',
									child: ListTile(
										leading: Icon(Icons.attach_money),
										title: Text('Earnings'),
										dense: true,
									),
								),
							],
						),
					],
					bottom: PreferredSize(
						preferredSize: const Size.fromHeight(48),
						child: StreamBuilder<List<Map<String, dynamic>>>(
							stream: _waitingRides(),
							builder: (context, s) {
								final count = (s.data?.length ?? 0);
								Widget iconWithBadge(IconData icon, int c) {
									return Stack(clipBehavior: Clip.none, children: [
										Icon(icon),
										if (c > 0) Positioned(
											right: -6, top: -4,
											child: Container(
												padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
												decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(10)),
												child: Text('$c', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
											),
										),
									]);
								}
								return TabBar(tabs: [
									Tab(icon: iconWithBadge(Icons.notifications_active, count), text: count > 0 ? 'New ($count)' : 'New Rides'),
									const Tab(icon: Icon(Icons.history), text: 'All History'),
								]);
							},
						),
					),
				),
				body: Column(children: [
					const ProviderHeader(service: 'transport'),
					
					// Online toggle and features
					Container(
						color: Colors.blue.shade50,
						padding: const EdgeInsets.all(16),
						child: Column(
							children: [
								Row(children: [
									Expanded(child: SwitchListTile(
										title: const Text('🟢 Go Online'),
										subtitle: Text(_online ? 'Accepting ride requests' : 'Offline - not receiving requests'),
										value: _online,
										onChanged: _toggleOnline,
										activeColor: Colors.green,
									)),
								]),
								const SizedBox(height: 8),
								
								// Quick access features
								Row(
									children: [
										Expanded(
											child: ElevatedButton.icon(
												onPressed: () => _navigateToServiceRoles(),
												icon: const Icon(Icons.tune),
												label: const Text('Vehicle Types'),
												style: ElevatedButton.styleFrom(
													backgroundColor: Colors.blue,
													foregroundColor: Colors.white,
												),
											),
										),
										const SizedBox(width: 8),
										Expanded(
											child: ElevatedButton.icon(
												onPressed: () => context.push('/operational-settings/transport'),
												icon: const Icon(Icons.settings),
												label: const Text('Settings'),
												style: ElevatedButton.styleFrom(
													backgroundColor: Colors.green,
													foregroundColor: Colors.white,
												),
											),
										),
									],
								),
							],
						),
					),

					// Status filters
					Container(
						padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
						child: SingleChildScrollView(
							scrollDirection: Axis.horizontal,
							child: Row(children: [
								FilterChip(
									label: const Text('📋 All History'),
									selected: _filterStatus == null,
									onSelected: (_) => setState(() => _filterStatus = null),
								),
								const SizedBox(width: 8),
								...RideStatus.values.map((status) => Padding(
									padding: const EdgeInsets.symmetric(horizontal: 4),
									child: FilterChip(
										label: Text(status.name),
										selected: _filterStatus == status,
										onSelected: (_) => setState(() => _filterStatus = status),
									),
								)),
							]),
						),
					),

					// Active ride card
					_buildActiveRideCard(),
					
					// Tabs content
					Expanded(child: TabBarView(children: [
						// New rides tab
						_online
							? StreamBuilder<List<Map<String, dynamic>>>(
								stream: _waitingRides(),
								builder: (context, snap) {
									if (!snap.hasData) return const Center(child: CircularProgressIndicator());
									final rides = snap.data!;
									if (rides.isEmpty) return const Center(child: Text('No new ride requests'));
									return ListView.separated(
										padding: const EdgeInsets.all(16),
										itemCount: rides.length,
										separatorBuilder: (_, __) => const Divider(height: 1),
										itemBuilder: (context, i) {
											final r = rides[i];
											return Card(
												elevation: 2,
												child: ListTile(
													title: Text('🚗 Ride ${r['id'].substring(0, 6)} • ${r['type']}'),
													subtitle: Column(
														crossAxisAlignment: CrossAxisAlignment.start,
														children: [
															Text('📍 ${r['pickupAddress'] ?? 'Pickup location'}'),
															Text('🎯 ${r['dropoffAddress'] ?? 'Destination'}'),
															Text('⏱️ ETA: ${r['etaMinutes'] ?? '-'} min'),
														],
													),
													trailing: FilledButton(
														onPressed: () => _rideService.assignAndAccept(r['id'] as String),
														style: FilledButton.styleFrom(backgroundColor: Colors.green),
														child: const Text('Accept'),
													),
													isThreeLine: true,
												),
											);
										},
									);
								},
							)
							: Center(
								child: Column(
									mainAxisAlignment: MainAxisAlignment.center,
									children: [
										Icon(Icons.offline_bolt, size: 64, color: Colors.grey.shade400),
										const SizedBox(height: 16),
										const Text('You are offline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
										const SizedBox(height: 8),
										const Text('Turn on "Go Online" to start receiving ride requests'),
										const SizedBox(height: 16),
										ElevatedButton.icon(
											onPressed: () => _toggleOnline(true),
											icon: const Icon(Icons.power_settings_new),
											label: const Text('Go Online'),
											style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
										),
									],
								),
							),
						
						// All rides history tab
						StreamBuilder<List<Map<String, dynamic>>>(
							stream: _allRidesHistory(),
							builder: (context, snap) {
								if (!snap.hasData) return const Center(child: CircularProgressIndicator());
								var rides = snap.data!;
								
								// Apply status filter
								if (_filterStatus != null) {
									rides = rides.where((r) {
										final status = r['status']?.toString();
										return status == _filterStatus?.name;
									}).toList();
								}
								
								if (rides.isEmpty) {
									return Center(
										child: Column(
											mainAxisAlignment: MainAxisAlignment.center,
											children: [
												Icon(Icons.history, size: 64, color: Colors.grey.shade400),
												const SizedBox(height: 16),
												Text(
													_filterStatus == null ? 'No ride history yet' : 'No ${_filterStatus?.name} rides',
													style: const TextStyle(fontSize: 16),
												),
												const SizedBox(height: 8),
												const Text('Complete rides to build your history'),
											],
										),
									);
								}
								
								return ListView.separated(
									padding: const EdgeInsets.all(16),
									itemCount: rides.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, i) {
										final r = rides[i];
										final status = r['status']?.toString() ?? 'unknown';
										final statusColor = _getStatusColor(status);
										
										return Card(
											elevation: 2,
											child: ListTile(
												leading: CircleAvatar(
													backgroundColor: statusColor,
													child: Text(
														status == 'completed' ? '✅' :
														status == 'cancelled' ? '❌' :
														status == 'enroute' ? '🚗' : '📋',
														style: const TextStyle(fontSize: 16),
													),
												),
												title: Text('🚗 Ride ${r['id'].substring(0, 8)} • ${r['type']}'),
												subtitle: Column(
													crossAxisAlignment: CrossAxisAlignment.start,
													children: [
														Text('Status: ${status.toUpperCase()}'),
														Text('📍 ${r['pickupAddress'] ?? 'Unknown pickup'}'),
														Text('💰 ₦${r['fare']?.toString() ?? '0'}'),
													],
												),
												trailing: _buildHistoryActions(r),
												onTap: () => context.push('/track/ride?rideId=${r['id']}'),
												isThreeLine: true,
											),
										);
									},
								);
							},
						),
					])),
				],
			),
		);
	}

	Future<void> _navigateToServiceRoles() async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid != null) {
				final providerDoc = await FirebaseFirestore.instance
					.collection('provider_profiles')
					.where('userId', isEqualTo: uid)
					.where('service', isEqualTo: 'transport')
					.limit(1)
					.get();
				
				if (providerDoc.docs.isNotEmpty) {
					final subcategory = providerDoc.docs.first.data()['subcategory']?.toString() ?? 'taxi';
					context.push('/service-roles/transport/$subcategory');
				}
			}
		} catch (e) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Error: $e')),
			);
		}
	}

	Color _getStatusColor(String status) {
		switch (status) {
			case 'completed':
				return Colors.green.shade100;
			case 'cancelled':
				return Colors.red.shade100;
			case 'enroute':
				return Colors.blue.shade100;
			case 'accepted':
				return Colors.orange.shade100;
			default:
				return Colors.grey.shade100;
		}
	}

	Widget _buildHistoryActions(Map<String, dynamic> ride) {
		final status = ride['status']?.toString() ?? '';
		
		switch (status) {
			case 'completed':
				return const Icon(Icons.check_circle, color: Colors.green);
			case 'cancelled':
				return const Icon(Icons.cancel, color: Colors.red);
			case 'accepted':
			case 'arriving':
			case 'arrived':
			case 'enroute':
				return ElevatedButton(
					onPressed: () => context.push('/track/ride?rideId=${ride['id']}'),
					style: ElevatedButton.styleFrom(
						backgroundColor: Colors.blue,
						foregroundColor: Colors.white,
						minimumSize: const Size(60, 32),
					),
					child: const Text('Track'),
				);
			default:
				return const SizedBox.shrink();
		}
	}
}