import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/order.dart' as models;
import 'package:zippup/features/food/providers/order_service.dart';
import 'package:zippup/features/providers/widgets/provider_header.dart';

class GroceryProviderDashboardScreen extends StatefulWidget {
	const GroceryProviderDashboardScreen({super.key});
	@override
	State<GroceryProviderDashboardScreen> createState() => _GroceryProviderDashboardScreenState();
}

class _GroceryProviderDashboardScreenState extends State<GroceryProviderDashboardScreen> {
	final _db = FirebaseFirestore.instance;
	final _auth = FirebaseAuth.instance;
	final _service = OrderService();
	bool _storeOpen = true;
	bool _hideNewWhenClosed = true;
	models.OrderStatus? _filter;
	Stream<List<models.Order>>? _incomingStream;
	late final String _providerId;

	Future<void> _dispatchNextReady() async {
		try {
			final q = await _db
				.collection('orders')
				.where('providerId', isEqualTo: _providerId)
				.where('status', isEqualTo: models.OrderStatus.dispatched.name)
				.limit(1)
				.get();
			if (q.docs.isEmpty) {
				if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No orders to dispatch')));
				return;
			}
			await q.docs.first.reference.set({'status': 'dispatched'}, SetOptions(merge: true));
			if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dispatching to courier…')));
		} catch (_) {}
	}

	@override
	void initState() {
		super.initState();
		_providerId = _auth.currentUser?.uid ?? '';
		_incomingStream = _db
			.collection('orders')
			.where('providerId', isEqualTo: _providerId)
			.where('status', isEqualTo: models.OrderStatus.pending.name)
			.snapshots()
			.map((snap) => snap.docs.map((d) => models.Order.fromJson(d.id, d.data())).toList());
	}

	Stream<List<models.Order>> _ordersStream(String providerId) {
		Query<Map<String, dynamic>> q = _db.collection('orders').where('providerId', isEqualTo: providerId);
		return q.snapshots().map((snap) => snap.docs.map((d) => models.Order.fromJson(d.id, d.data())).toList());
	}

	@override
	Widget build(BuildContext context) {
		return DefaultTabController(
			length: 2,
			child: Scaffold(
				appBar: AppBar(title: const Text('Grocery Provider Dashboard'), actions: [
					IconButton(icon: const Icon(Icons.home_outlined), onPressed: () => context.go('/')),
					IconButton(icon: const Icon(Icons.close), onPressed: () { if (Navigator.of(context).canPop()) { Navigator.pop(context); } else { context.go('/'); } }),
				], bottom: PreferredSize(
					preferredSize: const Size.fromHeight(48),
					child: StreamBuilder<List<models.Order>>(
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
								const Tab(icon: Icon(Icons.list), text: 'models.Orders'),
							]);
						},
					),
				),
				),
				body: Column(children: [
					const ProviderHeader(service: 'grocery'),
					Padding(
						padding: const EdgeInsets.all(12),
						child: Row(children: [
							Expanded(child: SwitchListTile(title: const Text('Store open'), value: _storeOpen, onChanged: (v) async {
								setState(() => _storeOpen = v);
								try { await _db.collection('vendors').doc(_providerId).set({'storeOpen': v}, SetOptions(merge: true)); } catch (_) {}
							})),
							const SizedBox(width: 8),
							OutlinedButton.icon(onPressed: () => context.push('/food/vendor/menu?vendorId=${_providerId}'), icon: const Icon(Icons.menu_book), label: const Text('Manage products')),
							const SizedBox(width: 8),
							OutlinedButton.icon(onPressed: () => context.push('/food/menu/manage'), icon: const Icon(Icons.edit_note), label: const Text('Add/Edit items')),
							const SizedBox(width: 8),
							OutlinedButton.icon(onPressed: () => context.push('/grocery/seller-categories'), icon: const Icon(Icons.shopping_basket), label: const Text('Grocery categories')),
							const SizedBox(width: 8),
							OutlinedButton.icon(onPressed: () => context.push('/food/kitchen/hours'), icon: const Icon(Icons.schedule), label: const Text('Open hours')),
							const SizedBox(width: 8),
							OutlinedButton.icon(onPressed: _dispatchNextReady, icon: const Icon(Icons.delivery_dining), label: const Text('Auto dispatch')),
							const SizedBox(width: 8),
							OutlinedButton.icon(onPressed: () => context.push('/hub/orders'), icon: const Icon(Icons.list_alt), label: const Text('All orders')),
						]),
					),
					SingleChildScrollView(
						scrollDirection: Axis.horizontal,
						child: Row(children: [
							FilterChip(label: const Text('All'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
							...[
								models.OrderStatus.pending,
								models.OrderStatus.preparing,
								models.OrderStatus.sorting,
								models.OrderStatus.dispatched,
								models.OrderStatus.assigned,
								models.OrderStatus.enroute,
								models.OrderStatus.arrived,
								models.OrderStatus.delivered,
							].map((s) => Padding(
								padding: const EdgeInsets.symmetric(horizontal: 4),
								child: FilterChip(label: Text(s.name), selected: _filter == s, onSelected: (_) => setState(() => _filter = s)),
							)),
							if (!_storeOpen)
								FilterChip(label: const Text('Hide new when closed'), selected: _hideNewWhenClosed, onSelected: (_) => setState(() => _hideNewWhenClosed = !_hideNewWhenClosed)),
						]),
					),
					Expanded(child: TabBarView(children: [
						StreamBuilder<List<models.Order>>(
							stream: _incomingStream,
							builder: (context, s) {
								final list = s.data ?? const <models.Order>[];
								if (list.isEmpty) return const Center(child: Text('No incoming requests'));
								return ListView.separated(
									itemCount: list.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, i) {
										final o = list[i];
										return ListTile(
											title: Text('REQUEST • ${o.category.name.toUpperCase()}'),
											subtitle: Text('models.Order ${o.id.substring(0,6)} • ${o.status.name}'),
											isThreeLine: false,
											trailing: Wrap(spacing: 6, children: [
												FilledButton(onPressed: () => _service.updateStatus(orderId: o.id, status: models.OrderStatus.preparing), child: const Text('Accept')),
												TextButton(onPressed: () => _db.collection('orders').doc(o.id).set({'status': 'cancelled', 'cancelReason': 'declined_by_vendor', 'cancelledAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)), child: const Text('Decline')),
											]),
										);
									},
								);
							},
						),
						StreamBuilder<List<models.Order>>(
							stream: _ordersStream(_providerId),
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
										if (!_storeOpen && _hideNewWhenClosed && o.status == models.OrderStatus.pending) return const SizedBox.shrink();
										return ListTile(
											title: Text('${o.category.name.toUpperCase()} • ${o.status.name}'),
											subtitle: Text('models.Order ${o.id.substring(0,6)}'),
											isThreeLine: false,
											trailing: Wrap(spacing: 6, children: _groceryActions(context, o, _service)),
										);
									},
								);
							},
						),
					])),
					StreamBuilder<List<models.Order>>(
						stream: _incomingStream,
						builder: (context, s) {
							if (!s.hasData || s.data!.isEmpty) return const SizedBox.shrink();
							final o = s.data!.first;
							WidgetsBinding.instance.addPostFrameCallback((_) {
								showDialog(
									context: context,
									builder: (_) => AlertDialog(
										title: const Text('New order request'),
										content: Text('models.Order ${o.id.substring(0,6)} • ${o.category.name}'),
										actions: [
											TextButton(onPressed: () { Navigator.pop(context); _service.updateStatus(orderId: o.id, status: models.OrderStatus.preparing); }, child: const Text('Accept')),
											TextButton(onPressed: () { Navigator.pop(context); _db.collection('orders').doc(o.id).set({'status': 'cancelled', 'cancelReason': 'declined_by_vendor', 'cancelledAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)); }, child: const Text('Decline')),
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

	List<Widget> _groceryActions(BuildContext context, models.Order o, OrderService s) {
		return [
			if (o.status == models.OrderStatus.pending)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: models.OrderStatus.preparing), child: const Text('Prepare')),
			if (o.status == models.OrderStatus.preparing)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: models.OrderStatus.sorting), child: const Text('Sorting')),
			if (o.status == models.OrderStatus.sorting)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: models.OrderStatus.dispatched), child: const Text('Dispatch')),
			if (o.status == models.OrderStatus.dispatched)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: models.OrderStatus.assigned), child: const Text('Assign courier')),
			if (o.status == models.OrderStatus.assigned)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: models.OrderStatus.enroute), child: const Text('Enroute')),
			if (o.status == models.OrderStatus.enroute)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: models.OrderStatus.arrived), child: const Text('Arrived')),
			if (o.status == models.OrderStatus.arrived)
				FilledButton(onPressed: () => s.updateStatus(orderId: o.id, status: models.OrderStatus.delivered), child: const Text('Complete')),
		];
	}
}

