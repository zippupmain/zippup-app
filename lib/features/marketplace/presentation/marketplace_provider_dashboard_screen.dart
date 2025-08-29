import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/order.dart';
import 'package:zippup/features/food/providers/order_service.dart';

class MarketplaceProviderDashboardScreen extends StatefulWidget {
	const MarketplaceProviderDashboardScreen({super.key});
	@override
	State<MarketplaceProviderDashboardScreen> createState() => _MarketplaceProviderDashboardScreenState();
}

class _MarketplaceProviderDashboardScreenState extends State<MarketplaceProviderDashboardScreen> {
	final _db = FirebaseFirestore.instance;
	final _auth = FirebaseAuth.instance;
	Stream<QuerySnapshot<Map<String, dynamic>>>? _incoming;
	final _service = OrderService();
	OrderStatus? _filter;

	@override
	void initState() {
		super.initState();
		final uid = _auth.currentUser?.uid;
		if (uid != null) {
			_incoming = _db.collection('orders').where('providerId', isEqualTo: uid).where('status', isEqualTo: 'pending').snapshots();
		}
	}

	Stream<QuerySnapshot<Map<String, dynamic>>> _listings(String uid) => _db.collection('listings').where('ownerId', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots();

	Stream<QuerySnapshot<Map<String, dynamic>>> _orders(String uid) => _db.collection('orders').where('providerId', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots();

	Future<void> _promptAssignCourier(BuildContext context, String orderId) async {
		final controller = TextEditingController();
		final courier = await showDialog<String>(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('Assign courier'),
				content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Courier UID or phone')),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
					FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Assign')),
				],
			),
		);
		if (courier == null || courier.isEmpty) return;
		await _db.collection('orders').doc(orderId).set({'deliveryId': courier, 'status': 'assigned'}, SetOptions(merge: true));
	}

	Future<void> _openAddListing() async { await showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _ListingForm()); }

	@override
	Widget build(BuildContext context) {
		final uid = _auth.currentUser?.uid ?? '';
		return DefaultTabController(
			length: 3,
			child: Scaffold(
				appBar: AppBar(title: const Text('Marketplace Provider'), actions: [
					IconButton(icon: const Icon(Icons.home_outlined), onPressed: () => context.go('/')),
					IconButton(icon: const Icon(Icons.close), onPressed: () { if (Navigator.of(context).canPop()) { Navigator.pop(context); } else { context.go('/'); } }),
				], bottom: const TabBar(tabs: [
					Tab(icon: Icon(Icons.inbox), text: 'Incoming'),
					Tab(icon: Icon(Icons.list_alt), text: 'Listings'),
					Tab(icon: Icon(Icons.bar_chart), text: 'Analytics'),
				])),
				body: TabBarView(children: [
					// Incoming/Orders
					StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
						stream: _orders(uid),
						builder: (context, s) {
							if (!s.hasData) return const Center(child: CircularProgressIndicator());
							var docs = s.data!.docs;
							if (_filter != null) docs = docs.where((e) => (e.data()['status'] ?? '') == _filter!.name).toList();
							if (docs.isEmpty) return const Center(child: Text('No orders'));
							return Column(children: [
								SingleChildScrollView(
									scrollDirection: Axis.horizontal,
									child: Row(children: [
										FilterChip(label: const Text('All'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
										...[
											OrderStatus.pending,
											OrderStatus.dispatched,
											OrderStatus.assigned,
											OrderStatus.enroute,
											OrderStatus.arrived,
											OrderStatus.delivered,
										].map((s) => Padding(
											padding: const EdgeInsets.symmetric(horizontal: 4),
											child: FilterChip(label: Text(s.name), selected: _filter == s, onSelected: (_) => setState(() => _filter = s)),
										)),
									]),
								),
								Expanded(child: ListView.separated(
									itemCount: docs.length,
									separatorBuilder: (_, __) => const Divider(height: 1),
									itemBuilder: (context, i) {
										final id = docs[i].id; final d = docs[i].data();
										return ListTile(
											title: Text('Order ${id.substring(0,6)} • ${(d['status'] ?? '').toString()}'),
											subtitle: Text('To: ${(d['buyerId'] ?? '').toString()}'),
											trailing: Wrap(spacing: 6, children: [
												if ((d['status'] ?? '') == 'pending') TextButton(onPressed: () => _db.collection('orders').doc(id).set({'status': 'accepted'}, SetOptions(merge: true)), child: const Text('Accept')),
												if ((d['status'] ?? '') == 'dispatched') TextButton(onPressed: () => _promptAssignCourier(context, id), child: const Text('Assign courier')),
												if ((d['status'] ?? '') == 'assigned') TextButton(onPressed: () => _db.collection('orders').doc(id).set({'status': 'enroute'}, SetOptions(merge: true)), child: const Text('Enroute')),
												if ((d['status'] ?? '') == 'enroute') TextButton(onPressed: () => _db.collection('orders').doc(id).set({'status': 'arrived'}, SetOptions(merge: true)), child: const Text('Arrived')),
									]),
									);
									},
								))
							]);
						},
					),
					// Listings
					Column(children: [
						Padding(
							padding: const EdgeInsets.all(12),
							child: Row(children: [
								FilledButton.icon(onPressed: _openAddListing, icon: const Icon(Icons.add), label: const Text('Add listing')),
								const SizedBox(width: 8),
								OutlinedButton.icon(onPressed: () => _db.collection('orders').where('providerId', isEqualTo: uid).where('status', isEqualTo: 'dispatched').limit(1).get().then((q) async { if (q.docs.isNotEmpty) { await q.docs.first.reference.set({'status': 'dispatched'}, SetOptions(merge: true)); } }), icon: const Icon(Icons.delivery_dining), label: const Text('Dispatch to courier')),
							]),
						),
						Expanded(
							child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
								stream: _listings(uid),
								builder: (context, s) {
									if (!s.hasData) return const Center(child: CircularProgressIndicator());
									final docs = s.data!.docs;
									if (docs.isEmpty) return const Center(child: Text('No listings yet'));
									return ListView.separated(
										itemCount: docs.length,
										separatorBuilder: (_, __) => const Divider(height: 1),
										itemBuilder: (context, i) {
											final id = docs[i].id; final d = docs[i].data();
											return ListTile(
												title: Text(d['title']?.toString() ?? ''),
												subtitle: Text((d['price'] is num) ? '₦${(d['price'] as num).toDouble().toStringAsFixed(0)}' : ''),
												trailing: Wrap(spacing: 8, children: [
													IconButton(onPressed: () => _db.collection('listings').doc(id).set({'status': 'paused'}, SetOptions(merge: true)), icon: const Icon(Icons.pause_circle)),
													IconButton(onPressed: () => _db.collection('listings').doc(id).delete(), icon: const Icon(Icons.delete, color: Colors.redAccent)),
												]),
											);
										},
									);
								},
							),
						),
					]),
					// Analytics simple
					FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
						future: _db.collection('orders').where('providerId', isEqualTo: uid).get(const GetOptions(source: Source.server)),
						builder: (context, s) {
							if (!s.hasData) return const Center(child: CircularProgressIndicator());
							double earnings = 0; int completed = 0;
							for (final d in s.data!.docs) {
								final m = d.data(); final st = (m['status'] ?? '').toString(); if (st == 'completed' || st == 'delivered') { completed++; earnings += (m['price'] as num?)?.toDouble() ?? 0; }
							}
							return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
								Text('Completed: $completed', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
								const SizedBox(height: 8),
								Text('Earnings: ${earnings.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
							]));
						},
					),
				]),
			),
		);
	}
}

class _ListingForm extends StatefulWidget {
	@override
	State<_ListingForm> createState() => _ListingFormState();
}

class _ListingFormState extends State<_ListingForm> {
	final _title = TextEditingController();
	final _price = TextEditingController();
	Uint8List? _imageBytes; bool _saving = false;

	Future<void> _pick() async { final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85); if (file != null) { final bytes = await file.readAsBytes(); if (mounted) setState(() => _imageBytes = bytes); } }

	Future<void> _save() async {
		setState(() => _saving = true);
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
			String? url;
			if (_imageBytes != null) { final ref = FirebaseStorage.instance.ref('listings/$uid/market_${DateTime.now().millisecondsSinceEpoch}.jpg'); await ref.putData(_imageBytes!, SettableMetadata(contentType: 'image/jpeg')); url = await ref.getDownloadURL(); }
			await FirebaseFirestore.instance.collection('listings').add({
				'ownerId': uid,
				'type': 'marketplace',
				'title': _title.text.trim(),
				'price': double.tryParse(_price.text.trim()) ?? 0,
				'imageUrl': url ?? '',
				'createdAt': FieldValue.serverTimestamp(),
				'status': 'active',
			});
			if (mounted) Navigator.pop(context);
		} finally { setState(() => _saving = false); }
	}

	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
			child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
				TextField(controller: _title, decoration: const InputDecoration(labelText: 'Listing title')),
				TextField(controller: _price, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
				const SizedBox(height: 8),
				Row(children: [IconButton(onPressed: _pick, icon: const Icon(Icons.image)), const Text('Add photo')]),
				const SizedBox(height: 12),
				FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Save listing')),
			]))
		);
	}
}