import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zippup/common/widgets/address_field.dart';
import 'package:zippup/services/location/location_service.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as Math;

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

	double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
		const double R = 6371.0;
		double dLat = (lat2 - lat1) * (Math.pi / 180.0);
		double dLon = (lon2 - lon1) * (Math.pi / 180.0);
		double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos(lat1 * (Math.pi/180.0)) * Math.cos(lat2 * (Math.pi/180.0)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
		double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
		return R * c;
	}

	@override
	void initState() {
		super.initState();
		_prefillPickup();
	}

	Future<void> _prefillPickup() async {
		final p = await LocationService.getCurrentPosition();
		if (p == null || !mounted) return;
		final addr = await LocationService.reverseGeocode(p);
		if (!mounted) return;
		if ((addr ?? '').isNotEmpty) _pickup.text = addr!;
	}

	Future<void> _openClassModal() async {
		final pickup = _pickup.text.trim();
		final dropoff = _dropoff.text.trim();
		if (pickup.isEmpty || dropoff.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter pickup and dropoff')));
			return;
		}
		final titles = _subcategory == 'courier'
			? ['Intra-city', 'Intra-state']
			: (_subcategory == 'truck' ? ['Small truck', 'Medium truck', 'Large truck'] : ['Small pickup', 'Large pickup']);
		final images = _subcategory == 'courier'
			? ['assets/images/courier_city.png', 'assets/images/courier_state.png']
			: (_subcategory == 'truck'
				? ['assets/images/truck_small.png','assets/images/truck_medium.png','assets/images/truck_large.png']
				: ['assets/images/pickup_small.png','assets/images/pickup_large.png']);
		await showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) {
			return Padding(
				padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
				child: ListView.separated(
					shrinkWrap: true,
					itemCount: titles.length,
					separatorBuilder: (_, __) => const Divider(height: 1),
					itemBuilder: (ctx, i) {
						final title = titles[i];
						final img = images[i];
						final base = _subcategory == 'courier' ? (i == 0 ? 1500.0 : 3500.0) : (_subcategory == 'truck' ? [5000.0, 7500.0, 10000.0][i] : [3000.0, 4500.0][i]);
						final km = 8.0;
						final eta = 20 + i * 5;
						final price = base + km * (_subcategory == 'courier' ? (i==0?100:150) : (_subcategory=='truck'? (i==0?250: i==1?300:350): (i==0?180:220)));
						return ListTile(
							leading: Image.asset(img, width: 56, height: 36, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.local_shipping)),
							title: Text(title),
							subtitle: Text('ETA ${eta} min • ${km.toStringAsFixed(1)} km'),
							trailing: Text('₦${price.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
							onTap: () {
								Navigator.pop(ctx);
								_submit(chosenClass: title, price: price);
							},
						);
					},
				),
			);
		});
	}

	Future<void> _submit({required String chosenClass, required double price}) async {
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
				'class': chosenClass,
				'priceEstimate': price,
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
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent. Opening live tracking...')));
				Navigator.of(context).pushNamed('/live');
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
					FilledButton(onPressed: _submitting ? null : _openClassModal, child: Text(_submitting ? 'Submitting...' : 'Choose class')),
				],
			),
		);
	}
}

