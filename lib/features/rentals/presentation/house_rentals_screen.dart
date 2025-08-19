import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HouseRentalsScreen extends StatefulWidget {
	const HouseRentalsScreen({super.key});

	@override
	State<HouseRentalsScreen> createState() => _HouseRentalsScreenState();
}

class _HouseRentalsScreenState extends State<HouseRentalsScreen> {
	final List<String> _types = const ['Apartment', 'Shortlet', 'Event hall', 'Office space', 'Warehouse'];
	String _selected = 'Apartment';
	DateTime? _startDate;
	DateTime? _endDate;
	final _notes = TextEditingController();
	bool _submitting = false;

	Future<void> _pickDate({required bool start}) async {
		final now = DateTime.now();
		final picked = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)), initialDate: (start ? _startDate : _endDate) ?? now);
		if (picked == null) return;
		setState(() { if (start) _startDate = picked; else _endDate = picked; });
	}

	Future<void> _submit() async {
		if (_submitting) return;
		if (_startDate == null || _endDate == null) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select start and end dates')));
			return;
		}
		if (_endDate!.isBefore(_startDate!)) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date must be after start date')));
			return;
		}
		setState(() => _submitting = true);
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
			await FirebaseFirestore.instance.collection('rental_requests').add({
				'userId': uid,
				'type': 'house',
				'subtype': _selected,
				'startDate': _startDate!.toIso8601String(),
				'endDate': _endDate!.toIso8601String(),
				'notes': _notes.text.trim(),
				'createdAt': DateTime.now().toIso8601String(),
				'status': 'requested',
			});
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request submitted. We will contact you.')));
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
			}
		} finally {
			if (mounted) setState(() => _submitting = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('House & Property Rentals')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					Wrap(
						spacing: 8,
						runSpacing: 8,
						children: _types.map((t) => ChoiceChip(label: Text(t), selected: _selected == t, onSelected: (_) => setState(() => _selected = t))).toList(),
					),
					const SizedBox(height: 12),
					ListTile(title: const Text('Start date'), subtitle: Text(_startDate == null ? 'Select' : _startDate!.toIso8601String().substring(0,10)), onTap: () => _pickDate(start: true)),
					ListTile(title: const Text('End date'), subtitle: Text(_endDate == null ? 'Select' : _endDate!.toIso8601String().substring(0,10)), onTap: () => _pickDate(start: false)),
					TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
					const SizedBox(height: 12),
					FilledButton(onPressed: _submitting ? null : _submit, child: Text(_submitting ? 'Submitting...' : 'Request rental')),
				],
			),
		);
	}
}

