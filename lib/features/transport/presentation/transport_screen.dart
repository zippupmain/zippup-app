import 'package:flutter/material.dart';

class TransportScreen extends StatefulWidget {
	const TransportScreen({super.key});

	@override
	State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
	final _pickup = TextEditingController();
	final List<TextEditingController> _stops = [TextEditingController()];
	bool _scheduled = false;
	DateTime? _scheduledAt;
	String _type = 'taxi';
	double _fare = 0;
	int _eta = 0;
	String _status = 'idle';

	void _addStop() {
		if (_stops.length < 5) setState(() => _stops.add(TextEditingController()));
	}

	void _removeStop(int index) {
		if (_stops.length > 1) setState(() => _stops.removeAt(index));
	}

	void _estimate() {
		setState(() {
			_fare = 1500 + (_stops.length - 1) * 500;
			_eta = 8 + (_stops.length - 1) * 3;
		});
	}

	Future<void> _requestRide() async {
		setState(() => _status = 'requesting');
		await Future.delayed(const Duration(seconds: 2));
		setState(() => _status = 'waiting_driver');
		await Future.delayed(const Duration(seconds: 3));
		setState(() => _status = 'driver_accepted');
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Transport')),
			body: ListView(
				padding: const EdgeInsets.all(16),
				children: [
					ToggleButtons(
						isSelected: ['taxi', 'bike', 'truck'].map((e) => _type == e).toList(),
						onPressed: (i) => setState(() => _type = ['taxi', 'bike', 'truck'][i]),
						children: const [
							Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Taxi')),
							Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Bike')),
							Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Truck')),
						],
					),
					const SizedBox(height: 12),
					SwitchListTile(
						title: const Text('Schedule ride'),
						value: _scheduled,
						onChanged: (v) => setState(() => _scheduled = v),
					),
					if (_scheduled)
						ListTile(
							title: const Text('Scheduled time'),
							subtitle: Text(_scheduledAt?.toString() ?? 'Pick time'),
							onTap: () async {
								final now = DateTime.now();
								final date = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 30)), initialDate: now);
								if (date == null) return;
								final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
								if (time == null) return;
								setState(() => _scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
							},
						),
					TextField(controller: _pickup, decoration: const InputDecoration(labelText: 'Pickup address')),
					const SizedBox(height: 8),
					const Text('Stops (max 5):'),
					for (int i = 0; i < _stops.length; i++)
						Row(children: [
							Expanded(child: TextField(controller: _stops[i], decoration: InputDecoration(labelText: 'Stop ${i + 1}'))),
							IconButton(onPressed: () => _removeStop(i), icon: const Icon(Icons.remove_circle_outline)),
						]),
					TextButton.icon(onPressed: _addStop, icon: const Icon(Icons.add), label: const Text('Add stop')),
					const SizedBox(height: 8),
					Row(
						children: [
							Expanded(child: OutlinedButton(onPressed: _estimate, child: const Text('Estimate fare'))),
							const SizedBox(width: 8),
							Expanded(child: FilledButton(onPressed: _requestRide, child: const Text('Request ride'))),
						],
					),
					const SizedBox(height: 12),
					Text('Fare estimate: ₦${_fare.toStringAsFixed(2)}'),
					Text('Driver ETA: ${_eta} min'),
					const SizedBox(height: 12),
					Text('Status: $_status'),
				],
			),
		);
	}
}