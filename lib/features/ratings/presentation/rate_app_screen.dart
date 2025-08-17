import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RateAppScreen extends StatefulWidget {
	const RateAppScreen({super.key});
	@override
	State<RateAppScreen> createState() => _RateAppScreenState();
}

class _RateAppScreenState extends State<RateAppScreen> {
	double _rating = 5;
	final _note = TextEditingController();
	Future<void> _submit() async {
		await FirebaseFirestore.instance.collection('app_ratings').add({
			'uid': FirebaseAuth.instance.currentUser?.uid,
			'rating': _rating,
			'note': _note.text.trim(),
			'createdAt': DateTime.now().toIso8601String(),
		});
		if (mounted) Navigator.pop(context);
	}
	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Rate ZippUp')),
			body: Padding(
				padding: const EdgeInsets.all(16),
				child: Column(children: [
					Slider(value: _rating, min: 1, max: 5, divisions: 4, label: _rating.toStringAsFixed(0), onChanged: (v) => setState(() => _rating = v)),
					TextField(controller: _note, decoration: const InputDecoration(labelText: 'Tell us more'), maxLines: 3),
					const SizedBox(height: 12),
					FilledButton(onPressed: _submit, child: const Text('Submit')),
				]),
			),
		);
	}
}