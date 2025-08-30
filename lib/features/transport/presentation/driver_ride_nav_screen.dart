import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as lm;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';
import 'package:zippup/common/models/ride.dart';
import 'package:zippup/features/transport/providers/ride_service.dart';
import 'package:zippup/services/location/distance_service.dart';
import 'package:zippup/services/location/location_service.dart';
import 'package:zippup/services/notifications/sound_service.dart';

class DriverRideNavScreen extends StatefulWidget {
	const DriverRideNavScreen({super.key, required this.rideId});
	final String rideId;

	@override
	State<DriverRideNavScreen> createState() => _DriverRideNavScreenState();
}

class _DriverRideNavScreenState extends State<DriverRideNavScreen> {
	final _db = FirebaseFirestore.instance;
	final _auth = FirebaseAuth.instance;
	final _rideService = RideService();
	final _distance = DistanceService();
	Timer? _locTimer;
	Timer? _simTimer;
	Set<Polyline> _polylines = {};
	bool _shownDriverSummary = false;

	@override
	void initState() {
		super.initState();
		_startLocationTimer();
	}

	@override
	void dispose() {
		_locTimer?.cancel();
		_locTimer = null;
		_simTimer?.cancel();
		_simTimer = null;
		super.dispose();
	}

	void _startLocationTimer() {
		_locTimer?.cancel();
		_locTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
			try {
				final pos = await LocationService.getCurrentPosition();
				if (pos == null) return;
				await _rideService.updateDriverLocation(widget.rideId, lat: pos.latitude, lng: pos.longitude);
			} catch (_) {
				// On web or permissions denied, simulate realistic movement along route
				try {
					final doc = await _db.collection('rides').doc(widget.rideId).get();
					final data = doc.data() ?? const {};
					final pickupLat = (data['pickupLat'] as num?)?.toDouble();
					final pickupLng = (data['pickupLng'] as num?)?.toDouble();
					final destLat = (data['destLat'] as num?)?.toDouble();
					final destLng = (data['destLng'] as num?)?.toDouble();
					final status = data['status']?.toString() ?? 'requested';
					
					if (pickupLat != null && pickupLng != null && destLat != null && destLng != null) {
						_simTimer ??= Timer.periodic(const Duration(seconds: 2), (t) async {
							double lat, lng;
							
							switch (status) {
								case 'accepted':
								case 'arriving':
									// Move towards pickup location
									final progress = ((t.tick % 15) / 15.0).clamp(0.0, 1.0);
									// Start from a point between pickup and destination
									final startLat = pickupLat + (destLat - pickupLat) * 0.4;
									final startLng = pickupLng + (destLng - pickupLng) * 0.4;
									lat = startLat + (pickupLat - startLat) * progress;
									lng = startLng + (pickupLng - startLng) * progress;
									break;
								case 'arrived':
									// Stay at pickup location
									lat = pickupLat;
									lng = pickupLng;
									break;
								case 'enroute':
									// Move from pickup to destination
									final progress = ((t.tick % 20) / 20.0).clamp(0.0, 1.0);
									lat = pickupLat + (destLat - pickupLat) * progress;
									lng = pickupLng + (destLng - pickupLng) * progress;
									break;
								default:
									// Default to pickup location
									lat = pickupLat;
									lng = pickupLng;
							}
							
							try { 
								await _rideService.updateDriverLocation(widget.rideId, lat: lat, lng: lng); 
							} catch (_) {}
						});
					}
				} catch (_) {}
			}
		});
	}

	Future<void> _buildPolyline(String origin, String destination) async {
		try {
			final poly = await _distance.getDirectionsPolyline(origin: origin, destination: destination);
			if (poly == null) return;
			final points = _decodePolyline(poly);
			setState(() {
				_polylines = {
					Polyline(polylineId: const PolylineId('route'), points: points, color: Colors.blue, width: 5),
				};
			});
		} catch (_) {}
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

	Future<void> _openExternalNav({required double originLat, required double originLng, required double destLat, required double destLng}) async {
		final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&origin=$originLat,$originLng&destination=$destLat,$destLng&travelmode=driving');
		if (await canLaunchUrl(uri)) {
			await launchUrl(uri, mode: LaunchMode.externalApplication);
		}
	}

	Widget _statusActions(Ride ride, Map<String, dynamic> data) {
		switch (ride.status) {
			case RideStatus.accepted:
				return Row(children:[
					Expanded(child: FilledButton(onPressed: () => _rideService.updateStatus(ride.id, RideStatus.arriving), child: const Text('Arriving'))),
				]);
			case RideStatus.arriving:
				return Row(children:[
					Expanded(child: FilledButton(onPressed: () => _rideService.updateStatus(ride.id, RideStatus.arrived), child: const Text('Arrived'))),
				]);
			case RideStatus.arrived:
				return Row(children:[
					Expanded(child: FilledButton(onPressed: () => _rideService.updateStatus(ride.id, RideStatus.enroute), child: const Text('Start trip'))),
				]);
			case RideStatus.enroute:
				return Row(children:[
					Expanded(child: FilledButton(onPressed: () => _rideService.updateStatus(ride.id, RideStatus.completed), child: const Text('Complete'))),
				]);
			default:
				return const SizedBox.shrink();
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Driver Navigation')),
			body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
				stream: _db.collection('rides').doc(widget.rideId).snapshots(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final data = snap.data!.data() ?? {};
					final ride = Ride.fromJson(widget.rideId, data);
					final pickupLat = (data['pickupLat'] as num?)?.toDouble();
					final pickupLng = (data['pickupLng'] as num?)?.toDouble();
					final destLat = (data['destLat'] as num?)?.toDouble();
					final destLng = (data['destLng'] as num?)?.toDouble();
					final driverLat = (data['driverLat'] as num?)?.toDouble();
					final driverLng = (data['driverLng'] as num?)?.toDouble();

					// Show driver completion summary
					if (ride.status == RideStatus.completed && !_shownDriverSummary) {
						_shownDriverSummary = true;
						WidgetsBinding.instance.addPostFrameCallback((_) async {
							// Play completion sound
							try {
								await SoundService.instance.playTrill();
							} catch (_) {}
							
							// Fetch customer info for summary
							String customerName = 'Customer';
							String customerPhoto = '';
							try {
								if (ride.riderId != null) {
									final results = await Future.wait([
										FirebaseFirestore.instance.collection('public_profiles').doc(ride.riderId!).get(),
										FirebaseFirestore.instance.collection('users').doc(ride.riderId!).get(),
									]);
									final pu = results[0].data() ?? const {};
									final u = results[1].data() ?? const {};
									
									if (pu['name'] != null && pu['name'].toString().trim().isNotEmpty) {
										customerName = pu['name'].toString().trim();
									} else if (u['name'] != null && u['name'].toString().trim().isNotEmpty) {
										customerName = u['name'].toString().trim();
									}
									
									if (pu['photoUrl'] != null && pu['photoUrl'].toString().trim().isNotEmpty) {
										customerPhoto = pu['photoUrl'].toString().trim();
									} else if (u['photoUrl'] != null && u['photoUrl'].toString().trim().isNotEmpty) {
										customerPhoto = u['photoUrl'].toString().trim();
									}
								}
							} catch (_) {}
							
							await showDialog(context: context, builder: (_) {
								final fare = ride.fareEstimate;
								final currency = data['currency'] ?? 'NGN';
								
								return AlertDialog(
									title: const Text('🎉 Ride Completed!'),
									content: SingleChildScrollView(
										child: Column(
											mainAxisSize: MainAxisSize.min,
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												// Customer info
												Card(
													child: ListTile(
														leading: CircleAvatar(
															backgroundImage: customerPhoto.isNotEmpty ? NetworkImage(customerPhoto) : null,
															child: customerPhoto.isEmpty ? const Icon(Icons.person) : null,
														),
														title: Text(customerName),
														subtitle: Text('Customer • ${ride.type.name.toUpperCase()}'),
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
												
												// Earnings section
												Card(
													color: Colors.green.shade50,
													child: Padding(
														padding: const EdgeInsets.all(16),
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																const Text('💰 Earnings', style: TextStyle(fontWeight: FontWeight.bold)),
																const SizedBox(height: 8),
																Text('Customer pays: $currency ${fare.toStringAsFixed(2)}', 
																	style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
																const SizedBox(height: 4),
																Text('Your earnings: $currency ${(fare * 0.85).toStringAsFixed(2)}', 
																	style: const TextStyle(fontSize: 16, color: Colors.green)),
																const SizedBox(height: 8),
																
																// Payment method info
																Container(
																	padding: const EdgeInsets.all(12),
																	decoration: BoxDecoration(
																		color: (data['paymentMethod'] == 'cash') ? Colors.orange.shade100 : Colors.blue.shade100,
																		borderRadius: BorderRadius.circular(8),
																	),
																	child: Row(
																		children: [
																			Icon(
																				(data['paymentMethod'] == 'cash') ? Icons.payments : Icons.credit_card,
																				color: (data['paymentMethod'] == 'cash') ? Colors.orange.shade700 : Colors.blue.shade700,
																			),
																			const SizedBox(width: 8),
																			Expanded(
																				child: Text(
																					(data['paymentMethod'] == 'cash') 
																						? 'Customer will pay you $currency ${fare.toStringAsFixed(2)} in cash'
																						: 'Payment processed automatically via card',
																					style: TextStyle(
																						color: (data['paymentMethod'] == 'cash') ? Colors.orange.shade700 : Colors.blue.shade700,
																						fontWeight: FontWeight.w600,
																					),
																				),
																			),
																		],
																	),
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
											onPressed: () => Navigator.pop(context),
											child: const Text('Done'),
										),
									],
								);
							});
						});
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
						markers.add(Marker(markerId: const MarkerId('me'), position: pos, infoWindow: const InfoWindow(title: 'You')));
						center = pos;
					}

					final originStr = driverLat != null && driverLng != null ? '$driverLat,$driverLng' : (pickupLat != null && pickupLng != null ? '$pickupLat,$pickupLng' : null);
					final destStr = (ride.status == RideStatus.accepted || ride.status == RideStatus.arriving || ride.status == RideStatus.requested)
						? (pickupLat != null && pickupLng != null ? '$pickupLat,$pickupLng' : null)
						: (destLat != null && destLng != null ? '$destLat,$destLng' : null);
					if (originStr != null && destStr != null) {
						_buildPolyline(originStr, destStr);
					}

					return Column(children: [
						Expanded(child: Builder(builder: (context) {
							if (center == null) return const Center(child: Text('Loading map…'));
							try {
								if (kIsWeb) {
									final widgets = <Widget>[
										lm.TileLayer(
											urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
											userAgentPackageName: 'com.zippup.app',
											maxZoom: 19,
										),
									];
									final fmMarkers = <lm.Marker>[];
									if (pickupLat != null && pickupLng != null) fmMarkers.add(lm.Marker(point: ll.LatLng(pickupLat, pickupLng), width: 36, height: 36, child: const Icon(Icons.flag, color: Colors.green)));
									if (destLat != null && destLng != null) fmMarkers.add(lm.Marker(point: ll.LatLng(destLat, destLng), width: 36, height: 36, child: const Icon(Icons.place, color: Colors.redAccent)));
									if (driverLat != null && driverLng != null) fmMarkers.add(lm.Marker(point: ll.LatLng(driverLat, driverLng), width: 40, height: 40, child: const Icon(Icons.directions_car, color: Colors.blue)));
									widgets.add(lm.MarkerLayer(markers: fmMarkers));
									return lm.FlutterMap(
										options: lm.MapOptions(initialCenter: ll.LatLng(center!.latitude, center!.longitude), initialZoom: 14),
										children: widgets,
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
								return const Center(child: Text('Map failed to load.'));
							}
						})),
						Padding(
							padding: const EdgeInsets.all(12),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.stretch,
								children: [
									Row(children: [
										Expanded(child: FilledButton.icon(
											onPressed: (driverLat != null && driverLng != null && destLat != null && destLng != null)
												? () => _openExternalNav(originLat: driverLat!, originLng: driverLng!, destLat: (ride.status == RideStatus.accepted || ride.status == RideStatus.arriving || ride.status == RideStatus.requested) && pickupLat != null && pickupLng != null ? pickupLat : (destLat ?? 0), destLng: (ride.status == RideStatus.accepted || ride.status == RideStatus.arriving || ride.status == RideStatus.requested) && pickupLat != null && pickupLng != null ? pickupLng : (destLng ?? 0))
												: null,
											icon: const Icon(Icons.navigation),
											label: const Text('Open in Maps')
										)),
									]),
									const SizedBox(height: 8),
									_statusActions(ride, data),
								],
							),
						),
					]);
				},
			),
		);
	}
}

