import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/ride.dart';
import 'package:zippup/features/providers/widgets/provider_header.dart';

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
	Stream<List<Ride>>? _incomingStream;

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
		// incoming assigned ride requests (requested and addressed to me)
		_incomingStream = _db
			.collection('rides')
			.where('driverId', isEqualTo: uid)
			.where('status', isEqualTo: RideStatus.requested.name)
			.snapshots()
			.map((s) => s.docs.map((d) => Ride.fromJson(d.id, d.data())).toList());
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
		return DefaultTabController(
			length: 2,
			child: Scaffold(
				appBar: AppBar(title: const Text('Transport Provider'), actions: [
					IconButton(icon: const Icon(Icons.home_outlined), onPressed: () => context.go('/')),
					IconButton(icon: const Icon(Icons.close), onPressed: () { if (Navigator.of(context).canPop()) { Navigator.pop(context); } else { context.go('/'); } }),
				], bottom: PreferredSize(
					preferredSize: const Size.fromHeight(48),
					child: StreamBuilder<List<Ride>>(
						stream: _incomingStream,
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
											constraints: const BoxConstraints(minWidth: 16),
											child: Text('$c', style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
										),
									),
								]);
							}
							return TabBar(tabs: [
								Tab(icon: iconWithBadge(Icons.notifications_active, count), text: count > 0 ? 'Incoming ($count)' : 'Incoming'),
								const Tab(icon: Icon(Icons.list), text: 'Rides'),
							]);
						},
					),
				),
				),
				body: Column(children: [
					const ProviderHeader(service: 'transport'),
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
					Expanded(child: TabBarView(children: [
						// Incoming tab
						StreamBuilder<List<Ride>>(
							stream: _incomingStream,
							builder: (context, s) {
								final list = s.data ?? const <Ride>[];
								if (list.isEmpty) return const Center(child: Text('No incoming requests'));
								return ListView.separated(
									itemCount: list.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, i) {
										final r = list[i];
										return ListTile(
											title: Text('REQUEST • ${r.type.name.toUpperCase()}'),
											subtitle: Text('From: ${r.pickupAddress}\nTo: ${(r.destinationAddresses.isNotEmpty ? r.destinationAddresses.first : '')}'),
											isThreeLine: true,
											trailing: Wrap(spacing: 6, children: [
												FilledButton(onPressed: () => _updateRide(r.id, RideStatus.accepted), child: const Text('Accept')),
												TextButton(onPressed: () => _db.collection('rides').doc(r.id).set({'status': 'cancelled', 'cancelReason': 'declined_by_driver', 'cancelledAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)), child: const Text('Decline')),
											]),
										);
									},
								);
							},
						),
						// Rides tab
						StreamBuilder<List<Ride>>(
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
					])),
					// Incoming request overlay/ping
					StreamBuilder<List<Ride>>(
						stream: _incomingStream,
						builder: (context, s) {
							if (!s.hasData || s.data!.isEmpty) return const SizedBox.shrink();
							final r = s.data!.first;
							WidgetsBinding.instance.addPostFrameCallback((_) {
								showDialog(
									context: context,
									builder: (_) => AlertDialog(
										title: const Text('New ride request'),
										content: Text('${r.type.name.toUpperCase()}\nFrom: ${r.pickupAddress}\nTo: ${(r.destinationAddresses.isNotEmpty ? r.destinationAddresses.first : '')}'),
										actions: [
											TextButton(onPressed: () { Navigator.pop(context); _updateRide(r.id, RideStatus.accepted); }, child: const Text('Accept')),
											TextButton(onPressed: () { Navigator.pop(context); _db.collection('rides').doc(r.id).set({'status': 'cancelled', 'cancelReason': 'declined_by_driver', 'cancelledAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)); }, child: const Text('Decline')),
										],
									),
								);
							});
							return const SizedBox.shrink();
						},
					),
				]),
			),
		);
	}

	List<Widget> _actionsFor(Ride r) {
		switch (r.status) {
			case RideStatus.requested:
				return [
					FilledButton(onPressed: () => _updateRide(r.id, RideStatus.accepted), child: const Text('Accept')),
					TextButton(onPressed: () => _db.collection('rides').doc(r.id).set({ 'status': 'cancelled', 'cancelReason': 'declined_by_driver', 'cancelledAt': FieldValue.serverTimestamp() }, SetOptions(merge: true)), child: const Text('Decline')),
				];
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

