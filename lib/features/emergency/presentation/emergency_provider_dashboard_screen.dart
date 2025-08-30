import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/emergency_booking.dart';
import 'package:zippup/features/providers/widgets/provider_header.dart';

class EmergencyProviderDashboardScreen extends StatefulWidget {
	const EmergencyProviderDashboardScreen({super.key});
	@override
	State<EmergencyProviderDashboardScreen> createState() => _EmergencyProviderDashboardScreenState();
}

class _EmergencyProviderDashboardScreenState extends State<EmergencyProviderDashboardScreen> {
	final _db = FirebaseFirestore.instance;
	final _auth = FirebaseAuth.instance;
	bool _online = false;
	EmergencyStatus? _filter;
	Stream<List<EmergencyBooking>>? _incomingStream;

	@override
	void initState() {
		super.initState();
		_init();
	}

	Future<void> _init() async {
		final uid = _auth.currentUser?.uid;
		if (uid == null) return;
		final prof = await _db.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: 'emergency').limit(1).get();
		if (prof.docs.isNotEmpty) {
			_online = prof.docs.first.get('availabilityOnline') == true;
			if (mounted) setState(() {});
		}
		_incomingStream = _db
			.collection('emergency_bookings')
			.where('providerId', isEqualTo: uid)
			.where('status', isEqualTo: EmergencyStatus.requested.name)
			.snapshots()
			.map((s) => s.docs.map((d) => EmergencyBooking.fromJson(d.id, d.data())).toList());
	}

	Stream<List<EmergencyBooking>> _bookingsStream(String uid) {
		Query<Map<String, dynamic>> q = _db.collection('emergency_bookings').where('providerId', isEqualTo: uid);
		return q.orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map((d) => EmergencyBooking.fromJson(d.id, d.data())).toList());
	}

	Future<void> _setOnline(bool v) async {
		final uid = _auth.currentUser?.uid; if (uid == null) return;
		setState(() => _online = v);
		final snap = await _db.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: 'emergency').limit(1).get();
		if (snap.docs.isNotEmpty) {
			await snap.docs.first.reference.set({'availabilityOnline': v}, SetOptions(merge: true));
		}
	}

	Future<void> _updateBooking(String id, EmergencyStatus status) async {
		await _db.collection('emergency_bookings').doc(id).set({'status': status.name}, SetOptions(merge: true));
	}

	Widget _actionsForBooking(EmergencyBooking booking) {
		final priorityColor = {
			EmergencyPriority.low: Colors.green,
			EmergencyPriority.medium: Colors.orange,
			EmergencyPriority.high: Colors.red,
			EmergencyPriority.critical: Colors.red.shade900,
		}[booking.priority] ?? Colors.orange;

		switch (booking.status) {
			case EmergencyStatus.requested:
				return FilledButton.icon(
					onPressed: () {
						_updateBooking(booking.id, EmergencyStatus.accepted);
						context.push('/track/emergency?bookingId=${booking.id}');
					},
					icon: const Icon(Icons.emergency, size: 16),
					label: const Text('RESPOND'),
					style: FilledButton.styleFrom(
						backgroundColor: priorityColor,
						minimumSize: const Size(80, 32),
					),
				);
			case EmergencyStatus.accepted:
				return FilledButton.icon(
					onPressed: () => _updateBooking(booking.id, EmergencyStatus.arriving),
					icon: const Icon(Icons.directions_run, size: 16),
					label: const Text('Arriving'),
					style: FilledButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(70, 32)),
				);
			case EmergencyStatus.arriving:
				return FilledButton.icon(
					onPressed: () => _updateBooking(booking.id, EmergencyStatus.arrived),
					icon: const Icon(Icons.location_on, size: 16),
					label: const Text('Arrived'),
					style: FilledButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(70, 32)),
				);
			case EmergencyStatus.arrived:
				return FilledButton.icon(
					onPressed: () => _updateBooking(booking.id, EmergencyStatus.inProgress),
					icon: const Icon(Icons.medical_services, size: 16),
					label: const Text('Start'),
					style: FilledButton.styleFrom(backgroundColor: priorityColor, minimumSize: const Size(70, 32)),
				);
			case EmergencyStatus.inProgress:
				return FilledButton.icon(
					onPressed: () => _updateBooking(booking.id, EmergencyStatus.completed),
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
						'🚨 Emergency Provider',
						style: TextStyle(fontWeight: FontWeight.bold),
					),
					backgroundColor: Colors.transparent,
					flexibleSpace: Container(
						decoration: const BoxDecoration(
							gradient: LinearGradient(
								colors: [Color(0xFFF44336), Color(0xFFEF5350)],
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
						child: StreamBuilder<List<EmergencyBooking>>(
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
								return TabBar(
									labelColor: Colors.white,
									unselectedLabelColor: Colors.white70,
									tabs: [
										Tab(icon: iconWithBadge(Icons.emergency, count), text: count > 0 ? 'Emergency ($count)' : 'Emergency'),
										const Tab(icon: Icon(Icons.list), text: 'History'),
									],
								);
							},
						),
					),
				),
				body: Column(children: [
					const ProviderHeader(service: 'emergency'),
					Padding(
						padding: const EdgeInsets.all(12),
						child: Row(children: [
							Expanded(child: SwitchListTile(
								title: const Text('Emergency Response Online'),
								subtitle: Text(_online ? 'Available for emergencies' : 'Offline - no requests'),
								value: _online,
								onChanged: _setOnline,
								activeColor: Colors.red,
							)),
						]),
					),
					SingleChildScrollView(
						scrollDirection: Axis.horizontal,
						child: Row(children: [
							FilterChip(label: const Text('All'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
							...[
								EmergencyStatus.requested,
								EmergencyStatus.accepted,
								EmergencyStatus.arriving,
								EmergencyStatus.arrived,
								EmergencyStatus.inProgress,
								EmergencyStatus.completed,
								EmergencyStatus.cancelled,
							].map((s) => Padding(
								padding: const EdgeInsets.symmetric(horizontal: 4),
								child: FilterChip(label: Text(s.name), selected: _filter == s, onSelected: (_) => setState(() => _filter = s)),
							)),
						]),
					),
					Expanded(child: TabBarView(children: [
						// Incoming emergency requests
						StreamBuilder<List<EmergencyBooking>>(
							stream: _incomingStream,
							builder: (context, s) {
								final list = s.data ?? const <EmergencyBooking>[];
								if (list.isEmpty) return const Center(child: Text('No incoming emergency requests'));
								return ListView.separated(
									itemCount: list.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, i) {
										final booking = list[i];
										return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
											future: _db.collection('users').doc(booking.clientId).get(),
											builder: (context, u) {
												final data = u.data?.data() ?? const {};
												final name = (data['name'] ?? 'Customer').toString();
												final photo = (data['photoUrl'] ?? '').toString();
												
												final priorityColor = {
													EmergencyPriority.low: Colors.green,
													EmergencyPriority.medium: Colors.orange,
													EmergencyPriority.high: Colors.red,
													EmergencyPriority.critical: Colors.red.shade900,
												}[booking.priority] ?? Colors.orange;
												
												return Container(
													margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
													decoration: BoxDecoration(
														gradient: LinearGradient(
															colors: [priorityColor.withOpacity(0.1), priorityColor.withOpacity(0.05)],
														),
														borderRadius: BorderRadius.circular(12),
														border: Border.all(color: priorityColor.withOpacity(0.3), width: 2),
													),
													child: ListTile(
														leading: CircleAvatar(
															backgroundColor: priorityColor,
															backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null, 
															child: photo.isEmpty ? const Icon(Icons.person, color: Colors.white) : null
														),
														title: Text(
															'🚨 ${booking.type.name.toUpperCase()} EMERGENCY',
															style: TextStyle(fontWeight: FontWeight.bold, color: priorityColor),
														),
														subtitle: Text(
															'$name • ${booking.priority.name.toUpperCase()} PRIORITY\n📍 ${booking.emergencyAddress}\n💰 ₦${booking.feeEstimate.toStringAsFixed(0)}',
															style: TextStyle(color: priorityColor),
														),
														isThreeLine: true,
														trailing: Column(
															mainAxisSize: MainAxisSize.min,
															children: [
																FilledButton.icon(
																	onPressed: () {
																		_updateBooking(booking.id, EmergencyStatus.accepted);
																		context.push('/track/emergency?bookingId=${booking.id}');
																	},
																	icon: const Icon(Icons.emergency, size: 16),
																	label: const Text('RESPOND'),
																	style: FilledButton.styleFrom(
																		backgroundColor: priorityColor,
																		minimumSize: const Size(80, 32),
																	),
																),
																const SizedBox(height: 4),
																TextButton(
																	onPressed: () => _updateBooking(booking.id, EmergencyStatus.cancelled),
																	child: const Text('Cannot Help', style: TextStyle(fontSize: 12)),
																),
															],
														),
													),
												);
											},
										);
									},
								);
							},
						),
						// Emergency history
						StreamBuilder<List<EmergencyBooking>>(
							stream: _bookingsStream(uid),
							builder: (context, snap) {
								if (!snap.hasData) return const Center(child: CircularProgressIndicator());
								var bookings = snap.data!;
								if (_filter != null) bookings = bookings.where((r) => r.status == _filter).toList();
								if (bookings.isEmpty) return const Center(child: Text('No emergency bookings'));
								return ListView.separated(
									itemCount: bookings.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, i) {
										final booking = bookings[i];
										final priorityColor = {
											EmergencyPriority.low: Colors.green,
											EmergencyPriority.medium: Colors.orange,
											EmergencyPriority.high: Colors.red,
											EmergencyPriority.critical: Colors.red.shade900,
										}[booking.priority] ?? Colors.orange;
										
										return Container(
											margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
											decoration: BoxDecoration(
												color: Colors.white,
												borderRadius: BorderRadius.circular(12),
												border: Border.all(color: priorityColor.withOpacity(0.3)),
											),
											child: ListTile(
												title: Text(
													'🚨 ${booking.type.name.toUpperCase()} • ${booking.status.name.toUpperCase()}',
													style: TextStyle(color: priorityColor, fontWeight: FontWeight.bold),
												),
												subtitle: Text(
													'${booking.priority.name.toUpperCase()} PRIORITY\nBooking ${booking.id.substring(0,6)}\n📍 ${booking.emergencyAddress}',
													style: TextStyle(color: priorityColor),
												),
												isThreeLine: true,
												trailing: _actionsForBooking(booking),
												onTap: () => context.push('/track/emergency?bookingId=${booking.id}'),
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