import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/ride.dart';

class TransportProviderDashboardScreen extends StatefulWidget {
	const TransportProviderDashboardScreen({super.key});
	@override
	State<TransportProviderDashboardScreen> createState() => _TransportProviderDashboardScreenState();
}

class _TransportProviderDashboardScreenState extends State<TransportProviderDashboardScreen> {
	final _db = FirebaseFirestore.instance;
	final _auth = FirebaseAuth.instance;
	bool _online = false;
	RideStatus? _filter;

	@override
	void initState() {
		super.initState();
		_init();
	}

	Future<void> _init() async {
		final uid = _auth.currentUser?.uid;
		if (uid == null) return;
		// read availability from provider_profiles
		final snap = await _db.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: 'transport').limit(1).get();
		if (snap.docs.isNotEmpty) {
			_online = snap.docs.first.get('availabilityOnline') == true;
			if (mounted) setState(() {});
		}
	}

	Stream<List<Ride>> _ridesStream(String uid) {
		Query<Map<String,dynamic>> q = _db.collection('rides').where('driverId', isEqualTo: uid);
		return q.orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map((d) => Ride.fromJson(d.id, d.data())).toList());
	}

	Future<void> _setOnline(bool v) async {
		final uid = _auth.currentUser?.uid; if (uid == null) return;
		setState(() => _online = v);
		final snap = await _db.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: 'transport').limit(1).get();
		if (snap.docs.isNotEmpty) {
			await snap.docs.first.reference.set({'availabilityOnline': v}, SetOptions(merge: true));
		}
	}

	Future<void> _updateRide(String id, RideStatus status) async {
		await _db.collection('rides').doc(id).set({'status': status.name}, SetOptions(merge: true));
	}

	@override
	Widget build(BuildContext context) {
		final uid = _auth.currentUser?.uid ?? '';
		return Scaffold(
			appBar: AppBar(title: const Text('Transport Provider'), actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.maybePop(context))]),
			body: Column(children: [
				Padding(
					padding: const EdgeInsets.all(12),
					child: Row(children: [
						Expanded(child: SwitchListTile(title: const Text('Go Online'), value: _online, onChanged: _setOnline)),
						const SizedBox(width: 8),
						OutlinedButton.icon(onPressed: () => context.push('/hub/orders'), icon: const Icon(Icons.list_alt), label: const Text('All orders')),
					]),
				),
				SingleChildScrollView(
					scrollDirection: Axis.horizontal,
					child: Row(children: [
						FilterChip(label: const Text('All'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
						...RideStatus.values.map((s) => Padding(
							padding: const EdgeInsets.symmetric(horizontal: 4),
							child: FilterChip(label: Text(s.name), selected: _filter == s, onSelected: (_) => setState(() => _filter = s)),
						)),
					]),
				),
				Expanded(
					child: StreamBuilder<List<Ride>>(
						stream: _ridesStream(uid),
						builder: (context, snap) {
							if (!snap.hasData) return const Center(child: CircularProgressIndicator());
							var rides = snap.data!;
							if (_filter != null) rides = rides.where((r) => r.status == _filter).toList();
							if (rides.isEmpty) return const Center(child: Text('No rides'));
							return ListView.separated(
								itemCount: rides.length,
								separatorBuilder: (_, __) => const Divider(height: 1),
								itemBuilder: (context, i) {
									final r = rides[i];
									return ListTile(
										title: Text('${r.type.name.toUpperCase()} • ${r.status.name}'),
										subtitle: Text('From: ${r.pickupAddress}\nTo: ${(r.destinationAddresses.isNotEmpty ? r.destinationAddresses.first : '')}'),
										isThreeLine: true,
										trailing: Wrap(spacing: 6, children: _actionsFor(r)),
									);
								},
							);
						},
					),
				),
			]),
		);
	}

	List<Widget> _actionsFor(Ride r) {
		switch (r.status) {
			case RideStatus.requested:
				return [FilledButton(onPressed: () => _updateRide(r.id, RideStatus.accepted), child: const Text('Accept'))];
			case RideStatus.accepted:
				return [TextButton(onPressed: () => _updateRide(r.id, RideStatus.arriving), child: const Text('Arriving'))];
			case RideStatus.arriving:
				return [TextButton(onPressed: () => _updateRide(r.id, RideStatus.arrived), child: const Text('Arrived'))];
			case RideStatus.arrived:
				return [FilledButton(onPressed: () => _updateRide(r.id, RideStatus.enroute), child: const Text('Start trip'))];
			case RideStatus.enroute:
				return [FilledButton(onPressed: () => _updateRide(r.id, RideStatus.completed), child: const Text('Complete'))];
			default:
				return const [];
		}
	}
}

