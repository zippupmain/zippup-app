import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatefulWidget {
	const SupportScreen({super.key});
	@override
	State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
	final _name = TextEditingController();
	final _phone = TextEditingController();
	final _email = TextEditingController();
	final _reason = TextEditingController();
	final _reportUserId = TextEditingController();
	String _supportNumber = '';

	@override
	void initState() {
		super.initState();
		_loadSupportNumber();
	}

	Future<void> _loadSupportNumber() async {
		final doc = await FirebaseFirestore.instance.collection('_config').doc('support').get();
		setState(() => _supportNumber = (doc.data() ?? const {})['phone']?.toString() ?? '');
	}

	Future<void> _submit() async {
		await FirebaseFirestore.instance.collection('support_tickets').add({
			'name': _name.text.trim(),
			'phone': _phone.text.trim(),
			'email': _email.text.trim(),
			'reason': _reason.text.trim(),
			'reporterId': FirebaseAuth.instance.currentUser?.uid,
			'reportedUserId': _reportUserId.text.trim(),
			'createdAt': DateTime.now().toIso8601String(),
		});
		if (mounted) Navigator.pop(context);
	}

	Future<void> _call() async {
		if (_supportNumber.isEmpty) return;
		final uri = Uri(scheme: 'tel', path: _supportNumber);
		await launchUrl(uri);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Help & Support')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					const Text('Suggested help'),
					const ListTile(title: Text('How to track my order?')),
					const ListTile(title: Text('How to reset password?')),
					const Divider(),
					TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
					TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone number')),
					TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
					TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 3),
					TextField(controller: _reportUserId, decoration: const InputDecoration(labelText: 'Report user ID (optional)')),
					const SizedBox(height: 12),
					FilledButton(onPressed: _submit, child: const Text('Submit')),
					const SizedBox(height: 24),
					if (_supportNumber.isNotEmpty) OutlinedButton.icon(onPressed: _call, icon: const Icon(Icons.call), label: Text('Call support: $_supportNumber')),
				],
			),
		);
	}
}