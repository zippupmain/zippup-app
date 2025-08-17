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
	bool _approved = false;

	@override
	void initState() {
		super.initState();
		_loadProviderState();
	}

	Future<void> _loadProviderState() async {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		if (uid == null) return;
		final vendor = await FirebaseFirestore.instance.collection('vendors').doc(uid).get();
		if (vendor.exists) {
			setState(() {
				_isProvider = true;
				_available = vendor.get('available') == true;
				_approved = true;
			});
		}
	}

	Future<void> _toggleAvailable(bool v) async {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		if (uid == null) return;
		await FirebaseFirestore.instance.collection('vendors').doc(uid).set({'available': v}, SetOptions(merge: true));
		setState(() => _available = v);
	}

	void _comingSoon(String title) {
		ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title is coming soon')));
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
					ListTile(leading: const Icon(Icons.person), title: const Text('Profile settings'), onTap: () => context.push('/profile/settings')),
					ListTile(leading: const Icon(Icons.assignment_outlined), title: const Text('My Bookings'), onTap: () => context.push('/bookings')),
					ListTile(leading: const Icon(Icons.verified_user), title: const Text('Apply as Service Provider / Vendor'), onTap: () => context.push('/profile/apply-provider')),
					if (_approved) ListTile(leading: const Icon(Icons.admin_panel_settings), title: const Text('Admin'), onTap: () => context.push('/admin/dashboard')),
					ListTile(leading: const Icon(Icons.account_balance_wallet), title: const Text('Wallet'), onTap: () => _comingSoon('Wallet')),
					ListTile(leading: const Icon(Icons.local_activity), title: const Text('Promo & vouchers'), onTap: () => _comingSoon('Promos')),
					ListTile(leading: const Icon(Icons.language), title: const Text('Languages'), onTap: () => _comingSoon('Languages')),
					ListTile(leading: const Icon(Icons.business), title: const Text('Business profile'), onTap: () => _comingSoon('Business profile')),
					ListTile(leading: const Icon(Icons.help_outline), title: const Text('Help / Report'), onTap: () => _comingSoon('Help & Report')),
					ListTile(leading: const Icon(Icons.manage_accounts), title: const Text('Manage account'), onTap: () => _comingSoon('Manage account')),
					ListTile(leading: const Icon(Icons.star_rate), title: const Text('Rate ZippUp'), onTap: () => _comingSoon('Rate ZippUp')),
					ListTile(leading: const Icon(Icons.privacy_tip), title: const Text('Privacy & policy'), onTap: () => _comingSoon('Privacy & policy')),
					ListTile(leading: const Icon(Icons.rule), title: const Text('Terms of service'), onTap: () => _comingSoon('Terms of service')),
					const Divider(),
					ListTile(leading: const Icon(Icons.logout), title: const Text('Logout'), onTap: () async { await FirebaseAuth.instance.signOut(); if (context.mounted) context.go('/'); }),
				],
			),
		);
	}
}