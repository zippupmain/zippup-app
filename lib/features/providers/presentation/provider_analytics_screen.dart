import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProviderAnalyticsScreen extends StatelessWidget {
	const ProviderAnalyticsScreen({super.key});
	@override
	Widget build(BuildContext context) {
		final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
		return Scaffold(
			appBar: AppBar(title: const Text('Analytics')),
			body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
				future: FirebaseFirestore.instance.collection('orders').where('providerId', isEqualTo: uid).get(const GetOptions(source: Source.server)),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final docs = snap.data!.docs;
					double earnings = 0;
					int completed = 0;
					for (final d in docs) {
						final status = (d.data()['status'] ?? '').toString();
						if (status == 'completed' || status == 'delivered') {
							completed++;
							earnings += (d.data()['price'] as num?)?.toDouble() ?? 0;
						}
					}
					return Padding(
						padding: const EdgeInsets.all(16),
						child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
							Text('Completed: $completed', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
							const SizedBox(height: 8),
							Text('Earnings: ${earnings.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
						]),
					);
				},
			),
		);
	}
}

