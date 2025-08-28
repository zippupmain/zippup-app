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
	bool _frozen = false;

	@override
	void initState() {
		super.initState();
		_uid = FirebaseAuth.instance.currentUser!.uid;
		_loadActive();
	}

  Future<void> _loadActive() async {
    final user = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    final data = user.data() ?? {};
    setState(() {
      _activeId = data['activeProfileId']?.toString();
      _frozen = data['frozen'] == true;
    });
  }

  Future<void> _setFrozen(bool v) async {
    await FirebaseFirestore.instance.collection('users').doc(_uid).set({'frozen': v, 'frozenAt': v ? DateTime.now().toIso8601String() : null}, SetOptions(merge: true));
    setState(() => _frozen = v);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(v ? 'Account frozen' : 'Account reactivated')));
  }

  Future<void> _reactivateIfWithinWindow() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    final deletedAtStr = (doc.data() ?? const {})['deletedAt']?.toString();
    if (deletedAtStr == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account not deleted'))); return; }
    final deletedAt = DateTime.tryParse(deletedAtStr);
    if (deletedAt == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot parse deletion date'))); return; }
    if (DateTime.now().difference(deletedAt).inDays > 30) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot reactivate after 30 days'))); return; }
    await FirebaseFirestore.instance.collection('users').doc(_uid).set({'deletedAt': null, 'frozen': false}, SetOptions(merge: true));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account reactivated')));
  }

  Future<void> _confirmDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Delete account'),
          content: Column(mainAxisSize: MainAxisSize.min, children: const [Text('If this is not a mistake, type DELETE to confirm.')]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () { if (controller.text.trim().toUpperCase() == 'DELETE') Navigator.pop(c, true); }, child: const Text('Confirm')),
          ],
        );
      },
    );
    if (confirm != true) return;
    await FirebaseFirestore.instance.collection('users').doc(_uid).set({'deletedAt': DateTime.now().toIso8601String()}, SetOptions(merge: true));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account scheduled for deletion')));
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
			appBar: AppBar(title: const Text('Manage account')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					SwitchListTile(title: const Text('Freeze account'), value: _frozen, onChanged: (v) => _setFrozen(v)),
					const Divider(),
					ListTile(title: const Text('Reactivate deleted account'), subtitle: const Text('Within 30 days of deletion'), onTap: _reactivateIfWithinWindow),
					const SizedBox(height: 32),
					const Text('Danger zone', style: TextStyle(color: Colors.red)),
					const SizedBox(height: 8),
					TextButton(style: TextButton.styleFrom(foregroundColor: Colors.red), onPressed: _confirmDeleteAccount, child: const Text('Delete account')),
				],
			),
		);
	}
}