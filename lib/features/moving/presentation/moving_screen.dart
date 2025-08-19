import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zippup/common/widgets/address_field.dart';

class MovingScreen extends StatefulWidget {
	const MovingScreen({super.key});

	@override
	State<MovingScreen> createState() => _MovingScreenState();
}

class _MovingScreenState extends State<MovingScreen> {
	final TextEditingController _pickup = TextEditingController();
	final TextEditingController _dropoff = TextEditingController();
	final TextEditingController _notes = TextEditingController();
	String _subcategory = 'truck';
	bool _scheduled = false;
	DateTime? _scheduledAt;
	bool _submitting = false;

	Future<void> _submit() async {
		if (_submitting) return;
		final pickup = _pickup.text.trim();
		final dropoff = _dropoff.text.trim();
		if (pickup.isEmpty || dropoff.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter pickup and dropoff')));
			return;
		}
		setState(() => _submitting = true);
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
			final doc = await FirebaseFirestore.instance.collection('moving_requests').add({
				'userId': uid,
				'subcategory': _subcategory,
				'pickupAddress': pickup,
				'dropoffAddress': dropoff,
				'notes': _notes.text.trim(),
				'isScheduled': _scheduled,
				'scheduledAt': _scheduledAt?.toIso8601String(),
				'createdAt': DateTime.now().toIso8601String(),
				'status': 'requested',
			});
			if (!mounted) return;
			if (_scheduled) {
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Moving request scheduled')));
			} else {
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent. We\'ll notify you when a mover accepts.')));
			}
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
			appBar: AppBar(title: const Text('Moving')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					ToggleButtons(
						isSelected: ['truck', 'backie', 'courier'].map((e) => _subcategory == e).toList(),
						onPressed: (i) => setState(() => _subcategory = ['truck', 'backie', 'courier'][i]),
						children: const [
							Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Truck')),
							Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Backie/Pickup')),
							Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Courier')),
						],
					),
					const SizedBox(height: 12),
					SwitchListTile(
						title: const Text('Schedule'),
						value: _scheduled,
						onChanged: (v) => setState(() => _scheduled = v),
					),
					if (_scheduled)
						ListTile(
							title: const Text('Select date'),
							subtitle: Text(_scheduledAt == null ? 'Pick a date' : '${_scheduledAt!.year}-${_scheduledAt!.month.toString().padLeft(2,'0')}-${_scheduledAt!.day.toString().padLeft(2,'0')}'),
							onTap: () async {
								final now = DateTime.now();
								final date = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 60)), initialDate: _scheduledAt ?? now);
								if (date == null) return;
								final base = _scheduledAt ?? now;
								setState(() => _scheduledAt = DateTime(date.year, date.month, date.day, base.hour, base.minute));
							},
						),
					if (_scheduled)
						ListTile(
							title: const Text('Select time'),
							subtitle: Text(_scheduledAt == null ? 'Pick a time' : '${_scheduledAt!.hour.toString().padLeft(2,'0')}:${_scheduledAt!.minute.toString().padLeft(2,'0')}'),
							onTap: () async {
								final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_scheduledAt ?? DateTime.now()));
								if (picked == null) return;
								final base = _scheduledAt ?? DateTime.now();
								setState(() => _scheduledAt = DateTime(base.year, base.month, base.day, picked.hour, picked.minute));
							},
						),
					AddressField(controller: _pickup, label: 'Pickup address'),
					const SizedBox(height: 8),
					AddressField(controller: _dropoff, label: 'Dropoff address'),
					const SizedBox(height: 8),
					TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes (optional)')),
					const SizedBox(height: 12),
					FilledButton(onPressed: _submitting ? null : _submit, child: Text(_submitting ? 'Submitting...' : 'Request moving')),
				],
			),
		);
	}
}

