import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/emergency_booking.dart';
import 'package:zippup/services/notifications/sound_service.dart';

class EmergencySearchScreen extends StatefulWidget {
	const EmergencySearchScreen({super.key, required this.bookingId});
	final String bookingId;

	@override
	State<EmergencySearchScreen> createState() => _EmergencySearchScreenState();
}

class _EmergencySearchScreenState extends State<EmergencySearchScreen> with TickerProviderStateMixin {
	late AnimationController _searchController;
	late Animation<double> _searchAnimation;
	StreamSubscription? _bookingSub;
	EmergencyBooking? _booking;
	bool _foundProvider = false;

	@override
	void initState() {
		super.initState();
		_searchController = AnimationController(
			duration: const Duration(seconds: 1),
			vsync: this,
		)..repeat();
		_searchAnimation = Tween<double>(begin: 0, end: 1).animate(_searchController);
		_listenForProviderAcceptance();
	}

	@override
	void dispose() {
		_searchController.dispose();
		_bookingSub?.cancel();
		super.dispose();
	}

	void _listenForProviderAcceptance() {
		_bookingSub = FirebaseFirestore.instance
			.collection('emergency_bookings')
			.doc(widget.bookingId)
			.snapshots()
			.listen((doc) {
				if (!doc.exists) return;
				
				final data = doc.data()!;
				final booking = EmergencyBooking.fromJson({...data, 'id': doc.id});
				
				setState(() => _booking = booking);
				
				// When provider accepts, navigate to live tracking
				if (booking.status == EmergencyStatus.accepted && !_foundProvider) {
					setState(() => _foundProvider = true);
					_searchController.stop();
					
					// Play success sound
					SoundService.instance.playChirp();
					
					// Navigate to live tracking after brief delay
					Future.delayed(const Duration(seconds: 2), () {
						if (mounted) {
							context.pushReplacement('/track/emergency?bookingId=${widget.bookingId}');
						}
					});
				}
			});
	}

	void _cancelRequest() async {
		try {
			await FirebaseFirestore.instance
				.collection('emergency_bookings')
				.doc(widget.bookingId)
				.update({'status': 'cancelled'});
			
			if (mounted) {
				context.pop();
			}
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Failed to cancel: $e'))
				);
			}
		}
	}

	Color _getPriorityColor() {
		if (_booking == null) return Colors.red;
		switch (_booking!.priority) {
			case 'critical': return Colors.red.shade800;
			case 'high': return Colors.red.shade600;
			case 'medium': return Colors.orange.shade600;
			case 'low': return Colors.yellow.shade700;
			default: return Colors.red;
		}
	}

	@override
	Widget build(BuildContext context) {
		final priorityColor = _getPriorityColor();
		
		return Scaffold(
			appBar: AppBar(
				title: const Text('🚨 Emergency Response'),
				backgroundColor: Colors.red.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
			),
			body: Container(
				decoration: BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: [Colors.red.shade50, Colors.white],
					),
				),
				child: Center(
					child: Padding(
						padding: const EdgeInsets.all(24),
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								// Animated emergency indicator
								AnimatedBuilder(
									animation: _searchAnimation,
									builder: (context, child) {
										return Container(
											width: 140,
											height: 140,
											decoration: BoxDecoration(
												shape: BoxShape.circle,
												border: Border.all(
													color: priorityColor,
													width: 4,
												),
												boxShadow: [
													BoxShadow(
														color: priorityColor.withOpacity(0.3),
														spreadRadius: _searchAnimation.value * 20,
														blurRadius: 20,
													),
												],
											),
											child: Center(
												child: Icon(
													Icons.emergency,
													size: 70,
													color: priorityColor,
												),
											),
										);
									},
								),
								
								const SizedBox(height: 32),
								
								// Status text
								Text(
									_foundProvider 
										? '✅ Emergency Team Found!'
										: '🚨 Dispatching Emergency Response...',
									style: TextStyle(
										fontSize: 24,
										fontWeight: FontWeight.bold,
										color: _foundProvider ? Colors.green.shade700 : priorityColor,
									),
									textAlign: TextAlign.center,
								),
								
								const SizedBox(height: 16),
								
								// Emergency details
								if (_booking != null) Card(
									color: Colors.white,
									elevation: 4,
									child: Padding(
										padding: const EdgeInsets.all(16),
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Row(
													children: [
														Icon(Icons.warning, color: priorityColor, size: 24),
														const SizedBox(width: 8),
														Text(
															'${_booking!.type.name.toUpperCase()} EMERGENCY',
															style: TextStyle(
																fontWeight: FontWeight.bold,
																color: priorityColor,
																fontSize: 16,
															),
														),
													],
												),
												const SizedBox(height: 12),
												Row(
													children: [
														Icon(Icons.priority_high, color: priorityColor, size: 20),
														const SizedBox(width: 8),
														Text(
															'Priority: ${_booking!.priority.toUpperCase()}',
															style: TextStyle(
																fontSize: 14,
																fontWeight: FontWeight.w600,
																color: priorityColor,
															),
														),
													],
												),
												const SizedBox(height: 8),
												Row(
													children: [
														const Icon(Icons.location_on, color: Colors.red, size: 20),
														const SizedBox(width: 8),
														Expanded(
															child: Text(
																'Location: ${_booking!.emergencyAddress}',
																style: const TextStyle(fontSize: 14),
															),
														),
													],
												),
												const SizedBox(height: 8),
												Row(
													children: [
														const Icon(Icons.schedule, color: Colors.blue, size: 20),
														const SizedBox(width: 8),
														Text(
															'ETA: ${_booking!.etaMinutes} minutes',
															style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
														),
													],
												),
												const SizedBox(height: 8),
												Row(
													children: [
														const Icon(Icons.attach_money, color: Colors.green, size: 20),
														const SizedBox(width: 8),
														Text(
															'Service Fee: ₦${_booking!.feeEstimate.toStringAsFixed(0)}',
															style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
														),
													],
												),
											],
										),
									),
								),
								
								const SizedBox(height: 32),
								
								// Status message
								Text(
									_foundProvider
										? 'Emergency team is preparing to respond...'
										: 'We\'re dispatching the nearest emergency response team to your location.',
									style: TextStyle(
										fontSize: 16,
										color: Colors.grey.shade600,
									),
									textAlign: TextAlign.center,
								),
								
								const SizedBox(height: 48),
								
								// Cancel button
								if (!_foundProvider) OutlinedButton.icon(
									onPressed: _cancelRequest,
									icon: const Icon(Icons.close, color: Colors.red),
									label: const Text('Cancel Emergency Request', style: TextStyle(color: Colors.red)),
									style: OutlinedButton.styleFrom(
										side: const BorderSide(color: Colors.red),
										padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
									),
								),
							],
						),
					),
				),
			),
		);
	}
}