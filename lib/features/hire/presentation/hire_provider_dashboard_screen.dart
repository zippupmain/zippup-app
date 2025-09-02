import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/hire_booking.dart';
import 'package:zippup/features/providers/widgets/provider_header.dart';

class HireProviderDashboardScreen extends StatefulWidget {
	const HireProviderDashboardScreen({super.key});
	@override
	State<HireProviderDashboardScreen> createState() => _HireProviderDashboardScreenState();
}

class _HireProviderDashboardScreenState extends State<HireProviderDashboardScreen> {
	final _db = FirebaseFirestore.instance;
	final _auth = FirebaseAuth.instance;
	bool _online = true;
	HireStatus? _filter;
	Stream<List<HireBooking>>? _incomingStream;

	@override
	void initState() {
		super.initState();
		_init();
	}

	Future<void> _init() async {
		final uid = _auth.currentUser?.uid;
		if (uid == null) return;
		final prof = await _db.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: 'hire').limit(1).get();
		if (prof.docs.isNotEmpty) {
			// Always default to online, update profile
			_online = true;
			await _db.collection('provider_profiles').doc(prof.docs.first.id).update({'availabilityOnline': true});
			if (mounted) setState(() {});
		}
		_incomingStream = _db
			.collection('hire_bookings')
			.where('providerId', isEqualTo: uid)
			.where('status', isEqualTo: HireStatus.requested.name)
			.snapshots()
			.map((s) => s.docs.map((d) => HireBooking.fromJson(d.id, d.data())).toList());
	}

	Stream<List<HireBooking>> _bookingsStream(String uid) {
		Query<Map<String, dynamic>> q = _db.collection('hire_bookings').where('providerId', isEqualTo: uid);
		return q.orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map((d) => HireBooking.fromJson(d.id, d.data())).toList());
	}

	Future<void> _setOnline(bool v) async {
		final uid = _auth.currentUser?.uid; if (uid == null) return;
		setState(() => _online = v);
		final snap = await _db.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: 'hire').limit(1).get();
		if (snap.docs.isNotEmpty) {
			await snap.docs.first.reference.set({'availabilityOnline': v}, SetOptions(merge: true));
		}
	}

	Future<void> _updateBooking(String id, HireStatus status) async {
		await _db.collection('hire_bookings').doc(id).set({'status': status.name}, SetOptions(merge: true));
	}

	Widget _actionsForBooking(HireBooking booking) {
		switch (booking.status) {
			case HireStatus.requested:
				return Row(
					mainAxisSize: MainAxisSize.min,
					children: [
						FilledButton.icon(
							onPressed: () => _updateBooking(booking.id, HireStatus.accepted),
							icon: const Icon(Icons.check, size: 16),
							label: const Text('Accept'),
							style: FilledButton.styleFrom(backgroundColor: Colors.green, minimumSize: const Size(70, 32)),
						),
					],
				);
			case HireStatus.accepted:
				return FilledButton.icon(
					onPressed: () => _updateBooking(booking.id, HireStatus.arriving),
					icon: const Icon(Icons.directions_car, size: 16),
					label: const Text('Arriving'),
					style: FilledButton.styleFrom(backgroundColor: Colors.blue, minimumSize: const Size(70, 32)),
				);
			case HireStatus.arriving:
				return FilledButton.icon(
					onPressed: () => _updateBooking(booking.id, HireStatus.arrived),
					icon: const Icon(Icons.location_on, size: 16),
					label: const Text('Arrived'),
					style: FilledButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(70, 32)),
				);
			case HireStatus.arrived:
				return FilledButton.icon(
					onPressed: () => _updateBooking(booking.id, HireStatus.inProgress),
					icon: const Icon(Icons.build, size: 16),
					label: const Text('Start Work'),
					style: FilledButton.styleFrom(backgroundColor: Colors.purple, minimumSize: const Size(70, 32)),
				);
			case HireStatus.inProgress:
				return FilledButton.icon(
					onPressed: () => _updateBooking(booking.id, HireStatus.completed),
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
				appBar: AppBar(title: const Text('Hire Provider'), actions: [
					IconButton(icon: const Icon(Icons.home_outlined), onPressed: () => context.go('/')),
					IconButton(icon: const Icon(Icons.close), onPressed: () { if (Navigator.of(context).canPop()) { Navigator.pop(context); } else { context.go('/'); } }),
				], bottom: PreferredSize(
					preferredSize: const Size.fromHeight(48),
					child: StreamBuilder<List<HireBooking>>(
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
								Tab(icon: iconWithBadge(Icons.notifications_active, count), text: count > 0 ? 'New ($count)' : 'New Requests'),
								const Tab(icon: Icon(Icons.history), text: 'All History'),
							]);
						},
					),
				),
				),
				body: Column(children: [
					const ProviderHeader(service: 'hire'),
					Padding(
						padding: const EdgeInsets.all(12),
						child: Column(
							children: [
								Row(children: [
									Expanded(child: SwitchListTile(title: const Text('Go Online'), value: _online, onChanged: _setOnline)),
									const SizedBox(width: 8),
									OutlinedButton.icon(onPressed: () => context.push('/hub/orders'), icon: const Icon(Icons.list_alt), label: const Text('All orders')),
								]),
								const SizedBox(height: 8),
								SingleChildScrollView(
									scrollDirection: Axis.horizontal,
									child: Row(children: [
										OutlinedButton.icon(
											onPressed: () => context.push('/hire/services/manage'),
											icon: const Icon(Icons.build, color: Colors.blue),
											label: const Text('Manage Services', style: TextStyle(color: Colors.blue)),
										),
										const SizedBox(width: 8),
										OutlinedButton.icon(
											onPressed: () => context.push('/hire/tools/manage'),
											icon: const Icon(Icons.construction, color: Colors.orange),
											label: const Text('Tools & Equipment', style: TextStyle(color: Colors.orange)),
										),
										const SizedBox(width: 8),
										OutlinedButton.icon(
											onPressed: () => context.push('/hire/pricing/manage'),
											icon: const Icon(Icons.attach_money, color: Colors.green),
											label: const Text('Pricing & Classes', style: TextStyle(color: Colors.green)),
										),
										const SizedBox(width: 8),
										OutlinedButton.icon(
											onPressed: () => context.push('/hire/schedule/manage'),
											icon: const Icon(Icons.schedule, color: Colors.purple),
											label: const Text('Schedule & Availability', style: TextStyle(color: Colors.purple)),
										),
									]),
								),
							],
						),
					),
					SingleChildScrollView(
						scrollDirection: Axis.horizontal,
						child: Row(children: [
							FilterChip(label: const Text('All'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
							...[
								HireStatus.requested,
								HireStatus.accepted,
								HireStatus.arriving,
								HireStatus.arrived,
								HireStatus.inProgress,
								HireStatus.completed,
								HireStatus.cancelled,
							].map((s) => Padding(
								padding: const EdgeInsets.symmetric(horizontal: 4),
								child: FilterChip(label: Text(s.name), selected: _filter == s, onSelected: (_) => setState(() => _filter = s)),
							)),
						]),
					),
					Expanded(child: TabBarView(children: [
						// Incoming tab
						StreamBuilder<List<HireBooking>>(
							stream: _incomingStream,
							builder: (context, s) {
								final list = s.data ?? const <HireBooking>[];
								if (list.isEmpty) return const Center(child: Text('No incoming hire requests'));
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
												return Container(
													margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
													decoration: BoxDecoration(
														gradient: const LinearGradient(
															colors: [Color(0xFFF3E5F5), Color(0xFFE1BEE7)],
														),
														borderRadius: BorderRadius.circular(12),
														border: Border.all(color: Colors.purple.shade200),
													),
													child: ListTile(
														leading: CircleAvatar(
															backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null, 
															child: photo.isEmpty ? const Icon(Icons.person) : null
														),
														title: Text('🔧 ${booking.serviceCategory.toUpperCase()} REQUEST'),
														subtitle: Text('$name\n📍 ${booking.serviceAddress}\n💰 ₦${booking.feeEstimate.toStringAsFixed(0)}'),
														isThreeLine: true,
														trailing: Column(
															mainAxisSize: MainAxisSize.min,
															children: [
																FilledButton.icon(
																	onPressed: () {
																		_updateBooking(booking.id, HireStatus.accepted);
																		context.push('/track/hire?bookingId=${booking.id}');
																	},
																	icon: const Icon(Icons.check, size: 16),
																	label: const Text('Accept'),
																	style: FilledButton.styleFrom(
																		backgroundColor: Colors.green,
																		minimumSize: const Size(80, 32),
																	),
																),
																const SizedBox(height: 4),
																TextButton(
																	onPressed: () => _updateBooking(booking.id, HireStatus.cancelled),
																	child: const Text('Decline', style: TextStyle(fontSize: 12)),
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
						// Bookings tab
						StreamBuilder<List<HireBooking>>(
							stream: _bookingsStream(uid),
							builder: (context, snap) {
								if (!snap.hasData) return const Center(child: CircularProgressIndicator());
								var bookings = snap.data!;
								if (_filter != null) bookings = bookings.where((r) => r.status == _filter).toList();
								if (bookings.isEmpty) return const Center(child: Text('No hire bookings'));
								return ListView.separated(
									itemCount: bookings.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, i) {
										final booking = bookings[i];
										return Container(
											margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
											decoration: BoxDecoration(
												color: Colors.white,
												borderRadius: BorderRadius.circular(12),
												border: Border.all(color: Colors.grey.shade200),
											),
											child: ListTile(
												title: Text('🔧 ${booking.serviceCategory.toUpperCase()} • ${booking.status.name.toUpperCase()}'),
												subtitle: Text('Booking ${booking.id.substring(0,6)}\n📍 ${booking.serviceAddress}\n💰 ₦${booking.feeEstimate.toStringAsFixed(0)}'),
												isThreeLine: true,
												trailing: _actionsForBooking(booking),
												onTap: () => context.push('/track/hire?bookingId=${booking.id}'),
											),
										);
									},
								);
							},
						),
					])),
					// Incoming overlay
					StreamBuilder<List<HireBooking>>(
						stream: _incomingStream,
						builder: (context, s) {
							if (!s.hasData || s.data!.isEmpty) return const SizedBox.shrink();
							final booking = s.data!.first;
							WidgetsBinding.instance.addPostFrameCallback((_) {
								showDialog(
									context: context,
									builder: (_) => AlertDialog(
										title: const Text('New hire request'),
										content: Text('Booking ${booking.id.substring(0,6)} • ${booking.serviceCategory}'),
										actions: [
											TextButton(onPressed: () { Navigator.pop(context); _updateBooking(booking.id, HireStatus.accepted); }, child: const Text('Accept')),
											TextButton(onPressed: () { Navigator.pop(context); _updateBooking(booking.id, HireStatus.cancelled); }, child: const Text('Decline')),
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


}

