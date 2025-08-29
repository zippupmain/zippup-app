import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminHubScreen extends StatefulWidget {
	const AdminHubScreen({super.key});
	@override
	State<AdminHubScreen> createState() => _AdminHubScreenState();
}

class _AdminHubScreenState extends State<AdminHubScreen> with SingleTickerProviderStateMixin {
	late final TabController _tab;
	String _serviceFilter = 'all';

	@override
	void initState() {
		super.initState();
		_tab = TabController(length: 3, vsync: this);
	}

	Stream<QuerySnapshot<Map<String, dynamic>>> _pendingProfiles() {
		final col = FirebaseFirestore.instance.collection('provider_profiles');
		Query<Map<String, dynamic>> q = col.where('status', isEqualTo: 'pending_review');
		if (_serviceFilter != 'all') q = q.where('service', isEqualTo: _serviceFilter);
		return q.snapshots();
	}

	Future<void> _approve(String id) async {
		await FirebaseFirestore.instance.collection('provider_profiles').doc(id).set({'status': 'active', 'metadata.kycStatus': 'approved'}, SetOptions(merge: true));
	}

	Future<void> _reject(String id) async {
		await FirebaseFirestore.instance.collection('provider_profiles').doc(id).set({'status': 'rejected', 'metadata.kycStatus': 'rejected'}, SetOptions(merge: true));
	}

	Future<void> _flagInspection(String id, bool required) async {
		await FirebaseFirestore.instance.collection('provider_profiles').doc(id).set({'metadata.inspectionRequired': required}, SetOptions(merge: true));
	}

	Widget _pendingTab() {
		return Column(children: [
			Padding(
				padding: const EdgeInsets.all(8),
				child: Row(children: [
					const Text('Service:'), const SizedBox(width: 8),
					DropdownButton<String>(value: _serviceFilter, items: const [
						DropdownMenuItem(value: 'all', child: Text('All')),
						DropdownMenuItem(value: 'transport', child: Text('Transport')),
						DropdownMenuItem(value: 'moving', child: Text('Moving')),
						DropdownMenuItem(value: 'emergency', child: Text('Emergency')),
						DropdownMenuItem(value: 'food', child: Text('Food')),
						DropdownMenuItem(value: 'grocery', child: Text('Grocery')),
						DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
						DropdownMenuItem(value: 'hire', child: Text('Hire')),
						DropdownMenuItem(value: 'rentals', child: Text('Rentals')),
						DropdownMenuItem(value: 'marketplace', child: Text('Marketplace')),
						DropdownMenuItem(value: 'others', child: Text('Others')),
					], onChanged: (v) => setState(() => _serviceFilter = v ?? 'all')),
				]),
			),
			Expanded(
				child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
					stream: _pendingProfiles(),
					builder: (context, snap) {
						if (!snap.hasData) return const Center(child: CircularProgressIndicator());
						final docs = snap.data!.docs;
						if (docs.isEmpty) return const Center(child: Text('No pending profiles'));
						return ListView.separated(
							separatorBuilder: (_, __) => const Divider(height: 1),
							itemCount: docs.length,
							itemBuilder: (context, i) {
								final d = docs[i].data();
								final id = docs[i].id;
								final meta = (d['metadata'] as Map<String, dynamic>? ?? {});
								final title = (meta['title'] ?? 'Untitled').toString();
								final service = (d['service'] ?? '').toString();
								final banner = (meta['bannerUrl'] ?? '').toString();
								final driverName = ((meta['publicDetails'] as Map?)?['driverName'] ?? '').toString();
								final plate = ((meta['publicDetails'] as Map?)?['plateNumber'] ?? '').toString();
								return ListTile(
									title: Text(title),
									subtitle: Text('Service: $service${driverName.isNotEmpty ? '\nDriver: $driverName • Plate: $plate' : ''}'),
									leading: banner.isEmpty ? const CircleAvatar(child: Icon(Icons.business)) : CircleAvatar(backgroundImage: NetworkImage(banner)),
									trailing: Wrap(spacing: 8, children: [
										TextButton(onPressed: () => _flagInspection(id, true), child: const Text('Require inspection')),
										TextButton(onPressed: () => _reject(id), child: const Text('Reject')),
										FilledButton(onPressed: () => _approve(id), child: const Text('Approve')),
									]),
								);
							},
						);
					},
				),
			),
		]);
	}

	Widget _flagsTab() {
		return const Center(child: Text('Config flags coming soon'));
	}

	Widget _reportsTab() {
		return const Center(child: Text('Reports & audits coming soon'));
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Admin Hub'),
				bottom: TabBar(controller: _tab, tabs: const [
					Tab(text: 'Approvals'),
					Tab(text: 'Flags'),
					Tab(text: 'Reports'),
				]),
			),
			body: TabBarView(controller: _tab, children: [
				_pendingTab(),
				_flagsTab(),
				_reportsTab(),
			]),
		);
	}
}