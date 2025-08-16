import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zippup/common/models/order.dart';
import 'package:zippup/features/food/providers/order_service.dart';

class TrackOrderScreen extends StatelessWidget {
	const TrackOrderScreen({super.key, required this.orderId});
	final String orderId;

	bool _isProviderOwner(Map<String, dynamic> data) {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		return uid != null && (uid == data['providerId'] || uid == data['deliveryId']);
	}

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
								const Spacer(),
								if (_isProviderOwner(data) && order.status == OrderStatus.enroute) FilledButton(onPressed: () => OrderService().updateStatus(orderId: orderId, status: OrderStatus.arrived), child: const Text('Mark arrived')),
								if (_isProviderOwner(data) && order.status == OrderStatus.arrived)
									FilledButton(
										onPressed: () async {
											final code = await _promptCode(context);
											if (code == null) return;
											await OrderService().updateStatus(orderId: orderId, status: OrderStatus.delivered, extra: {'deliveryCodeEntered': code});
										},
										child: const Text('Complete delivery')),
							],
						),
					);
				},
			),
		);
	}

	Future<String?> _promptCode(BuildContext context) async {
		final controller = TextEditingController();
		return showDialog<String>(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('Enter delivery code'),
				content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '6-digit code')),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
					FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Submit')),
				],
			),
		);
	}
}