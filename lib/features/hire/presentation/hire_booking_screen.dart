import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/location/location_service.dart';
import 'package:zippup/services/currency/currency_service.dart';
import 'package:zippup/common/widgets/address_field.dart';
import 'package:geolocator/geolocator.dart' as geo;

class HireBookingScreen extends StatefulWidget {
	const HireBookingScreen({super.key, this.initialCategory});
	final String? initialCategory;

	@override
	State<HireBookingScreen> createState() => _HireBookingScreenState();
}

class _HireBookingScreenState extends State<HireBookingScreen> {
	final TextEditingController _serviceController = TextEditingController();
	final TextEditingController _addressController = TextEditingController();
	final TextEditingController _descriptionController = TextEditingController();
	String _selectedCategory = 'home';
	String _selectedClass = 'Basic';
	geo.Position? _currentLocation;
	bool _isSearching = false;
	bool _scheduled = false;
	DateTime? _scheduledAt;

	final Map<String, List<String>> _serviceExamples = const {
		'home': ['Plumber', 'Electrician', 'Cleaner', 'Painter', 'Carpenter', 'Pest Control'],
		'tech': ['Phone Repair', 'Computer Repair', 'Network Setup', 'CCTV Install', 'Data Recovery'],
		'construction': ['Builder', 'Roofer', 'Tiler', 'Welder', 'Scaffolding'],
		'auto': ['Mechanic', 'Tyre Service', 'Battery Service', 'Fuel Delivery'],
		'personal': ['Barber', 'Hairstylist', 'Massage', 'Nails', 'Makeup Artist'],
	};

	@override
	void initState() {
		super.initState();
		if (widget.initialCategory != null) {
			_selectedCategory = widget.initialCategory!;
		}
		_getCurrentLocation();
	}

	Future<void> _getCurrentLocation() async {
		final position = await LocationService.getCurrentPosition();
		if (mounted) {
			setState(() => _currentLocation = position);
		}
	}

	Future<void> _searchAndBook() async {
		final service = _serviceController.text.trim();
		final address = _addressController.text.trim();
		final description = _descriptionController.text.trim();

		if (service.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please enter the service you need'))
			);
			return;
		}

		if (address.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please enter service address'))
			);
			return;
		}

		setState(() => _isSearching = true);

		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Please sign in to book services'))
				);
				return;
			}

			// Create hire booking
			final bookingRef = FirebaseFirestore.instance.collection('hire_bookings').doc();
			final feeAmount = _selectedClass == 'Basic' ? 2000.0 : (_selectedClass == 'Standard' ? 3500.0 : 5000.0);

			await bookingRef.set({
				'clientId': uid,
				'type': _selectedCategory,
				'serviceCategory': service,
				'description': description.isEmpty ? service : description,
				'serviceAddress': address,
				'createdAt': DateTime.now().toIso8601String(),
				'isScheduled': _scheduled,
				'scheduledAt': _scheduled ? _scheduledAt?.toIso8601String() : null,
				'feeEstimate': feeAmount,
				'etaMinutes': 30,
				'status': 'requested',
				'currency': await CurrencyService.getCode(),
				'serviceClass': _selectedClass,
				'paymentMethod': 'card',
			});

			// Navigate to transport-style search screen
			if (mounted) {
				context.push('/hire/search?bookingId=${bookingRef.id}');
			}

		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Booking failed: $e'))
				);
			}
		} finally {
			setState(() => _isSearching = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('🔧 Hire Services'),
				backgroundColor: Colors.blue.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
			),
			body: SingleChildScrollView(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						// Service category selection
						Card(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text('Service Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
										const SizedBox(height: 12),
										Wrap(
											spacing: 8,
											children: _serviceExamples.keys.map((category) {
												final isSelected = category == _selectedCategory;
												return FilterChip(
													label: Text(category.toUpperCase()),
													selected: isSelected,
													onSelected: (selected) {
														setState(() {
															_selectedCategory = category;
															_serviceController.clear();
														});
													},
													selectedColor: Colors.blue.shade100,
												);
											}).toList(),
										),
									],
								),
							),
						),

						const SizedBox(height: 16),

						// Service search
						Card(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text('What service do you need?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
										const SizedBox(height: 12),
										TextField(
											controller: _serviceController,
											decoration: InputDecoration(
												labelText: 'Search for service (e.g., Plumber, Electrician)',
												border: const OutlineInputBorder(),
												prefixIcon: const Icon(Icons.search),
											),
										),
										const SizedBox(height: 12),
										const Text('Popular services:', style: TextStyle(fontWeight: FontWeight.w600)),
										const SizedBox(height: 8),
										Wrap(
											spacing: 8,
											children: _serviceExamples[_selectedCategory]!.map((service) {
												return ActionChip(
													label: Text(service),
													onPressed: () {
														_serviceController.text = service;
													},
												);
											}).toList(),
										),
									],
								),
							),
						),

						const SizedBox(height: 16),

						// Service address
						Card(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text('Service Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
										const SizedBox(height: 12),
										AddressField(
											controller: _addressController,
											label: 'Where do you need the service?',
											hint: 'Enter your address for service location',
										),
									],
								),
							),
						),

						const SizedBox(height: 16),

						// Service details
						Card(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text('Additional Details (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
										const SizedBox(height: 12),
										TextField(
											controller: _descriptionController,
											decoration: const InputDecoration(
												labelText: 'Describe your specific needs...',
												border: OutlineInputBorder(),
												prefixIcon: Icon(Icons.description),
											),
											maxLines: 3,
										),
									],
								),
							),
						),

						const SizedBox(height: 16),

						// Service class selection
						Card(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text('Service Class', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
										const SizedBox(height: 12),
										RadioListTile<String>(
											value: 'Basic',
											groupValue: _selectedClass,
											onChanged: (value) => setState(() => _selectedClass = value!),
											title: FutureBuilder<String>(
												future: CurrencyService.formatAmount(2000),
												builder: (context, snapshot) {
													return Text('Basic • ${snapshot.data ?? "${CurrencyService.getCachedSymbol()}2,000"}');
												},
											),
											subtitle: const Text('Standard service quality'),
										),
										RadioListTile<String>(
											value: 'Standard',
											groupValue: _selectedClass,
											onChanged: (value) => setState(() => _selectedClass = value!),
											title: FutureBuilder<String>(
												future: CurrencyService.formatAmount(3500),
												builder: (context, snapshot) {
													return Text('Standard • ${snapshot.data ?? "${CurrencyService.getCachedSymbol()}3,500"}');
												},
											),
											subtitle: const Text('Enhanced service with guarantees'),
										),
										RadioListTile<String>(
											value: 'Pro',
											groupValue: _selectedClass,
											onChanged: (value) => setState(() => _selectedClass = value!),
											title: FutureBuilder<String>(
												future: CurrencyService.formatAmount(5000),
												builder: (context, snapshot) {
													return Text('Pro • ${snapshot.data ?? "${CurrencyService.getCachedSymbol()}5,000"}');
												},
											),
											subtitle: const Text('Premium service with full support'),
										),
									],
								),
							),
						),

						const SizedBox(height: 16),

						// Schedule booking section (like transport and moving)
						Card(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										SwitchListTile(
											title: const Text('Schedule Booking', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
											subtitle: const Text('Book for a future date and time', style: TextStyle(color: Colors.black54)),
											value: _scheduled,
											onChanged: (v) => setState(() => _scheduled = v),
											activeColor: Colors.blue,
										),
										if (_scheduled) ...[
											ListTile(
												title: const Text('Select Date & Time', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
												subtitle: Text(
													_scheduledAt == null 
														? 'Tap to pick date and time' 
														: '${_scheduledAt!.toString().substring(0, 16)}',
													style: const TextStyle(color: Colors.black54),
												),
												leading: const Icon(Icons.schedule, color: Colors.blue),
												onTap: () async {
													final date = await showDatePicker(
														context: context,
														initialDate: DateTime.now().add(const Duration(hours: 1)),
														firstDate: DateTime.now(),
														lastDate: DateTime.now().add(const Duration(days: 30)),
													);
													if (date != null && mounted) {
														final time = await showTimePicker(
															context: context,
															initialTime: TimeOfDay.now(),
														);
														if (time != null && mounted) {
															setState(() {
																_scheduledAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
															});
														}
													}
												},
											),
										],
									],
								),
							),
						),

						const SizedBox(height: 24),

						// Book button
						SizedBox(
							height: 56,
							child: FilledButton.icon(
								onPressed: _isSearching ? null : _searchAndBook,
								icon: _isSearching 
									? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
									: const Icon(Icons.search),
								label: Text(_isSearching ? 'Finding Providers...' : 'Find & Book Provider'),
								style: FilledButton.styleFrom(
									backgroundColor: Colors.blue.shade600,
									textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
								),
							),
						),

						const SizedBox(height: 16),

						// Info card
						Card(
							color: Colors.blue.shade50,
							child: const Padding(
								padding: EdgeInsets.all(16),
								child: Column(
									children: [
										Icon(Icons.info_outline, color: Colors.blue),
										SizedBox(height: 8),
										Text(
											'We\'ll automatically find available providers near your location and send your request. You\'ll get notified when a provider accepts!',
											textAlign: TextAlign.center,
											style: TextStyle(color: Colors.blue),
										),
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