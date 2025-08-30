import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/emergency_booking.dart';
import 'package:zippup/features/orders/widgets/status_timeline.dart';
import 'package:zippup/services/notifications/sound_service.dart';

class EmergencyTrackScreen extends StatefulWidget {
	const EmergencyTrackScreen({super.key, required this.bookingId});
	final String bookingId;

	@override
	State<EmergencyTrackScreen> createState() => _EmergencyTrackScreenState();
}

class _EmergencyTrackScreenState extends State<EmergencyTrackScreen> {
	bool _shownSummary = false;

	List<String> _stepsFor(EmergencyType type) => const ['Requested', 'Accepted', 'Arriving', 'Arrived', 'In Progress', 'Completed'];

	int _indexFor(EmergencyStatus status, List<String> steps) {
		final map = {
			EmergencyStatus.requested: 'Requested',
			EmergencyStatus.accepted: 'Accepted',
			EmergencyStatus.arriving: 'Arriving',
			EmergencyStatus.arrived: 'Arrived',
			EmergencyStatus.inProgress: 'In Progress',
			EmergencyStatus.completed: 'Completed',
			EmergencyStatus.cancelled: 'Completed',
		};
		final label = map[status] ?? 'Requested';
		return steps.indexOf(label).clamp(0, steps.length - 1);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Track Emergency Service'),
				backgroundColor: Colors.red.shade100,
			),
			body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('emergency_bookings').doc(widget.bookingId).snapshots(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final data = snap.data!.data() ?? {};
					final booking = EmergencyBooking.fromJson(widget.bookingId, data);
					final steps = _stepsFor(booking.type);
					final idx = _indexFor(booking.status, steps);

					// Priority indicator
					final priorityColor = {
						EmergencyPriority.low: Colors.green,
						EmergencyPriority.medium: Colors.orange,
						EmergencyPriority.high: Colors.red,
						EmergencyPriority.critical: Colors.red.shade900,
					}[booking.priority] ?? Colors.orange;

					return Column(
						children: [
							// Priority banner
							Container(
								width: double.infinity,
								padding: const EdgeInsets.all(12),
								color: priorityColor.withOpacity(0.1),
								child: Row(
									children: [
										Icon(Icons.warning, color: priorityColor),
										const SizedBox(width: 8),
										Text(
											'${booking.priority.name.toUpperCase()} PRIORITY',
											style: TextStyle(
												fontWeight: FontWeight.bold,
												color: priorityColor,
											),
										),
									],
								),
							),
							
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
																title: Text('Loading responder info...'),
															);
														}
														
														final u = (s.data?[0] as DocumentSnapshot<Map<String, dynamic>>?)?.data() ?? const {};
														final pu = (s.data?[1] as DocumentSnapshot<Map<String, dynamic>>?)?.data() ?? const {};
														
														String name = 'Emergency Responder';
														String photo = '';
														
														if (pu['name'] != null && pu['name'].toString().trim().isNotEmpty) {
															name = pu['name'].toString().trim();
														} else if (u['name'] != null && u['name'].toString().trim().isNotEmpty) {
															name = u['name'].toString().trim();
														}
														
														if (pu['photoUrl'] != null && pu['photoUrl'].toString().trim().isNotEmpty) {
															photo = pu['photoUrl'].toString().trim();
														} else if (u['photoUrl'] != null && u['photoUrl'].toString().trim().isNotEmpty) {
															photo = u['photoUrl'].toString().trim();
														}
														
														return ListTile(
															leading: CircleAvatar(
																backgroundColor: Colors.red.shade100,
																backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null, 
																child: photo.isEmpty ? const Icon(Icons.medical_services, color: Colors.red) : null
															),
															title: Text(name),
															subtitle: Text('Emergency Responder • ${booking.type.name.toUpperCase()}'),
															trailing: const Icon(Icons.phone, color: Colors.red),
														);
													},
												),
											),
											const SizedBox(height: 16),
											StatusTimeline(steps: steps, currentIndex: idx),
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