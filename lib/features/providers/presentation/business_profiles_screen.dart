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
					if (docs.isEmpty) {
						return Center(
							child: Padding(
								padding: const EdgeInsets.all(24),
								child: Column(mainAxisSize: MainAxisSize.min, children: [
									const Text('No business profiles yet'),
									const SizedBox(height: 12),
									FilledButton.icon(onPressed: () => context.push('/providers/create'), icon: const Icon(Icons.add_business), label: const Text('Create business profile')),
								]),
							),
						);
					}
					return ListView(
						children: [
							Padding(
								padding: const EdgeInsets.all(16),
								child: FilledButton.icon(onPressed: () => context.push('/providers/create'), icon: const Icon(Icons.add_business), label: const Text('Create business profile')),
							),
							...docs.map((d) {
								final p = d.data();
								return ListTile(
									title: Text(p['title']?.toString() ?? 'Untitled'),
									subtitle: Text('${p['category'] ?? ''} • ${p['subcategory'] ?? ''} • ${p['type'] ?? 'individual'} • ${p['status'] ?? 'draft'}'),
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

