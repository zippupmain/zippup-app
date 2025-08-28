import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProviderHubScreen extends StatefulWidget {
	const ProviderHubScreen({super.key});
	@override
	State<ProviderHubScreen> createState() => _ProviderHubScreenState();
}

class _ProviderHubScreenState extends State<ProviderHubScreen> {
	bool _loading = true;
	bool _isProviderMode = false;
	bool _online = false;
	String _service = '';

	@override
	void initState() {
		super.initState();
		_init();
	}

	Future<void> _init() async {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		if (uid == null) { setState(() { _loading = false; }); return; }
		try {
			final user = await FirebaseFirestore.instance.collection('users').doc(uid).get();
			final role = (user.data()?['activeRole']?.toString() ?? 'customer');
			_isProviderMode = role.startsWith('provider:');
			_service = _isProviderMode ? role.split(':').last : '';
			if (_isProviderMode) {
				final prof = await FirebaseFirestore.instance.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: _service).limit(1).get();
				if (prof.docs.isNotEmpty) {
					_online = prof.docs.first.get('availabilityOnline') == true;
				}
			}
		} catch (_) {}
		if (mounted) setState(() { _loading = false; });
	}

	Future<void> _toggleOnline(bool v) async {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		if (uid == null) return;
		setState(() => _online = v);
		try {
			await FirebaseFirestore.instance.collection('provider_profiles')
				.where('userId', isEqualTo: uid)
				.where('service', isEqualTo: _service)
				.limit(1)
				.get().then((snap) async {
					if (snap.docs.isNotEmpty) {
						await snap.docs.first.reference.set({'availabilityOnline': v}, SetOptions(merge: true));
					}
				});
		} catch (e) {
			if (mounted) setState(() => _online = !v);
		}
	}

	@override
	Widget build(BuildContext context) {
		if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
		return Scaffold(
			appBar: AppBar(title: const Text('Provider Hub')),
			body: !_isProviderMode
				? _BecomeProvider()
				: ListView(children: [
					Padding(
						padding: const EdgeInsets.all(16),
						child: Row(children: [
							Expanded(child: Text('$_service • ${_online ? 'Online' : 'Offline'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
							Switch(value: _online, onChanged: _toggleOnline),
						]),
					),
					const Divider(),
					ListTile(leading: const Icon(Icons.inbox), title: const Text('Incoming requests'), subtitle: const Text('Requests routed to you'), onTap: () => context.push('/providers')), // reuse business hub for now
					ListTile(leading: const Icon(Icons.list_alt), title: const Text('Active jobs')), // TODO wire list
					ListTile(leading: const Icon(Icons.bar_chart), title: const Text('Analytics')), // TODO wire charts
					ListTile(leading: const Icon(Icons.settings_suggest), title: const Text('Manage service profile'), onTap: () => context.push('/providers')),
					const SizedBox(height: 24),
				]),
		);
	}
}

class _BecomeProvider extends StatelessWidget {
	@override
	Widget build(BuildContext context) {
		return Center(
			child: Padding(
				padding: const EdgeInsets.all(24),
				child: Column(mainAxisSize: MainAxisSize.min, children: [
					const Text('Become a provider and start earning on ZippUp'),
					const SizedBox(height: 12),
					FilledButton.icon(onPressed: () => context.push('/providers/kyc'), icon: const Icon(Icons.verified_user), label: const Text('Apply as Provider / Vendor')),
				]),
			),
		);
	}
}

