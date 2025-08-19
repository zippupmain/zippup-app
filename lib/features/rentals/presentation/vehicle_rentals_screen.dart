import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VehicleRentalsScreen extends StatefulWidget {
	const VehicleRentalsScreen({super.key});

	@override
	State<VehicleRentalsScreen> createState() => _VehicleRentalsScreenState();
}

class _VehicleRentalsScreenState extends State<VehicleRentalsScreen> {
	String _type = 'luxury_car';
	DateTime? _startDate;
	DateTime? _endDate;
	final _notes = TextEditingController();
	bool _submitting = false;

	Future<void> _pickDate({required bool start}) async {
		final now = DateTime.now();
		final picked = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 180)), initialDate: (start ? _startDate : _endDate) ?? now);
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
				'type': _type,
				'startDate': _startDate!.toIso8601String(),
				'endDate': _endDate!.toIso8601String(),
				'notes': _notes.text.trim(),
				'createdAt': DateTime.now().toIso8601String(),
				'status': 'requested',
				'scheduledOnly': true,
			});
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request submitted. Visit company for documentation.')));
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
			appBar: AppBar(title: const Text('Vehicle Rentals (Scheduled Only)')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					ToggleButtons(
						isSelected: ['luxury_car','normal_car','bus','truck','tractor'].map((e) => _type == e).toList(),
						onPressed: (i) => setState(() => _type = ['luxury_car','normal_car','bus','truck','tractor'][i]),
						children: const [
							Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Luxury car')),
							Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Normal car')),
							Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Bus')),
							Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Truck')),
							Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Tractor')),
						],
					),
					const SizedBox(height: 12),
					ListTile(title: const Text('Start date'), subtitle: Text(_startDate == null ? 'Select date' : '${_startDate!.year}-${_startDate!.month.toString().padLeft(2,'0')}-${_startDate!.day.toString().padLeft(2,'0')}'), onTap: () => _pickDate(start: true)),
					ListTile(title: const Text('End date'), subtitle: Text(_endDate == null ? 'Select date' : '${_endDate!.year}-${_endDate!.month.toString().padLeft(2,'0')}-${_endDate!.day.toString().padLeft(2,'0')}'), onTap: () => _pickDate(start: false)),
					TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
					const SizedBox(height: 12),
					FilledButton(onPressed: _submitting ? null : _submit, child: Text(_submitting ? 'Submitting...' : 'Request rental')),
				],
			),
		);
	}
}

