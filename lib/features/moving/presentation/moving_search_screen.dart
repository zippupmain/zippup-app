import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/moving_booking.dart';
import 'package:zippup/services/notifications/sound_service.dart';

class MovingSearchScreen extends StatefulWidget {
	const MovingSearchScreen({super.key, required this.bookingId});
	final String bookingId;

	@override
	State<MovingSearchScreen> createState() => _MovingSearchScreenState();
}

class _MovingSearchScreenState extends State<MovingSearchScreen> with TickerProviderStateMixin {
	late AnimationController _searchController;
	late Animation<double> _searchAnimation;
	StreamSubscription? _bookingSub;
	MovingBooking? _booking;
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
			.collection('moving_bookings')
			.doc(widget.bookingId)
			.snapshots()
			.listen((doc) {
				if (!doc.exists) return;
				
				final data = doc.data()!;
				final booking = MovingBooking.fromJson(doc.id, data);
				
				setState(() => _booking = booking);
				
				// When provider accepts, navigate to live tracking
				if (booking.status == MovingStatus.accepted && !_foundProvider) {
					setState(() => _foundProvider = true);
					_searchController.stop();
					
					// Play success sound
					SoundService.instance.playChirp();
					
					// Navigate to live tracking after brief delay
					Future.delayed(const Duration(seconds: 2), () {
						if (mounted) {
							context.pushReplacement('/moving/track?bookingId=${widget.bookingId}');
						}
					});
				}
			});
	}

	void _cancelRequest() async {
		try {
			await FirebaseFirestore.instance
				.collection('moving_bookings')
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
				title: const Text('🚛 Finding Moving Team'),
				backgroundColor: Colors.orange.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
			),
			body: Container(
				decoration: BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: [Colors.orange.shade50, Colors.white],
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
												width: 130,
												height: 130,
												decoration: BoxDecoration(
													shape: BoxShape.circle,
													gradient: LinearGradient(
														colors: [Colors.orange.shade400, Colors.orange.shade600],
														stops: [0.0, _searchAnimation.value],
													),
												),
												child: const Center(
													child: Icon(
														Icons.local_shipping,
														size: 65,
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
										? '✅ Moving Team Found!'
										: '🚛 Connecting to Moving Teams...',
									style: TextStyle(
										fontSize: 24,
										fontWeight: FontWeight.bold,
										color: _foundProvider ? Colors.green.shade700 : Colors.orange.shade700,
									),
									textAlign: TextAlign.center,
								),
								
								const SizedBox(height: 16),
								
								// Moving details
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
														Icon(Icons.moving, color: Colors.orange.shade700, size: 24),
														const SizedBox(width: 8),
														Text(
															'${_booking!.type.name.toUpperCase()} MOVING',
															style: TextStyle(
																fontWeight: FontWeight.bold,
																color: Colors.orange.shade700,
																fontSize: 16,
															),
														),
													],
												),
												const SizedBox(height: 12),
												Row(
													children: [
														const Icon(Icons.my_location, color: Colors.green, size: 20),
														const SizedBox(width: 8),
														Expanded(
															child: Text(
																'From: ${_booking!.pickupAddress}',
																style: const TextStyle(fontSize: 14),
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
																'To: ${_booking!.destinationAddress}',
																style: const TextStyle(fontSize: 14),
															),
														),
													],
												),
												const SizedBox(height: 8),
												if (_booking!.isScheduled && _booking!.scheduledAt != null) Row(
													children: [
														const Icon(Icons.schedule, color: Colors.blue, size: 20),
														const SizedBox(width: 8),
														Text(
															'Scheduled: ${_booking!.scheduledAt!.toString().substring(0, 16)}',
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
															'Estimated Cost: ₦${_booking!.feeEstimate.toStringAsFixed(0)}',
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
										? 'Moving team is preparing vehicle and equipment...'
										: 'We\'re connecting you with professional moving teams in your area.',
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
									label: const Text('Cancel Moving Request', style: TextStyle(color: Colors.red)),
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