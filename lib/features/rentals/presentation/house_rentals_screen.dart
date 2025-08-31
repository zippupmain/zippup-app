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
	DateTime? _endDate;
	bool _useEndDate = false;
	bool _yearlyApartment = false;
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
		if (_yearlyApartment && _selected == 'Apartment') return 365;
		if (_useEndDate && _startDate != null && _endDate != null) {
			final diff = _endDate!.difference(_startDate!).inDays;
			return diff <= 0 ? 1 : diff;
		}
		final v = int.tryParse(_days.text.trim());
		return v == null || v <= 0 ? 1 : v;
	}

	Future<void> _pickStartDate() async {
		final now = DateTime.now();
		final picked = await showDatePicker(context: context, firstDate: now, lastDate: now.add(const Duration(days: 365)), initialDate: _startDate ?? now);
		if (picked == null) return;
		setState(() => _startDate = picked);
	}

	Future<void> _pickEndDate() async {
		final base = _startDate ?? DateTime.now();
		final picked = await showDatePicker(context: context, firstDate: base, lastDate: base.add(const Duration(days: 365*2)), initialDate: _endDate ?? base.add(const Duration(days: 1)));
		if (picked == null) return;
		setState(() => _endDate = picked);
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
				if (_useEndDate && _endDate != null) {
					endDateTime = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, _endTime.hour, _endTime.minute);
				} else {
					endDateTime = startDateTime.add(Duration(days: _numDays));
					endDateTime = DateTime(endDateTime.year, endDateTime.month, endDateTime.day, _endTime.hour, _endTime.minute);
				}
			}
			await FirebaseFirestore.instance.collection('rental_requests').add({
				'userId': uid,
				'providerId': providerId,
				'category': 'rentals',
				'subcategory': 'Houses',
				'rentalSubtype': _selected,
				'startDate': _startDate?.toIso8601String(),
				'endDate': _endDate?.toIso8601String(),
				'numDays': _numDays,
				'dailyPrice': daily,
				'totalPrice': total,
				'startTime': '${_startTime.hour}:${_startTime.minute.toString().padLeft(2,'0')}',
				'endTime': '${_endTime.hour}:${_endTime.minute.toString().padLeft(2,'0')}',
				'startDateTime': startDateTime?.toIso8601String(),
				'endDateTime': endDateTime?.toIso8601String(),
				'yearly': _yearlyApartment && _selected == 'Apartment',
				'useEndDate': _useEndDate,
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
			appBar: AppBar(
				title: const Text('🏠 House Rentals'),
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
			),
			body: Container(
				color: Colors.white, // White background for text visibility
				child: Column(children: [
					// Search bar
					Container(
						color: Colors.white,
						padding: const EdgeInsets.all(16),
						child: TextField(
							style: const TextStyle(color: Colors.black),
							decoration: InputDecoration(
								labelText: 'Search properties...',
								labelStyle: const TextStyle(color: Colors.black),
								hintText: 'Location, amenities, or property type...',
								hintStyle: const TextStyle(color: Colors.black38),
								prefixIcon: const Icon(Icons.search, color: Colors.green),
								border: OutlineInputBorder(
									borderRadius: BorderRadius.circular(12),
									borderSide: const BorderSide(color: Colors.green),
								),
								focusedBorder: OutlineInputBorder(
									borderRadius: BorderRadius.circular(12),
									borderSide: BorderSide(color: Colors.green.shade600, width: 2),
								),
								filled: true,
								fillColor: Colors.green.shade50,
							),
							onChanged: (value) {
								// TODO: Implement search filtering
								setState(() {});
							},
						),
					),
					// Property type selection
					Container(
						color: Colors.white,
						child: SingleChildScrollView(
							scrollDirection: Axis.horizontal,
							padding: const EdgeInsets.all(8),
							child: Row(
								children: _subtypes.map((t) => Padding(
									padding: const EdgeInsets.symmetric(horizontal: 4),
									child: ChoiceChip(
										label: Text(t, style: const TextStyle(color: Colors.black)),
										selected: _selected == t,
										onSelected: (_) => setState(() { 
											_selected = t; 
											if (_selected != 'Apartment') _yearlyApartment = false; 
										}),
										backgroundColor: Colors.white,
										selectedColor: Colors.green.shade100,
									),
								)).toList(),
							),
						),
					),
					// Date and time controls - made scrollable
					Container(
						color: Colors.white,
						padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
						child: Column(children: [
							// First row - date selection (horizontally scrollable)
							SingleChildScrollView(
								scrollDirection: Axis.horizontal,
								child: Row(children: [
									OutlinedButton.icon(
										onPressed: _pickStartDate, 
										icon: const Icon(Icons.calendar_today, color: Colors.black), 
										label: Text(
											_startDate == null ? 'Select start date' : '${_startDate!.year}-${_startDate!.month.toString().padLeft(2,'0')}-${_startDate!.day.toString().padLeft(2,'0')}',
											style: const TextStyle(color: Colors.black),
										),
									),
									const SizedBox(width: 8),
									if (_useEndDate)
										OutlinedButton.icon(
											onPressed: _pickEndDate, 
											icon: const Icon(Icons.calendar_month, color: Colors.black), 
											label: Text(
												_endDate == null ? 'Select end date' : '${_endDate!.year}-${_endDate!.month.toString().padLeft(2,'0')}-${_endDate!.day.toString().padLeft(2,'0')}',
												style: const TextStyle(color: Colors.black),
											),
										),
									const SizedBox(width: 8),
									if (!_useEndDate && !(_yearlyApartment && _selected == 'Apartment'))
										SizedBox(
											width: 120,
											child: TextField(
												controller: _days,
												keyboardType: TextInputType.number,
												style: const TextStyle(color: Colors.black),
												decoration: const InputDecoration(
													labelText: 'Days',
													labelStyle: TextStyle(color: Colors.black),
													border: OutlineInputBorder(),
												),
												onChanged: (_) => setState(() {}),
											),
										),
								]),
							),
							const SizedBox(height: 8),
							// Second row - time selection (horizontally scrollable)
							SingleChildScrollView(
								scrollDirection: Axis.horizontal,
								child: Row(children: [
									OutlinedButton.icon(
										onPressed: () => _pickTime(isStart: true), 
										icon: const Icon(Icons.schedule, color: Colors.black), 
										label: Text('Start ${_startTime.format(context)}', style: const TextStyle(color: Colors.black)),
									),
									const SizedBox(width: 8),
									OutlinedButton.icon(
										onPressed: () => _pickTime(isStart: false), 
										icon: const Icon(Icons.schedule_outlined, color: Colors.black), 
										label: Text('End ${_endTime.format(context)}', style: const TextStyle(color: Colors.black)),
									),
									const SizedBox(width: 8),
									DropdownButton<String>(
										value: _sort,
										items: const [
											DropdownMenuItem(value: 'nearest', child: Text('Nearest', style: TextStyle(color: Colors.black))),
											DropdownMenuItem(value: 'price_asc', child: Text('Price: Low to High', style: TextStyle(color: Colors.black))),
											DropdownMenuItem(value: 'price_desc', child: Text('Price: High to Low', style: TextStyle(color: Colors.black))),
											DropdownMenuItem(value: 'rating', child: Text('Rating', style: TextStyle(color: Colors.black))),
										],
										onChanged: (v) => setState(() => _sort = v ?? 'nearest'),
									),
								]),
							),
							const SizedBox(height: 8),
							// Switches
							SwitchListTile(
								title: const Text('Pick end date', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
								value: _useEndDate,
								onChanged: (v) => setState(() { _useEndDate = v; if (v) { _yearlyApartment = false; } }),
								activeColor: Colors.green,
							),
							if (_selected == 'Apartment')
								SwitchListTile(
									title: const Text('Yearly (365 days)', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
									value: _yearlyApartment,
									onChanged: (v) => setState(() { _yearlyApartment = v; if (v) { _useEndDate = false; _days.text = '365'; } }),
									activeColor: Colors.green,
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
			),
		);
	}
}

