import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zippup/common/models/order.dart';
import 'package:zippup/features/food/providers/order_service.dart';

class ProviderDashboardScreen extends StatefulWidget {
	const ProviderDashboardScreen({super.key});

	@override
	State<ProviderDashboardScreen> createState() => _ProviderDashboardScreenState();
}

class _ProviderDashboardScreenState extends State<ProviderDashboardScreen> {
	late final OrderService _service;
	String _providerId = '';
	Stream<List<Order>>? _pendingStream;

	@override
	void initState() {
		super.initState();
		_service = OrderService();
		_providerId = FirebaseAuth.instance.currentUser?.uid ?? '';
		_pendingStream = FirebaseFirestore.instance
			.collection('orders')
			.where('providerId', isEqualTo: _providerId)
			.where('status', isEqualTo: OrderStatus.pending.name)
			.snapshots()
			.map((snap) => snap.docs.map((d) => Order.fromJson(d.id, d.data())).toList());
	}

	Stream<List<Order>> _ordersStream(String providerId) {
		return FirebaseFirestore.instance
			.collection('orders')
			.where('providerId', isEqualTo: providerId)
			.orderBy('createdAt', descending: true)
			.snapshots()
			.map((snap) => snap.docs.map((d) => Order.fromJson(d.id, d.data())).toList());
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Provider Dashboard')),
			body: Stack(
				children: [
					StreamBuilder<List<Order>>(
						stream: _ordersStream(_providerId),
						builder: (context, snapshot) {
							if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
							final orders = snapshot.data!;
							if (orders.isEmpty) return const Center(child: Text('No orders yet'));
							return ListView.separated(
								itemCount: orders.length,
								separatorBuilder: (_, __) => const Divider(height: 1),
								itemBuilder: (context, i) {
									final o = orders[i];
									return ListTile(
										title: Text('Order ${o.id.substring(0, 6)} • ${o.category.name}'),
										subtitle: Text('Status: ${o.status.name}'),
										trailing: Wrap(spacing: 8, children: _actionsFor(o, _service)),
									);
								},
							);
						},
					),
					// Listener overlay
					StreamBuilder<List<Order>>(
						stream: _pendingStream,
						builder: (context, snapshot) {
							if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
							final pending = snapshot.data!;
							final latest = pending.first;
							WidgetsBinding.instance.addPostFrameCallback((_) {
								showDialog(
									context: context,
									builder: (_) => AlertDialog(
										title: const Text('New order request'),
										content: Text('Order ${latest.id.substring(0, 6)} • ${latest.category.name}'),
										actions: [
											TextButton(onPressed: () => Navigator.pop(context), child: const Text('Later')),
											FilledButton(onPressed: () { _service.updateStatus(orderId: latest.id, status: OrderStatus.accepted); Navigator.pop(context); }, child: const Text('Accept')),
											TextButton(onPressed: () { _service.updateStatus(orderId: latest.id, status: OrderStatus.rejected); Navigator.pop(context); }, child: const Text('Decline')),
										],
									),
								);
							});
							return const SizedBox.shrink();
						},
					),
				],
			),
		);
	}

	List<Widget> _actionsFor(Order o, OrderService service) {
		switch (o.category) {
			case OrderCategory.food:
				return _foodActions(o, service);
			case OrderCategory.groceries:
				return _groceryActions(o, service);
			default:
				return _commonActions(o, service);
		}
	}

	List<Widget> _foodActions(Order o, OrderService s) {
		return [
			if (o.status == OrderStatus.preparing)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: OrderStatus.dispatched), child: const Text('Dispatch')),
			if (o.status == OrderStatus.dispatched)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: OrderStatus.assigned), child: const Text('Assign courier')),
			if (o.status == OrderStatus.assigned)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: OrderStatus.enroute), child: const Text('Enroute')),
			if (o.status == OrderStatus.enroute)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: OrderStatus.delivered), child: const Text('Delivered')),
		];
	}

	List<Widget> _groceryActions(Order o, OrderService s) {
		return [
			if (o.status == OrderStatus.preparing)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: OrderStatus.sorting), child: const Text('Sorting')),
			if (o.status == OrderStatus.sorting)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: OrderStatus.dispatched), child: const Text('Dispatch')),
			..._foodActions(o, s),
		];
	}

	List<Widget> _commonActions(Order o, OrderService s) {
		return [
			if (o.status == OrderStatus.pending)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: OrderStatus.accepted), child: const Text('Accept')),
			if (o.status == OrderStatus.pending)
				TextButton(onPressed: () => s.updateStatus(orderId: o.id, status: OrderStatus.rejected), child: const Text('Reject')),
		];
	}
}