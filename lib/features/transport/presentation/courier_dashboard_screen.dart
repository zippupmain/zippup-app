import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zippup/common/models/ride.dart';
import 'package:zippup/features/transport/providers/ride_service.dart';
import 'package:zippup/services/location/location_service.dart';

class CourierDashboardScreen extends StatefulWidget {
	const CourierDashboardScreen({super.key});
	@override
	State<CourierDashboardScreen> createState() => _CourierDashboardScreenState();
}

class _CourierDashboardScreenState extends State<CourierDashboardScreen> {
	bool _online = true;
	final _rideService = RideService();
	StreamSubscription<Map<String, dynamic>?>? _activeSub;
	String? _activeRideId;
	Map<String, dynamic>? _activeRide;
	Timer? _locTimer;

	Stream<List<Map<String, dynamic>>> _waitingRides() {
		return FirebaseFirestore.instance
			.collection('rides')
			.where('status', isEqualTo: 'requested')
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
		return Scaffold(
			appBar: AppBar(title: const Text('Courier Dashboard'), actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.maybePop(context))]),
			body: Column(
				children: [
					SwitchListTile(title: const Text('Online'), value: _online, onChanged: _toggleOnline),
					_buildActiveRideCard(),
					Expanded(
						child: _online
								? StreamBuilder<List<Map<String, dynamic>>>(
									stream: _waitingRides(),
									builder: (context, snap) {
										if (!snap.hasData) return const Center(child: CircularProgressIndicator());
										final rides = snap.data!;
										if (rides.isEmpty) return const Center(child: Text('No waiting rides'));
										return ListView.separated(
											itemCount: rides.length,
											separatorBuilder: (_, __) => const Divider(height: 1),
											itemBuilder: (context, i) {
												final r = rides[i];
												return ListTile(
													title: Text('Ride ${r['id'].substring(0, 6)} • ${r['type']}'),
													subtitle: Text('ETA: ${r['etaMinutes'] ?? '-'}'),
													trailing: FilledButton(onPressed: () => _rideService.assignAndAccept(r['id'] as String), child: const Text('Accept')),
												);
											},
										);
									},
								)
							: const Center(child: Text('Go online to receive rides')),
					),
				],
			),
		);
	}
}