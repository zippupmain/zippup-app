import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CreateServiceProfileScreen extends StatefulWidget {
	const CreateServiceProfileScreen({super.key});
	@override
	State<CreateServiceProfileScreen> createState() => _CreateServiceProfileScreenState();
}

class _CreateServiceProfileScreenState extends State<CreateServiceProfileScreen> {
	final _title = TextEditingController();
	final _desc = TextEditingController();
	String? _category = 'transport';
	String? _subcategory;
	String _status = 'active';
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
			final user = FirebaseAuth.instance.currentUser;
			if (user == null) {
				if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in first')));
				return;
			}
			final uid = user.uid;
			final nowIso = DateTime.now().toIso8601String();
			final service = (_category ?? 'transport');
			// Write business profile (for admin management)
			await FirebaseFirestore.instance.collection('business_profiles').doc(uid).collection('profiles').add({
				'title': _title.text.trim(),
				'description': _desc.text.trim(),
				'category': _category,
				'subcategory': _subcategory,
				'type': _type,
				'status': 'active',
				'createdAt': nowIso,
			});
			// Create provider profile for Provider Hub (active for testing)
			try {
				await FirebaseFirestore.instance.collection('provider_profiles').add({
					'userId': uid,
					'service': service,
					'status': 'active',
					'availabilityOnline': false,
					'rating': 0.0,
					'totalRatings': 0,
					'earnings': 0.0,
					'createdAt': nowIso,
					'metadata': {
						'title': _title.text.trim(),
						'description': _desc.text.trim(),
						'category': _category,
						'subcategory': _subcategory,
						'type': _type,
					},
				});
			} catch (_) {}
			// Try to set user provider roles; ignore failures
			try {
				await FirebaseFirestore.instance.collection('users').doc(uid).set({
					'providerRoles': FieldValue.arrayUnion(['provider:$service']),
					'activeRole': 'provider:$service',
				}, SetOptions(merge: true));
			} catch (_) {}
			// Ensure role is switched via Cloud Function (bypasses client rules)
			try {
				final fn = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('switchActiveRole');
				await fn.call({'role': 'provider:$service'});
			} catch (_) {}
			if (!mounted) return;
			// Go to Hub
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile created')));
			context.go('/hub');
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

