import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

class OthersProviderDashboardScreen extends StatefulWidget {
	const OthersProviderDashboardScreen({super.key});
	@override
	State<OthersProviderDashboardScreen> createState() => _OthersProviderDashboardScreenState();
}

class _OthersProviderDashboardScreenState extends State<OthersProviderDashboardScreen> {
	final _db = FirebaseFirestore.instance;
	final _auth = FirebaseAuth.instance;
	Stream<QuerySnapshot<Map<String, dynamic>>>? _incoming;

	@override
	void initState() {
		super.initState();
		final uid = _auth.currentUser?.uid;
		if (uid != null) {
			_incoming = _db.collection('orders').where('providerId', isEqualTo: uid).where('status', isEqualTo: 'pending').snapshots();
		}
	}

	Future<void> _openAddEvent() async { await showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _EventForm()); }
	Future<void> _openAddTutor() async { await showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _TutorForm()); }

	@override
	Widget build(BuildContext context) {
		final uid = _auth.currentUser?.uid ?? '';
		return DefaultTabController(
			length: 3,
			child: Scaffold(
				appBar: AppBar(title: const Text('Others Provider'), actions: [
					IconButton(icon: const Icon(Icons.home_outlined), onPressed: () => context.go('/')),
					IconButton(icon: const Icon(Icons.close), onPressed: () { if (Navigator.of(context).canPop()) { Navigator.pop(context); } else { context.go('/'); } }),
				], bottom: const TabBar(tabs: [
					Tab(icon: Icon(Icons.inbox), text: 'Incoming'),
					Tab(icon: Icon(Icons.build), text: 'Manage'),
					Tab(icon: Icon(Icons.bar_chart), text: 'Analytics'),
				])),
				body: TabBarView(children: [
					// Incoming
					StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
						stream: _incoming,
						builder: (context, s) {
							if (!s.hasData) return const Center(child: CircularProgressIndicator());
							final docs = s.data!.docs;
							if (docs.isEmpty) return const Center(child: Text('No incoming requests'));
							return ListView.separated(
								itemCount: docs.length,
								separatorBuilder: (_, __) => const Divider(height: 1),
								itemBuilder: (context, i) {
									final d = docs[i].data();
									return ListTile(
										title: Text('Request • ${(d['category'] ?? '').toString()}'),
										subtitle: Text('Order ${docs[i].id.substring(0,6)} • ${(d['status'] ?? '').toString()}'),
										trailing: Wrap(spacing: 6, children: [
											FilledButton(onPressed: () => _db.collection('orders').doc(docs[i].id).set({'status': 'accepted'}, SetOptions(merge: true)), child: const Text('Accept')),
											TextButton(onPressed: () => _db.collection('orders').doc(docs[i].id).set({'status': 'cancelled'}, SetOptions(merge: true)), child: const Text('Decline')),
										]),
									);
								},
							);
						},
					),
					// Manage
					SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
						Row(children: [
							FilledButton.icon(onPressed: _openAddEvent, icon: const Icon(Icons.event), label: const Text('Add event/tickets')),
							const SizedBox(width: 8),
							FilledButton.icon(onPressed: _openAddTutor, icon: const Icon(Icons.school), label: const Text('Add tutor service')),
						]),
						const SizedBox(height: 16),
						// Could list existing items later
					])) ,
					// Analytics
					FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
						future: _db.collection('orders').where('providerId', isEqualTo: uid).get(const GetOptions(source: Source.server)),
						builder: (context, s) {
							if (!s.hasData) return const Center(child: CircularProgressIndicator());
							double earnings = 0; int completed = 0;
							for (final d in s.data!.docs) { final m = d.data(); final st = (m['status'] ?? '').toString(); if (st == 'completed' || st == 'delivered') { completed++; earnings += (m['price'] as num?)?.toDouble() ?? 0; } }
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

class _EventForm extends StatefulWidget {
	@override
	State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
	final _title = TextEditingController();
	final _venue = TextEditingController();
	final _price = TextEditingController();
	Uint8List? _imageBytes; bool _saving = false;

	Future<void> _pick() async { final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85); if (f != null) { final b = await f.readAsBytes(); if (mounted) setState(() => _imageBytes = b); } }

	Future<void> _save() async {
		setState(() => _saving = true);
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
			String? url; if (_imageBytes != null) { final ref = FirebaseStorage.instance.ref('others/$uid/event_${DateTime.now().millisecondsSinceEpoch}.jpg'); await ref.putData(_imageBytes!, SettableMetadata(contentType: 'image/jpeg')); url = await ref.getDownloadURL(); }
			await FirebaseFirestore.instance.collection('others_events').add({
				'ownerId': uid,
				'type': 'event',
				'title': _title.text.trim(),
				'venue': _venue.text.trim(),
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
				TextField(controller: _title, decoration: const InputDecoration(labelText: 'Event title')),
				TextField(controller: _venue, decoration: const InputDecoration(labelText: 'Venue')),
				TextField(controller: _price, decoration: const InputDecoration(labelText: 'Ticket price'), keyboardType: TextInputType.number),
				const SizedBox(height: 8),
				Row(children: [IconButton(onPressed: _pick, icon: const Icon(Icons.image)), const Text('Add poster')]),
				const SizedBox(height: 12),
				FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Save event')),
			]))
		);
	}
}

class _TutorForm extends StatefulWidget {
	@override
	State<_TutorForm> createState() => _TutorFormState();
}

class _TutorFormState extends State<_TutorForm> {
	final _title = TextEditingController();
	final _rate = TextEditingController();
	bool _inPerson = true; bool _online = true;
	bool _saving = false;

	Future<void> _save() async {
		setState(() => _saving = true);
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
			await FirebaseFirestore.instance.collection('tutors').add({
				'ownerId': uid,
				'title': _title.text.trim(),
				'rate': double.tryParse(_rate.text.trim()) ?? 0,
				'inPerson': _inPerson,
				'online': _online,
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
				TextField(controller: _title, decoration: const InputDecoration(labelText: 'Tutor service title')),
				TextField(controller: _rate, decoration: const InputDecoration(labelText: 'Hourly rate'), keyboardType: TextInputType.number),
				SwitchListTile(title: const Text('Offer in-person classes'), value: _inPerson, onChanged: (v) => setState(() => _inPerson = v)),
				SwitchListTile(title: const Text('Offer online classes'), value: _online, onChanged: (v) => setState(() => _online = v)),
				const SizedBox(height: 12),
				FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Save tutor service')),
			]))
		);
	}
}