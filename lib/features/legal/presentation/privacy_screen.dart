import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
	const PrivacyScreen({super.key});
	Future<String> _load() async {
		final doc = await FirebaseFirestore.instance.collection('_legal').doc('privacy').get();
		final content = (doc.data() ?? const {})['content']?.toString();
		return content ?? 'Privacy Policy\n\nWe respect your privacy. This policy explains how we collect and use your data within ZippUp. Admin can edit this text in Firestore at _legal/privacy.';
	}
	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Privacy & Policy')),
			body: FutureBuilder<String>(
				future: _load(),
				builder: (context, snap) => Padding(padding: const EdgeInsets.all(16), child: Text(snap.data ?? 'Loading...')),
			),
		);
	}
}