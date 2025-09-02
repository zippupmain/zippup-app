import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as gc;
import 'package:zippup/services/location/distance_service.dart';
import 'package:zippup/services/location/location_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/widgets/address_field.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:zippup/services/notifications/notifications_service.dart';
import 'dart:math' as Math;
import 'package:zippup/core/config/country_config_service.dart';

class TransportScreen extends StatefulWidget {
	const TransportScreen({super.key});

	@override
	State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
	final _pickup = TextEditingController();
	final List<TextEditingController> _stops = [TextEditingController()];
	final _scheduleMsg = TextEditingController();
	bool _scheduled = false;
	DateTime? _scheduledAt;
	String _type = 'taxi';
	double _fare = 0;
	int _eta = 0;
	double _distanceKm = 0;
	String _status = 'idle';
	final _distanceService = DistanceService();
	bool _submitting = false;
	StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _rideSub;
	bool _isCharter = false;

	double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
		const double R = 6371.0;
		double dLat = _deg2rad(lat2 - lat1);
		double dLon = _deg2rad(lon2 - lon1);
		double a =
				Math.sin(dLat / 2) * Math.sin(dLat / 2) +
				Math.cos(_deg2rad(lat1)) * Math.cos(_deg2rad(lat2)) *
				Math.sin(dLon / 2) * Math.sin(dLon / 2);
		double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
		return R * c;
	}

	double _deg2rad(double deg) => deg * (3.141592653589793 / 180.0);

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
				_distanceKm = 0;
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
			final base = _type == 'bike' ? 300.0 : _type == 'bus' ? 900.0 : _type == 'tricycle' ? 500.0 : 700.0;
			final perKm = _type == 'bike' ? 100.0 : _type == 'bus' ? 220.0 : _type == 'tricycle' ? 140.0 : 200.0;
			final perMin = 15.0;
			setState(() {
				_fare = base + km * perKm + mins * perMin;
				_eta = mins;
				_distanceKm = km;
			});
		} catch (_) {
			setState(() {
				_fare = 0;
				_eta = 0;
				_distanceKm = 0;
			});
		}
	}

	double _priceForClass({required int capacity, required double km, required int mins}) {
		// Simple pricing model by capacity
		double base;
		double perKm;
		double perMin;
		switch (capacity) {
			case 2: // Tricycle
				base = 500; perKm = 120; perMin = 10; break;
			case 3: // Compact
				base = 600; perKm = 150; perMin = 12; break;
			case 4: // Standard
				base = 700; perKm = 180; perMin = 15; break;
			case 6: // XL
				base = 900; perKm = 220; perMin = 18; break;
			default:
				base = 700; perKm = 180; perMin = 15;
		}
		return base + km * perKm + mins * perMin;
	}

	double _charterPrice({required int seats, required double km, required int mins}) {
		double base;
		double perKm;
		double perMin;
		switch (seats) {
			case 8: base = 1500; perKm = 90; perMin = 8; break;
			case 12: base = 2200; perKm = 110; perMin = 10; break;
			case 16: base = 3000; perKm = 130; perMin = 12; break;
			case 30: base = 5000; perKm = 160; perMin = 15; break;
			default: base = 3000; perKm = 130; perMin = 12;
		}
		return base + km * perKm + mins * perMin;
	}

	String _vehicleClassLabel(int capacity) {
		switch (capacity) {
			case 2: return 'Tricycle';
			case 3: return 'Compact';
			case 4: return 'Standard';
			case 6: return 'XL';
			default: return 'Standard';
		}
	}

	String _rideTypeForCapacity(int capacity) {
		if (_isCharter || capacity >= 8) return 'bus';
		if (capacity == 2) return 'tricycle';
		if (capacity == 6) return 'bus';
		return 'taxi';
	}

	Widget _vehicleImage(String assetName) {
		return Image.asset(
			assetName,
			width: 64,
			height: 40,
			fit: BoxFit.contain,
			errorBuilder: (_, __, ___) => const Icon(Icons.directions_car, size: 40),
		);
	}

	Future<void> _openClassSelection({
		required String origin,
		required List<String> dests,
		required double oLat,
		required double oLng,
		required double dLat,
		required double dLng,
		required double km,
		required int mins,
	}) async {
		final parentContext = context;
		bool scheduled = _scheduled;
		DateTime? scheduledAt = _scheduledAt;
		await showModalBottomSheet(
			context: parentContext,
			isScrollControlled: true,
			builder: (ctx) {
				return StatefulBuilder(builder: (ctx, setModalState) {
					List<Map<String, dynamic>> classes;
					
					if (_type == 'bike') {
						classes = [
							{'capacity': 1, 'label': 'Economy Bike', 'emoji': '🏍️', 'price': 400.0},
							{'capacity': 1, 'label': 'Luxury Bike', 'emoji': '🏍️⚡', 'price': 600.0},
						];
					} else if (_type == 'bus' || _isCharter) {
						classes = [
							{'capacity': 8, 'label': 'Mini Bus (8 seater)', 'emoji': '🚐', 'price': 0.0},
							{'capacity': 12, 'label': 'Standard Bus (12 seater)', 'emoji': '🚌', 'price': 0.0},
							{'capacity': 16, 'label': 'Large Bus (16 seater)', 'emoji': '🚌', 'price': 0.0},
							{'capacity': 30, 'label': 'Charter Bus (30 seater)', 'emoji': '🚌', 'price': 0.0},
						];
					} else {
						// Taxi classes as they appear in request UI
						classes = [
							{'capacity': 2, 'label': 'Tricycle', 'emoji': '🛺', 'price': 0.0},
							{'capacity': 3, 'label': 'Compact', 'emoji': '🚗', 'price': 0.0},
							{'capacity': 4, 'label': 'Standard', 'emoji': '🚙', 'price': 0.0},
							{'capacity': 6, 'label': 'SUV/Van', 'emoji': '🚐', 'price': 0.0},
						];
					}
					
					return Container(
						decoration: const BoxDecoration(
							gradient: LinearGradient(
								colors: [Color(0xFFFAFAFA), Color(0xFFFFFFFF)],
								begin: Alignment.topCenter,
								end: Alignment.bottomCenter,
							),
							borderRadius: BorderRadius.only(
								topLeft: Radius.circular(20),
								topRight: Radius.circular(20),
							),
						),
						child: Padding(
							padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
							child: SingleChildScrollView(
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Row(children:[
											Text(
												_type == 'bike' ? '🏍️ Choose Bike Type' : 
												(_type == 'bus' || _isCharter) ? '🚌 Choose Bus Charter' : '🚗 Choose Ride Class',
												style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
											),
											const Spacer(),
											Container(
												padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
												decoration: BoxDecoration(
													color: Colors.blue.shade100,
													borderRadius: BorderRadius.circular(20),
												),
												child: Text(
													'~${km.toStringAsFixed(1)} km • ${mins} min',
													style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
												),
											),
										]),
										const SizedBox(height: 20),
										ListView.separated(
											shrinkWrap: true,
											physics: const NeverScrollableScrollPhysics(),
											itemCount: classes.length,
											separatorBuilder: (_, __) => const SizedBox(height: 12),
											itemBuilder: (ctx, i) {
												final classData = classes[i];
												final cap = classData['capacity'] as int;
												final label = classData['label'] as String;
												final emoji = classData['emoji'] as String;
												final basePrice = classData['price'] as double;
												
												final price = _type == 'bike' 
													? basePrice + (km * 50) + (mins * 5)
													: (_type == 'bus' || _isCharter)
														? (_charterPrice(seats: cap, km: km, mins: mins))
														: _priceForClass(capacity: cap, km: km, mins: mins);
												
												return Container(
													margin: const EdgeInsets.only(bottom: 8),
													decoration: BoxDecoration(
														gradient: const LinearGradient(
															colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
														),
														borderRadius: BorderRadius.circular(16),
														border: Border.all(color: Colors.blue.shade200),
													),
													child: ListTile(
														contentPadding: const EdgeInsets.all(16),
														leading: Container(
															padding: const EdgeInsets.all(8),
															decoration: BoxDecoration(
																color: Colors.white,
																borderRadius: BorderRadius.circular(12),
															),
															child: Text(emoji, style: const TextStyle(fontSize: 24)),
														),
														title: Text(
															label,
															style: const TextStyle(
																fontWeight: FontWeight.bold,
																color: Colors.blue,
															),
														),
														subtitle: Text(
															_type == 'bike' 
																? 'ETA ${mins} min • ${km.toStringAsFixed(1)} km'
																: '$cap passengers • ETA ${mins} min • ${km.toStringAsFixed(1)} km',
															style: const TextStyle(color: Colors.blue),
														),
														trailing: Container(
															padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
															decoration: BoxDecoration(
																gradient: const LinearGradient(
																	colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
																),
																borderRadius: BorderRadius.circular(20),
															),
															child: FutureBuilder<String>(
																future: CountryConfigService.instance.getCurrencySymbol(),
																builder: (context, snap) {
																	final symbol = snap.data ?? '₦';
																	return Text(
																		'${symbol}${price.toStringAsFixed(0)}',
																		style: const TextStyle(
																			fontWeight: FontWeight.bold,
																			color: Colors.white,
																		),
																	);
																},
															),
														),
														onTap: () async {
															Navigator.of(ctx).pop();
															await _createRideAndSearch(
																origin: origin,
																dests: dests,
																oLat: oLat,
																oLng: oLng,
																dLat: dLat,
																dLng: dLng,
																km: km,
																mins: mins,
																capacity: cap,
																classLabel: label,
																fare: price,
																scheduled: scheduled,
																scheduledAt: scheduledAt,
															);
														},
													),
												);
											},
										),
										const SizedBox(height: 8),
										SwitchListTile(
											title: const Text('Schedule booking', style: TextStyle(color: Colors.black)),
											value: scheduled,
											onChanged: (v) => setModalState(() => scheduled = v),
										),
										if (scheduled)
											ListTile(
												title: const Text('Scheduled time', style: TextStyle(color: Colors.black)),
												subtitle: Text(scheduledAt?.toString() ?? 'Pick time', style: const TextStyle(color: Colors.black54)),
												onTap: () async {
													final now = DateTime.now();
													final date = await showDatePicker(context: ctx, firstDate: now, lastDate: now.add(const Duration(days: 30)), initialDate: now);
													if (date == null) return;
													final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
													if (time == null) return;
													setModalState(() => scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
												},
											),
										const SizedBox(height: 8),
									],
								),
							),
						),
					);
				});
			},
		);
	}

	Future<void> _createRideAndSearch({
		required String origin,
		required List<String> dests,
		required double oLat,
		required double oLng,
		required double dLat,
		required double dLng,
		required double km,
		required int mins,
		required int capacity,
		required String classLabel,
		required double fare,
		required bool scheduled,
		DateTime? scheduledAt,
	}) async {
		final db = FirebaseFirestore.instance;
		final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
		if (scheduled && scheduledAt != null && scheduledAt!.isAfter(DateTime.now().add(const Duration(minutes: 6)))) {
			// Schedule reminder 5 minutes before
			final reminderAt = scheduledAt!.subtract(const Duration(minutes: 5));
			await NotificationsService.scheduleReminderStatic(
				id: 'ride_${DateTime.now().millisecondsSinceEpoch}',
				when: reminderAt,
				title: 'Upcoming ride',
				body: 'Your scheduled ride is in 5 minutes. Continue or cancel?'
			);
		}
		final doc = await db.collection('rides').add({
			'riderId': uid,
			'type': _rideTypeForCapacity(capacity),
			'isScheduled': scheduled,
			'scheduledAt': scheduledAt?.toIso8601String(),
			'pickupAddress': origin,
			'destinationAddresses': dests,
			'pickupLat': oLat,
			'pickupLng': oLng,
			'destLat': dLat,
			'destLng': dLng,
			'createdAt': DateTime.now().toIso8601String(),
			'fareEstimate': fare,
			'etaMinutes': mins,
			'distanceKm': km,
			'vehicleClass': classLabel,
			'classCapacity': capacity,
			'notes': scheduled ? _scheduleMsg.text.trim() : null,
			'status': 'requested',
		});

		// Best-effort auto-assignment to an online transport provider
		try {
			final rideType = _rideTypeForCapacity(capacity);
			final subcategory = rideType == 'bus'
				? 'Bus'
				: rideType == 'tricycle'
					? 'Tricycle'
					: rideType == 'bike'
						? 'Bike'
						: 'Taxi';
			Query<Map<String, dynamic>> q = db
				.collection('provider_profiles')
				.where('service', isEqualTo: 'transport')
				.where('availabilityOnline', isEqualTo: true)
				.where('metadata.subcategory', isEqualTo: subcategory);
			final providersSnap = await q.limit(25).get(const GetOptions(source: Source.server));
			final candidates = providersSnap.docs
				.map((d) => d.data())
				.where((m) => (m['userId'] ?? '') != uid)
				.toList();
			if (candidates.isNotEmpty) {
				final picked = candidates[Math.Random().nextInt(candidates.length)];
				final driverId = (picked['userId'] ?? '').toString();
				if (driverId.isNotEmpty) {
					await db.collection('rides').doc(doc.id).set({'driverId': driverId}, SetOptions(merge: true));
				}
			}
		} catch (_) {/* ignore assignment failures */}

		if (!mounted) return;
		setState(() => _status = 'searching');
		final navigator = Navigator.of(context);
		showDialog(
			context: context,
			barrierDismissible: false,
			builder: (ctx) => AlertDialog(
				title: const Text('Finding drivers…'),
				content: const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
				actions: [TextButton(onPressed: () { try { _rideSub?.cancel(); } catch (_) {} Navigator.of(ctx).pop(); }, child: const Text('Cancel'))],
			),
		);

		bool navigated = false;
		_rideSub?.cancel();
		final rideRef = db.collection('rides').doc(doc.id);
		_rideSub = rideRef.snapshots().listen((snap) {
			final data = snap.data() ?? const {};
			final status = (data['status'] ?? '').toString();
			if (!navigated && (status == 'accepted' || status == 'arriving' || status == 'arrived' || status == 'enroute')) {
				if (navigator.canPop()) navigator.pop();
				context.pushNamed('trackRide', queryParameters: {'rideId': doc.id});
				navigated = true;
			}
		});

		Future.delayed(const Duration(seconds: 60), () {
			if (!mounted) return;
			if (!navigated) {
				try { _rideSub?.cancel(); } catch (_) {}
				if (navigator.canPop()) navigator.pop();
				setState(() => _status = 'idle');
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No driver found. Please try again.')));
			}
		});
	}

	Future<void> _requestRide() async {
		if (_submitting) return;
		final origin = _pickup.text.trim();
		final dests = _stops.map((e) => e.text.trim()).where((e) => e.isNotEmpty).toList();
		if (origin.isEmpty || dests.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a destination')));
			return;
		}
		setState(() { _status = 'requesting'; _submitting = true; });
		try {
			// Resolve coordinates with web fallback to Nominatim
			double oLat; double oLng; double dLat; double dLng;
			try {
				if (kIsWeb) {
					final o = await _geocodeWeb(origin);
					final d = await _geocodeWeb(dests.first);
					if (o == null || d == null) throw Exception('Could not resolve addresses.');
					oLat = o.$1; oLng = o.$2; dLat = d.$1; dLng = d.$2;
				} else {
					final oLocs = await gc.locationFromAddress(origin).catchError((_) => <gc.Location>[]);
					final dLocs = await gc.locationFromAddress(dests.first).catchError((_) => <gc.Location>[]);
					if (oLocs.isEmpty || dLocs.isEmpty) throw Exception('Could not resolve addresses.');
					oLat = oLocs.first.latitude; oLng = oLocs.first.longitude; dLat = dLocs.first.latitude; dLng = dLocs.first.longitude;
				}
			} catch (_) {
				throw Exception('Could not resolve addresses. Please refine search.');
			}

			double km;
			int mins;
			if (kIsWeb) {
				km = _haversineKm(oLat, oLng, dLat, dLng);
				final avgSpeedKmh = 25.0;
				mins = (km / avgSpeedKmh * 60).clamp(5, 90).round();
			} else {
				final matrix = await _distanceService.getMatrix(
					origin: '$oLat,$oLng',
					destinations: ['$dLat,$dLng'],
				);
				final rows = (matrix['rows'] as List?) ?? const [];
				final elements = rows.isNotEmpty ? (rows.first['elements'] as List? ?? const []) : const [];
				double meters = 0; int seconds = 0;
				for (final el in elements) {
					if (el is Map && el['status'] == 'OK') {
						final dist = (el['distance'] as Map?)?['value'];
						final dur = (el['duration'] as Map?)?['value'];
						if (dist is num) meters += dist.toDouble();
						if (dur is num) seconds += dur.toInt();
					}
				}
				km = meters > 0 ? meters / 1000.0 : 5.0;
				mins = seconds > 0 ? (seconds / 60).round() : 10;
			}
			if (!mounted) return;
			await _openClassSelection(origin: origin, dests: dests, oLat: oLat, oLng: oLng, dLat: dLat, dLng: dLng, km: km, mins: mins);
			setState(() => _status = 'idle');
		} catch (e) {
			setState(() => _status = 'idle');
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Request failed: $e')));
		} finally {
			if (mounted) setState(() { _submitting = false; });
		}
	}

	@override
	void dispose() {
		_rideSub?.cancel();
		super.dispose();
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text(
					'🚗 Transport',
					style: TextStyle(
						fontWeight: FontWeight.bold,
						fontSize: 20,
					),
				),
				backgroundColor: Colors.transparent,
				flexibleSpace: Container(
					decoration: const BoxDecoration(
						gradient: LinearGradient(
							colors: [Color(0xFF2196F3), Color(0xFF21CBF3)],
							begin: Alignment.topLeft,
							end: Alignment.bottomRight,
						),
					),
				),
				foregroundColor: Colors.white,
			),
			body: Container(
				decoration: const BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
					),
				),
				child: ListView(
					padding: const EdgeInsets.all(16),
					children: [
						// Vehicle type selection
						Card(
							elevation: 8,
							shadowColor: Colors.blue.withOpacity(0.3),
							shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
							child: Container(
								decoration: BoxDecoration(
									gradient: const LinearGradient(
										colors: [Color(0xFFFAFAFA), Color(0xFFFFFFFF)],
									),
									borderRadius: BorderRadius.circular(16),
								),
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text(
											'🚙 Select Vehicle Type',
											style: TextStyle(
												fontSize: 16,
												fontWeight: FontWeight.bold,
												color: Colors.black87,
											),
										),
										const SizedBox(height: 12),
										Row(
											children: [
												Expanded(
													child: _VehicleTypeCard(
														type: 'taxi',
														label: 'Taxi',
														emoji: '🚕',
														isSelected: _type == 'taxi',
														onTap: () => setState(() => _type = 'taxi'),
													),
												),
												const SizedBox(width: 8),
												Expanded(
													child: _VehicleTypeCard(
														type: 'bike',
														label: 'Bike',
														emoji: '🏍️',
														isSelected: _type == 'bike',
														onTap: () => setState(() => _type = 'bike'),
													),
												),
												const SizedBox(width: 8),
												Expanded(
													child: _VehicleTypeCard(
														type: 'bus',
														label: 'Bus/Charter',
														emoji: '🚌',
														isSelected: _type == 'bus',
														onTap: () => setState(() => _type = 'bus'),
													),
												),
											],
										),
									],
								),
							),
						),
						
						const SizedBox(height: 16),
						AddressField(controller: _pickup, label: 'Pickup address'),
						const SizedBox(height: 8),
						const Text('Stops (max 5):', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
						for (int i = 0; i < _stops.length; i++)
							Row(children: [
								Expanded(child: AddressField(controller: _stops[i], label: 'Stop ${i + 1} (destination)')),
								IconButton(onPressed: () => _removeStop(i), icon: const Icon(Icons.remove_circle_outline)),
							]),
						TextButton.icon(onPressed: _addStop, icon: const Icon(Icons.add), label: const Text('Add stop')),
						const SizedBox(height: 16),
						
						// Action buttons
						Row(
							children: [
								Expanded(
									child: OutlinedButton.icon(
										onPressed: _estimate,
										icon: const Icon(Icons.calculate),
										label: const Text('Estimate fare'),
										style: OutlinedButton.styleFrom(
											padding: const EdgeInsets.symmetric(vertical: 16),
											side: const BorderSide(color: Colors.blue),
											foregroundColor: Colors.blue,
										),
									),
								),
								const SizedBox(width: 12),
								Expanded(
									child: FilledButton.icon(
										onPressed: _submitting ? null : _requestRide,
										icon: _submitting 
											? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
											: const Icon(Icons.directions_car),
										label: Text(_submitting ? 'Requesting...' : 'Request ride'),
										style: FilledButton.styleFrom(
											padding: const EdgeInsets.symmetric(vertical: 16),
											backgroundColor: Colors.blue.shade600,
										),
									),
								),
							],
						),
						
						const SizedBox(height: 16),
						
						// Fare info card
						if (_fare > 0) Card(
							color: Colors.green.shade50,
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									children: [
										FutureBuilder<String>(
											future: CountryConfigService.instance.getCurrencySymbol(),
											builder: (context, snap) => Text(
												'Fare estimate: ${(snap.data ?? '₦')}${_fare.toStringAsFixed(2)}',
												style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
											),
										),
										Text('Driver ETA: ${_eta} min', style: const TextStyle(color: Colors.green)),
										Text('Distance: ${_distanceKm.toStringAsFixed(1)} km', style: const TextStyle(color: Colors.green)),
									],
								),
							),
						),
						
						// Status indicator
						if (_status != 'idle') Card(
							color: Colors.blue.shade50,
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Row(
									children: [
										const CircularProgressIndicator(),
										const SizedBox(width: 16),
										Text('Status: $_status', style: const TextStyle(fontWeight: FontWeight.w600)),
									],
								),
							),
						),
					],
				),
			),
		);
	}
}

class _VehicleTypeCard extends StatelessWidget {
	const _VehicleTypeCard({
		required this.type,
		required this.label,
		required this.emoji,
		required this.isSelected,
		required this.onTap,
	});
	
	final String type;
	final String label;
	final String emoji;
	final bool isSelected;
	final VoidCallback onTap;
	
	@override
	Widget build(BuildContext context) {
		return InkWell(
			onTap: onTap,
			borderRadius: BorderRadius.circular(12),
			child: Container(
				padding: const EdgeInsets.symmetric(vertical: 12),
				decoration: BoxDecoration(
					gradient: isSelected 
						? const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF64B5F6)])
						: const LinearGradient(colors: [Color(0xFFF5F5F5), Color(0xFFEEEEEE)]),
					borderRadius: BorderRadius.circular(12),
					border: Border.all(
						color: isSelected ? Colors.blue : Colors.grey.shade300,
						width: isSelected ? 2 : 1,
					),
				),
				child: Column(
					children: [
						Text(emoji, style: const TextStyle(fontSize: 24)),
						const SizedBox(height: 4),
						Text(
							label,
							style: TextStyle(
								color: isSelected ? Colors.white : Colors.black87,
								fontWeight: FontWeight.w600,
								fontSize: 12,
							),
						),
					],
				),
			),
		);
	}
}

// Web geocode helper using Nominatim
Future<(double,double)?> _geocodeWeb(String input) async {
	try {
		final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(queryParameters: {
			'q': input,
			'format': 'json',
			'limit': '1',
			'addressdetails': '0',
			'email': 'support@zippup.app',
		});
		final res = await http.get(uri, headers: {'Accept': 'application/json'});
		if (res.statusCode != 200) return null;
		final List data = res.body.isNotEmpty ? (jsonDecode(res.body) as List) : const [];
		if (data.isEmpty) return null;
		final lat = double.tryParse(data.first['lat']?.toString() ?? '');
		final lon = double.tryParse(data.first['lon']?.toString() ?? '');
		if (lat == null || lon == null) return null;
		return (lat, lon);
	} catch (_) {
		return null;
	}
}