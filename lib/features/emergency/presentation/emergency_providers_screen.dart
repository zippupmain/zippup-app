import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:zippup/features/profile/presentation/provider_profile_screen.dart';

class EmergencyProvidersScreen extends StatefulWidget {
	const EmergencyProvidersScreen({super.key, required this.type});
	final String type; // ambulance | fire | security | towing
	@override
	State<EmergencyProvidersScreen> createState() => _EmergencyProvidersScreenState();
}

class _EmergencyProvidersScreenState extends State<EmergencyProvidersScreen> {
	final _qController = TextEditingController();
	String _q = '';
	String get _title => switch (widget.type) {
		'ambulance' => 'Ambulance',
		'fire' => 'Fire Service',
		'security' => 'Security',
		'towing' => 'Towing',
		_ => 'Emergency'
	};

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: Text(_title),
				bottom: PreferredSize(
					preferredSize: const Size.fromHeight(56),
					child: Padding(
						padding: const EdgeInsets.all(8.0),
						child: TextField(
							controller: _qController,
							decoration: const InputDecoration(
								labelText: 'Search providers',
								prefixIcon: Icon(Icons.search),
								border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12))),
								filled: true,
							),
							onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
						),
					),
				),
			),
			body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('providers').where('category', isEqualTo: widget.type).snapshots(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final docs = snap.data!.docs.where((d) {
						if (_q.isEmpty) return true;
						final name = (d.data()['name'] ?? '').toString().toLowerCase();
						final title = (d.data()['title'] ?? '').toString().toLowerCase();
						return name.contains(_q) || title.contains(_q);
					}).toList();
					if (docs.isEmpty) return Center(child: Text('No ${_title.toLowerCase()} providers found'));
					return ListView.separated(
						itemCount: docs.length,
						separatorBuilder: (_, __) => const Divider(height: 1),
						itemBuilder: (context, i) {
							final p = docs[i].data();
							final pid = docs[i].id;
							return ListTile(
								title: Text(p['name'] ?? 'Provider'),
								subtitle: Text(p['title']?.toString() ?? ''),
								trailing: FilledButton(
									onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProviderProfileScreen(providerId: pid))),
									child: const Text('View'),
								),
							);
						},
					);
				},
			),
		);
	}
}