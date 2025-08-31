import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PersonalNormalBookingScreen extends StatefulWidget {
	const PersonalNormalBookingScreen({super.key});

	@override
	State<PersonalNormalBookingScreen> createState() => _PersonalNormalBookingScreenState();
}

class _PersonalNormalBookingScreenState extends State<PersonalNormalBookingScreen> {
	final TextEditingController _serviceController = TextEditingController();
	final TextEditingController _notesController = TextEditingController();
	String _selectedType = 'beauty';
	int _selectedDuration = 60;
	bool _isBooking = false;
	bool _scheduled = false;
	DateTime? _scheduledAt;

	final Map<String, List<String>> _personalServices = const {
		'beauty': ['Hair Cut', 'Hair Styling', 'Makeup', 'Facial', 'Eyebrow Threading'],
		'wellness': ['Massage', 'Spa Treatment', 'Reflexology', 'Aromatherapy'],
		'fitness': ['Personal Trainer', 'Yoga Instructor', 'Physiotherapy', 'Nutrition Coaching'],
		'tutoring': ['Math Tutor', 'Language Tutor', 'Music Lessons', 'Art Classes'],
		'cleaning': ['House Cleaning', 'Deep Cleaning', 'Laundry Service', 'Organizing'],
		'childcare': ['Babysitter', 'Nanny', 'Child Tutor', 'Child Activities'],
	};

	Future<void> _bookAppointment() async {
		final service = _serviceController.text.trim();

		if (service.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please enter the service you need'))
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
			final bookingRef = FirebaseFirestore.instance.collection('personal_appointments').doc();
			final hourlyRate = _selectedType == 'tutoring' ? 3000.0 : 
							  (_selectedType == 'fitness' ? 4000.0 : 2500.0);
			final feeAmount = (hourlyRate * _selectedDuration / 60);

			await bookingRef.set({
				'clientId': uid,
				'type': _selectedType,
				'serviceCategory': service,
				'notes': _notesController.text.trim(),
				'createdAt': DateTime.now().toIso8601String(),
				'isScheduled': _scheduled,
				'scheduledAt': _scheduled ? _scheduledAt?.toIso8601String() : null,
				'normalBooking': true, // This is normal booking mode
				'meetAtProvider': true, // User meets provider at their location
				'feeEstimate': feeAmount,
				'status': 'appointment_requested',
				'currency': 'NGN',
				'paymentMethod': 'card',
				'durationMinutes': _selectedDuration,
			});

			// Show success message and navigate to provider list
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(
						content: Text('✅ Appointment request submitted! Providers will contact you.'),
						backgroundColor: Colors.green,
					)
				);
				context.push('/personal/providers?appointmentId=${bookingRef.id}');
			}

		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Appointment booking failed: $e'))
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
				title: const Text('📅 Book Appointment'),
				backgroundColor: Colors.purple.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
			),
			body: Container(
				color: Colors.white,
				child: SingleChildScrollView(
					padding: const EdgeInsets.all(16),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							// Info card
							Card(
								color: Colors.purple.shade50,
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										children: [
											const Icon(Icons.handshake, size: 48, color: Colors.purple),
											const SizedBox(height: 8),
											const Text(
												'Normal Booking Mode',
												style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
											),
											const SizedBox(height: 8),
											const Text(
												'Meet the provider at their location or shop. Perfect for salons, clinics, studios, and professional offices.',
												style: TextStyle(color: Colors.black54),
												textAlign: TextAlign.center,
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Service type selection
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
												runSpacing: 8,
												children: _personalServices.keys.map((type) => ChoiceChip(
													label: Text(type.toUpperCase(), style: const TextStyle(color: Colors.black)),
													selected: _selectedType == type,
													onSelected: (_) => setState(() => _selectedType = type),
													selectedColor: Colors.purple.shade100,
													backgroundColor: Colors.white,
												)).toList(),
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Service input
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Service Needed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											TextField(
												controller: _serviceController,
												style: const TextStyle(color: Colors.black),
												decoration: const InputDecoration(
													labelText: 'What service do you need?',
													labelStyle: TextStyle(color: Colors.black),
													hintText: 'e.g., Hair cut, Massage, Personal training...',
													hintStyle: TextStyle(color: Colors.black38),
													border: OutlineInputBorder(),
													prefixIcon: Icon(Icons.build, color: Colors.purple),
												),
											),
											const SizedBox(height: 12),
											Wrap(
												spacing: 8,
												runSpacing: 4,
												children: _personalServices[_selectedType]!.map((service) => 
													ActionChip(
														label: Text(service, style: const TextStyle(fontSize: 12, color: Colors.black)),
														onPressed: () => _serviceController.text = service,
														backgroundColor: Colors.purple.shade50,
													)
												).toList(),
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
											const Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											Wrap(
												spacing: 8,
												children: [30, 60, 90, 120, 180].map((minutes) => ChoiceChip(
													label: Text('${minutes}min', style: const TextStyle(color: Colors.black)),
													selected: _selectedDuration == minutes,
													onSelected: (_) => setState(() => _selectedDuration = minutes),
													selectedColor: Colors.purple.shade100,
													backgroundColor: Colors.white,
												)).toList(),
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Notes
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Additional Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											TextField(
												controller: _notesController,
												style: const TextStyle(color: Colors.black),
												decoration: const InputDecoration(
													labelText: 'Special requests or preferences...',
													labelStyle: TextStyle(color: Colors.black),
													border: OutlineInputBorder(),
													prefixIcon: Icon(Icons.note, color: Colors.purple),
												),
												maxLines: 3,
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Schedule booking section
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											SwitchListTile(
												title: const Text('Schedule Appointment', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
												subtitle: const Text('Book for a future date and time', style: TextStyle(color: Colors.black54)),
												value: _scheduled,
												onChanged: (v) => setState(() => _scheduled = v),
												activeColor: Colors.purple,
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
													leading: const Icon(Icons.schedule, color: Colors.purple),
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

							// Book appointment button
							SizedBox(
								height: 56,
								child: FilledButton.icon(
									onPressed: _isBooking ? null : _bookAppointment,
									icon: _isBooking 
										? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
										: const Icon(Icons.calendar_today),
									label: Text(_isBooking ? 'Booking Appointment...' : 'Book Appointment'),
									style: FilledButton.styleFrom(
										backgroundColor: Colors.purple.shade600,
										textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
									),
								),
							),

							const SizedBox(height: 16),

							// Info text
							Card(
								color: Colors.purple.shade50,
								child: const Padding(
									padding: EdgeInsets.all(16),
									child: Text(
										'💡 Normal Booking: You will meet the provider at their location (salon, clinic, studio, etc.). Providers will contact you to confirm appointment details.',
										style: TextStyle(color: Colors.black54, fontSize: 14),
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