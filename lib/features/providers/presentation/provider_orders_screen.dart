import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProviderOrdersScreen extends StatelessWidget {
	const ProviderOrdersScreen({super.key});
	@override
	Widget build(BuildContext context) {
		final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
		return Scaffold(
			appBar: AppBar(title: const Text('Orders'), actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.maybePop(context))]),
			body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('orders').where('providerId', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final docs = snap.data!.docs;
					if (docs.isEmpty) return const Center(child: Text('No orders yet'));
					return ListView.separated(
						itemCount: docs.length,
						separatorBuilder: (_, __) => const Divider(height: 1),
						itemBuilder: (context, i) {
							final d = docs[i].data();
							return ListTile(
								title: Text(d['type']?.toString() ?? 'order'),
								subtitle: Text('Status: ${d['status'] ?? ''} • ${d['createdAt'] ?? ''}'),
								trailing: Text((d['price'] ?? '').toString()),
							);
						},
					);
				},
			),
		);
	}
}

