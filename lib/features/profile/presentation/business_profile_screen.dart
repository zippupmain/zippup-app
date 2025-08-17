import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BusinessProfileScreen extends StatelessWidget {
	const BusinessProfileScreen({super.key});
	@override
	Widget build(BuildContext context) {
		final uid = FirebaseAuth.instance.currentUser!.uid;
		return Scaffold(
			appBar: AppBar(title: const Text('Business profile')),
			body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('providers').where('ownerId', isEqualTo: uid).snapshots(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final docs = snap.data!.docs;
					if (docs.isEmpty) return const Center(child: Text('No business found'));
					return ListView.separated(
						itemCount: docs.length,
						separatorBuilder: (_, __) => const Divider(height: 1),
						itemBuilder: (context, i) {
							final d = docs[i].data();
							return ListTile(title: Text(d['name'] ?? 'Business'), subtitle: Text(d['category'] ?? ''));
						},
					);
				},
			),
		);
	}
}