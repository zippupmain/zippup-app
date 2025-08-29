import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zippup/common/models/order.dart';

class OrderService {
	final FirebaseFirestore _db = FirebaseFirestore.instance;
	final FirebaseAuth _auth = FirebaseAuth.instance;

	Future<String> createOrder({required OrderCategory category, required String providerId, Map<String, dynamic>? extra}) async {
		final now = DateTime.now();
		final isTransport = category == OrderCategory.transport;
		final estimated = isTransport ? null : now.add(const Duration(minutes: 10));
		final data = {
			'buyerId': _auth.currentUser?.uid ?? 'anonymous',
			'providerId': providerId,
			'category': category.name,
			'status': isTransport ? OrderStatus.pending.name : OrderStatus.preparing.name,
			'createdAt': now.toIso8601String(),
			'estimatedPreparedAt': estimated?.toIso8601String(),
			if (category == OrderCategory.food || category == OrderCategory.groceries) ...{
				'price': (extra != null && extra['price'] != null) ? extra['price'] : 0,
				'deliveryFee': (extra != null && extra['deliveryFee'] != null) ? extra['deliveryFee'] : null,
				'platformFee': (extra != null && extra['platformFee'] != null) ? extra['platformFee'] : null,
			},
			...?(extra ?? {}),
		};
		final ref = await _db.collection('orders').add(data);
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

	Future<void> cancel({required String orderId, required String reason, String? cancelledBy}) async {
		await _db.collection('orders').doc(orderId).set({
			'status': OrderStatus.cancelled.name,
			'cancelReason': reason,
			'cancelledBy': cancelledBy ?? _auth.currentUser?.uid ?? 'buyer',
			'cancelledAt': FieldValue.serverTimestamp(),
		}, SetOptions(merge: true));
	}
}