import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zippup/services/location/location_service.dart';
import 'package:geolocator/geolocator.dart' as geo;

class HouseRentalsScreen extends StatefulWidget {
	const HouseRentalsScreen({super.key});

	@override
	State<HouseRentalsScreen> createState() => _HouseRentalsScreenState();
}

class _HouseRentalsScreenState extends State<HouseRentalsScreen> {
	final List<String> _subtypes = const ['Apartment','Shortlet','Event hall','Office space','Warehouse'];
	String _selected = 'Apartment';
	final TextEditingController _days = TextEditingController(text: '1');
	DateTime? _startDate;
	geo.Position? _me;

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

	String _distanceText(Map<String, dynamic> p) {
		final lat = (p['lat'] as num?)?.toDouble();
		final lng = (p['lng'] as num?)?.toDouble();
		if (_me == null || lat == null || lng == null) return '';
		final meters = geo.Geolocator.distanceBetween(_me!.latitude, _me!.longitude, lat, lng);
		final km = meters / 1000.0;
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

	Future<void> _bookProvider(String providerId, Map<String, dynamic> provider) async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
			final daily = (provider['dailyPrice'] is num) ? (provider['dailyPrice'] as num).toDouble() : 0.0;
			final total = daily * _numDays;
			await FirebaseFirestore.instance.collection('rental_requests').add({
				'userId': uid,
				'providerId': providerId,
				'category': 'rentals',
				'subcategory': 'Houses',
				'rentalSubtype': _selected,
				'startDate': _startDate?.toIso8601String(),
				'numDays': _numDays,
				'dailyPrice': daily,
				'totalPrice': total,
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
			appBar: AppBar(title: const Text('House Rentals')),
			body: Column(children: [
				SingleChildScrollView(
					scrollDirection: Axis.horizontal,
					padding: const EdgeInsets.all(8),
					child: Wrap(spacing: 8, children: _subtypes.map((t) => ChoiceChip(label: Text(t), selected: _selected == t, onSelected: (_) => setState(() => _selected = t))).toList()),
				),
				Padding(
					padding: const EdgeInsets.symmetric(horizontal: 16),
					child: Row(children: [
						Expanded(child: ListTile(title: const Text('Start date'), subtitle: Text(_startDate == null ? 'Choose' : '${_startDate!.year}-${_startDate!.month.toString().padLeft(2,'0')}-${_startDate!.day.toString().padLeft(2,'0')}'), onTap: _pickStartDate)),
						SizedBox(
							width: 140,
							child: TextField(
								controller: _days,
								keyboardType: TextInputType.number,
								decoration: const InputDecoration(labelText: 'Days'),
								onChanged: (_) => setState(() {}),
							),
						),
					]),
				),
				const Divider(height: 1),
				Expanded(
					child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
						stream: FirebaseFirestore.instance
							.collection('providers')
							.where('category', isEqualTo: 'rentals')
							.where('rentalCategory', isEqualTo: 'houses')
							.snapshots(),
						builder: (context, snap) {
							if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
							if (!snap.hasData) return const Center(child: CircularProgressIndicator());
							final docs = snap.data!.docs.where((d) {
								final data = d.data();
								final subtype = (data['rentalSubtype'] ?? '').toString().toLowerCase();
								return subtype == _selected.toLowerCase();
							}).toList();
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

