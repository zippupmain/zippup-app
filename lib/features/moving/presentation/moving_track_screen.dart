import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/moving_booking.dart';
import 'package:zippup/features/orders/widgets/status_timeline.dart';
import 'package:zippup/services/notifications/sound_service.dart';

class MovingTrackScreen extends StatefulWidget {
	const MovingTrackScreen({super.key, required this.bookingId});
	final String bookingId;

	@override
	State<MovingTrackScreen> createState() => _MovingTrackScreenState();
}

class _MovingTrackScreenState extends State<MovingTrackScreen> {
	bool _shownSummary = false;

	List<String> _stepsFor(MovingType type) => const ['Requested', 'Accepted', 'Arriving', 'Arrived', 'Loading', 'In Transit', 'Unloading', 'Completed'];

	int _indexFor(MovingStatus status, List<String> steps) {
		final map = {
			MovingStatus.requested: 'Requested',
			MovingStatus.accepted: 'Accepted',
			MovingStatus.arriving: 'Arriving',
			MovingStatus.arrived: 'Arrived',
			MovingStatus.loading: 'Loading',
			MovingStatus.inTransit: 'In Transit',
			MovingStatus.unloading: 'Unloading',
			MovingStatus.completed: 'Completed',
			MovingStatus.cancelled: 'Completed',
		};
		final label = map[status] ?? 'Requested';
		return steps.indexOf(label).clamp(0, steps.length - 1);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Track Moving Service')),
			body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('moving_bookings').doc(widget.bookingId).snapshots(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final data = snap.data!.data() ?? {};
					final booking = MovingBooking.fromJson(widget.bookingId, data);
					final steps = _stepsFor(booking.type);
					final idx = _indexFor(booking.status, steps);

					// Show completion summary
					if (booking.status == MovingStatus.completed && !_shownSummary) {
						_shownSummary = true;
						WidgetsBinding.instance.addPostFrameCallback((_) async {
							try {
								await SoundService.instance.playTrill();
							} catch (_) {}
							
							// Show completion dialog similar to transport
							await showDialog(context: context, builder: (_) {
								final fee = booking.feeEstimate;
								final currency = data['currency'] ?? 'NGN';
								
								return StatefulBuilder(builder: (context, setDialogState) {
									String paymentMethod = data['paymentMethod'] ?? 'card';
									return AlertDialog(
										title: const Text('📦 Moving Completed!'),
										content: SingleChildScrollView(
											child: Column(
												mainAxisSize: MainAxisSize.min,
												children: [
													Card(
														color: Colors.green.shade50,
														child: Padding(
															padding: const EdgeInsets.all(16),
															child: Column(
																children: [
																	Text('Amount to pay: $currency ${fee.toStringAsFixed(2)}', 
																		style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
																	const SizedBox(height: 12),
																	Row(
																		children: [
																			Expanded(
																				child: RadioListTile<String>(
																					value: 'card',
																					groupValue: paymentMethod,
																					onChanged: (value) => setDialogState(() => paymentMethod = value!),
																					title: const Text('💳 Card'),
																					dense: true,
																				),
																			),
																			Expanded(
																				child: RadioListTile<String>(
																					value: 'cash',
																					groupValue: paymentMethod,
																					onChanged: (value) => setDialogState(() => paymentMethod = value!),
																					title: const Text('💵 Cash'),
																					dense: true,
																				),
																			),
																		],
																	),
																],
															),
														),
													),
												],
											),
										),
										actions: [
											FilledButton(
												onPressed: () async {
													await FirebaseFirestore.instance
														.collection('moving_bookings')
														.doc(widget.bookingId)
														.set({'paymentMethod': paymentMethod}, SetOptions(merge: true));
													if (context.mounted) Navigator.pop(context);
												},
												child: const Text('Done'),
											),
										],
									);
								});
							});
						});
					}

					return SingleChildScrollView(
						padding: const EdgeInsets.all(16),
						child: Column(
							children: [
								// Route info card
								Card(
									child: Padding(
										padding: const EdgeInsets.all(16),
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												const Text('📍 Moving Details', style: TextStyle(fontWeight: FontWeight.bold)),
												const SizedBox(height: 8),
												Text('From: ${booking.pickupAddress}'),
												Text('To: ${booking.destinationAddress}'),
												Text('Type: ${booking.type.name.toUpperCase()}'),
											],
										),
									),
								),
								const SizedBox(height: 16),
								StatusTimeline(steps: steps, currentIndex: idx),
							],
						),
					);
				},
			),
		);
	}
}