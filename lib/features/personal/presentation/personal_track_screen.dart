import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/personal_booking.dart';
import 'package:zippup/features/orders/widgets/status_timeline.dart';
import 'package:zippup/services/notifications/sound_service.dart';

class PersonalTrackScreen extends StatefulWidget {
	const PersonalTrackScreen({super.key, required this.bookingId});
	final String bookingId;

	@override
	State<PersonalTrackScreen> createState() => _PersonalTrackScreenState();
}

class _PersonalTrackScreenState extends State<PersonalTrackScreen> {
	bool _shownSummary = false;

	List<String> _stepsFor(PersonalType type) => const ['Requested', 'Accepted', 'Arriving', 'Arrived', 'In Progress', 'Completed'];

	int _indexFor(PersonalStatus status, List<String> steps) {
		final map = {
			PersonalStatus.requested: 'Requested',
			PersonalStatus.accepted: 'Accepted',
			PersonalStatus.arriving: 'Arriving',
			PersonalStatus.arrived: 'Arrived',
			PersonalStatus.inProgress: 'In Progress',
			PersonalStatus.completed: 'Completed',
			PersonalStatus.cancelled: 'Completed',
		};
		final label = map[status] ?? 'Requested';
		return steps.indexOf(label).clamp(0, steps.length - 1);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Track Personal Service')),
			body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('personal_bookings').doc(widget.bookingId).snapshots(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final data = snap.data!.data() ?? {};
					final booking = PersonalBooking.fromJson(widget.bookingId, data);
					final steps = _stepsFor(booking.type);
					final idx = _indexFor(booking.status, steps);

					// Show completion summary with rating
					if (booking.status == PersonalStatus.completed && !_shownSummary) {
						_shownSummary = true;
						WidgetsBinding.instance.addPostFrameCallback((_) async {
							try {
								await SoundService.instance.playTrill();
							} catch (_) {}
							
							await showDialog(context: context, builder: (_) {
								final fee = booking.feeEstimate;
								final currency = data['currency'] ?? 'NGN';
								int? stars;
								final ctl = TextEditingController();
								
								return StatefulBuilder(builder: (context, setDialogState) {
									String paymentMethod = data['paymentMethod'] ?? 'card';
									return AlertDialog(
										title: const Text('💆 Service Completed!'),
										content: SingleChildScrollView(
											child: Column(
												mainAxisSize: MainAxisSize.min,
												children: [
													// Payment section
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
													const SizedBox(height: 16),
													// Rating
													const Text('Rate your service provider:', style: TextStyle(fontWeight: FontWeight.bold)),
													Row(
														mainAxisAlignment: MainAxisAlignment.center,
														children: List.generate(5, (i) => IconButton(
															onPressed: () => setDialogState(() => stars = i + 1),
															icon: Icon(
																stars != null && stars! > i ? Icons.star : Icons.star_border,
																color: Colors.amber,
																size: 32,
															),
														)),
													),
													TextField(
														controller: ctl,
														decoration: const InputDecoration(labelText: 'Feedback'),
														maxLines: 2,
													),
												],
											),
										),
										actions: [
											FilledButton(
												onPressed: () async {
													await FirebaseFirestore.instance
														.collection('personal_bookings')
														.doc(widget.bookingId)
														.set({'paymentMethod': paymentMethod}, SetOptions(merge: true));
													if (stars != null) {
														await FirebaseFirestore.instance
															.collection('personal_bookings')
															.doc(widget.bookingId)
															.collection('ratings')
															.add({
																'stars': stars,
																'text': ctl.text.trim(),
																'createdAt': DateTime.now().toIso8601String(),
															});
													}
													if (context.mounted) Navigator.pop(context);
												},
												child: const Text('Submit'),
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
								// Service info card
								Card(
									child: Padding(
										padding: const EdgeInsets.all(16),
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												Text('💆 ${booking.serviceCategory}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
												const SizedBox(height: 8),
												Text('Service: ${booking.description}'),
												Text('Location: ${booking.serviceAddress}'),
												Text('Type: ${booking.type.name.toUpperCase()}'),
												if (booking.durationMinutes != null) Text('Duration: ${booking.durationMinutes} minutes'),
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