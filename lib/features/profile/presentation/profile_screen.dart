import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends StatefulWidget {
	const ProfileScreen({super.key});
	@override
	State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
	bool _isProvider = false;
	bool _available = false;

	@override
	void initState() {
		super.initState();
		_loadProviderState();
	}

	Future<void> _loadProviderState() async {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		if (uid == null) return;
		final doc = await FirebaseFirestore.instance.collection('vendors').doc(uid).get();
		if (!doc.exists) return;
		setState(() {
			_isProvider = true;
			_available = doc.get('available') == true;
		});
	}

	Future<void> _toggleAvailable(bool v) async {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		if (uid == null) return;
		await FirebaseFirestore.instance.collection('vendors').doc(uid).set({'available': v}, SetOptions(merge: true));
		setState(() => _available = v);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Profile'), actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.maybePop(context))]),
			body: ListView(
				children: [
					if (_isProvider)
						SwitchListTile(
							title: const Text('Available'),
							value: _available,
							onChanged: _toggleAvailable,
						),
					ListTile(leading: const Icon(Icons.person), title: const Text('Profile'), onTap: () {}),
					ListTile(leading: const Icon(Icons.account_balance_wallet), title: const Text('Wallet'), onTap: () => context.push('/wallet')),
					ListTile(leading: const Icon(Icons.local_activity), title: const Text('Promo & vouchers'), onTap: () => context.push('/profile/promos')),
					ListTile(leading: const Icon(Icons.language), title: const Text('Languages'), onTap: () => context.push('/profile/languages')),
					ListTile(leading: const Icon(Icons.business), title: const Text('Business profile'), onTap: () => context.push('/profile/business')),
					ListTile(leading: const Icon(Icons.help_outline), title: const Text('Help / Report'), onTap: () => context.push('/profile/help')),
					ListTile(leading: const Icon(Icons.manage_accounts), title: const Text('Manage account'), onTap: () => context.push('/profile/manage')),
					ListTile(leading: const Icon(Icons.star_rate), title: const Text('Rate ZippUp'), onTap: () {}),
					ListTile(leading: const Icon(Icons.privacy_tip), title: const Text('Privacy & policy'), onTap: () => context.push('/profile/privacy')),
					ListTile(leading: const Icon(Icons.rule), title: const Text('Terms of service'), onTap: () => context.push('/profile/terms')),
					const Divider(),
					ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: () async { await FirebaseAuth.instance.signOut(); if (context.mounted) context.go('/'); }),
				],
			),
		);
	}
}