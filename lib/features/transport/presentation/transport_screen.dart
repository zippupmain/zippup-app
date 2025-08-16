import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as gc;
import 'package:zippup/services/location/distance_service.dart';
import 'package:zippup/services/location/location_service.dart';

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
	final _distanceService = DistanceService();

	@override
	void initState() {
		super.initState();
		_initPickup();
	}

	Future<void> _initPickup() async {
		final pos = await LocationService.getCurrentPosition();
		if (pos == null) return;
		final addr = await LocationService.reverseGeocode(pos);
		if (!mounted) return;
		_pickup.text = addr ?? 'Current location';
	}

	void _addStop() {
		if (_stops.length < 5) setState(() => _stops.add(TextEditingController()));
	}

	void _removeStop(int index) {
		if (_stops.length > 1) setState(() => _stops.removeAt(index));
	}

	Future<void> _estimate() async {
		final originAddress = _pickup.text.trim();
		final destAddresses = _stops.map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList();
		if (originAddress.isEmpty || destAddresses.isEmpty) {
			setState(() {
				_fare = 0;
				_eta = 0;
			});
			return;
		}
		try {
			final originLocs = await gc.locationFromAddress(originAddress);
			if (originLocs.isEmpty) return;
			final origin = '${originLocs.first.latitude},${originLocs.first.longitude}';
			final dests = <String>[];
			for (final d in destAddresses) {
				final locs = await gc.locationFromAddress(d);
				if (locs.isNotEmpty) dests.add('${locs.first.latitude},${locs.first.longitude}');
			}
			if (dests.isEmpty) return;
			final matrix = await _distanceService.getMatrix(origin: origin, destinations: dests);
			final elements = (matrix['rows'][0]['elements'] as List);
			double meters = 0;
			int seconds = 0;
			for (final el in elements) {
				if (el['status'] == 'OK') {
					meters += (el['distance']['value'] as num).toDouble();
					seconds += (el['duration']['value'] as num).toInt();
				}
			}
			final km = meters / 1000.0;
			final mins = (seconds / 60).round();
			// Simple fare: base + per km + per minute (adjust per type)
			final base = _type == 'bike' ? 300.0 : _type == 'truck' ? 1500.0 : 700.0;
			final perKm = _type == 'bike' ? 100.0 : _type == 'truck' ? 350.0 : 200.0;
			final perMin = 15.0;
			setState(() {
				_fare = base + km * perKm + mins * perMin;
				_eta = mins;
			});
		} catch (_) {
			setState(() {
				_fare = 0;
				_eta = 0;
			});
		}
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