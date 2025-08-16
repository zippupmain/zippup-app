import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zippup/common/models/order.dart';

class OrderService {
	final FirebaseFirestore _db = FirebaseFirestore.instance;
	final FirebaseAuth _auth = FirebaseAuth.instance;

	Future<String> createOrder({required OrderCategory category, required String providerId}) async {
		final now = DateTime.now();
		final isTransport = category == OrderCategory.transport;
		final estimated = isTransport ? null : now.add(const Duration(minutes: 10));
		final ref = await _db.collection('orders').add({
			'buyerId': _auth.currentUser?.uid ?? 'anonymous',
			'providerId': providerId,
			'category': category.name,
			'status': isTransport ? OrderStatus.pending.name : OrderStatus.preparing.name,
			'createdAt': now.toIso8601String(),
			'estimatedPreparedAt': estimated?.toIso8601String(),
		});
		return ref.id;
	}

	Future<void> updateStatus({required String orderId, required OrderStatus status, String? deliveryId, String? deliveryCode, Map<String, dynamic>? extra}) async {
		final data = {
			'status': status.name,
			'deliveryId': deliveryId,
			'deliveryCode': deliveryCode,
			...?(extra ?? {}),
		};
		await _db.collection('orders').doc(orderId).update(data);
	}

	Stream<Order> watchOrder(String orderId) {
		return _db.collection('orders').doc(orderId).snapshots().map((doc) {
			final data = doc.data() ?? {};
			return Order.fromJson(doc.id, data);
		});
	}
}