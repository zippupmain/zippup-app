import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart' as lm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:zippup/common/models/hire_booking.dart';
import 'package:zippup/features/orders/widgets/status_timeline.dart';
import 'package:zippup/services/notifications/sound_service.dart';
import 'package:zippup/services/distance/distance_service.dart';

class HireTrackScreen extends StatefulWidget {
	const HireTrackScreen({super.key, required this.bookingId});
	final String bookingId;

	@override
	State<HireTrackScreen> createState() => _HireTrackScreenState();
}

class _HireTrackScreenState extends State<HireTrackScreen> {
	bool _shownSummary = false;
	final DistanceService _distance = DistanceService();
	Set<Polyline> _polylines = {};
	LatLng? _simulatedProvider;
	Timer? _providerSimTimer;
	String _eta = '';

	@override
	void dispose() {
		_providerSimTimer?.cancel();
		super.dispose();
	}

	List<String> _stepsFor(HireType type) => const ['Requested', 'Accepted', 'Arriving', 'Arrived', 'In Progress', 'Completed'];

	int _indexFor(HireStatus status, List<String> steps) {
		final map = {
			HireStatus.requested: 'Requested',
			HireStatus.accepted: 'Accepted',
			HireStatus.arriving: 'Arriving',
			HireStatus.arrived: 'Arrived',
			HireStatus.inProgress: 'In Progress',
			HireStatus.completed: 'Completed',
			HireStatus.cancelled: 'Completed',
		};
		final label = map[status] ?? 'Requested';
		return steps.indexOf(label).clamp(0, steps.length - 1);
	}

	bool _bookingCancelable(HireStatus status) {
		return status == HireStatus.requested || status == HireStatus.accepted;
	}

	Future<void> _cancel(BuildContext context, String bookingId) async {
		final confirm = await showDialog<bool>(
			context: context,
			builder: (_) => AlertDialog(
				title: const Text('Cancel booking'),
				content: const Text('Are you sure you want to cancel this hire booking?'),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
					FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, cancel')),
				],
			),
		);
		if (confirm == true) {
			await FirebaseFirestore.instance.collection('hire_bookings').doc(bookingId).set({
				'status': 'cancelled',
				'cancelReason': 'cancelled_by_client',
				'cancelledAt': FieldValue.serverTimestamp(),
			}, SetOptions(merge: true));
			if (context.mounted) context.pop();
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Track Hire Service')),
			body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('hire_bookings').doc(widget.bookingId).snapshots(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final data = snap.data!.data() ?? {};
					final booking = HireBooking.fromJson(widget.bookingId, data);
					final steps = _stepsFor(booking.type);
					final idx = _indexFor(booking.status, steps);

					// Show completion summary
					if (booking.status == HireStatus.completed && !_shownSummary) {
						_shownSummary = true;
						WidgetsBinding.instance.addPostFrameCallback((_) async {
							try {
								await SoundService.instance.playTrill();
							} catch (_) {}
							
							// Fetch provider info
							String providerName = 'Provider';
							String providerPhoto = '';
							try {
								if (booking.providerId != null) {
									final results = await Future.wait([
										FirebaseFirestore.instance.collection('public_profiles').doc(booking.providerId!).get(),
										FirebaseFirestore.instance.collection('users').doc(booking.providerId!).get(),
									]);
									final pu = results[0].data() ?? const {};
									final u = results[1].data() ?? const {};
									
									if (pu['name'] != null && pu['name'].toString().trim().isNotEmpty) {
										providerName = pu['name'].toString().trim();
									} else if (u['name'] != null && u['name'].toString().trim().isNotEmpty) {
										providerName = u['name'].toString().trim();
									}
									
									if (pu['photoUrl'] != null && pu['photoUrl'].toString().trim().isNotEmpty) {
										providerPhoto = pu['photoUrl'].toString().trim();
									} else if (u['photoUrl'] != null && u['photoUrl'].toString().trim().isNotEmpty) {
										providerPhoto = u['photoUrl'].toString().trim();
									}
								}
							} catch (_) {}
							
							await showDialog(context: context, builder: (_) {
								final fee = booking.feeEstimate;
								final currency = data['currency'] ?? 'NGN';
								int? stars;
								final ctl = TextEditingController();
								
								return StatefulBuilder(builder: (context, setDialogState) {
									String paymentMethod = data['paymentMethod'] ?? 'card';
									return AlertDialog(
										title: const Text('🎉 Service Completed!'),
										content: SingleChildScrollView(
											child: Column(
												mainAxisSize: MainAxisSize.min,
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													// Provider info
													if (booking.providerId != null) Card(
														child: ListTile(
															leading: CircleAvatar(
																backgroundImage: providerPhoto.isNotEmpty ? NetworkImage(providerPhoto) : null,
																child: providerPhoto.isEmpty ? const Icon(Icons.person) : null,
															),
															title: Text(providerName),
															subtitle: Text('${booking.serviceCategory} • ${booking.type.name.toUpperCase()}'),
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
																	const Text('Service Details', style: TextStyle(fontWeight: FontWeight.bold)),
																	const SizedBox(height: 8),
																	Text('Service: ${booking.description}'),
																	Text('Location: ${booking.serviceAddress}'),
																	Text('Category: ${booking.serviceCategory}'),
																],
															),
														),
													),
													const SizedBox(height: 16),
													
													// Payment section
													Card(
														color: Colors.green.shade50,
														child: Padding(
															padding: const EdgeInsets.all(16),
															child: Column(
																crossAxisAlignment: CrossAxisAlignment.start,
																children: [
																	const Text('💳 Payment', style: TextStyle(fontWeight: FontWeight.bold)),
																	const SizedBox(height: 8),
																	Text('Amount to pay: $currency ${fee.toStringAsFixed(2)}', 
																		style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
																	const SizedBox(height: 12),
																	
																	// Payment method selection
																	const Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.w600)),
																	const SizedBox(height: 8),
																	Row(
																		children: [
																			Expanded(
																				child: Card(
																					child: RadioListTile<String>(
																						value: 'card',
																						groupValue: paymentMethod,
																						onChanged: (value) => setDialogState(() => paymentMethod = value!),
																						title: const Text('💳 Card'),
																						subtitle: const Text('Auto-processed'),
																						dense: true,
																					),
																				),
																			),
																			Expanded(
																				child: Card(
																					child: RadioListTile<String>(
																						value: 'cash',
																						groupValue: paymentMethod,
																						onChanged: (value) => setDialogState(() => paymentMethod = value!),
																						title: const Text('💵 Cash'),
																						subtitle: const Text('Pay provider'),
																						dense: true,
																					),
																				),
																			),
																		],
																	),
																	const SizedBox(height: 8),
																	Text(
																		paymentMethod == 'card' 
																			? 'Card payments are processed automatically.' 
																			: 'Please pay the provider $currency ${fee.toStringAsFixed(2)} in cash.',
																		style: TextStyle(
																			color: paymentMethod == 'cash' ? Colors.orange[700] : Colors.grey[600], 
																			fontSize: 12,
																			fontWeight: paymentMethod == 'cash' ? FontWeight.w600 : FontWeight.normal,
																		),
																	),
																],
															),
														),
													),
													const SizedBox(height: 16),
													
													// Rating section
													const Text('Rate your service provider (optional):', style: TextStyle(fontWeight: FontWeight.bold)),
													const SizedBox(height: 8),
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
													const SizedBox(height: 8),
													TextField(
														controller: ctl,
														decoration: const InputDecoration(
															labelText: 'Feedback (optional)',
															border: OutlineInputBorder(),
														),
														maxLines: 3,
													),
												],
											),
										),
										actions: [
											TextButton(
												onPressed: () => Navigator.pop(context),
												child: const Text('Skip Rating'),
											),
											FilledButton(
												onPressed: () async {
													try {
														// Save payment method
														await FirebaseFirestore.instance
															.collection('hire_bookings')
															.doc(widget.bookingId)
															.set({
																'paymentMethod': paymentMethod,
																'paymentStatus': paymentMethod == 'cash' ? 'pending_cash' : 'processed',
																'completedAt': DateTime.now().toIso8601String(),
															}, SetOptions(merge: true));
														
														// Save rating if provided
														if (stars != null) {
															await FirebaseFirestore.instance
																.collection('hire_bookings')
																.doc(widget.bookingId)
																.collection('ratings')
																.add({
																	'stars': stars,
																	'text': ctl.text.trim(),
																	'createdAt': DateTime.now().toIso8601String(),
																	'clientId': FirebaseAuth.instance.currentUser?.uid,
																	'providerId': booking.providerId,
																});
														}
													} catch (_) {}
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

					return Column(
						children: [
							Expanded(
								child: SingleChildScrollView(
									padding: const EdgeInsets.all(16),
									child: Column(
										children: [
											// Provider info card
											if (booking.providerId != null) Card(
												child: FutureBuilder<List<dynamic>>(
													future: Future.wait([
														FirebaseFirestore.instance.collection('users').doc(booking.providerId!).get(),
														FirebaseFirestore.instance.collection('public_profiles').doc(booking.providerId!).get(),
													]),
													builder: (context, s) {
														if (s.connectionState == ConnectionState.waiting) {
															return const ListTile(
																leading: CircularProgressIndicator(),
																title: Text('Loading provider info...'),
															);
														}
														
														final u = (s.data?[0] as DocumentSnapshot<Map<String, dynamic>>?)?.data() ?? const {};
														final pu = (s.data?[1] as DocumentSnapshot<Map<String, dynamic>>?)?.data() ?? const {};
														
														// Create public profile if missing
														if (!(s.data?[1] as DocumentSnapshot?)!.exists && (s.data?[0] as DocumentSnapshot?)!.exists && u['name'] != null) {
															FirebaseFirestore.instance.collection('public_profiles').doc(booking.providerId!).set({
																'name': u['name'],
																'photoUrl': u['photoUrl'] ?? '',
																'createdAt': DateTime.now().toIso8601String(),
															}).then((_) {
																print('✅ Created missing public profile for provider: ${u['name']}');
															}).catchError((e) {
																print('❌ Failed to create provider public profile: $e');
															});
														}
														
														// Get provider name
														String name = 'Provider';
														if (pu['name'] != null && pu['name'].toString().trim().isNotEmpty) {
															name = pu['name'].toString().trim();
														} else if (u['name'] != null && u['name'].toString().trim().isNotEmpty) {
															name = u['name'].toString().trim();
														}
														
														// Get provider photo
														String photo = '';
														if (pu['photoUrl'] != null && pu['photoUrl'].toString().trim().isNotEmpty) {
															photo = pu['photoUrl'].toString().trim();
														} else if (u['photoUrl'] != null && u['photoUrl'].toString().trim().isNotEmpty) {
															photo = u['photoUrl'].toString().trim();
														}
														
														return ListTile(
															leading: CircleAvatar(
																backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null, 
																child: photo.isEmpty ? const Icon(Icons.person) : null
															),
															title: Text(name),
															subtitle: Text('${booking.serviceCategory} • ${booking.type.name.toUpperCase()}'),
															trailing: const Icon(Icons.star_border),
														);
													},
												),
											),
											const SizedBox(height: 16),
											StatusTimeline(steps: steps, currentIndex: idx),
											if (_bookingCancelable(booking.status)) Align(
												alignment: Alignment.centerRight,
												child: TextButton.icon(
													onPressed: () => _cancel(context, widget.bookingId), 
													icon: const Icon(Icons.cancel_outlined), 
													label: const Text('Cancel booking')
												),
											),
										],
									),
								),
							),
						],
					);
				},
			),
		);
	}
}