import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PlatformAdminScreen extends StatefulWidget {
	const PlatformAdminScreen({super.key});
	@override
	State<PlatformAdminScreen> createState() => _PlatformAdminScreenState();
}

class _PlatformAdminScreenState extends State<PlatformAdminScreen> {
	bool? _isAdmin;
	int _adminsCount = 0;
	bool _loading = true;

	@override
	void initState() {
		super.initState();
		_init();
	}

	Future<void> _init() async {
		final uid = FirebaseAuth.instance.currentUser!.uid;
		final admins = await FirebaseFirestore.instance.collection('_config').doc('admins').collection('users').get();
		final me = admins.docs.where((d) => d.id == uid).isNotEmpty;
		setState(() {
			_isAdmin = me;
			_adminsCount = admins.size;
			_loading = false;
		});
	}

	Future<void> _claimAdmin() async {
		final uid = FirebaseAuth.instance.currentUser!.uid;
		await FirebaseFirestore.instance.collection('_config').doc('admins').collection('users').doc(uid).set({
			'role': 'owner',
			'createdAt': DateTime.now().toIso8601String(),
		});
		if (mounted) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin role granted')));
			await _init();
		}
	}

	@override
	Widget build(BuildContext context) {
		if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
		if (_adminsCount == 0 && _isAdmin != true) {
			return Scaffold(
				appBar: AppBar(title: const Text('Platform Admin')),
				body: Center(child: FilledButton(onPressed: _claimAdmin, child: const Text('Claim platform admin'))),
			);
		}
		if (_isAdmin != true) {
			return Scaffold(
				appBar: AppBar(title: const Text('Platform Admin')),
				body: const Center(child: Text('Access denied. Contact a platform admin.')),
			);
		}
		return Scaffold(
			appBar: AppBar(title: const Text('Platform Admin')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					ListTile(
						leading: const Icon(Icons.verified_user),
						title: const Text('Provider applications'),
						onTap: () => context.push('/admin/applications'),
					),
					ListTile(
						leading: const Icon(Icons.card_giftcard),
						title: const Text('Promos & vouchers'),
						onTap: () => context.push('/admin/promos'),
					),
					ListTile(
						leading: const Icon(Icons.emergency_share),
						title: const Text('Emergency default lines'),
						onTap: () => context.push('/admin/emergency-config'),
					),
					const Divider(),
					ListTile(
						leading: const Icon(Icons.people),
						title: const Text('Users'),
						onTap: () {},
					),
					ListTile(
						leading: const Icon(Icons.store_mall_directory),
						title: const Text('Providers/Vendors'),
						onTap: () {},
					),
				],
			),
		);
	}
}