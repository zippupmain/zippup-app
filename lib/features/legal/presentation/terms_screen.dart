import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
	const TermsScreen({super.key});
	Future<String> _load() async {
		final doc = await FirebaseFirestore.instance.collection('_legal').doc('terms').get();
		final content = (doc.data() ?? const {})['content']?.toString();
		return content ?? 'Terms & Conditions\n\nBy using ZippUp, you agree to our terms. Admin can edit this content in Firestore at _legal/terms.';
	}
	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Terms of service')),
			body: FutureBuilder<String>(
				future: _load(),
				builder: (context, snap) => Padding(padding: const EdgeInsets.all(16), child: Text(snap.data ?? 'Loading...')),
			),
		);
	}
}