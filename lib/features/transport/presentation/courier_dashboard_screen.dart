import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:zippup/common/models/ride.dart';
import 'package:zippup/features/transport/providers/ride_service.dart';
import 'package:zippup/services/location/location_service.dart';

class CourierDashboardScreen extends StatefulWidget {
	const CourierDashboardScreen({super.key});
	@override
	State<CourierDashboardScreen> createState() => _CourierDashboardScreenState();
}

class _CourierDashboardScreenState extends State<CourierDashboardScreen> {
	bool _online = false;
	final _rideService = RideService();

	Stream<List<Map<String, dynamic>>> _waitingRides() {
		return FirebaseFirestore.instance.collection('rides').where('status', isEqualTo: 'requested').snapshots().map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
	}

	Future<void> _toggleOnline(bool v) async {
		setState(() => _online = v);
		// Optionally mark driver presence
		final uid = FirebaseAuth.instance.currentUser?.uid;
		if (uid != null) await FirebaseFirestore.instance.collection('drivers').doc(uid).set({'online': v}, SetOptions(merge: true));
	}

	Future<void> _updateLocation() async {
		final pos = await LocationService.getCurrentPosition();
		if (pos == null) return;
		// This would typically be tied to a current active ride
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Courier Dashboard'), actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.maybePop(context))]),
			body: Column(
				children: [
					SwitchListTile(title: const Text('Online'), value: _online, onChanged: _toggleOnline),
					Expanded(
						child: _online
								? StreamBuilder<List<Map<String, dynamic}}>(
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
			bottomNavigationBar: SafeArea(
				child: Padding(
					padding: const EdgeInsets.all(12.0),
					child: Row(children: [
						Expanded(child: OutlinedButton.icon(onPressed: _updateLocation, icon: const Icon(Icons.my_location), label: const Text('Update location'))),
					]),
				),
			),
		);
	}
}