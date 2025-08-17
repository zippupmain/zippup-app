import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LanguagesScreen extends StatefulWidget {
	const LanguagesScreen({super.key});
	@override
	State<LanguagesScreen> createState() => _LanguagesScreenState();
}

class _LanguagesScreenState extends State<LanguagesScreen> {
	String _lang = 'en';
	Future<void> _save() async {
		final uid = FirebaseAuth.instance.currentUser!.uid;
		await FirebaseFirestore.instance.collection('users').doc(uid).set({'language': _lang}, SetOptions(merge: true));
		if (mounted) Navigator.pop(context);
	}
	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Languages')),
			body: Column(children: [
				RadioListTile(value: 'en', groupValue: _lang, onChanged: (v) => setState(() => _lang = v as String), title: const Text('English')),
				RadioListTile(value: 'fr', groupValue: _lang, onChanged: (v) => setState(() => _lang = v as String), title: const Text('French')),
				RadioListTile(value: 'es', groupValue: _lang, onChanged: (v) => setState(() => _lang = v as String), title: const Text('Spanish')),
				const SizedBox(height: 12),
				FilledButton(onPressed: _save, child: const Text('Save')),
			]),
		);
	}
}