import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PromosScreen extends StatelessWidget {
	const PromosScreen({super.key});
	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Promos & Vouchers')),
			body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('promos').orderBy('createdAt', descending: true).snapshots(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final docs = snap.data!.docs;
					if (docs.isEmpty) {
						return const Center(child: Text('Coming soon'));
					}
					return ListView.separated(
						itemCount: docs.length,
						separatorBuilder: (_, __) => const Divider(height: 1),
						itemBuilder: (context, i) {
							final d = docs[i].data();
							return ListTile(
								title: Text(d['title']?.toString() ?? 'Promo'),
								subtitle: Text(d['description']?.toString() ?? ''),
								trailing: Text(d['code']?.toString() ?? ''),
								onTap: () => Navigator.of(context).pushNamed('/'),
							);
						},
					);
				},
			),
		);
	}
}