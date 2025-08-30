import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/location/location_service.dart';

class PersonalBookingScreen extends StatefulWidget {
	const PersonalBookingScreen({super.key});

	@override
	State<PersonalBookingScreen> createState() => _PersonalBookingScreenState();
}

class _PersonalBookingScreenState extends State<PersonalBookingScreen> {
	final TextEditingController _serviceController = TextEditingController();
	final TextEditingController _addressController = TextEditingController();
	final TextEditingController _descriptionController = TextEditingController();
	String _selectedType = 'beauty';
	int _selectedDuration = 60;
	bool _isBooking = false;

	final Map<String, List<String>> _personalServices = const {
		'beauty': ['Hair Cut', 'Hair Styling', 'Makeup', 'Facial', 'Eyebrow Threading'],
		'wellness': ['Massage', 'Spa Treatment', 'Reflexology', 'Aromatherapy'],
		'fitness': ['Personal Trainer', 'Yoga Instructor', 'Physiotherapy', 'Nutrition Coaching'],
		'tutoring': ['Math Tutor', 'Language Tutor', 'Music Lessons', 'Art Classes'],
		'cleaning': ['House Cleaning', 'Deep Cleaning', 'Laundry Service', 'Organizing'],
		'childcare': ['Babysitter', 'Nanny', 'Child Tutor', 'Child Activities'],
	};

	Future<void> _bookPersonalService() async {
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

		setState(() => _isBooking = true);

		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Please sign in to book services'))
				);
				return;
			}

			// Create personal booking
			final bookingRef = FirebaseFirestore.instance.collection('personal_bookings').doc();
			final hourlyRate = _selectedType == 'tutoring' ? 3000.0 : 
							  (_selectedType == 'fitness' ? 4000.0 : 2500.0);
			final feeAmount = (hourlyRate * _selectedDuration / 60);

			await bookingRef.set({
				'clientId': uid,
				'type': _selectedType,
				'serviceCategory': service,
				'description': description.isEmpty ? service : description,
				'serviceAddress': address,
				'createdAt': DateTime.now().toIso8601String(),
				'isScheduled': false,
				'feeEstimate': feeAmount,
				'etaMinutes': 20,
				'status': 'requested',
				'currency': 'NGN',
				'paymentMethod': 'card',
				'durationMinutes': _selectedDuration,
			});

			// Navigate to tracking screen
			if (mounted) {
				context.push('/track/personal?bookingId=${bookingRef.id}');
			}

		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Booking failed: $e'))
				);
			}
		} finally {
			setState(() => _isBooking = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('💆 Personal Services'),
				backgroundColor: Colors.purple.shade50,
			),
			body: SingleChildScrollView(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						// Service type selection
						Card(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text('Service Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
										const SizedBox(height: 12),
										Wrap(
											spacing: 8,
											children: _personalServices.keys.map((type) {
												final isSelected = type == _selectedType;
												return FilterChip(
													label: Text(type.toUpperCase()),
													selected: isSelected,
													onSelected: (selected) {
														setState(() {
															_selectedType = type;
															_serviceController.clear();
														});
													},
													selectedColor: Colors.purple.shade100,
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
										const Text('What service do you need?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
										const SizedBox(height: 12),
										TextField(
											controller: _serviceController,
											decoration: const InputDecoration(
												labelText: 'Search for personal service',
												border: OutlineInputBorder(),
												prefixIcon: Icon(Icons.search),
											),
										),
										const SizedBox(height: 12),
										const Text('Popular services:', style: TextStyle(fontWeight: FontWeight.w600)),
										const SizedBox(height: 8),
										Wrap(
											spacing: 8,
											children: _personalServices[_selectedType]!.map((service) {
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
										TextField(
											controller: _addressController,
											decoration: const InputDecoration(
												labelText: 'Where do you need the service?',
												border: OutlineInputBorder(),
												prefixIcon: Icon(Icons.location_on),
											),
											maxLines: 2,
										),
									],
								),
							),
						),

						const SizedBox(height: 16),

						// Duration selection
						Card(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text('Service Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
										const SizedBox(height: 12),
										RadioListTile<int>(
											value: 30,
											groupValue: _selectedDuration,
											onChanged: (value) => setState(() => _selectedDuration = value!),
											title: const Text('30 minutes'),
										),
										RadioListTile<int>(
											value: 60,
											groupValue: _selectedDuration,
											onChanged: (value) => setState(() => _selectedDuration = value!),
											title: const Text('1 hour'),
										),
										RadioListTile<int>(
											value: 90,
											groupValue: _selectedDuration,
											onChanged: (value) => setState(() => _selectedDuration = value!),
											title: const Text('1.5 hours'),
										),
										RadioListTile<int>(
											value: 120,
											groupValue: _selectedDuration,
											onChanged: (value) => setState(() => _selectedDuration = value!),
											title: const Text('2 hours'),
										),
									],
								),
							),
						),

						const SizedBox(height: 16),

						// Service description
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

						const SizedBox(height: 24),

						// Book button
						SizedBox(
							height: 56,
							child: FilledButton.icon(
								onPressed: _isBooking ? null : _bookPersonalService,
								icon: _isBooking 
									? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
									: const Icon(Icons.person_search),
								label: Text(_isBooking ? 'Finding Providers...' : 'Find & Book Provider'),
								style: FilledButton.styleFrom(
									backgroundColor: Colors.purple.shade600,
									textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
								),
							),
						),

						const SizedBox(height: 16),

						// Info card
						Card(
							color: Colors.purple.shade50,
							child: const Padding(
								padding: EdgeInsets.all(16),
								child: Column(
									children: [
										Icon(Icons.info_outline, color: Colors.purple),
										SizedBox(height: 8),
										Text(
											'We\'ll find available personal service providers near you and send your request. You\'ll get notified when someone accepts!',
											textAlign: TextAlign.center,
											style: TextStyle(color: Colors.purple),
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