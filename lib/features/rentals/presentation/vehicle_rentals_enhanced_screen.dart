import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/location/location_service.dart';
import 'package:geolocator/geolocator.dart' as geo;

class VehicleRentalsEnhancedScreen extends StatefulWidget {
	const VehicleRentalsEnhancedScreen({super.key});

	@override
	State<VehicleRentalsEnhancedScreen> createState() => _VehicleRentalsEnhancedScreenState();
}

class _VehicleRentalsEnhancedScreenState extends State<VehicleRentalsEnhancedScreen> {
	final TextEditingController _searchController = TextEditingController();
	String _searchQuery = '';
	final List<String> _vehicleTypes = const ['Luxury car','Normal car','Bus','Truck','Tractor','Motorcycle','Bicycle'];
	String _selectedType = 'Normal car';
	geo.Position? _currentLocation;

	@override
	void initState() {
		super.initState();
		_getCurrentLocation();
	}

	Future<void> _getCurrentLocation() async {
		final position = await LocationService.getCurrentPosition();
		if (mounted) {
			setState(() => _currentLocation = position);
		}
	}

	double _calculateDistance(Map<String, dynamic> provider) {
		final lat = (provider['lat'] as num?)?.toDouble();
		final lng = (provider['lng'] as num?)?.toDouble();
		if (_currentLocation == null || lat == null || lng == null) return 1e9;
		final meters = geo.Geolocator.distanceBetween(_currentLocation!.latitude, _currentLocation!.longitude, lat, lng);
		return meters / 1000.0;
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('🚗 Vehicle Rentals'),
				backgroundColor: Colors.blue.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
			),
			body: Container(
				decoration: const BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
					),
				),
				child: Column(
					children: [
						// Search bar
						Container(
							margin: const EdgeInsets.all(16),
							decoration: BoxDecoration(
								color: Colors.white,
								borderRadius: BorderRadius.circular(12),
								boxShadow: [
									BoxShadow(
										color: Colors.black.withOpacity(0.1),
										blurRadius: 8,
										offset: const Offset(0, 2),
									),
								],
							),
							child: TextField(
								controller: _searchController,
								style: const TextStyle(color: Colors.black),
								onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
								decoration: const InputDecoration(
									hintText: '🔍 Search vehicles (BMW, Toyota, Bus, etc.)',
									hintStyle: TextStyle(color: Colors.black54),
									prefixIcon: Icon(Icons.search, color: Colors.black54),
									border: InputBorder.none,
									contentPadding: EdgeInsets.all(16),
								),
							),
						),

						// Vehicle type filter
						SingleChildScrollView(
							scrollDirection: Axis.horizontal,
							padding: const EdgeInsets.symmetric(horizontal: 16),
							child: Row(
								children: _vehicleTypes.map((type) {
									final isSelected = type == _selectedType;
									return Padding(
										padding: const EdgeInsets.only(right: 8),
										child: FilterChip(
											label: Text(type, style: const TextStyle(color: Colors.black)),
											selected: isSelected,
											onSelected: (selected) {
												setState(() => _selectedType = type);
											},
											selectedColor: Colors.blue.shade100,
										),
									);
								}).toList(),
							),
						),

						const SizedBox(height: 16),

						// Vehicle providers
						Expanded(
							child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
								stream: FirebaseFirestore.instance
									.collection('vehicle_providers')
									.where('vehicleType', isEqualTo: _selectedType)
									.where('available', isEqualTo: true)
									.snapshots(),
								builder: (context, snapshot) {
									if (snapshot.connectionState == ConnectionState.waiting) {
										return const Center(child: CircularProgressIndicator());
									}

									if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
										return Center(
											child: Column(
												mainAxisAlignment: MainAxisAlignment.center,
												children: [
													const Icon(Icons.directions_car, size: 64, color: Colors.grey),
													const SizedBox(height: 16),
													Text('No $_selectedType available', style: const TextStyle(fontSize: 18, color: Colors.grey)),
													const Text('Try a different vehicle type', style: TextStyle(color: Colors.grey)),
												],
											),
										);
									}

									final providers = snapshot.data!.docs.where((doc) {
										final data = doc.data();
										final vehicleName = (data['vehicleName'] ?? '').toString().toLowerCase();
										final brand = (data['brand'] ?? '').toString().toLowerCase();
										
										if (_searchQuery.isNotEmpty) {
											return vehicleName.contains(_searchQuery) || brand.contains(_searchQuery);
										}
										return true;
									}).toList();

									return ListView.builder(
										padding: const EdgeInsets.symmetric(horizontal: 16),
										itemCount: providers.length,
										itemBuilder: (context, index) {
											final provider = providers[index];
											final data = provider.data();
											return _VehicleProviderCard(
												providerId: provider.id,
												providerData: data,
												distance: _calculateDistance(data),
												onBook: () => _showBookingDialog(context, provider.id, data),
											);
										},
									);
								},
							),
						),
					],
				),
			),
		);
	}

	void _showBookingDialog(BuildContext context, String providerId, Map<String, dynamic> vehicleData) {
		DateTime? startDate;
		DateTime? endDate;
		int days = 1;

		showDialog(
			context: context,
			builder: (ctx) => StatefulBuilder(
				builder: (context, setDialogState) {
					final dailyRate = (vehicleData['dailyRate'] as num?)?.toDouble() ?? 0.0;
					final total = dailyRate * days;

					return AlertDialog(
						title: Text('🚗 Book ${vehicleData['vehicleName']}'),
						content: SingleChildScrollView(
							child: Column(
								mainAxisSize: MainAxisSize.min,
								children: [
									// Start date
									OutlinedButton.icon(
										onPressed: () async {
											final date = await showDatePicker(
												context: ctx,
												firstDate: DateTime.now(),
												lastDate: DateTime.now().add(const Duration(days: 365)),
												initialDate: startDate ?? DateTime.now().add(const Duration(days: 1)),
											);
											if (date != null) {
												setDialogState(() {
													startDate = date;
													endDate = date.add(Duration(days: days));
												});
											}
										},
										icon: const Icon(Icons.calendar_today),
										label: Text(startDate == null ? 'Select Start Date' : '${startDate!.day}/${startDate!.month}/${startDate!.year}'),
									),
									const SizedBox(height: 12),
									
									// Duration
									Row(
										children: [
											const Text('Days: '),
											IconButton(
												onPressed: days > 1 ? () => setDialogState(() {
													days--;
													if (startDate != null) endDate = startDate!.add(Duration(days: days));
												}) : null,
												icon: const Icon(Icons.remove),
											),
											Text('$days', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
											IconButton(
												onPressed: () => setDialogState(() {
													days++;
													if (startDate != null) endDate = startDate!.add(Duration(days: days));
												}),
												icon: const Icon(Icons.add),
											),
										],
									),
									const SizedBox(height: 12),
									
									// Total cost
									Container(
										padding: const EdgeInsets.all(12),
										decoration: BoxDecoration(
											color: Colors.green.shade50,
											borderRadius: BorderRadius.circular(8),
										),
										child: Column(
											children: [
												Text('Daily Rate: ₦${dailyRate.toStringAsFixed(0)}'),
												Text('Total Cost: ₦${total.toStringAsFixed(0)}', 
													style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
											],
										),
									),
								],
							),
						),
						actions: [
							TextButton(
								onPressed: () => Navigator.pop(ctx),
								child: const Text('Cancel'),
							),
							FilledButton(
								onPressed: startDate != null ? () async {
									await _bookVehicle(context, providerId, vehicleData, startDate!, endDate!, total);
									Navigator.pop(ctx);
								} : null,
								child: const Text('Book Now'),
							),
						],
					);
				},
			),
		);
	}

	Future<void> _bookVehicle(BuildContext context, String providerId, Map<String, dynamic> vehicleData, DateTime startDate, DateTime endDate, double total) async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) return;

			// Create rental booking
			await FirebaseFirestore.instance.collection('rental_bookings').add({
				'userId': uid,
				'providerId': providerId,
				'vehicleId': providerId,
				'vehicleName': vehicleData['vehicleName'],
				'startDate': startDate.toIso8601String(),
				'endDate': endDate.toIso8601String(),
				'totalCost': total,
				'status': 'requested',
				'createdAt': DateTime.now().toIso8601String(),
				'category': 'vehicle_rental',
			});

			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('✅ Vehicle rental request submitted!')),
				);
			}
		} catch (e) {
			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Booking failed: $e')),
				);
			}
		}
	}
}

class _VehicleProviderCard extends StatelessWidget {
	const _VehicleProviderCard({
		required this.providerId,
		required this.providerData,
		required this.distance,
		required this.onBook,
	});

	final String providerId;
	final Map<String, dynamic> providerData;
	final double distance;
	final VoidCallback onBook;

	@override
	Widget build(BuildContext context) {
		final vehicleName = providerData['vehicleName'] ?? 'Vehicle';
		final brand = providerData['brand'] ?? '';
		final model = providerData['model'] ?? '';
		final year = providerData['year'] ?? '';
		final dailyRate = (providerData['dailyRate'] as num?)?.toDouble() ?? 0.0;
		final rating = (providerData['rating'] as num?)?.toDouble() ?? 0.0;
		final images = (providerData['images'] as List?)?.cast<String>() ?? [];
		final features = (providerData['features'] as List?)?.cast<String>() ?? [];

		return Container(
			margin: const EdgeInsets.only(bottom: 16),
			decoration: BoxDecoration(
				gradient: const LinearGradient(
					colors: [Color(0xFFFFFFFF), Color(0xFFF8F9FA)],
				),
				borderRadius: BorderRadius.circular(16),
				boxShadow: [
					BoxShadow(
						color: Colors.black.withOpacity(0.1),
						blurRadius: 8,
						offset: const Offset(0, 4),
					),
				],
			),
			child: InkWell(
				onTap: onBook,
				borderRadius: BorderRadius.circular(16),
				child: Padding(
					padding: const EdgeInsets.all(16),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Row(
								children: [
									// Vehicle image
									Container(
										width: 100,
										height: 80,
										decoration: BoxDecoration(
											color: Colors.blue.shade50,
											borderRadius: BorderRadius.circular(12),
										),
										child: images.isNotEmpty
											? ClipRRect(
													borderRadius: BorderRadius.circular(12),
													child: Image.network(
														images.first,
														fit: BoxFit.cover,
														errorBuilder: (_, __, ___) => const Center(
															child: Icon(Icons.directions_car, size: 32, color: Colors.blue),
														),
													),
												)
											: const Center(
													child: Icon(Icons.directions_car, size: 32, color: Colors.blue),
												),
									),
									const SizedBox(width: 16),

									// Vehicle details
									Expanded(
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Text(
													vehicleName,
													style: const TextStyle(
														fontWeight: FontWeight.bold,
														fontSize: 16,
														color: Colors.black,
													),
												),
												if (brand.isNotEmpty || model.isNotEmpty)
													Text(
														'$brand $model $year'.trim(),
														style: const TextStyle(color: Colors.black54, fontSize: 14),
													),
												const SizedBox(height: 8),
												Row(
													children: [
														Row(
															children: List.generate(5, (index) {
																return Icon(
																	index < rating ? Icons.star : Icons.star_border,
																	color: Colors.amber,
																	size: 16,
																);
															}),
														),
														const SizedBox(width: 4),
														Text('(${rating.toStringAsFixed(1)})', style: const TextStyle(fontSize: 12)),
													],
												),
												const SizedBox(height: 4),
												if (distance < 1e9)
													Text(
														'📍 ${distance.toStringAsFixed(1)} km away',
														style: const TextStyle(color: Colors.black54, fontSize: 12),
													),
											],
										),
									),

									// Price and book button
									Column(
										crossAxisAlignment: CrossAxisAlignment.end,
										children: [
											Text(
												'₦${dailyRate.toStringAsFixed(0)}',
												style: const TextStyle(
													fontWeight: FontWeight.bold,
													fontSize: 18,
													color: Colors.black,
												),
											),
											const Text(
												'per day',
												style: TextStyle(color: Colors.black54, fontSize: 12),
											),
											const SizedBox(height: 8),
											FilledButton(
												onPressed: onBook,
												style: FilledButton.styleFrom(
													backgroundColor: Colors.blue.shade600,
													minimumSize: const Size(80, 32),
												),
												child: const Text('BOOK', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
											),
										],
									),
								],
							),

							// Features
							if (features.isNotEmpty) ...[
								const SizedBox(height: 12),
								const Text('Features:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
								const SizedBox(height: 6),
								Wrap(
									spacing: 6,
									children: features.take(4).map((feature) {
										return Container(
											padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
											decoration: BoxDecoration(
												color: Colors.blue.shade100,
												borderRadius: BorderRadius.circular(8),
											),
											child: Text(
												feature,
												style: TextStyle(
													color: Colors.blue.shade700,
													fontSize: 11,
													fontWeight: FontWeight.w500,
												),
											),
										);
									}).toList(),
								),
							],

							// Image gallery preview
							if (images.length > 1) ...[
								const SizedBox(height: 12),
								SizedBox(
									height: 60,
									child: ListView.builder(
										scrollDirection: Axis.horizontal,
										itemCount: images.length.clamp(0, 5),
										itemBuilder: (context, index) {
											return Container(
												margin: const EdgeInsets.only(right: 8),
												width: 80,
												decoration: BoxDecoration(
													borderRadius: BorderRadius.circular(8),
												),
												child: ClipRRect(
													borderRadius: BorderRadius.circular(8),
													child: Image.network(
														images[index],
														fit: BoxFit.cover,
														errorBuilder: (_, __, ___) => Container(
															color: Colors.grey.shade200,
															child: const Icon(Icons.image, color: Colors.grey),
														),
													),
												),
											);
										},
									),
								),
							],
						],
					),
				),
			),
		);
	}
}