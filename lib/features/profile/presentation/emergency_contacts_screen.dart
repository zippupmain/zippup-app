import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmergencyContactsScreen extends StatefulWidget {
	const EmergencyContactsScreen({super.key});
	@override
	State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
	final _newNumber = TextEditingController();
	bool _saving = false;
	late final String _uid;

	@override
	void initState() {
		super.initState();
		_uid = FirebaseAuth.instance.currentUser!.uid;
	}

	Stream<DocumentSnapshot<Map<String, dynamic>>> _userStream() {
		return FirebaseFirestore.instance.collection('users').doc(_uid).snapshots();
	}

	Future<void> _add(List contacts) async {
		final number = _newNumber.text.trim();
		if (number.isEmpty) return;
		if (contacts.length >= 5) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 5 contacts')));
			return;
		}
		setState(() => _saving = true);
		try {
			final updated = [...contacts.map((e) => e.toString()), number];
			await FirebaseFirestore.instance.collection('users').doc(_uid).set({'emergencyContacts': updated}, SetOptions(merge: true));
			_newNumber.clear();
		} finally {
			if (mounted) setState(() => _saving = false);
		}
	}

	Future<void> _remove(List contacts, int index) async {
		final updated = [...contacts]..removeAt(index);
		await FirebaseFirestore.instance.collection('users').doc(_uid).set({'emergencyContacts': updated}, SetOptions(merge: true));
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Emergency contacts')),
			body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
				stream: _userStream(),
				builder: (context, snap) {
					final data = snap.data?.data() ?? const {};
					final contacts = (data['emergencyContacts'] as List?) ?? const [];
					return Column(children: [
						Padding(
							padding: const EdgeInsets.all(16),
							child: Row(children: [
								Expanded(child: TextField(controller: _newNumber, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number'))),
								const SizedBox(width: 8),
								FilledButton(onPressed: _saving ? null : () async { await _add(contacts); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added'))); }, child: const Text('Add')),
							]),
						),
						Expanded(
							child: ListView.separated(
								itemCount: contacts.length,
								separatorBuilder: (_, __) => const Divider(height: 1),
								itemBuilder: (context, i) => ListTile(
									title: Text(contacts[i].toString()),
									trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () async { await _remove(contacts, i); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed'))); }),
								),
							),
						),
					]);
				},
			),
		);
	}
}