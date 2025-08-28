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
		if (mounted) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted. We will get back to you.')));
			Navigator.pop(context);
		}
	}

	Future<void> _call() async {
		if (_supportNumber.isEmpty) return;
		final uri = Uri(scheme: 'tel', path: _supportNumber);
		final ok = await launchUrl(uri);
		if (!ok && mounted) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open dialer')));
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Help & Support')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					const Text('Suggested questions'),
					const SizedBox(height: 8),
					Card(child: ExpansionTile(title: const Text('How do I track my booking?'), children: const [Padding(padding: EdgeInsets.all(12), child: Text('Go to Profile > My Bookings, open a booking, then tap Track.'))])),
					Card(child: ExpansionTile(title: const Text('How do I reset my password?'), children: const [Padding(padding: EdgeInsets.all(12), child: Text('Open Profile > Manage account or use “Forgot password” on sign-in.'))])),
					Card(child: ExpansionTile(title: const Text('How do I change language?'), children: const [Padding(padding: EdgeInsets.all(12), child: Text('Profile > Languages. Pick your language and the app updates.'))])),
					const SizedBox(height: 12),
					const Text("Aren't satisfied with the answers?"),
					TextButton(onPressed: () {}, child: const Text('Contact support…')),
					const Divider(),
					TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
					TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone number')),
					TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
					TextField(controller: _reason, decoration: const InputDecoration(labelText: 'Reason'), maxLines: 3),
					TextField(controller: _reportUserId, decoration: const InputDecoration(labelText: 'Report user ID (optional)')),
					const SizedBox(height: 12),
					FilledButton(onPressed: _submit, child: const Text('Submit')),
					const SizedBox(height: 12),
					OutlinedButton.icon(onPressed: _call, icon: const Icon(Icons.call), label: Text(_supportNumber.isEmpty ? 'Call support' : 'Call support: $_supportNumber')),
				],
			),
		);
	}
}