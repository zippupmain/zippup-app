import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BusinessProfilesScreen extends StatelessWidget {
	const BusinessProfilesScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
		return Scaffold(
			appBar: AppBar(title: const Text('Business profiles')),
			body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('business_profiles').doc(uid).collection('profiles').snapshots(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final docs = snap.data!.docs;
					return ListView(
						children: [
							Padding(
								padding: const EdgeInsets.all(16),
								child: FilledButton.icon(onPressed: () => context.push('/providers/create'), icon: const Icon(Icons.add), label: const Text('Create profile')),
							),
							...docs.map((d) {
								final p = d.data();
								return ListTile(
									title: Text(p['title']?.toString() ?? 'Untitled'),
									subtitle: Text('${p['category'] ?? ''} • ${p['subcategory'] ?? ''} • ${p['status'] ?? 'draft'}'),
									trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => context.push('/providers/create?profileId=${d.id}')),
								);
							}),
						],
					);
				},
			),
		);
	}
}

