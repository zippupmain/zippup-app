import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/moving_booking.dart';
import 'package:zippup/features/providers/widgets/provider_header.dart';

class MovingProviderDashboardScreen extends StatefulWidget {
	const MovingProviderDashboardScreen({super.key});
	@override
	State<MovingProviderDashboardScreen> createState() => _MovingProviderDashboardScreenState();
}

class _MovingProviderDashboardScreenState extends State<MovingProviderDashboardScreen> {
	final _db = FirebaseFirestore.instance;
	final _auth = FirebaseAuth.instance;
	bool _online = true;
	String? _filter;
	Stream<List<MovingBooking>>? _incomingStream;

	@override
	void initState() {
		super.initState();
		_init();
	}

	Future<void> _init() async {
		final uid = _auth.currentUser?.uid;
		if (uid == null) return;
		final prof = await _db.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: 'moving').limit(1).get();
		if (prof.docs.isNotEmpty) {
			// Always default to online, update profile
			_online = true;
			await _db.collection('provider_profiles').doc(prof.docs.first.id).update({'availabilityOnline': true});
			if (mounted) setState(() {});
		}
		_incomingStream = _db
			.collection('moving_bookings')
			.where('providerId', isEqualTo: uid)
			.where('status', isEqualTo: 'requested')
			.snapshots()
			.map((s) => s.docs.map((d) => MovingBooking.fromJson(d.id, d.data())).toList());
	}

	Stream<List<MovingBooking>> _bookingsStream(String uid) {
		Query<Map<String, dynamic>> q = _db.collection('moving_bookings').where('providerId', isEqualTo: uid);
		return q.orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map((d) => MovingBooking.fromJson(d.id, d.data())).toList());
	}

	Future<void> _setOnline(bool v) async {
		final uid = _auth.currentUser?.uid; if (uid == null) return;
		setState(() => _online = v);
		final snap = await _db.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: 'moving').limit(1).get();
		if (snap.docs.isNotEmpty) {
			await snap.docs.first.reference.set({'availabilityOnline': v}, SetOptions(merge: true));
		}
	}

	Future<void> _updateBooking(String id, String status) async {
		await _db.collection('moving_bookings').doc(id).set({'status': status}, SetOptions(merge: true));
	}

	Widget _actionsForBooking(MovingBooking booking) {
		switch (booking.status.name) {
			case 'requested':
				return FilledButton.icon(
					onPressed: () {
						_updateBooking(booking.id, 'accepted');
						context.push('/track/moving?bookingId=${booking.id}');
					},
					icon: const Icon(Icons.check, size: 16),
					label: const Text('Accept'),
					style: FilledButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(70, 32)),
				);
			case 'accepted':
				return FilledButton.icon(
					onPressed: () => _updateBooking(booking.id, 'arriving'),
					icon: const Icon(Icons.directions_car, size: 16),
					label: const Text('Arriving'),
					style: FilledButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(70, 32)),
				);
			case 'arriving':
				return FilledButton.icon(
					onPressed: () => _updateBooking(booking.id, 'arrived'),
					icon: const Icon(Icons.location_on, size: 16),
					label: const Text('Arrived'),
					style: FilledButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(70, 32)),
				);
			case 'arrived':
				return FilledButton.icon(
					onPressed: () => _updateBooking(booking.id, 'loading'),
					icon: const Icon(Icons.inbox, size: 16),
					label: const Text('Loading'),
					style: FilledButton.styleFrom(backgroundColor: Colors.indigo, minimumSize: const Size(70, 32)),
				);
			case 'loading':
				return FilledButton.icon(
					onPressed: () => _updateBooking(booking.id, 'inTransit'),
					icon: const Icon(Icons.local_shipping, size: 16),
					label: const Text('In Transit'),
					style: FilledButton.styleFrom(backgroundColor: Colors.purple, minimumSize: const Size(70, 32)),
				);
			case 'inTransit':
				return FilledButton.icon(
					onPressed: () => _updateBooking(booking.id, 'unloading'),
					icon: const Icon(Icons.unarchive, size: 16),
					label: const Text('Unloading'),
					style: FilledButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size(70, 32)),
				);
			case 'unloading':
				return FilledButton.icon(
					onPressed: () => _updateBooking(booking.id, 'completed'),
					icon: const Icon(Icons.check_circle, size: 16),
					label: const Text('Complete'),
					style: FilledButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(70, 32)),
				);
			default:
				return const SizedBox.shrink();
		}
	}

	@override
	Widget build(BuildContext context) {
		final uid = _auth.currentUser?.uid ?? '';
		return DefaultTabController(
			length: 2,
			child: Scaffold(
				appBar: AppBar(
					title: const Text(
						'📦 Moving Provider',
						style: TextStyle(fontWeight: FontWeight.bold),
					),
					backgroundColor: Colors.transparent,
					flexibleSpace: Container(
						decoration: const BoxDecoration(
							gradient: LinearGradient(
								colors: [Color(0xFF3F51B5), Color(0xFF7986CB)],
								begin: Alignment.topLeft,
								end: Alignment.bottomRight,
							),
						),
					),
					foregroundColor: Colors.white,
					actions: [
						IconButton(icon: const Icon(Icons.home_outlined), onPressed: () => context.go('/')),
						IconButton(icon: const Icon(Icons.close), onPressed: () { if (Navigator.of(context).canPop()) { Navigator.pop(context); } else { context.go('/'); } }),
					], 
					bottom: PreferredSize(
						preferredSize: const Size.fromHeight(48),
						child: StreamBuilder<List<MovingBooking>>(
							stream: _incomingStream,
							builder: (context, s) {
								final count = (s.data?.length ?? 0);
								return TabBar(
									labelColor: Colors.white,
									unselectedLabelColor: Colors.white70,
									tabs: [
										Tab(text: count > 0 ? 'Requests ($count)' : 'Requests'),
										const Tab(text: 'History'),
									],
								);
							},
						),
					),
				),
				body: Column(children: [
					const ProviderHeader(service: 'moving'),
					Padding(
						padding: const EdgeInsets.all(12),
						child: Column(
							children: [
								SwitchListTile(
									title: const Text('Moving Services Online'),
									subtitle: Text(_online ? 'Available for moving requests' : 'Offline'),
									value: _online,
									onChanged: _setOnline,
									activeColor: Colors.indigo,
								),
								const SizedBox(height: 8),
								SingleChildScrollView(
									scrollDirection: Axis.horizontal,
									child: Row(children: [
										OutlinedButton.icon(
											onPressed: () => context.push('/moving/vehicles/manage'),
											icon: const Icon(Icons.local_shipping, color: Colors.orange),
											label: const Text('Manage Vehicles', style: TextStyle(color: Colors.orange)),
										),
										const SizedBox(width: 8),
										OutlinedButton.icon(
											onPressed: () => context.push('/moving/team/manage'),
											icon: const Icon(Icons.group, color: Colors.blue),
											label: const Text('Moving Team', style: TextStyle(color: Colors.blue)),
										),
										const SizedBox(width: 8),
										OutlinedButton.icon(
											onPressed: () => context.push('/moving/pricing/manage'),
											icon: const Icon(Icons.attach_money, color: Colors.green),
											label: const Text('Pricing & Sizes', style: TextStyle(color: Colors.green)),
										),
										const SizedBox(width: 8),
										OutlinedButton.icon(
											onPressed: () => context.push('/moving/schedule/manage'),
											icon: const Icon(Icons.schedule, color: Colors.purple),
											label: const Text('Schedule Management', style: TextStyle(color: Colors.purple)),
										),
									]),
								),
							],
						),
					),
					Expanded(child: TabBarView(children: [
						// Incoming requests
						StreamBuilder<List<MovingBooking>>(
							stream: _incomingStream,
							builder: (context, s) {
								final list = s.data ?? const <MovingBooking>[];
								if (list.isEmpty) return const Center(child: Text('No incoming moving requests'));
								return ListView.builder(
									padding: const EdgeInsets.all(12),
									itemCount: list.length,
									itemBuilder: (context, i) {
										final booking = list[i];
										return Container(
											margin: const EdgeInsets.only(bottom: 12),
											decoration: BoxDecoration(
												gradient: const LinearGradient(
													colors: [Color(0xFFE8EAF6), Color(0xFFC5CAE9)],
												),
												borderRadius: BorderRadius.circular(12),
												border: Border.all(color: Colors.indigo.shade200),
											),
											child: ListTile(
												title: Text('📦 ${booking.type.name.toUpperCase()} MOVING'),
												subtitle: Text('${booking.pickupAddress} → ${booking.destinationAddress}\n💰 ₦${booking.feeEstimate.toStringAsFixed(0)}'),
												isThreeLine: true,
												trailing: _actionsForBooking(booking),
											),
										);
									},
								);
							},
						),
						// History
						StreamBuilder<List<MovingBooking>>(
							stream: _bookingsStream(uid),
							builder: (context, snap) {
								if (!snap.hasData) return const Center(child: CircularProgressIndicator());
								var bookings = snap.data!;
								if (_filter != null) bookings = bookings.where((r) => r.status.name == _filter).toList();
								if (bookings.isEmpty) return const Center(child: Text('No moving bookings'));
								return ListView.builder(
									padding: const EdgeInsets.all(12),
									itemCount: bookings.length,
									itemBuilder: (context, i) {
										final booking = bookings[i];
										return Container(
											margin: const EdgeInsets.only(bottom: 12),
											decoration: BoxDecoration(
												color: Colors.white,
												borderRadius: BorderRadius.circular(12),
												border: Border.all(color: Colors.grey.shade200),
											),
											child: ListTile(
												title: Text('📦 ${booking.type.name.toUpperCase()} • ${booking.status.name.toUpperCase()}'),
												subtitle: Text('${booking.pickupAddress} → ${booking.destinationAddress}'),
												trailing: _actionsForBooking(booking),
												onTap: () => context.push('/track/moving?bookingId=${booking.id}'),
											),
										);
									},
								);
							},
						),
					])),
				]),
			),
		);
	}
}