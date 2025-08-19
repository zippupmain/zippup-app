import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateServiceProfileScreen extends StatefulWidget {
	const CreateServiceProfileScreen({super.key});
	@override
	State<CreateServiceProfileScreen> createState() => _CreateServiceProfileScreenState();
}

class _CreateServiceProfileScreenState extends State<CreateServiceProfileScreen> {
	final _title = TextEditingController();
	final _desc = TextEditingController();
	String? _category;
	String? _subcategory;
	String _status = 'draft';
	bool _saving = false;

	final Map<String, List<String>> _cats = const {
		'food': ['Fast Food','Local','Grocery'],
		'hire': ['Home','Tech','Construction','Auto','Personal'],
		'transport': ['Taxi','Bus','Tricycle','Bike','Courier'],
		'rentals': ['Vehicle','Houses','Other rentals'],
		'emergency': ['Ambulance','Fire','Security','Towing','Roadside'],
		'personal': ['Nails','Hair','Massage','Pedicure','Makeups'],
		'marketplace': ['Electronics','Vehicles','Property','Services'],
	};

	Future<void> _save() async {
		setState(() => _saving = true);
		try {
			final uid = FirebaseAuth.instance.currentUser!.uid;
			await FirebaseFirestore.instance.collection('business_profiles').doc(uid).collection('profiles').add({
				'title': _title.text.trim(),
				'description': _desc.text.trim(),
				'category': _category,
				'subcategory': _subcategory,
				'status': _status,
				'createdAt': DateTime.now().toIso8601String(),
			});
			if (!mounted) return;
			Navigator.pop(context);
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
			}
		} finally {
			if (mounted) setState(() => _saving = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		final subs = _category == null ? const <String>[] : (_cats[_category] ?? const <String>[]);
		return Scaffold(
			appBar: AppBar(title: const Text('Create service profile')),
			body: ListView(padding: const EdgeInsets.all(16), children: [
				DropdownButtonFormField<String>(
					value: _category,
					items: _cats.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
					decoration: const InputDecoration(labelText: 'Category'),
					onChanged: (v) => setState(() { _category = v; _subcategory = null; }),
				),
				if (subs.isNotEmpty)
					DropdownButtonFormField<String>(
						value: _subcategory,
						items: subs.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
						decoration: const InputDecoration(labelText: 'Subcategory'),
						onChanged: (v) => setState(() => _subcategory = v),
					),
				TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
				TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
				const SizedBox(height: 12),
				FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Save')),
			]),
		);
	}
}

