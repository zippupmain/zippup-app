import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/features/providers/widgets/provider_header.dart';

class MovingProviderDashboardScreen extends StatefulWidget {
	const MovingProviderDashboardScreen({super.key});
	@override
	State<MovingProviderDashboardScreen> createState() => _MovingProviderDashboardScreenState();
}

class _MovingProviderDashboardScreenState extends State<MovingProviderDashboardScreen> {
	final _db = FirebaseFirestore.instance;
	final _auth = FirebaseAuth.instance;
	bool _online = false;
	String? _filter; // requested, accepted, assigned, enroute, completed, cancelled
	Stream<QuerySnapshot<Map<String, dynamic>>>? _incomingStream;

	@override
	void initState() {
		super.initState();
		_init();
	}

	Future<void> _init() async {
		final uid = _auth.currentUser?.uid;
		if (uid == null) return;
		final prof = await _db.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: 'moving').limit(1).get();
		if (prof.docs.isNotEmpty) {
			_online = prof.docs.first.get('availabilityOnline') == true;
			if (mounted) setState(() {});
		}
		_incomingStream = _db
			.collection('moving_requests')
			.where('assignedProviderId', isEqualTo: uid)
			.where('status', isEqualTo: 'requested')
			.snapshots();
	}

	Stream<QuerySnapshot<Map<String, dynamic>>> _requestsStream(String uid) {
		Query<Map<String, dynamic>> q = _db.collection('moving_requests').where('assignedProviderId', isEqualTo: uid);
		return q.orderBy('createdAt', descending: true).snapshots();
	}

	Future<void> _setOnline(bool v) async {
		final uid = _auth.currentUser?.uid; if (uid == null) return;
		setState(() => _online = v);
		final snap = await _db.collection('provider_profiles').where('userId', isEqualTo: uid).where('service', isEqualTo: 'moving').limit(1).get();
		if (snap.docs.isNotEmpty) {
			await snap.docs.first.reference.set({'availabilityOnline': v}, SetOptions(merge: true));
		}
	}

	Future<void> _updateRequest(String id, String status) async {
		await _db.collection('moving_requests').doc(id).set({'status': status}, SetOptions(merge: true));
	}

	@override
	Widget build(BuildContext context) {
		final uid = _auth.currentUser?.uid ?? '';
		return DefaultTabController(
			length: 2,
			child: Scaffold(
				appBar: AppBar(title: const Text('Moving Provider'), actions: [
					IconButton(icon: const Icon(Icons.home_outlined), onPressed: () => context.go('/')),
					IconButton(icon: const Icon(Icons.close), onPressed: () { if (Navigator.of(context).canPop()) { Navigator.pop(context); } else { context.go('/'); } }),
				], bottom: const TabBar(tabs: [
					Tab(icon: Icon(Icons.notifications_active), text: 'Incoming'),
					Tab(icon: Icon(Icons.local_shipping), text: 'Requests'),
				])),
				body: Column(children: [
					const ProviderHeader(service: 'moving'),
					Padding(
						padding: const EdgeInsets.all(12),
						child: Row(children: [
							Expanded(child: SwitchListTile(title: const Text('Go Online'), value: _online, onChanged: _setOnline)),
							const SizedBox(width: 8),
							OutlinedButton.icon(onPressed: () => context.push('/hub/orders'), icon: const Icon(Icons.list_alt), label: const Text('All orders')),
						]),
					),
					SingleChildScrollView(
						scrollDirection: Axis.horizontal,
						child: Row(children: [
							FilterChip(label: const Text('All'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
							...['requested','accepted','assigned','enroute','arrived','delivered','cancelled'].map((s) => Padding(
								padding: const EdgeInsets.symmetric(horizontal: 4),
								child: FilterChip(label: Text(s), selected: _filter == s, onSelected: (_) => setState(() => _filter = s)),
							)),
						]),
					),
					Expanded(child: TabBarView(children: [
						StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
							stream: _incomingStream,
							builder: (context, s) {
								final list = (s.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
								if (list.isEmpty) return const Center(child: Text('No incoming requests'));
								return ListView.separated(
									itemCount: list.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, i) {
										final d = list[i];
										final data = d.data();
										return ListTile(
											title: Text('REQUEST • ${(data['subcategory'] ?? 'moving').toString()}'),
											subtitle: Text('From: ${data['pickupAddress'] ?? ''}\nTo: ${data['dropoffAddress'] ?? ''}'),
											isThreeLine: true,
											trailing: Wrap(spacing: 6, children: [
												FilledButton(onPressed: () => _updateRequest(d.id, 'accepted'), child: const Text('Accept')),
												TextButton(onPressed: () => _updateRequest(d.id, 'cancelled'), child: const Text('Decline')),
											]),
										);
									},
								);
							},
						),
						StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
							stream: _requestsStream(uid),
							builder: (context, snap) {
								if (!snap.hasData) return const Center(child: CircularProgressIndicator());
								var docs = snap.data!.docs;
								if (_filter != null) docs = docs.where((r) => (r.data()['status'] ?? '') == _filter).toList();
								if (docs.isEmpty) return const Center(child: Text('No requests'));
								return ListView.separated(
									itemCount: docs.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, i) {
										final d = docs[i];
										final data = d.data();
										return ListTile(
											title: Text('${(data['subcategory'] ?? 'moving').toString().toUpperCase()} • ${(data['status'] ?? '').toString()}'),
											subtitle: Text('From: ${data['pickupAddress'] ?? ''}\nTo: ${data['dropoffAddress'] ?? ''}'),
											isThreeLine: true,
											trailing: Wrap(spacing: 6, children: _actionsFor(d.id, (data['status'] ?? '').toString())),
										);
									},
								);
							},
						),
					])),
					StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
						stream: _incomingStream,
						builder: (context, s) {
							if (!s.hasData || s.data!.docs.isEmpty) return const SizedBox.shrink();
							final d = s.data!.docs.first;
							final data = d.data();
							WidgetsBinding.instance.addPostFrameCallback((_) {
								showDialog(
									context: context,
									builder: (_) => AlertDialog(
										title: const Text('New moving request'),
										content: Text('${(data['subcategory'] ?? 'moving').toString().toUpperCase()}\nFrom: ${data['pickupAddress'] ?? ''}\nTo: ${data['dropoffAddress'] ?? ''}'),
										actions: [
											TextButton(onPressed: () { Navigator.pop(context); _updateRequest(d.id, 'accepted'); }, child: const Text('Accept')),
											TextButton(onPressed: () { Navigator.pop(context); _updateRequest(d.id, 'cancelled'); }, child: const Text('Decline')),
										],
									),
								);
							});
							return const SizedBox.shrink();
						},
					),
				]),
			),
		);
	}

	List<Widget> _actionsFor(String id, String status) {
		switch (status) {
			case 'accepted':
				return [TextButton(onPressed: () => _updateRequest(id, 'assigned'), child: const Text('Assign'))];
			case 'assigned':
				return [TextButton(onPressed: () => _updateRequest(id, 'enroute'), child: const Text('Enroute'))];
			case 'enroute':
				return [TextButton(onPressed: () => _updateRequest(id, 'arrived'), child: const Text('Arrived'))];
			case 'arrived':
				return [FilledButton(onPressed: () => _updateRequest(id, 'completed'), child: const Text('Complete'))];
			default:
				return const [];
		}
	}
}

