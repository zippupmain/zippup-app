import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zippup/features/profile/presentation/provider_profile_screen.dart';

class HireScreen extends StatefulWidget {
	const HireScreen({super.key});

	@override
	State<HireScreen> createState() => _HireScreenState();
}

class _HireScreenState extends State<HireScreen> {
	String _filter = 'home';

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Hire')),
			body: Column(
				children: [
					SingleChildScrollView(
						scrollDirection: Axis.horizontal,
						padding: const EdgeInsets.all(8),
						child: Wrap(spacing: 8, children: [
							ChoiceChip(label: const Text('Home'), selected: _filter == 'home', onSelected: (_) => setState(() => _filter = 'home')),
							ChoiceChip(label: const Text('Tech'), selected: _filter == 'tech', onSelected: (_) => setState(() => _filter = 'tech')),
							ChoiceChip(label: const Text('Construction'), selected: _filter == 'construction', onSelected: (_) => setState(() => _filter = 'construction')),
							ChoiceChip(label: const Text('Auto'), selected: _filter == 'auto', onSelected: (_) => setState(() => _filter = 'auto')),
						]),
					),
					Expanded(
						child: StreamBuilder<QuerySnapshot<Map<String, dynamic}}>(
							stream: FirebaseFirestore.instance.collection('providers').where('category', isEqualTo: _filter).snapshots(),
							builder: (context, snap) {
								if (!snap.hasData) return const Center(child: CircularProgressIndicator());
								final docs = snap.data!.docs;
								if (docs.isEmpty) return const Center(child: Text('No providers found'));
								return ListView.separated(
									itemCount: docs.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, i) {
										final p = docs[i].data();
										final pid = docs[i].id;
										return ListTile(
											title: Text(p['name'] ?? 'Provider'),
											subtitle: Text('Rating: ${(p['rating'] ?? 0).toString()} • Fee: ₦${(p['fee'] ?? 0).toString()}'),
											trailing: Wrap(spacing: 8, children: [
												TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderProfileScreen(providerId: pid))), child: const Text('Profile')),
												FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderProfileScreen(providerId: pid))), child: const Text('Book')),
											]),
										);
									},
								);
							},
						),
					),
				],
			),
		);
	}
}