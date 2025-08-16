import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:zippup/common/models/order.dart';

class TrackOrderScreen extends StatelessWidget {
	const TrackOrderScreen({super.key, required this.orderId});
	final String orderId;

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Track Order')),
			body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('orders').doc(orderId).snapshots(),
				builder: (context, snapshot) {
					if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
					final data = snapshot.data!.data() ?? {};
					final order = Order.fromJson(orderId, data);
					return Padding(
						padding: const EdgeInsets.all(16),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text('Order ${order.id.substring(0,6)}'),
								const SizedBox(height: 8),
								Text('Category: ${order.category.name}'),
								const SizedBox(height: 8),
								Text('Status: ${order.status.name.toUpperCase()}'),
								if (order.estimatedPreparedAt != null) ...[
									const SizedBox(height: 8),
									Text('Estimated ready: ${order.estimatedPreparedAt}')
								],
							],
						),
					);
				},
			),
		);
	}
}