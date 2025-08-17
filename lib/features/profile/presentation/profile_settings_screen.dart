import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileSettingsScreen extends StatefulWidget {
	const ProfileSettingsScreen({super.key});
	@override
	State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
	final _name = TextEditingController();
	final _phone = TextEditingController();
	String? _photoUrl;
	bool _saving = false;

	@override
	void initState() {
		super.initState();
		final u = FirebaseAuth.instance.currentUser;
		_name.text = u?.displayName ?? '';
		_phone.text = u?.phoneNumber ?? '';
		_photoUrl = u?.photoURL;
	}

	Future<void> _save() async {
		setState(() => _saving = true);
		try {
			final u = FirebaseAuth.instance.currentUser;
			if (u == null) return;
			await u.updateDisplayName(_name.text.trim());
			await FirebaseFirestore.instance.collection('users').doc(u.uid).set({'name': _name.text.trim(), 'phone': _phone.text.trim(), 'photoUrl': _photoUrl}, SetOptions(merge: true));
			if (context.mounted) Navigator.pop(context);
		} finally {
			setState(() => _saving = false);
		}
	}

	Future<void> _deleteAccount() async {
		final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Delete account'), content: const Text('This cannot be undone.'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))]));
		if (ok != true) return;
		final u = FirebaseAuth.instance.currentUser;
		await FirebaseFirestore.instance.collection('users').doc(u!.uid).delete().catchError((_){});
		await u.delete();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Profile settings')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					CircleAvatar(radius: 36, backgroundImage: _photoUrl != null ? NetworkImage(_photoUrl!) : null, child: _photoUrl == null ? const Icon(Icons.person) : null),
					const SizedBox(height: 8),
					TextField(controller: _name, decoration: const InputDecoration(labelText: 'Public name')),
					TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone number')),
					const SizedBox(height: 12),
					FilledButton(onPressed: _saving ? null : _save, child: const Text('Save')),
					const SizedBox(height: 24),
					TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), onPressed: _deleteAccount, child: const Text('Delete account')),
				],
			),
		);
	}
}