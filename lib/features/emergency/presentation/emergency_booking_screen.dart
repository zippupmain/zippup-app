import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/location/location_service.dart';
import 'package:zippup/common/widgets/address_field.dart';

class EmergencyBookingScreen extends StatefulWidget {
	const EmergencyBookingScreen({super.key});

	@override
	State<EmergencyBookingScreen> createState() => _EmergencyBookingScreenState();
}

class _EmergencyBookingScreenState extends State<EmergencyBookingScreen> {
	final TextEditingController _addressController = TextEditingController();
	final TextEditingController _descriptionController = TextEditingController();
	String _selectedType = 'medical';
	String _selectedPriority = 'high';
	bool _isBooking = false;

	final Map<String, String> _emergencyTypes = const {
		'medical': '🏥 Medical Emergency',
		'security': '🛡️ Security Emergency',
		'fire': '🔥 Fire Emergency',
		'technical': '⚡ Technical Emergency',
		'roadside': '🚗 Roadside Assistance',
	};

	final Map<String, Color> _priorityColors = const {
		'low': Colors.green,
		'medium': Colors.orange,
		'high': Colors.red,
		'critical': Colors.red,
	};

	Future<void> _bookEmergencyService() async {
		final address = _addressController.text.trim();
		final description = _descriptionController.text.trim();

		if (address.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please enter emergency address'))
			);
			return;
		}

		if (description.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please describe the emergency'))
			);
			return;
		}

		setState(() => _isBooking = true);

		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Please sign in to request emergency services'))
				);
				return;
			}

			// Create emergency booking
			final bookingRef = FirebaseFirestore.instance.collection('emergency_bookings').doc();
			final feeAmount = _selectedPriority == 'critical' ? 10000.0 : 
							  (_selectedPriority == 'high' ? 7500.0 : 
							  (_selectedPriority == 'medium' ? 5000.0 : 3000.0));

			await bookingRef.set({
				'clientId': uid,
				'type': _selectedType,
				'description': description,
				'priority': _selectedPriority,
				'emergencyAddress': address,
				'createdAt': DateTime.now().toIso8601String(),
				'feeEstimate': feeAmount,
				'etaMinutes': _selectedPriority == 'critical' ? 5 : 15,
				'status': 'requested',
				'currency': 'NGN',
				'paymentMethod': 'card',
			});

			// Navigate to tracking screen
			if (mounted) {
				context.push('/track/emergency?bookingId=${bookingRef.id}');
			}

		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Emergency request failed: $e'))
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
				title: const Text('🚨 Emergency Services'),
				backgroundColor: Colors.red.shade50,
			),
			body: SingleChildScrollView(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						// Emergency type selection
						Card(
							color: Colors.red.shade50,
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text('Emergency Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
										const SizedBox(height: 12),
										..._emergencyTypes.entries.map((entry) {
											return RadioListTile<String>(
												value: entry.key,
												groupValue: _selectedType,
												onChanged: (value) => setState(() => _selectedType = value!),
												title: Text(entry.value, style: const TextStyle(color: Colors.black)),
												dense: true,
											);
										}).toList(),
									],
								),
							),
						),

						const SizedBox(height: 16),

						// Priority selection
						Card(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text('Priority Level', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
										const SizedBox(height: 12),
										RadioListTile<String>(
											value: 'low',
											groupValue: _selectedPriority,
											onChanged: (value) => setState(() => _selectedPriority = value!),
											title: const Text('Low Priority • ₦3,000'),
											subtitle: const Text('Non-urgent, can wait 30+ minutes'),
										),
										RadioListTile<String>(
											value: 'medium',
											groupValue: _selectedPriority,
											onChanged: (value) => setState(() => _selectedPriority = value!),
											title: const Text('Medium Priority • ₦5,000'),
											subtitle: const Text('Urgent, need help within 15-30 minutes'),
										),
										RadioListTile<String>(
											value: 'high',
											groupValue: _selectedPriority,
											onChanged: (value) => setState(() => _selectedPriority = value!),
											title: const Text('High Priority • ₦7,500'),
											subtitle: const Text('Very urgent, need help within 10-15 minutes'),
										),
										RadioListTile<String>(
											value: 'critical',
											groupValue: _selectedPriority,
											onChanged: (value) => setState(() => _selectedPriority = value!),
											title: Text('CRITICAL • ₦10,000', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
											subtitle: Text('Life-threatening, immediate response needed', style: TextStyle(color: Colors.red.shade700)),
										),
									],
								),
							),
						),

						const SizedBox(height: 16),

						// Emergency address
						Card(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text('Emergency Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
										const SizedBox(height: 12),
										AddressField(
											controller: _addressController,
											label: 'Where is the emergency?',
											hint: 'Enter the exact emergency location',
										),
									],
								),
							),
						),

						const SizedBox(height: 16),

						// Emergency description
						Card(
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										const Text('Emergency Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
										const SizedBox(height: 12),
										TextField(
											controller: _descriptionController,
											decoration: const InputDecoration(
												labelText: 'Describe the emergency situation...',
												border: OutlineInputBorder(),
												prefixIcon: Icon(Icons.warning, color: Colors.red),
											),
											maxLines: 4,
										),
									],
								),
							),
						),

						const SizedBox(height: 24),

						// Request emergency button
						SizedBox(
							height: 56,
							child: FilledButton.icon(
								onPressed: _isBooking ? null : _bookEmergencyService,
								icon: _isBooking 
									? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
									: const Icon(Icons.emergency),
								label: Text(_isBooking ? 'Requesting Emergency Help...' : 'REQUEST EMERGENCY HELP'),
								style: FilledButton.styleFrom(
									backgroundColor: Colors.red.shade600,
									textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
								),
							),
						),

						const SizedBox(height: 16),

						// Warning card
						Card(
							color: Colors.red.shade50,
							child: Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									children: [
										Icon(Icons.warning, color: Colors.red.shade700, size: 32),
										const SizedBox(height: 8),
										Text(
											'For life-threatening emergencies, call 911 or your local emergency number immediately!',
											textAlign: TextAlign.center,
											style: TextStyle(
												color: Colors.red.shade700,
												fontWeight: FontWeight.bold,
											),
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