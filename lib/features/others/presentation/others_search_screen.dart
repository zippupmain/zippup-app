import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OthersSearchScreen extends StatefulWidget {
	const OthersSearchScreen({super.key, required this.kind});
	final String kind; // events | tickets | tutors
	@override
	State<OthersSearchScreen> createState() => _OthersSearchScreenState();
}

class _OthersSearchScreenState extends State<OthersSearchScreen> {
	final _q = TextEditingController();
	bool _submitting = false;
	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: Text(widget.kind == 'events' ? 'Events planning' : widget.kind == 'tickets' ? 'Live event tickets' : 'Tutors'),
				bottom: PreferredSize(
					preferredSize: const Size.fromHeight(56),
					child: Padding(
						padding: const EdgeInsets.all(8.0),
						child: TextField(
							controller: _q,
							decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search...', filled: true, border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(12)))),
							onChanged: (_) => setState(() {}),
						),
					),
				),
			),
			body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('others').where('type', isEqualTo: widget.kind).snapshots(),
				builder: (context, snap) {
					if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final docs = snap.data!.docs.where((d) {
						final q = _q.text.trim().toLowerCase();
						if (q.isEmpty) return true;
						final t = (d.data()['title'] ?? '').toString().toLowerCase();
						return t.contains(q);
					}).toList();
					if (docs.isEmpty) return const Center(child: Text('No results'));
					return ListView.separated(
						itemCount: docs.length,
						separatorBuilder: (_, __) => const Divider(height: 1),
						itemBuilder: (context, i) {
							final d = docs[i];
							final data = d.data();
							final title = data['title']?.toString() ?? 'Item';
							final desc = data['description']?.toString() ?? '';
							final ownerId = data['organizerId']?.toString() ?? data['ownerId']?.toString() ?? '';
							return ListTile(
								title: Text(title),
								subtitle: Text(desc),
								trailing: Row(
									mainAxisSize: MainAxisSize.min,
									children: [
										if (ownerId.isNotEmpty) IconButton(onPressed: () => context.push('/provider?providerId=$ownerId'), icon: const Icon(Icons.person_outline)),
										_actions(context, widget.kind, d.id, data),
									],
								),
								onTap: widget.kind == 'tickets' ? () => context.push('/others/ticket/${d.id}') : null,
							);
						},
					);
				},
			),
		);
	}

	Widget _actions(BuildContext context, String kind, String id, Map<String, dynamic> data) {
		if (kind == 'tickets') {
			final expireAt = DateTime.tryParse(data['expireAt']?.toString() ?? '');
			final expired = expireAt != null && DateTime.now().isAfter(expireAt);
			return Wrap(spacing: 8, children: [
				if (!expired) FilledButton(onPressed: () => context.push('/others/ticket/${id}'), child: const Text('Buy')),
				if (expired) const Text('Ended', style: TextStyle(color: Colors.red))
			]);
		}
		// events and tutors: Book / Schedule
		return Wrap(spacing: 8, children: [
			TextButton(onPressed: _submitting ? null : () => _book(context, kind, id, data, scheduled: false), child: Text(_submitting ? 'Booking…' : 'Book')),
			TextButton(onPressed: _submitting ? null : () => _book(context, kind, id, data, scheduled: true), child: const Text('Schedule')),
		]);
	}

	Future<void> _book(BuildContext context, String kind, String id, Map<String, dynamic> data, {required bool scheduled}) async {
		if (_submitting) return;
		setState(() => _submitting = true);
		try {
			DateTime? at;
			if (scheduled) {
				final now = DateTime.now();
				final date = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)), initialDate: now);
				if (date == null) { setState(() => _submitting = false); return; }
				final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
				if (time == null) { setState(() => _submitting = false); return; }
				at = DateTime(date.year, date.month, date.day, time.hour, time.minute);
			}
			final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
			final ref = await FirebaseFirestore.instance.collection('orders').add({
				'buyerId': uid,
				'providerId': id,
				'category': kind,
				'status': scheduled ? 'scheduled' : 'pending',
				'scheduledAt': at?.toIso8601String(),
				'createdAt': DateTime.now().toIso8601String(),
			});
			if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request submitted')));
			if (!scheduled && widget.kind != 'tickets') {
				// One-off listener to auto-navigate when provider accepts/assigns/enroute (not for tickets)
				final sub = FirebaseFirestore.instance.collection('orders').doc(ref.id).snapshots().listen((doc) {
					final d = doc.data() ?? {};
					final status = (d['status'] ?? '').toString();
					if (status == 'accepted' || status == 'assigned' || status == 'enroute') {
						if (mounted) context.pushNamed('trackOrder', queryParameters: {'orderId': ref.id});
					}
				});
				// Cancel the subscription after 10 minutes to avoid leaks
				Future.delayed(const Duration(minutes: 10)).then((_) => sub.cancel());
			}
		} finally {
			if (mounted) setState(() => _submitting = false);
		}
	}
}