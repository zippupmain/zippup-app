import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ManageAccountsScreen extends StatefulWidget {
	const ManageAccountsScreen({super.key});
	@override
	State<ManageAccountsScreen> createState() => _ManageAccountsScreenState();
}

class _ManageAccountsScreenState extends State<ManageAccountsScreen> {
	late final String _uid;
	String? _activeId;
	final _name = TextEditingController();
	final _type = TextEditingController();

	@override
	void initState() {
		super.initState();
		_uid = FirebaseAuth.instance.currentUser!.uid;
		_loadActive();
	}

	Future<void> _loadActive() async {
		final user = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
		setState(() => _activeId = user.data()?['activeProfileId']?.toString());
	}

	Stream<QuerySnapshot<Map<String, dynamic>>> _profiles() {
		return FirebaseFirestore.instance.collection('users').doc(_uid).collection('profiles').snapshots();
	}

	Future<void> _addProfile() async {
		await FirebaseFirestore.instance.collection('users').doc(_uid).collection('profiles').add({
			'displayName': _name.text.trim(),
			'type': _type.text.trim(),
			'createdAt': DateTime.now().toIso8601String(),
		});
		_name.clear(); _type.clear();
		if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile added')));
	}

	Future<void> _setActive(String id) async {
		await FirebaseFirestore.instance.collection('users').doc(_uid).set({'activeProfileId': id}, SetOptions(merge: true));
		setState(() => _activeId = id);
		if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Switched profile')));
	}

	Future<void> _delete(String id) async {
		await FirebaseFirestore.instance.collection('users').doc(_uid).collection('profiles').doc(id).delete();
		if (_activeId == id) await _setActive('');
		if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Manage accounts')),
			body: Column(children: [
				Padding(
					padding: const EdgeInsets.all(16),
					child: Row(children: [
						Expanded(child: TextField(controller: _name, decoration: const InputDecoration(labelText: 'Profile name'))),
						const SizedBox(width: 8),
						Expanded(child: TextField(controller: _type, decoration: const InputDecoration(labelText: 'Profile type'))),
						const SizedBox(width: 8),
						FilledButton(onPressed: _addProfile, child: const Text('Add')),
					]),
				),
				Expanded(
					child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
						stream: _profiles(),
						builder: (context, snap) {
							if (!snap.hasData) return const Center(child: CircularProgressIndicator());
							final docs = snap.data!.docs;
							if (docs.isEmpty) return const Center(child: Text('No additional profiles'));
							return ListView.separated(
								itemCount: docs.length,
								separatorBuilder: (_, __) => const Divider(height: 1),
								itemBuilder: (context, i) {
									final d = docs[i];
									final data = d.data();
									final isActive = _activeId == d.id;
									return ListTile(
										title: Text(data['displayName']?.toString() ?? 'Profile'),
										subtitle: Text(data['type']?.toString() ?? ''),
										trailing: Wrap(spacing: 8, children: [
											if (!isActive) TextButton(onPressed: () => _setActive(d.id), child: const Text('Switch')),
											TextButton(onPressed: () => _delete(d.id), child: const Text('Delete', style: TextStyle(color: Colors.red))),
										]),
										leading: isActive ? const Icon(Icons.check_circle, color: Colors.green) : const SizedBox.shrink(),
									);
								},
							);
						},
					),
				),
			]),
		);
	}
}