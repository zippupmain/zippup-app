import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/hire_booking.dart';
import 'package:zippup/services/notifications/sound_service.dart';

class HireSearchScreen extends StatefulWidget {
	const HireSearchScreen({super.key, required this.bookingId});
	final String bookingId;

	@override
	State<HireSearchScreen> createState() => _HireSearchScreenState();
}

class _HireSearchScreenState extends State<HireSearchScreen> with TickerProviderStateMixin {
	late AnimationController _searchController;
	late Animation<double> _searchAnimation;
	StreamSubscription? _bookingSub;
	HireBooking? _booking;
	bool _foundProvider = false;

	@override
	void initState() {
		super.initState();
		_searchController = AnimationController(
			duration: const Duration(seconds: 2),
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
			.collection('hire_bookings')
			.doc(widget.bookingId)
			.snapshots()
			.listen((doc) {
				if (!doc.exists) return;
				
				final data = doc.data()!;
				final booking = HireBooking.fromJson(doc.id, data);
				
				setState(() => _booking = booking);
				
				// When provider accepts, navigate to live tracking
				if (booking.status == HireStatus.accepted && !_foundProvider) {
					setState(() => _foundProvider = true);
					_searchController.stop();
					
					// Play success sound
					SoundService.instance.playChirp();
					
					// Navigate to live tracking after brief delay
					Future.delayed(const Duration(seconds: 2), () {
						if (mounted) {
							context.pushReplacement('/hire/track?bookingId=${widget.bookingId}');
						}
					});
				}
			});
	}

	void _cancelRequest() async {
		try {
			await FirebaseFirestore.instance
				.collection('hire_bookings')
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

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('🔍 Finding Provider'),
				backgroundColor: Colors.blue.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
			),
			body: Container(
				decoration: BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: [Colors.blue.shade50, Colors.white],
					),
				),
				child: Center(
					child: Padding(
						padding: const EdgeInsets.all(24),
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								// Animated search indicator
								AnimatedBuilder(
									animation: _searchAnimation,
									builder: (context, child) {
										return Transform.rotate(
											angle: _searchAnimation.value * 2 * 3.14159,
											child: Container(
												width: 120,
												height: 120,
												decoration: BoxDecoration(
													shape: BoxShape.circle,
													gradient: LinearGradient(
														colors: [Colors.blue.shade400, Colors.blue.shade600],
														stops: [0.0, _searchAnimation.value],
													),
												),
												child: const Center(
													child: Icon(
														Icons.search,
														size: 60,
														color: Colors.white,
													),
												),
											),
										);
									},
								),
								
								const SizedBox(height: 32),
								
								// Status text
								Text(
									_foundProvider 
										? '✅ Provider Found!'
										: '🔍 Connecting to Providers...',
									style: TextStyle(
										fontSize: 24,
										fontWeight: FontWeight.bold,
										color: _foundProvider ? Colors.green.shade700 : Colors.blue.shade700,
									),
									textAlign: TextAlign.center,
								),
								
								const SizedBox(height: 16),
								
								// Service details
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
														Icon(Icons.build, color: Colors.blue.shade700, size: 24),
														const SizedBox(width: 8),
														Text(
															'${_booking!.serviceCategory.toUpperCase()} SERVICE',
															style: TextStyle(
																fontWeight: FontWeight.bold,
																color: Colors.blue.shade700,
																fontSize: 16,
															),
														),
													],
												),
												const SizedBox(height: 12),
												Row(
													children: [
														const Icon(Icons.location_on, color: Colors.red, size: 20),
														const SizedBox(width: 8),
														Expanded(
															child: Text(
																'Service Address: ${_booking!.serviceAddress}',
																style: const TextStyle(fontSize: 14),
															),
														),
													],
												),
												const SizedBox(height: 8),
												Row(
													children: [
														const Icon(Icons.star, color: Colors.orange, size: 20),
														const SizedBox(width: 8),
														Text(
															'Service Class: ${_booking!.type.name}',
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
															'Estimated Fee: ₦${_booking!.feeEstimate.toStringAsFixed(0)}',
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
										? 'Redirecting to live tracking...'
										: 'We\'re connecting you with the best available provider for your service.',
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
									label: const Text('Cancel Request', style: TextStyle(color: Colors.red)),
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