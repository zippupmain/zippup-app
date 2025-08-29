import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/order.dart';
import 'package:zippup/features/providers/widgets/provider_header.dart';

class PersonalProviderDashboardScreen extends StatefulWidget {
	const PersonalProviderDashboardScreen({super.key});
	@override
	State<PersonalProviderDashboardScreen> createState() => _PersonalProviderDashboardScreenState();
}

class _PersonalProviderDashboardScreenState extends State<PersonalProviderDashboardScreen> {
	final _db = FirebaseFirestore.instance;
	final _auth = FirebaseAuth.instance;
	bool _online = false;
	OrderStatus? _filter;
	Stream<List<Order>>? _incomingStream;

	@override
	void initState() {
		super.initState();
		_init();
	}

	Future<void> _init() async {
		final uid = _auth.currentUser?.uid;
		if (uid == null) return;
		final prof = await _db.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: 'personal').limit(1).get();
		if (prof.docs.isNotEmpty) {
			_online = prof.docs.first.get('availabilityOnline') == true;
			if (mounted) setState(() {});
		}
		_incomingStream = _db
			.collection('orders')
			.where('providerId', isEqualTo: uid)
			.where('status', isEqualTo: OrderStatus.pending.name)
			.snapshots()
			.map((s) => s.docs.map((d) => Order.fromJson(d.id, d.data())).toList());
	}

	Stream<List<Order>> _ordersStream(String uid) {
		Query<Map<String, dynamic>> q = _db.collection('orders').where('providerId', isEqualTo: uid);
		return q.orderBy('createdAt', descending: true).snapshots().map((s) => s.docs.map((d) => Order.fromJson(d.id, d.data())).toList());
	}

	Future<void> _setOnline(bool v) async {
		final uid = _auth.currentUser?.uid; if (uid == null) return;
		setState(() => _online = v);
		final snap = await _db.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: 'personal').limit(1).get();
		if (snap.docs.isNotEmpty) {
			await snap.docs.first.reference.set({'availabilityOnline': v}, SetOptions(merge: true));
		}
	}

	Future<void> _updateOrder(String id, OrderStatus status) async {
		await _db.collection('orders').doc(id).set({'status': status.name}, SetOptions(merge: true));
	}

	@override
	Widget build(BuildContext context) {
		final uid = _auth.currentUser?.uid ?? '';
		return DefaultTabController(
			length: 2,
			child: Scaffold(
				appBar: AppBar(title: const Text('Personal Provider'), actions: [
					IconButton(icon: const Icon(Icons.home_outlined), onPressed: () => context.go('/')),
					IconButton(icon: const Icon(Icons.close), onPressed: () { if (Navigator.of(context).canPop()) { Navigator.pop(context); } else { context.go('/'); } }),
				], bottom: PreferredSize(
					preferredSize: const Size.fromHeight(48),
					child: StreamBuilder<List<Order>>(
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
								const Tab(icon: Icon(Icons.list), text: 'Jobs'),
							]);
						},
					),
				),
				),
				body: Column(children: [
					const ProviderHeader(service: 'personal'),
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
							...[
								OrderStatus.pending,
								OrderStatus.accepted,
								OrderStatus.enroute,
								OrderStatus.arrived,
								OrderStatus.completed,
								OrderStatus.cancelled,
							].map((s) => Padding(
								padding: const EdgeInsets.symmetric(horizontal: 4),
								child: FilterChip(label: Text(s.name), selected: _filter == s, onSelected: (_) => setState(() => _filter = s)),
							)),
						]),
					),
					Expanded(child: TabBarView(children: [
						StreamBuilder<List<Order>>(
							stream: _incomingStream,
							builder: (context, s) {
								final list = s.data ?? const <Order>[];
								if (list.isEmpty) return const Center(child: Text('No incoming requests'));
								return ListView.separated(
									itemCount: list.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, i) {
										final o = list[i];
										return ListTile(
											title: Text('REQUEST • ${o.category.name.toUpperCase()}'),
											subtitle: Text('Order ${o.id.substring(0,6)} • ${o.status.name}'),
											isThreeLine: false,
											trailing: Wrap(spacing: 6, children: [
												FilledButton(onPressed: () => _updateOrder(o.id, OrderStatus.accepted), child: const Text('Accept')),
												TextButton(onPressed: () => _db.collection('orders').doc(o.id).set({'status': 'cancelled', 'cancelReason': 'declined_by_provider', 'cancelledAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)), child: const Text('Decline')),
											]),
										);
									},
								);
							},
						),
						StreamBuilder<List<Order>>(
							stream: _ordersStream(uid),
							builder: (context, snap) {
								if (!snap.hasData) return const Center(child: CircularProgressIndicator());
								var orders = snap.data!;
								if (_filter != null) orders = orders.where((r) => r.status == _filter).toList();
								if (orders.isEmpty) return const Center(child: Text('No orders'));
								return ListView.separated(
									itemCount: orders.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, i) {
										final o = orders[i];
										return ListTile(
											title: Text('${o.category.name.toUpperCase()} • ${o.status.name}'),
											subtitle: Text('Order ${o.id.substring(0,6)}'),
											isThreeLine: false,
											trailing: Wrap(spacing: 6, children: _actionsFor(o)),
										);
									},
								);
							},
						),
					])),
					StreamBuilder<List<Order>>(
						stream: _incomingStream,
						builder: (context, s) {
							if (!s.hasData || s.data!.isEmpty) return const SizedBox.shrink();
							final o = s.data!.first;
							WidgetsBinding.instance.addPostFrameCallback((_) {
								showDialog(
									context: context,
									builder: (_) => AlertDialog(
										title: const Text('New order request'),
										content: Text('Order ${o.id.substring(0,6)} • ${o.category.name}'),
										actions: [
											TextButton(onPressed: () { Navigator.pop(context); _updateOrder(o.id, OrderStatus.accepted); }, child: const Text('Accept')),
											TextButton(onPressed: () { Navigator.pop(context); _db.collection('orders').doc(o.id).set({'status': 'cancelled', 'cancelReason': 'declined_by_provider', 'cancelledAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)); }, child: const Text('Decline')),
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

	List<Widget> _actionsFor(Order o) {
		switch (o.status) {
			case OrderStatus.pending:
				return [
					FilledButton(onPressed: () => _updateOrder(o.id, OrderStatus.accepted), child: const Text('Accept')),
					TextButton(onPressed: () => _db.collection('orders').doc(o.id).set({'status': 'cancelled', 'cancelReason': 'declined_by_provider', 'cancelledAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)), child: const Text('Reject')),
				];
			case OrderStatus.accepted:
				return [TextButton(onPressed: () => _updateOrder(o.id, OrderStatus.enroute), child: const Text('Enroute'))];
			case OrderStatus.enroute:
				return [TextButton(onPressed: () => _updateOrder(o.id, OrderStatus.arrived), child: const Text('Arrived'))];
			case OrderStatus.arrived:
				return [FilledButton(onPressed: () => _updateOrder(o.id, OrderStatus.completed), child: const Text('Complete'))];
			default:
				return const [];
		}
	}
}

