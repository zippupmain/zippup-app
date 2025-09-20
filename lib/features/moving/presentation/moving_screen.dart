import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/widgets/address_field.dart';
import 'package:zippup/services/location/location_service.dart';
import 'package:zippup/services/currency/currency_service.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' as Math;
import 'dart:async';
import 'package:zippup/core/config/country_config_service.dart';

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
			? ['Intra-City', 'Intra-State', 'Nationwide'] // Corrected capitalization
			: (_subcategory == 'truck' ? ['Small Truck', 'Medium Truck', 'Large Truck'] : 
			   _subcategory == 'pickup' ? ['Small Pickup', 'Large Pickup'] : ['Intra-City', 'Intra-State', 'Nationwide']);
		final images = _subcategory == 'courier'
			? ['assets/images/courier_car.png', 'assets/images/courier_van.png', 'assets/images/courier_big_van.png'] // Updated image names
			: (_subcategory == 'truck'
				? ['assets/images/truck_small.png','assets/images/truck_medium.png','assets/images/truck_large.png']
				: ['assets/images/pickup_small.png','assets/images/pickup_large.png']);
		final classEmojis = _subcategory == 'courier'
			? ['🚗', '🚐', '🚛'] // Updated: car, small van, big courier van
			: (_subcategory == 'truck' ? ['🚚', '🚛', '🚜'] : 
			   _subcategory == 'pickup' ? ['🛻', '🚐'] : ['🚗', '🚐', '🚛']);
		
		bool modalScheduled = _scheduled;
		DateTime? modalScheduledAt = _scheduledAt;
		
		await showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) {
			return StatefulBuilder(builder: (ctx, setModalState) {
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
						child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Text(
								'📦 Choose ${_subcategory.toUpperCase()} Size',
								style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
							),
							const SizedBox(height: 20),
							ListView.separated(
								shrinkWrap: true,
								physics: const NeverScrollableScrollPhysics(),
								itemCount: titles.length,
								separatorBuilder: (_, __) => const SizedBox(height: 12),
								itemBuilder: (ctx, i) {
									final title = titles[i];
									final emoji = classEmojis[i];
									final base = _subcategory == 'courier' ? (i == 0 ? 1500.0 : i == 1 ? 3500.0 : 8000.0) : (_subcategory == 'truck' ? [5000.0, 7500.0, 10000.0][i] : [3000.0, 4500.0][i]);
									final km = 8.0;
									final eta = 20 + i * 5;
									final price = base + km * (_subcategory == 'courier' ? (i==0?100: i==1?150: 250) : (_subcategory=='truck'? (i==0?250: i==1?300:350): (i==0?180:220)));
									
									return Container(
										decoration: BoxDecoration(
											gradient: const LinearGradient(
												colors: [Color(0xFFE8EAF6), Color(0xFFC5CAE9)],
											),
											borderRadius: BorderRadius.circular(16),
											border: Border.all(color: Colors.indigo.shade200),
										),
										child: ListTile(
											contentPadding: const EdgeInsets.all(16),
											leading: Container(
												padding: const EdgeInsets.all(12),
												decoration: BoxDecoration(
													color: Colors.white,
													borderRadius: BorderRadius.circular(12),
												),
												child: Text(emoji, style: const TextStyle(fontSize: 28)),
											),
											title: Text(
												title,
												style: const TextStyle(
													fontWeight: FontWeight.bold,
													color: Colors.indigo,
												),
											),
											subtitle: Text(
												'ETA ${eta} min • ${km.toStringAsFixed(1)} km',
												style: const TextStyle(color: Colors.indigo),
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
													builder: (context, snap) => Text(
														'${snap.data ?? CurrencyService.getCachedSymbol()}${price.toStringAsFixed(0)}',
														style: const TextStyle(
															fontWeight: FontWeight.bold,
															color: Colors.white,
														),
													),
												),
											),
											onTap: () {
												Navigator.pop(ctx);
												// Update main state before submit
												setState(() {
													_scheduled = modalScheduled;
													_scheduledAt = modalScheduledAt;
												});
												_submit(chosenClass: title, price: price);
											},
										),
									);
								},
							),
							const SizedBox(height: 20),
							
							// Schedule booking section - like transport
							SwitchListTile(
								title: const Text('Schedule Booking', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
								subtitle: const Text('Book for a future date and time', style: TextStyle(color: Colors.black54)),
								value: modalScheduled,
								onChanged: (v) => setModalState(() => modalScheduled = v),
								activeColor: Colors.indigo,
							),
							if (modalScheduled) ...[
								ListTile(
									title: const Text('Select Date', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
									subtitle: Text(
										modalScheduledAt == null ? 'Tap to pick a date' : '${modalScheduledAt!.year}-${modalScheduledAt!.month.toString().padLeft(2,'0')}-${modalScheduledAt!.day.toString().padLeft(2,'0')}',
										style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
									),
									leading: const Icon(Icons.calendar_today, color: Colors.indigo),
									onTap: () async {
										final now = DateTime.now();
										final date = await showDatePicker(context: ctx, firstDate: now, lastDate: now.add(const Duration(days: 60)), initialDate: modalScheduledAt ?? now);
										if (date == null) return;
										final base = modalScheduledAt ?? now;
										setModalState(() => modalScheduledAt = DateTime(date.year, date.month, date.day, base.hour, base.minute));
									},
								),
								ListTile(
									title: const Text('Select Time', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
									subtitle: Text(
										modalScheduledAt == null ? 'Tap to pick a time' : '${modalScheduledAt!.hour.toString().padLeft(2,'0')}:${modalScheduledAt!.minute.toString().padLeft(2,'0')}',
										style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
									),
									leading: const Icon(Icons.access_time, color: Colors.indigo),
									onTap: () async {
										final picked = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(modalScheduledAt ?? DateTime.now()));
										if (picked == null) return;
										final base = modalScheduledAt ?? DateTime.now();
										setModalState(() => modalScheduledAt = DateTime(base.year, base.month, base.day, picked.hour, picked.minute));
									},
								),
							],
							const SizedBox(height: 20),
						],
					),
				),
			);
		});
		}).then((_) {
			// Update main state with modal values
			setState(() {
				_scheduled = modalScheduled;
				_scheduledAt = modalScheduledAt;
			});
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
			final doc = await FirebaseFirestore.instance.collection('moving_bookings').add({
				'clientId': uid,
				'type': _subcategory,
				'description': _notes.text.trim().isEmpty ? chosenClass : _notes.text.trim(),
				'pickupAddress': pickup,
				'destinationAddress': dropoff,
				'createdAt': DateTime.now().toIso8601String(),
				'isScheduled': _scheduled,
				'scheduledAt': _scheduledAt?.toIso8601String(),
				'feeEstimate': price,
				'etaMinutes': 30,
				'status': 'requested',
				'currency': await CurrencyService.getCode(),
				'serviceClass': chosenClass,
				'paymentMethod': 'card',
				'status': 'requested',
			});

			// Best-effort auto-assignment to an online moving provider
			try {
				final db = FirebaseFirestore.instance;
				final req = _subcategory; // 'truck' | 'backie' | 'courier'
				final List<String> allowed = req == 'truck'
					? ['Truck']
					: req == 'backie'
						? ['Pickup/Backie', 'Backie/Pickup']
						: ['Courier'];
				final profs = await db
					.collection('provider_profiles')
					.where('service', isEqualTo: 'moving')
					.where('availabilityOnline', isEqualTo: true)
					.limit(50)
					.get(const GetOptions(source: Source.server));
				final candidates = profs.docs
					.map((d) => d.data())
					.where((m) {
						final meta = (m['metadata'] as Map<String, dynamic>?) ?? const {};
						final sub = (meta['subcategory'] ?? '').toString();
						return allowed.contains(sub);
					})
					.where((m) => (m['userId'] ?? '') != uid)
					.toList();
				if (candidates.isNotEmpty) {
					final chosen = candidates[Math.Random().nextInt(candidates.length)];
					final providerId = (chosen['userId'] ?? '').toString();
					if (providerId.isNotEmpty) {
						await db.collection('moving_bookings').doc(doc.id).set({'providerId': providerId}, SetOptions(merge: true));
					}
				}
			} catch (_) {/* ignore assignment failures */}
			
			// Navigate to transport-style search screen
			if (mounted) {
				context.push('/moving/search?bookingId=${doc.id}');
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
			appBar: AppBar(
				title: const Text(
					'📦 Moving Services',
					style: TextStyle(
						fontWeight: FontWeight.bold,
						fontSize: 20,
					),
				),
				backgroundColor: Colors.transparent,
				flexibleSpace: Container(
					decoration: const BoxDecoration(
						gradient: LinearGradient(
							colors: [Color(0xFF3F51B5), Color(0xFF7986CB)],
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
						colors: [Color(0xFFE8EAF6), Color(0xFFC5CAE9)],
					),
				),
				child: ListView(
					padding: const EdgeInsets.all(16),
					children: [
						// Moving type selection
						Card(
							elevation: 8,
							shadowColor: Colors.indigo.withOpacity(0.3),
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
											'🚚 Select Moving Type',
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
													child: _MovingTypeCard(
														type: 'truck',
														label: 'Truck',
														emoji: '🚚',
														isSelected: _subcategory == 'truck',
														onTap: () => setState(() => _subcategory = 'truck'),
													),
												),
												const SizedBox(width: 8),
												Expanded(
													child: _MovingTypeCard(
														type: 'pickup',
														label: 'Pickup',
														emoji: '🛻',
														isSelected: _subcategory == 'pickup',
														onTap: () => setState(() => _subcategory = 'pickup'),
													),
												),
												const SizedBox(width: 8),
												Expanded(
													child: _MovingTypeCard(
														type: 'courier',
														label: 'Courier',
														emoji: '📦',
														isSelected: _subcategory == 'courier',
														onTap: () => setState(() => _subcategory = 'courier'),
													),
												),
											],
										),
									],
								),
							),
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
					TextField(
						controller: _notes,
						style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
						decoration: const InputDecoration(
							labelText: 'Notes (optional)',
							labelStyle: TextStyle(color: Colors.black87),
							hintText: 'Add any special instructions...',
							hintStyle: TextStyle(color: Colors.black54),
							border: OutlineInputBorder(),
							filled: true,
							fillColor: Colors.white,
						),
						maxLines: 3,
					),
					const SizedBox(height: 12),
					FilledButton(onPressed: _submitting ? null : _openClassModal, child: Text(_submitting ? 'Submitting...' : 'Choose class')),
				],
				),
			),
		);
	}
}

class _MovingTypeCard extends StatelessWidget {
	const _MovingTypeCard({
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
						? const LinearGradient(colors: [Color(0xFF3F51B5), Color(0xFF7986CB)])
						: const LinearGradient(colors: [Color(0xFFF5F5F5), Color(0xFFEEEEEE)]),
					borderRadius: BorderRadius.circular(12),
					border: Border.all(
						color: isSelected ? Colors.indigo : Colors.grey.shade300,
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

