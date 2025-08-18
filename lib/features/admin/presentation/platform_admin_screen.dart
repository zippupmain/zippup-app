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
	String? _error;

	@override
	void initState() {
		super.initState();
		_init();
	}

	Future<void> _init() async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) throw Exception('Not signed in');
			final admins = await FirebaseFirestore.instance.collection('_config').doc('admins').collection('users').get();
			final me = admins.docs.any((d) => d.id == uid);
			setState(() {
				_isAdmin = me;
				_adminsCount = admins.size;
				_loading = false;
				_error = null;
			});
		} catch (e) {
			// Fallback: check just my doc; mark adminsCount unknown (-1)
			try {
				final uid = FirebaseAuth.instance.currentUser?.uid;
				final myDoc = await FirebaseFirestore.instance.collection('_config').doc('admins').collection('users').doc(uid).get();
				setState(() {
					_isAdmin = myDoc.exists;
					_adminsCount = -1;
					_loading = false;
					_error = e.toString();
				});
			} catch (_) {
				setState(() {
					_isAdmin = false;
					_adminsCount = -1;
					_loading = false;
					_error = e.toString();
				});
			}
		}
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
		final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
		if ((_adminsCount == 0 || _adminsCount == -1) && _isAdmin != true) {
			return Scaffold(
				appBar: AppBar(title: const Text('Platform Admin')),
				body: Center(
					child: Column(mainAxisSize: MainAxisSize.min, children: [
						if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Note: $_error', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
						Text('Your UID: $uid', style: const TextStyle(fontSize: 12, color: Colors.black54)),
						const SizedBox(height: 12),
						FilledButton(onPressed: _claimAdmin, child: const Text('Claim platform admin')),
					]),
				),
			);
		}
		if (_isAdmin != true) {
			return Scaffold(
				appBar: AppBar(title: const Text('Platform Admin')),
				body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
					if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Error: $_error', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
					Text('Your UID: $uid', style: const TextStyle(fontSize: 12, color: Colors.black54)),
					const SizedBox(height: 12),
					const Text('Access denied. Contact a platform admin.'),
				])),
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
					const Text('Users', style: TextStyle(fontWeight: FontWeight.bold)),
					StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
						stream: FirebaseFirestore.instance.collection('users').orderBy('createdAt', descending: true).limit(50).snapshots(),
						builder: (context, snap) {
							if (!snap.hasData) return const Center(child: CircularProgressIndicator());
							return Column(children: [
								for (final d in snap.data!.docs)
									Card(
										child: ListTile(
											title: Text(d.data()['name']?.toString() ?? d.id),
											subtitle: Text(d.data()['email']?.toString() ?? ''),
											trailing: Wrap(spacing: 8, children: [
												TextButton(onPressed: () => d.reference.set({'disabled': false}, SetOptions(merge: true)), child: const Text('Enable')),
												TextButton(onPressed: () => d.reference.set({'disabled': true}, SetOptions(merge: true)), child: const Text('Disable')),
												TextButton(onPressed: () => d.reference.delete(), child: const Text('Delete', style: TextStyle(color: Colors.red))),
											]),
										),
								),
							]);
					},
					),
					const Divider(),
					const Text('Providers / Vendors', style: TextStyle(fontWeight: FontWeight.bold)),
					StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
						stream: FirebaseFirestore.instance.collection('providers').orderBy('createdAt', descending: true).limit(50).snapshots(),
						builder: (context, snap) {
							if (!snap.hasData) return const Center(child: CircularProgressIndicator());
							return Column(children: [
								for (final d in snap.data!.docs)
									Card(
										child: ListTile(
											title: Text(d.data()['name']?.toString() ?? d.id),
											subtitle: Text(d.data()['category']?.toString() ?? ''),
											trailing: Wrap(spacing: 8, children: [
												TextButton(onPressed: () => d.reference.set({'approved': true}, SetOptions(merge: true)), child: const Text('Approve')),
												TextButton(onPressed: () => d.reference.set({'approved': false}, SetOptions(merge: true)), child: const Text('Reject')),
												TextButton(onPressed: () => d.reference.delete(), child: const Text('Delete', style: TextStyle(color: Colors.red))),
											]),
										),
								),
							]);
					},
					),
				],
			),
		);
	}
}