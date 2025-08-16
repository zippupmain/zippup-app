import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/order.dart';

class MyBookingsScreen extends StatelessWidget {
	const MyBookingsScreen({super.key});

	Stream<List<Order>> _orders() {
		final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
		return FirebaseFirestore.instance
			.collection('orders')
			.where('buyerId', isEqualTo: uid)
			.orderBy('createdAt', descending: true)
			.snapshots()
			.map((snap) => snap.docs.map((d) => Order.fromJson(d.id, d.data())).toList());
	}

	bool _canCancel(Order o) {
		if (o.category == OrderCategory.food || o.category == OrderCategory.groceries) {
			return o.status.index < OrderStatus.dispatched.index;
		}
		return o.status.index < OrderStatus.enroute.index;
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('My Bookings')),
			body: StreamBuilder<List<Order>>(
				stream: _orders(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final orders = snap.data!;
					if (orders.isEmpty) return const Center(child: Text('No bookings yet'));
					return ListView.separated(
						itemCount: orders.length,
						separatorBuilder: (_, __) => const Divider(height: 1),
						itemBuilder: (context, i) {
							final o = orders[i];
							return ListTile(
								title: Text('${o.category.name} • ${o.status.name}'),
								subtitle: Text(o.id),
								trailing: Wrap(spacing: 8, children: [
									TextButton(onPressed: () => context.pushNamed('trackOrder', queryParameters: {'orderId': o.id}), child: const Text('Track')),
									if (_canCancel(o)) TextButton(onPressed: () => _cancel(context, o.id), child: const Text('Cancel')),
									IconButton(onPressed: () => context.pushNamed('chat', pathParameters: {'threadId': 'order_${o.id}'}, queryParameters: {'title': 'Order Chat'}), icon: const Icon(Icons.chat_bubble_outline)),
								]),
							);
						},
					);
				},
			),
		);
	}

	Future<void> _cancel(BuildContext context, String orderId) async {
		await FirebaseFirestore.instance.collection('orders').doc(orderId).update({'status': 'cancelled'});
		if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancelled')));
	}
}