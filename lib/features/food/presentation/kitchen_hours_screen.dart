import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class KitchenHoursScreen extends StatefulWidget {
	const KitchenHoursScreen({super.key});
	@override
	State<KitchenHoursScreen> createState() => _KitchenHoursScreenState();
}

class _KitchenHoursScreenState extends State<KitchenHoursScreen> {
	final Map<String, TimeOfDayRange> _hours = {
		'Mon': const TimeOfDayRange(start: TimeOfDay(hour: 8, minute: 0), end: TimeOfDay(hour: 20, minute: 0)),
		'Tue': const TimeOfDayRange(start: TimeOfDay(hour: 8, minute: 0), end: TimeOfDay(hour: 20, minute: 0)),
		'Wed': const TimeOfDayRange(start: TimeOfDay(hour: 8, minute: 0), end: TimeOfDay(hour: 20, minute: 0)),
		'Thu': const TimeOfDayRange(start: TimeOfDay(hour: 8, minute: 0), end: TimeOfDay(hour: 20, minute: 0)),
		'Fri': const TimeOfDayRange(start: TimeOfDay(hour: 8, minute: 0), end: TimeOfDay(hour: 22, minute: 0)),
		'Sat': const TimeOfDayRange(start: TimeOfDay(hour: 9, minute: 0), end: TimeOfDay(hour: 22, minute: 0)),
		'Sun': const TimeOfDayRange(start: TimeOfDay(hour: 10, minute: 0), end: TimeOfDay(hour: 20, minute: 0)),
	};
	bool _saving = false;

	Future<void> _pickTime(String day, bool isStart) async {
		final initial = isStart ? _hours[day]!.start : _hours[day]!.end;
		final res = await showTimePicker(context: context, initialTime: initial);
		if (res != null) {
			setState(() {
				final r = _hours[day]!;
				_hours[day] = TimeOfDayRange(start: isStart ? res : r.start, end: isStart ? r.end : res);
			});
		}
	}

	Future<void> _save() async {
		setState(() => _saving = true);
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
			if (uid.isEmpty) return;
			final map = _hours.map((k, v) => MapEntry(k, {'start': _fmt(v.start), 'end': _fmt(v.end)}));
			await FirebaseFirestore.instance.collection('vendors').doc(uid).set({'hours': map}, SetOptions(merge: true));
			if (mounted) Navigator.maybePop(context);
		} finally {
			if (mounted) setState(() => _saving = false);
		}
	}

	String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Kitchen Hours'), actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.maybePop(context))]),
			floatingActionButton: FloatingActionButton.extended(onPressed: _saving ? null : _save, icon: const Icon(Icons.save), label: const Text('Save')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: _hours.entries.map((e) {
					return ListTile(
						title: Text(e.key),
						subtitle: Text('${_fmt(e.value.start)} - ${_fmt(e.value.end)}'),
						trailing: Wrap(spacing: 8, children: [
							OutlinedButton(onPressed: () => _pickTime(e.key, true), child: const Text('Start')),
							OutlinedButton(onPressed: () => _pickTime(e.key, false), child: const Text('End')),
						]),
					);
				}).toList(),
			),
		);
	}
}

