import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/widgets/address_field.dart';

class AppointmentBookingScreen extends StatefulWidget {
	const AppointmentBookingScreen({super.key, required this.serviceType});
	final String serviceType; // events, tutoring, education, creative, business

	@override
	State<AppointmentBookingScreen> createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
	final TextEditingController _serviceController = TextEditingController();
	final TextEditingController _addressController = TextEditingController();
	final TextEditingController _descriptionController = TextEditingController();
	final TextEditingController _budgetController = TextEditingController();
	DateTime? _preferredDate;
	TimeOfDay? _preferredTime;
	String _duration = '1 hour';
	String _priority = 'normal';
	bool _isBooking = false;

	final Map<String, Map<String, dynamic>> _serviceConfigs = {
		'events': {
			'title': '🎉 Events Planning',
			'gradient': const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFF06292)]),
			'services': ['Wedding Planning', 'Birthday Party', 'Corporate Event', 'Conference', 'Workshop', 'Product Launch'],
			'durations': ['2 hours', '4 hours', '6 hours', '8 hours', '1 day', '2 days', '3 days'],
			'basePrice': 50000.0,
		},
		'tutoring': {
			'title': '👨‍🏫 Tutoring Services',
			'gradient': const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF64B5F6)]),
			'services': ['Math Tutoring', 'English Tutoring', 'Science Tutoring', 'Language Learning', 'Test Prep', 'Homework Help'],
			'durations': ['30 minutes', '1 hour', '1.5 hours', '2 hours'],
			'basePrice': 3000.0,
		},
		'education': {
			'title': '📚 Education Services',
			'gradient': const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF81C784)]),
			'services': ['Online Course', 'Workshop', 'Seminar', 'Training Program', 'Certification Course', 'Skill Development'],
			'durations': ['1 hour', '2 hours', '4 hours', '1 day', '1 week', '1 month'],
			'basePrice': 15000.0,
		},
		'creative': {
			'title': '🎨 Creative Services',
			'gradient': const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFFB74D)]),
			'services': ['Photography', 'Videography', 'Graphic Design', 'Web Design', 'Logo Design', 'Content Creation'],
			'durations': ['1 hour', '2 hours', '4 hours', '1 day', '1 week'],
			'basePrice': 25000.0,
		},
		'business': {
			'title': '💼 Business Services',
			'gradient': const LinearGradient(colors: [Color(0xFF607D8B), Color(0xFF90A4AE)]),
			'services': ['Business Consulting', 'Legal Advice', 'Accounting', 'Marketing Strategy', 'HR Consulting', 'Financial Planning'],
			'durations': ['30 minutes', '1 hour', '2 hours', '4 hours', '1 day'],
			'basePrice': 20000.0,
		},
	};

	Map<String, dynamic> get _config => _serviceConfigs[widget.serviceType] ?? _serviceConfigs['tutoring']!;

	Future<void> _bookAppointment() async {
		final service = _serviceController.text.trim();
		final address = _addressController.text.trim();
		final description = _descriptionController.text.trim();
		final budget = double.tryParse(_budgetController.text.trim()) ?? 0;

		if (service.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please select a service'))
			);
			return;
		}

		if (_preferredDate == null || _preferredTime == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please select preferred date and time'))
			);
			return;
		}

		setState(() => _isBooking = true);

		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Please sign in to book appointments'))
				);
				return;
			}

			// Create appointment booking
			final appointmentRef = FirebaseFirestore.instance.collection('appointments').doc();
			final appointmentDateTime = DateTime(
				_preferredDate!.year,
				_preferredDate!.month,
				_preferredDate!.day,
				_preferredTime!.hour,
				_preferredTime!.minute,
			);

			await appointmentRef.set({
				'clientId': uid,
				'serviceType': widget.serviceType,
				'serviceCategory': service,
				'description': description.isEmpty ? service : description,
				'serviceAddress': address,
				'appointmentDateTime': appointmentDateTime.toIso8601String(),
				'duration': _duration,
				'priority': _priority,
				'budget': budget,
				'createdAt': DateTime.now().toIso8601String(),
				'status': 'requested',
				'currency': 'NGN',
				'paymentMethod': 'card',
			});

			// Navigate to provider list screen
			if (mounted) {
				context.push('/others/providers?serviceType=${widget.serviceType}&appointmentId=${appointmentRef.id}');
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
		final config = _config;
		final gradient = config['gradient'] as LinearGradient;
		final services = config['services'] as List<String>;
		final durations = config['durations'] as List<String>;

		return Scaffold(
			appBar: AppBar(
				title: Text(config['title'] as String),
				backgroundColor: gradient.colors.first.withOpacity(0.1),
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
			),
			body: Container(
				color: Colors.white, // White background for text visibility
				decoration: BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: [
							Colors.white,
							gradient.colors.first.withOpacity(0.02),
						],
					),
				),
				child: SingleChildScrollView(
					padding: const EdgeInsets.all(16),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							// Service selection
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Select Service', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											TextField(
												controller: _serviceController,
												style: const TextStyle(color: Colors.black),
												decoration: const InputDecoration(
													labelText: 'What service do you need?',
													labelStyle: TextStyle(color: Colors.black87),
													border: OutlineInputBorder(),
													filled: true,
													fillColor: Colors.white,
												),
											),
											const SizedBox(height: 12),
											const Text('Popular services:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
											const SizedBox(height: 8),
											Wrap(
												spacing: 8,
												children: services.map((service) {
													return ActionChip(
														label: Text(service, style: const TextStyle(color: Colors.black)),
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

							// Date and time selection
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Preferred Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											Row(
												children: [
													Expanded(
														child: OutlinedButton.icon(
															onPressed: () async {
																final date = await showDatePicker(
																	context: context,
																	firstDate: DateTime.now(),
																	lastDate: DateTime.now().add(const Duration(days: 90)),
																	initialDate: _preferredDate ?? DateTime.now().add(const Duration(days: 1)),
																);
																if (date != null) {
																	setState(() => _preferredDate = date);
																}
															},
															icon: const Icon(Icons.calendar_today, color: Colors.black),
															label: Text(
																_preferredDate == null 
																	? 'Select Date' 
																	: '${_preferredDate!.day}/${_preferredDate!.month}/${_preferredDate!.year}',
																style: const TextStyle(color: Colors.black),
															),
														),
													),
													const SizedBox(width: 12),
													Expanded(
														child: OutlinedButton.icon(
															onPressed: () async {
																final time = await showTimePicker(
																	context: context,
																	initialTime: _preferredTime ?? const TimeOfDay(hour: 10, minute: 0),
																);
																if (time != null) {
																	setState(() => _preferredTime = time);
																}
															},
															icon: const Icon(Icons.access_time, color: Colors.black),
															label: Text(
																_preferredTime == null 
																	? 'Select Time' 
																	: _preferredTime!.format(context),
																style: const TextStyle(color: Colors.black),
															),
														),
													),
												],
											),
											const SizedBox(height: 12),
											const Text('Duration:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
											const SizedBox(height: 8),
											Wrap(
												spacing: 8,
												children: durations.map((duration) {
													final isSelected = duration == _duration;
													return FilterChip(
														label: Text(duration, style: const TextStyle(color: Colors.black)),
														selected: isSelected,
														onSelected: (selected) {
															setState(() => _duration = duration);
														},
														selectedColor: gradient.colors.first.withOpacity(0.3),
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
											const Text('Service Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											AddressField(
												controller: _addressController,
												label: 'Where should the service be provided?',
												hint: 'Enter service address or select online',
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Service details and budget
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Service Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											TextField(
												controller: _descriptionController,
												style: const TextStyle(color: Colors.black),
												decoration: const InputDecoration(
													labelText: 'Describe your requirements...',
													labelStyle: TextStyle(color: Colors.black87),
													border: OutlineInputBorder(),
													filled: true,
													fillColor: Colors.white,
												),
												maxLines: 4,
											),
											const SizedBox(height: 16),
											TextField(
												controller: _budgetController,
												style: const TextStyle(color: Colors.black),
												keyboardType: TextInputType.number,
												decoration: const InputDecoration(
													labelText: 'Budget (NGN)',
													labelStyle: TextStyle(color: Colors.black87),
													border: OutlineInputBorder(),
													filled: true,
													fillColor: Colors.white,
													prefixText: '₦ ',
												),
											),
											const SizedBox(height: 16),
											const Text('Priority:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black)),
											const SizedBox(height: 8),
											Row(
												children: [
													Expanded(
														child: RadioListTile<String>(
															value: 'normal',
															groupValue: _priority,
															onChanged: (value) => setState(() => _priority = value!),
															title: const Text('Normal', style: TextStyle(color: Colors.black)),
															dense: true,
														),
													),
													Expanded(
														child: RadioListTile<String>(
															value: 'urgent',
															groupValue: _priority,
															onChanged: (value) => setState(() => _priority = value!),
															title: const Text('Urgent', style: TextStyle(color: Colors.black)),
															dense: true,
														),
													),
												],
											),
										],
									),
								),
							),

							const SizedBox(height: 24),

							// Book appointment button
							SizedBox(
								height: 56,
								child: FilledButton.icon(
									onPressed: _isBooking ? null : _bookAppointment,
									icon: _isBooking 
										? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
										: const Icon(Icons.calendar_month),
									label: Text(_isBooking ? 'Booking Appointment...' : 'Book Appointment'),
									style: FilledButton.styleFrom(
										backgroundColor: gradient.colors.first,
										textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
									),
								),
							),

							const SizedBox(height: 16),

							// Info card
							Card(
								color: gradient.colors.first.withOpacity(0.1),
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										children: [
											Icon(Icons.info_outline, color: gradient.colors.first),
											const SizedBox(height: 8),
											Text(
												'We\'ll find available ${widget.serviceType} providers and send your appointment request. You\'ll get notified when someone accepts!',
												textAlign: TextAlign.center,
												style: TextStyle(color: gradient.colors.first),
											),
										],
									),
								),
							),
						],
					),
				),
			),
		);
	}
}