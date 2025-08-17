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

	final Map<String, List<String>> _examples = const {
		'home': ['Cleaning', 'Plumbing', 'Electrician', 'Painting', 'Carpentry', 'Pest control'],
		'tech': ['Phone repair', 'Computer repair', 'Networking', 'CCTV install', 'Data recovery'],
		'construction': ['Builders', 'Roofing', 'Tiling', 'Welding', 'Scaffolding'],
		'auto': ['Mechanic', 'Tyre replacement', 'Battery jumpstart', 'Fuel delivery'],
		'personal': ['Nails', 'Hair', 'Massage', 'Pedicure', 'Manicure', 'Makeups'],
	};

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Hire'), backgroundColor: Colors.white, foregroundColor: Colors.black),
			backgroundColor: Colors.white,
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
							ChoiceChip(label: const Text('Personal'), selected: _filter == 'personal', onSelected: (_) => setState(() => _filter = 'personal')),
						]),
					),
					Padding(
						padding: const EdgeInsets.symmetric(horizontal: 16.0),
						child: Align(
							alignment: Alignment.centerLeft,
							child: Text(
								'Examples: ${( _examples[_filter] ?? const <String>[] ).join(', ')}',
								style: const TextStyle(fontSize: 12, color: Colors.black54),
							),
						),
					),
					Expanded(
						child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
							stream: FirebaseFirestore.instance.collection('providers').where('category', isEqualTo: _filter).snapshots(),
							builder: (context, snap) {
								if (!snap.hasData) return const Center(child: CircularProgressIndicator());
								final docs = snap.data!.docs;
								if (docs.isEmpty) return const Center(child: Text('No providers found', style: TextStyle(color: Colors.black)));
								return ListView.separated(
									itemCount: docs.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, i) {
										final p = docs[i].data();
										final pid = docs[i].id;
										return ListTile(
											title: Text(p['name'] ?? 'Provider', style: const TextStyle(color: Colors.black)),
											subtitle: Text('Rating: ${(p['rating'] ?? 0).toString()} • Fee: ₦${(p['fee'] ?? 0).toString()}', style: const TextStyle(color: Colors.black54)),
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