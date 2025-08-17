import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OthersSearchScreen extends StatefulWidget {
	const OthersSearchScreen({super.key, required this.kind});
	final String kind; // events | tickets | tutors
	@override
	State<OthersSearchScreen> createState() => _OthersSearchScreenState();
}

class _OthersSearchScreenState extends State<OthersSearchScreen> {
	final _q = TextEditingController();
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
							final d = docs[i].data();
							return ListTile(title: Text(d['title']?.toString() ?? 'Item'), subtitle: Text(d['description']?.toString() ?? ''));
						},
					);
				},
			),
		);
	}
}