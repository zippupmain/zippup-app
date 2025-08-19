import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zippup/services/location/location_service.dart';
import 'package:geolocator/geolocator.dart' as geo;

class VehicleRentalsScreen extends StatefulWidget {
	const VehicleRentalsScreen({super.key});

	@override
	State<VehicleRentalsScreen> createState() => _VehicleRentalsScreenState();
}

class _VehicleRentalsScreenState extends State<VehicleRentalsScreen> {
	final List<String> _subtypes = const ['Luxury car','Normal car','Bus','Truck','Tractor'];
	String _selected = 'Luxury car';
	final TextEditingController _days = TextEditingController(text: '1');
	DateTime? _startDate;
	TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
	TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);
	geo.Position? _me;
	String _sort = 'nearest';

	@override
	void initState() {
		super.initState();
		_initLocation();
	}

	Future<void> _initLocation() async {
		final p = await LocationService.getCurrentPosition();
		if (!mounted) return;
		setState(() => _me = p);
	}

	double _distanceKm(Map<String, dynamic> p) {
		final lat = (p['lat'] as num?)?.toDouble();
		final lng = (p['lng'] as num?)?.toDouble();
		if (_me == null || lat == null || lng == null) return 1e9;
		final meters = geo.Geolocator.distanceBetween(_me!.latitude, _me!.longitude, lat, lng);
		return meters / 1000.0;
	}

	String _distanceText(Map<String, dynamic> p) {
		final km = _distanceKm(p);
		if (km >= 1e9) return '';
		return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km away';
	}

	int get _numDays {
		final v = int.tryParse(_days.text.trim());
		return v == null || v <= 0 ? 1 : v;
	}

	Future<void> _pickStartDate() async {
		final now = DateTime.now();
		final picked = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)), initialDate: _startDate ?? now);
		if (picked == null) return;
		setState(() => _startDate = picked);
	}

	Future<void> _pickTime({required bool isStart}) async {
		final base = isStart ? _startTime : _endTime;
		final picked = await showTimePicker(context: context, initialTime: base);
		if (picked == null) return;
		setState(() { if (isStart) _startTime = picked; else _endTime = picked; });
	}

	Future<void> _bookProvider(String providerId, Map<String, dynamic> provider) async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
			final daily = (provider['dailyPrice'] is num) ? (provider['dailyPrice'] as num).toDouble() : 0.0;
			final total = daily * _numDays;
			DateTime? startDateTime;
			DateTime? endDateTime;
			if (_startDate != null) {
				startDateTime = DateTime(_startDate!.year, _startDate!.month, _startDate!.day, _startTime.hour, _startTime.minute);
				endDateTime = startDateTime.add(Duration(days: _numDays));
				endDateTime = DateTime(endDateTime.year, endDateTime.month, endDateTime.day, _endTime.hour, _endTime.minute);
			}
			await FirebaseFirestore.instance.collection('rental_requests').add({
				'userId': uid,
				'providerId': providerId,
				'category': 'rentals',
				'subcategory': 'Vehicle',
				'rentalSubtype': _selected,
				'startDate': _startDate?.toIso8601String(),
				'numDays': _numDays,
				'dailyPrice': daily,
				'totalPrice': total,
				'startTime': '${_startTime.hour}:${_startTime.minute.toString().padLeft(2,'0')}',
				'endTime': '${_endTime.hour}:${_endTime.minute.toString().padLeft(2,'0')}',
				'startDateTime': startDateTime?.toIso8601String(),
				'endDateTime': endDateTime?.toIso8601String(),
				'status': 'requested',
				'createdAt': DateTime.now().toIso8601String(),
			});
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rental request submitted')));
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
			}
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Vehicle Rentals')),
			body: Column(children: [
				SingleChildScrollView(
					scrollDirection: Axis.horizontal,
					padding: const EdgeInsets.all(8),
					child: Wrap(spacing: 8, children: _subtypes.map((t) => ChoiceChip(label: Text(t), selected: _selected == t, onSelected: (_) => setState(() => _selected = t))).toList()),
				),
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 16),
					child: Row(children: [
						OutlinedButton.icon(onPressed: _pickStartDate, icon: const Icon(Icons.calendar_today), label: Text(_startDate == null ? 'Select date' : '${_startDate!.year}-${_startDate!.month.toString().padLeft(2,'0')}-${_startDate!.day.toString().padLeft(2,'0')}')),
						const SizedBox(width: 8),
						OutlinedButton.icon(onPressed: () => _pickTime(isStart: true), icon: const Icon(Icons.schedule), label: Text('Start ${_startTime.format(context)}')),
						const SizedBox(width: 8),
						OutlinedButton.icon(onPressed: () => _pickTime(isStart: false), icon: const Icon(Icons.schedule_outlined), label: Text('End ${_endTime.format(context)}')),
						const Spacer(),
						SizedBox(
							width: 120,
							child: TextField(
								controller: _days,
								keyboardType: TextInputType.number,
								decoration: const InputDecoration(labelText: 'Days'),
								onChanged: (_) => setState(() {}),
							),
						),
						const SizedBox(width: 12),
						DropdownButton<String>(
							value: _sort,
							items: const [
								DropdownMenuItem(value: 'nearest', child: Text('Nearest')),
								DropdownMenuItem(value: 'price_asc', child: Text('Price: Low to High')),
								DropdownMenuItem(value: 'price_desc', child: Text('Price: High to Low')),
								DropdownMenuItem(value: 'rating', child: Text('Rating')),
							],
							onChanged: (v) => setState(() => _sort = v ?? 'nearest'),
						),
					]),
				),
				const Divider(height: 1),
				Expanded(
					child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
						stream: FirebaseFirestore.instance
							.collection('providers')
							.where('category', isEqualTo: 'rentals')
							.where('rentalCategory', isEqualTo: 'vehicle')
							.snapshots(),
						builder: (context, snap) {
							if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
							if (!snap.hasData) return const Center(child: CircularProgressIndicator());
							final docs = snap.data!.docs.where((d) {
								final data = d.data();
								final subtype = (data['rentalSubtype'] ?? '').toString().toLowerCase();
								return subtype == _selected.toLowerCase() || ((data['tags'] as List?)?.map((e) => e.toString().toLowerCase()).contains(_selected.toLowerCase()) ?? false);
							}).toList();
							docs.sort((a, b) {
								final pa = a.data();
								final pb = b.data();
								final da = (pa['dailyPrice'] is num) ? (pa['dailyPrice'] as num).toDouble() : 0.0;
								final db = (pb['dailyPrice'] is num) ? (pb['dailyPrice'] as num).toDouble() : 0.0;
								final ra = (pa['rating'] is num) ? (pa['rating'] as num).toDouble() : 0.0;
								final rb = (pb['rating'] is num) ? (pb['rating'] as num).toDouble() : 0.0;
								final na = _distanceKm(pa);
								final nb = _distanceKm(pb);
								switch (_sort) {
									case 'price_asc':
										return da.compareTo(db);
									case 'price_desc':
										return db.compareTo(da);
									case 'rating':
										return rb.compareTo(ra);
									case 'nearest':
									default:
										return na.compareTo(nb);
								}
							});
							if (docs.isEmpty) return const Center(child: Text('No providers yet'));
							return ListView.separated(
								itemCount: docs.length,
								separatorBuilder: (_, __) => const Divider(height: 1),
								itemBuilder: (context, i) {
									final p = docs[i].data();
									final pid = docs[i].id;
									final name = (p['name'] ?? 'Provider').toString();
									final rating = (p['rating'] ?? 0).toString();
									final daily = (p['dailyPrice'] is num) ? (p['dailyPrice'] as num).toDouble() : 0.0;
									final dist = _distanceText(p);
									final total = daily * _numDays;
									return ListTile(
										title: Text(name, style: const TextStyle(color: Colors.black)),
										subtitle: Text('Rating: $rating • Daily: ₦${daily.toStringAsFixed(0)}${dist.isNotEmpty ? ' • $dist' : ''}', style: const TextStyle(color: Colors.black54)),
										trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
											Text('Total: ₦${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold)),
											const SizedBox(height: 6),
											FilledButton(onPressed: () => _bookProvider(pid, p), child: const Text('Book')),
										]),
									);
								},
							);
						},
					),
				),
			]),
		);
	}
}

