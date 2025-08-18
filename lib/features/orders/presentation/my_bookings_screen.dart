import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/order.dart';
import 'package:zippup/features/food/providers/order_service.dart';

class MyBookingsScreen extends StatelessWidget {
	const MyBookingsScreen({super.key});

  bool _isInstant(Order o) {
    // Instant categories navigate to live map immediately on acceptance
    return o.category != OrderCategory.tickets && o.category != OrderCategory.events && o.category != OrderCategory.tutors;
  }

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
			body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('orders').where('buyerId', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? 'self').snapshots(),
				builder: (context, snap) {
					if (snap.hasError) return Center(child: Text('Error loading bookings: ${snap.error}'));
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final docs = snap.data!.docs;
					if (docs.isEmpty) return const Center(child: Text('No bookings'));
					final orders = docs.map((d) => Order.fromJson(d.id, d.data())).toList();
					// Auto-navigate to live tracking when an instant order moves to accepted/assigned/enroute
					for (final o in orders) {
						if (_isInstant(o) && (o.status == OrderStatus.accepted || o.status == OrderStatus.assigned || o.status == OrderStatus.enroute)) {
							WidgetsBinding.instance.addPostFrameCallback((_) {
								if (context.mounted) context.pushNamed('trackOrder', queryParameters: {'orderId': o.id});
							});
							break;
						}
					}
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
									if (_canCancel(o)) TextButton(onPressed: () => _promptCancel(context, o), child: const Text('Cancel')),
									IconButton(onPressed: () => context.pushNamed('chat', pathParameters: {'threadId': 'order_${o.id}'}, queryParameters: {'title': 'Order Chat'}), icon: const Icon(Icons.chat_bubble_outline)),
								]),
							);
						},
					);
				},
			),
		);
	}

	Future<void> _promptCancel(BuildContext context, Order o) async {
		final reasons = <String>[
			'Change of plans',
			'Found cheaper elsewhere',
			'Booked by mistake',
			'Provider taking too long',
			'Other',
		];
		String? selected = reasons.first;
		final controller = TextEditingController();
		final confirmed = await showDialog<bool>(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('Cancel booking'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						DropdownButtonFormField<String>(
							value: selected,
							items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
							onChanged: (v) => selected = v,
							decoration: const InputDecoration(labelText: 'Reason'),
						),
						TextField(
							controller: controller,
							maxLines: 3,
							decoration: const InputDecoration(labelText: 'Details (optional)'),
						),
					],
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
					FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel booking')),
				],
			),
		);
		if (confirmed != true) return;
		final reason = selected == 'Other' && controller.text.trim().isNotEmpty ? controller.text.trim() : selected ?? 'Cancelled';
		await OrderService().cancel(orderId: o.id, reason: reason, cancelledBy: FirebaseAuth.instance.currentUser?.uid ?? 'buyer');
		if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled')));
	}
}