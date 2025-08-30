import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart' show MapsObjectId;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart' as lm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:zippup/common/models/ride.dart';
import 'package:zippup/features/orders/widgets/status_timeline.dart';
import 'package:zippup/features/transport/providers/ride_service.dart';
import 'package:zippup/services/location/distance_service.dart';
import 'package:zippup/services/notifications/sound_service.dart';
import 'package:go_router/go_router.dart';

class RideTrackScreen extends StatefulWidget {
	const RideTrackScreen({super.key, required this.rideId});
	final String rideId;

	@override
	State<RideTrackScreen> createState() => _RideTrackScreenState();
}

class _RideTrackScreenState extends State<RideTrackScreen> {
	final _distance = DistanceService();
	final _rideService = RideService();
	Set<Polyline> _polylines = {};
	int? _etaMinutes;
	DateTime? _waitingSince;
	bool _mockStarted = false;
	// Rider-side simulation when no live driver location
	Timer? _riderSimTimer;
	LatLng? _simulatedDriver;
	bool _shownSummary = false;

	@override
	void dispose() {
		_riderSimTimer?.cancel();
		_riderSimTimer = null;
		super.dispose();
	}

	List<String> _stepsFor(RideType type) => const ['Accepted', 'Arriving', 'Arrived', 'Enroute', 'Completed'];

	int _indexFor(RideStatus status, List<String> steps) {
		final map = {
			RideStatus.accepted: 'Accepted',
			RideStatus.arriving: 'Arriving',
			RideStatus.arrived: 'Arrived',
			RideStatus.enroute: 'Enroute',
			RideStatus.completed: 'Completed',
			RideStatus.cancelled: 'Completed',
			RideStatus.requested: 'Accepted',
		};
		final label = map[status] ?? 'Accepted';
		return steps.indexOf(label).clamp(0, steps.length - 1);
	}

	Future<void> _buildPolyline(String origin, String destination) async {
		final poly = await _distance.getDirectionsPolyline(origin: origin, destination: destination);
		if (poly == null) return;
		final points = _decodePolyline(poly);
		setState(() {
			_polylines = {
				Polyline(polylineId: const PolylineId('route'), points: points, color: Colors.blue, width: 5),
			};
		});
	}

	Future<void> _updateEta({required double originLat, required double originLng, required double destLat, required double destLng}) async {
		try {
			final matrix = await _distance.getMatrix(origin: '$originLat,$originLng', destinations: ['$destLat,$destLng']);
			final elements = (matrix['rows'][0]['elements'] as List);
			for (final el in elements) {
				if (el['status'] == 'OK') {
					setState(() => _etaMinutes = ((el['duration']['value'] as num).toInt() / 60).round());
					return;
				}
			}
		} catch (_) {
			// ignore errors
		}
	}

	List<LatLng> _decodePolyline(String polyline) {
		int index = 0, len = polyline.length;
		int lat = 0, lng = 0;
		final List<LatLng> coordinates = [];
		while (index < len) {
			int b, shift = 0, result = 0;
			do {
				b = polyline.codeUnitAt(index++) - 63;
				result |= (b & 0x1f) << shift;
				shift += 5;
			} while (b >= 0x20);
			final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
			lat += dlat;
			shift = 0;
			result = 0;
			do {
				b = polyline.codeUnitAt(index++) - 63;
				result |= (b & 0x1f) << shift;
				shift += 5;
			} while (b >= 0x20);
			final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
			lng += dlng;
			coordinates.add(LatLng(lat / 1E5, lng / 1E5));
		}
		return coordinates;
	}

	Future<void> _promptWaitRedirect() async {
		if (!mounted) return;
		final go = await showDialog<bool>(
			context: context,
			builder: (c) => AlertDialog(
				title: const Text('Provider is taking long to accept'),
				content: const Text('Do you want to try other providers or continue waiting?'),
				actions: [
					TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Continue waiting')),
					FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Find others')),
				],
			),
		);
		if (go == true && mounted) {
			context.push('/transport');
		} else {
			_waitingSince = DateTime.now();
		}
	}

	Future<void> _maybeStartMockAccept(Map<String, dynamic> data) async {
		if (_mockStarted) return;
		try {
			final conf = await FirebaseFirestore.instance.collection('_config').doc('mock').get();
			final auto = (conf.data() ?? const {})['autoAccept'] == true;
			if (!auto) return;
			_mockStarted = true;
			await Future.delayed(const Duration(seconds: 10));
			final pickupLat = (data['pickupLat'] as num?)?.toDouble();
			final pickupLng = (data['pickupLng'] as num?)?.toDouble();
			await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).set({
				'driverId': 'mock_driver',
				'status': 'accepted',
				if (pickupLat != null && pickupLng != null) 'driverLat': pickupLat,
				if (pickupLat != null && pickupLng != null) 'driverLng': pickupLng,
			}, SetOptions(merge: true));
		} catch (_) {}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Track Ride')),
			body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('rides').doc(widget.rideId).snapshots(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final data = snap.data!.data() ?? {};
					final ride = Ride.fromJson(widget.rideId, data);
					final steps = _stepsFor(ride.type);
					final idx = _indexFor(ride.status, steps);

					final driverLat = (data['driverLat'] as num?)?.toDouble();
					final driverLng = (data['driverLng'] as num?)?.toDouble();
					final pickupLat = (data['pickupLat'] as num?)?.toDouble();
					final pickupLng = (data['pickupLng'] as num?)?.toDouble();
					final destLat = (data['destLat'] as num?)?.toDouble();
					final destLng = (data['destLng'] as num?)?.toDouble();

					// On completion, show comprehensive summary with payment and rating
					if (ride.status == RideStatus.completed && !_shownSummary) {
						_shownSummary = true;
						WidgetsBinding.instance.addPostFrameCallback((_) async {
							// Play completion sound
							try {
								await SoundService.instance.playTrill();
							} catch (_) {}
							
							// Fetch driver info for summary
							String driverName = 'Driver';
							String driverPhoto = '';
							try {
								if (ride.driverId != null) {
									final results = await Future.wait([
										FirebaseFirestore.instance.collection('public_profiles').doc(ride.driverId!).get(),
										FirebaseFirestore.instance.collection('users').doc(ride.driverId!).get(),
									]);
									final pu = results[0].data() ?? const {};
									final u = results[1].data() ?? const {};
									
									if (pu['name'] != null && pu['name'].toString().trim().isNotEmpty) {
										driverName = pu['name'].toString().trim();
									} else if (u['name'] != null && u['name'].toString().trim().isNotEmpty) {
										driverName = u['name'].toString().trim();
									}
									
									if (pu['photoUrl'] != null && pu['photoUrl'].toString().trim().isNotEmpty) {
										driverPhoto = pu['photoUrl'].toString().trim();
									} else if (u['photoUrl'] != null && u['photoUrl'].toString().trim().isNotEmpty) {
										driverPhoto = u['photoUrl'].toString().trim();
									}
								}
							} catch (_) {}
							
							await showDialog(context: context, builder: (_) {
								final fare = ride.fareEstimate;
								final currency = data['currency'] ?? 'NGN';
								int? stars;
								final ctl = TextEditingController();
								
								return StatefulBuilder(builder: (context, setDialogState) {
									String paymentMethod = 'card';
									return AlertDialog(
										title: const Text('🎉 Ride Completed!'),
										content: SingleChildScrollView(
											child: Column(
												mainAxisSize: MainAxisSize.min,
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													// Driver info
													if (ride.driverId != null) Card(
														child: ListTile(
															leading: CircleAvatar(
																backgroundImage: driverPhoto.isNotEmpty ? NetworkImage(driverPhoto) : null,
																child: driverPhoto.isEmpty ? const Icon(Icons.person) : null,
															),
															title: Text(driverName),
															subtitle: Text('Driver • ${ride.type.name.toUpperCase()}'),
														),
													),
													const SizedBox(height: 16),
													
													// Trip details
													Card(
														child: Padding(
															padding: const EdgeInsets.all(16),
															child: Column(
																crossAxisAlignment: CrossAxisAlignment.start,
																children: [
																	const Text('Trip Details', style: TextStyle(fontWeight: FontWeight.bold)),
																	const SizedBox(height: 8),
																	Text('From: ${data['pickupAddress'] ?? 'Unknown'}'),
																	Text('To: ${data['destinationAddresses'] is List && (data['destinationAddresses'] as List).isNotEmpty ? (data['destinationAddresses'] as List).first.toString() : 'Unknown'}'),
																	if (data['distance'] != null) Text('Distance: ${(data['distance'] as num).toStringAsFixed(1)} km'),
																	if (data['duration'] != null) Text('Duration: ${((data['duration'] as num) / 60).toStringAsFixed(0)} min'),
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
																	Text('Amount to pay: $currency ${fare.toStringAsFixed(2)}', 
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
																						subtitle: const Text('Pay driver'),
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
																			: 'Please pay the driver $currency ${fare.toStringAsFixed(2)} in cash.',
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
													const Text('Rate your driver (optional):', style: TextStyle(fontWeight: FontWeight.bold)),
													const SizedBox(height: 8),
													Row(
														mainAxisAlignment: MainAxisAlignment.center,
														children: List.generate(5, (i) => IconButton(
															onPressed: () => setState(() => stars = i + 1),
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
														// Save payment method to ride
														await FirebaseFirestore.instance
															.collection('rides')
															.doc(widget.rideId)
															.set({
																'paymentMethod': paymentMethod,
																'paymentStatus': paymentMethod == 'cash' ? 'pending_cash' : 'processed',
																'completedAt': DateTime.now().toIso8601String(),
															}, SetOptions(merge: true));
														
														// Save rating if provided
														if (stars != null) {
															await FirebaseFirestore.instance
																.collection('rides')
																.doc(widget.rideId)
																.collection('ratings')
																.add({
																	'stars': stars,
																	'text': ctl.text.trim(),
																	'createdAt': DateTime.now().toIso8601String(),
																	'riderId': FirebaseAuth.instance.currentUser?.uid,
																	'driverId': ride.driverId,
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

					if (ride.status == RideStatus.requested) {
						_waitingSince ??= DateTime.now();
						// prompt every 70 seconds
						if (DateTime.now().difference(_waitingSince!).inSeconds >= 70) {
							_waitingSince = DateTime.now();
							_promptWaitRedirect();
						}
						_maybeStartMockAccept(data);
					}

					LatLng? center;
					final markers = <Marker>{};
					if (pickupLat != null && pickupLng != null) {
						final pos = LatLng(pickupLat, pickupLng);
						markers.add(Marker(markerId: const MarkerId('pickup'), position: pos, infoWindow: const InfoWindow(title: 'Pickup')));
						center ??= pos;
					}
					if (destLat != null && destLng != null) {
						final pos = LatLng(destLat, destLng);
						markers.add(Marker(markerId: const MarkerId('dest'), position: pos, infoWindow: const InfoWindow(title: 'Destination')));
						center ??= pos;
					}
					if (driverLat != null && driverLng != null) {
						final pos = LatLng(driverLat, driverLng);
						markers.add(Marker(
							markerId: const MarkerId('driver'),
							position: pos,
							infoWindow: const InfoWindow(title: 'Driver'),
							icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
						));
						center = pos;
					}

					final origin = pickupLat != null && pickupLng != null ? '$pickupLat,$pickupLng' : null;
					final dest = destLat != null && destLng != null ? '$destLat,$destLng' : null;
					if (origin != null && dest != null) {
						_buildPolyline(origin, dest);
					}

					// Update ETA when positions are available
					if (driverLat != null && driverLng != null) {
						// Before pickup: ETA to pickup; otherwise ETA to destination
						if (ride.status == RideStatus.accepted || ride.status == RideStatus.arriving || ride.status == RideStatus.requested) {
							if (pickupLat != null && pickupLng != null) {
								_updateEta(originLat: driverLat, originLng: driverLng, destLat: pickupLat, destLng: pickupLng);
							}
						} else if (destLat != null && destLng != null) {
							_updateEta(originLat: driverLat, originLng: driverLng, destLat: destLat, destLng: destLng);
						}
						// Stop rider-side simulation when real driver appears
						_riderSimTimer?.cancel();
						_riderSimTimer = null;
						_simulatedDriver = null;
					} else {
						// Enhanced simulation: show realistic driver movement
						if (pickupLat != null && pickupLng != null && destLat != null && destLng != null) {
							_riderSimTimer ??= Timer.periodic(const Duration(seconds: 3), (t) {
								// More realistic movement simulation
								double progress;
								switch (ride.status) {
									case RideStatus.accepted:
									case RideStatus.arriving:
										// Driver moving towards pickup (0% to 100% of route to pickup)
										progress = ((t.tick % 20) / 20.0).clamp(0.0, 1.0);
										break;
									case RideStatus.arrived:
										// Driver at pickup location
										progress = 1.0;
										break;
									case RideStatus.enroute:
										// Driver moving from pickup to destination (0% to 100% of main route)
										progress = ((t.tick % 30) / 30.0).clamp(0.0, 1.0);
										final lat = pickupLat + (destLat - pickupLat) * progress;
										final lng = pickupLng + (destLng - pickupLng) * progress;
										setState(() { _simulatedDriver = LatLng(lat, lng); });
										return;
									default:
										progress = 0.0;
								}
								
								// For arriving/accepted status, move towards pickup
								if (ride.status == RideStatus.accepted || ride.status == RideStatus.arriving) {
									// Start driver at a reasonable distance from pickup
									final startLat = pickupLat + (destLat - pickupLat) * 0.3; // 30% towards destination as starting point
									final startLng = pickupLng + (destLng - pickupLng) * 0.3;
									final lat = startLat + (pickupLat - startLat) * progress;
									final lng = startLng + (pickupLng - startLng) * progress;
									setState(() { _simulatedDriver = LatLng(lat, lng); });
								} else if (ride.status == RideStatus.arrived) {
									// Keep driver at pickup location
									setState(() { _simulatedDriver = LatLng(pickupLat, pickupLng); });
								}
							});
							
							// Initialize driver position if not set
							_simulatedDriver ??= LatLng(
								pickupLat + (destLat - pickupLat) * 0.3,
								pickupLng + (destLng - pickupLng) * 0.3,
							);
							
							if (_simulatedDriver != null) {
								markers.add(Marker(
									markerId: const MarkerId('driver'),
									position: _simulatedDriver!,
									infoWindow: InfoWindow(
										title: 'Driver',
										snippet: ride.status == RideStatus.arrived ? 'Arrived at pickup' : 'En route',
									),
									icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
								));
								center = _simulatedDriver;
							}
						}
					}

					return Column(
						children: [
							Expanded(
								child: Builder(builder: (context) {
									if (center == null) return const Center(child: Text('Waiting for provider...'));
									try {
										if (kIsWeb) {
											final fmMarkers = markers.map<lm.Marker>((m) {
												final isDriver = (m.markerId == const MarkerId('driver'));
												return lm.Marker(
													point: ll.LatLng(m.position.latitude, m.position.longitude),
													width: isDriver ? 44 : 36,
													height: isDriver ? 44 : 36,
													child: isDriver
														? const Icon(Icons.directions_car, color: Colors.blue, size: 40)
														: const Icon(Icons.location_on, color: Colors.redAccent),
												);
											}).toList();
											return lm.FlutterMap(
												options: lm.MapOptions(initialCenter: ll.LatLng(center!.latitude, center!.longitude), initialZoom: 14),
												children: [
													lm.TileLayer(
														urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
														userAgentPackageName: 'com.zippup.app',
														maxZoom: 19,
													),
													lm.MarkerLayer(markers: fmMarkers),
												],
											);
										}
										return GoogleMap(
											initialCameraPosition: CameraPosition(target: center!, zoom: 14),
											markers: markers,
											polylines: _polylines,
											myLocationEnabled: false,
											compassEnabled: false,
										);
									} catch (_) {
										return const Center(child: Text('Map failed to load. Check API key/config.'));
									}
							}),
							),
							Padding(
								padding: const EdgeInsets.all(16),
								child: Column(
									children: [
										if (ride.driverId != null) Card(
											child: FutureBuilder<List<dynamic>>(
												future: Future.wait([
													FirebaseFirestore.instance.collection('users').doc(ride.driverId!).get(),
													FirebaseFirestore.instance.collection('public_profiles').doc(ride.driverId!).get(),
													FirebaseFirestore.instance
														.collection('provider_profiles')
														.where('userId', isEqualTo: ride.driverId!)
														.where('service', isEqualTo: 'transport')
														.limit(1)
														.get(),
													FirebaseFirestore.instance.collection('applications').doc(ride.driverId!).get(),
												]),
												builder: (context, s) {
													if (s.connectionState == ConnectionState.waiting) {
														return const ListTile(
															leading: CircularProgressIndicator(),
															title: Text('Loading driver info...'),
														);
													}
													
													final u = (s.data?[0] as DocumentSnapshot<Map<String, dynamic>>?)?.data() ?? const {};
													final pu = (s.data?[1] as DocumentSnapshot<Map<String, dynamic>>?)?.data() ?? const {};
													
													// Debug: Print profile data
													print('🔍 Driver Profile Debug:');
													print('User profile exists: ${(s.data?[0] as DocumentSnapshot?)?.exists ?? false}');
													print('Public profile exists: ${(s.data?[1] as DocumentSnapshot?)?.exists ?? false}');
													print('User profile data: $u');
													print('Public profile data: $pu');
													
													// Create public profile if missing but user profile exists
													if (!(s.data?[1] as DocumentSnapshot?)!.exists && (s.data?[0] as DocumentSnapshot?)!.exists && u['name'] != null) {
														// Fire and forget - don't await in builder
														FirebaseFirestore.instance.collection('public_profiles').doc(ride.driverId!).set({
															'name': u['name'],
															'photoUrl': u['photoUrl'] ?? '',
															'createdAt': DateTime.now().toIso8601String(),
														}).then((_) {
															print('✅ Created missing public profile for driver: ${u['name']}');
														}).catchError((e) {
															print('❌ Failed to create driver public profile: $e');
														});
													}
													
													// Better name resolution with fallbacks
													String name = 'Driver';
													if (pu['name'] != null && pu['name'].toString().trim().isNotEmpty) {
														name = pu['name'].toString().trim();
														print('✅ Found driver name in public profile: $name');
													} else if (u['name'] != null && u['name'].toString().trim().isNotEmpty) {
														name = u['name'].toString().trim();
														print('✅ Found driver name in user profile: $name');
													} else if (u['displayName'] != null && u['displayName'].toString().trim().isNotEmpty) {
														name = u['displayName'].toString().trim();
													} else if (u['email'] != null) {
														// Extract name from email as last resort
														final email = u['email'].toString();
														final atIndex = email.indexOf('@');
														if (atIndex > 0) {
															name = email.substring(0, atIndex).replaceAll('.', ' ').replaceAll('_', ' ');
															name = name.split(' ').map((word) => word.isNotEmpty ? word[0].toUpperCase() + word.substring(1).toLowerCase() : '').join(' ');
														}
													}
													
													// Better photo resolution
													String photo = '';
													if (pu['photoUrl'] != null && pu['photoUrl'].toString().trim().isNotEmpty) {
														photo = pu['photoUrl'].toString().trim();
													} else if (u['photoUrl'] != null && u['photoUrl'].toString().trim().isNotEmpty) {
														photo = u['photoUrl'].toString().trim();
													} else if (u['profilePicture'] != null && u['profilePicture'].toString().trim().isNotEmpty) {
														photo = u['profilePicture'].toString().trim();
													}
													String plate = '';
													String car = '';
													try {
														final prof = (s.data?[2] as QuerySnapshot<Map<String, dynamic>>?);
														final app = (s.data?[3] as DocumentSnapshot<Map<String, dynamic>>?);
														final meta = prof != null && prof.docs.isNotEmpty ? (prof.docs.first.data()['metadata'] as Map<String, dynamic>? ?? const {}) : const {};
														final public = (meta['publicDetails'] as Map<String, dynamic>? ?? const {});
														plate = (public['plateNumber'] ?? '').toString();
														final a = app?.data() ?? const {};
														final color = (a['vehicleColor'] ?? '').toString();
														final brand = (a['vehicleBrand'] ?? '').toString();
														final model = (a['vehicleModel'] ?? '').toString();
														final parts = [color, brand, model].where((e) => e.trim().isNotEmpty).toList();
														car = parts.isEmpty ? '' : parts.join(' ');
													} catch (_) {}
													final vehicleLine = 'Vehicle: ' + (car.isNotEmpty ? car : 'details pending');
													final plateLine = 'Plate: ' + (plate.isNotEmpty ? plate : '—');
													return ListTile(
														leading: CircleAvatar(backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null, child: photo.isEmpty ? const Icon(Icons.person) : null),
														title: Text(name),
														subtitle: Text('ID: ${ride.driverId!.substring(0, 6)} • ${ride.type.name.toUpperCase()}\n$vehicleLine\n$plateLine'),
														trailing: const Icon(Icons.star_border),
													);
												},
											),
										),
										StatusTimeline(steps: steps, currentIndex: idx),
										if (_etaMinutes != null) Padding(
											padding: const EdgeInsets.only(top: 8.0),
											child: Text('ETA: $_etaMinutes min'),
										),
										if (_rideCancelable(ride.status)) Align(
											alignment: Alignment.centerRight,
											child: TextButton.icon(onPressed: () => _cancel(context, widget.rideId), icon: const Icon(Icons.cancel_outlined), label: const Text('Cancel ride')),
										),
									],
								),
							),
						],
					);
				},
			),
		);
	}

	Future<void> _cancel(BuildContext context, String rideId) async {
		final reasons = <String>['Change of plans', 'Booked by mistake', 'Driver taking too long', 'Other'];
		String? selected = reasons.first;
		final controller = TextEditingController();
		final confirmed = await showDialog<bool>(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('Cancel ride'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						DropdownButtonFormField<String>(
							value: selected,
							items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
							onChanged: (v) => selected = v,
							decoration: const InputDecoration(labelText: 'Reason'),
						),
						TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(labelText: 'Details (optional)')),
					],
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
					FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel ride')),
				],
			),
		);
		if (confirmed == true) {
			final reason = selected == 'Other' && controller.text.trim().isNotEmpty ? controller.text.trim() : selected ?? 'Cancelled';
			await _rideService.cancel(rideId, reason: reason, cancelledBy: 'rider');
			if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ride cancelled')));
		}
	}

	bool _rideCancelable(RideStatus s) {
		return s == RideStatus.requested || s == RideStatus.accepted || s == RideStatus.arriving || s == RideStatus.arrived;
	}
}