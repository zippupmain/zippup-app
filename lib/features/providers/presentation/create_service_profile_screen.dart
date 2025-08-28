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
	String _type = 'individual';
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
			final ref = await FirebaseFirestore.instance.collection('business_profiles').doc(uid).collection('profiles').add({
				'title': _title.text.trim(),
				'description': _desc.text.trim(),
				'category': _category,
				'subcategory': _subcategory,
				'type': _type,
				'status': _status,
				'createdAt': DateTime.now().toIso8601String(),
			});
			if (!mounted) return;
			// Route to extra registration forms for specific categories
			final isVehicleRental = _category == 'rentals' && _subcategory == 'Vehicle';
			if (_category == 'transport' || _category == 'food' || isVehicleRental) {
				final params = <String, String>{'category': _category ?? ''};
				if (isVehicleRental) params['subcategory'] = 'Vehicle';
				Navigator.of(context).pushNamed('/profile/apply-provider', arguments: params);
				return;
			}
			Navigator.pop(context, ref.id);
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
			appBar: AppBar(title: const Text('Create business profile')),
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
				DropdownButtonFormField<String>(
					value: _type,
					items: const [
						DropdownMenuItem(value: 'individual', child: Text('Individual')),
						DropdownMenuItem(value: 'company', child: Text('Company')),
					],
					decoration: const InputDecoration(labelText: 'Type'),
					onChanged: (v) => setState(() => _type = v ?? 'individual'),
				),
				TextField(controller: _title, decoration: const InputDecoration(labelText: 'Business title')),
				TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description'), maxLines: 3),
				const SizedBox(height: 12),
				FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving...' : 'Create')),
			]),
		);
	}
}

