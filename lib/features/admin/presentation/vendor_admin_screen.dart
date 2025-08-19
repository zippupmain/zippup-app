import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VendorAdminScreen extends StatefulWidget {
	const VendorAdminScreen({super.key});
	@override
	State<VendorAdminScreen> createState() => _VendorAdminScreenState();
}

class _VendorAdminScreenState extends State<VendorAdminScreen> {
	String _statusFilter = 'all';
	final _driverId = TextEditingController();
	final _deliveryCode = TextEditingController();
	final _complaint = TextEditingController();

	Stream<QuerySnapshot<Map<String, dynamic>>> _orders() {
		final uid = FirebaseAuth.instance.currentUser!.uid;
		final base = FirebaseFirestore.instance.collection('orders').where('providerId', isEqualTo: uid);
		if (_statusFilter == 'all') return base.snapshots();
		return base.where('status', isEqualTo: _statusFilter).snapshots();
	}

	Future<void> _update(String id, String status, {Map<String, dynamic>? extra}) async {
		await FirebaseFirestore.instance.collection('orders').doc(id).set({'status': status, if (extra != null) ...extra}, SetOptions(merge: true));
	}

	Future<void> _assign(String id) async {
		await _update(id, 'assigned', extra: {'deliveryId': _driverId.text.trim()});
	}

	Future<void> _enterCode(String id) async {
		await _update(id, 'delivered', extra: {'deliveryCodeEntered': _deliveryCode.text.trim()});
	}

	Future<void> _decline(String id) async {
		await _update(id, 'cancelled', extra: {'cancelledBy': FirebaseAuth.instance.currentUser!.uid, 'cancelReason': 'Declined by provider'});
	}

	Future<void> _complainOn(String id) async {
		await FirebaseFirestore.instance.collection('orders').doc(id).collection('complaints').add({'by': FirebaseAuth.instance.currentUser!.uid, 'text': _complaint.text.trim(), 'createdAt': DateTime.now().toIso8601String()});
		_complaint.clear();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Provider Admin')),
			body: Column(children: [
				Padding(
					padding: const EdgeInsets.all(8.0),
					child: Row(children: [
						const Text('Filter:'), const SizedBox(width: 8),
						DropdownButton<String>(value: _statusFilter, items: const [
							DropdownMenuItem(value: 'all', child: Text('All')),
							DropdownMenuItem(value: 'pending', child: Text('Pending')),
							DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
							DropdownMenuItem(value: 'preparing', child: Text('Preparing')),
							DropdownMenuItem(value: 'dispatched', child: Text('Dispatched')),
							DropdownMenuItem(value: 'assigned', child: Text('Assigned')),
							DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
						], onChanged: (v) => setState(() => _statusFilter = v ?? 'all')),
					]),
				),
				Expanded(
					child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
						stream: _orders(),
						builder: (context, snap) {
							if (!snap.hasData) return const Center(child: CircularProgressIndicator());
							final docs = snap.data!.docs;
							if (docs.isEmpty) return const Center(child: Text('No orders'));
							return ListView.separated(
								separatorBuilder: (_, __) => const Divider(height: 1),
								itemCount: docs.length,
								itemBuilder: (context, i) {
									final d = docs[i].data();
									final id = docs[i].id;
									final buyer = (d['buyerId'] ?? 'unknown').toString();
									final category = (d['category'] ?? 'other').toString();
									final from = 'From: $buyer • $category';
									return ListTile(
										title: Text('Order #$id'),
										subtitle: Text('Status: ${d['status']}\n$from'),
										isThreeLine: true,
										trailing: Wrap(spacing: 6, children: [
											TextButton(onPressed: () => _update(id, 'accepted'), child: const Text('Accept')),
											TextButton(onPressed: () => _decline(id), child: const Text('Decline')),
											TextButton(onPressed: () => _update(id, 'preparing'), child: const Text('Preparing')),
											TextButton(onPressed: () => _update(id, 'dispatched'), child: const Text('Dispatch')),
											TextButton(onPressed: () => _assign(id), child: const Text('Assign driver')),
											TextButton(onPressed: () => _enterCode(id), child: const Text('Enter code')),
										]),
									);
							},
							);
						},
					),
				),
				Padding(
					padding: const EdgeInsets.all(12),
					child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
						TextField(controller: _driverId, decoration: const InputDecoration(labelText: 'Driver ID for assignment')),
						TextField(controller: _deliveryCode, decoration: const InputDecoration(labelText: 'Delivery code from customer')),
						TextField(controller: _complaint, decoration: const InputDecoration(labelText: 'Complain or query')),
						Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _complainOn(''), child: const Text('Submit complaint'))),
					]),
				),
			]),
		);
	}
}