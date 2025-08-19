import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart' show MapsObjectId;
import 'package:zippup/common/models/ride.dart';
import 'package:zippup/features/orders/widgets/status_timeline.dart';
import 'package:zippup/features/transport/providers/ride_service.dart';
import 'package:zippup/services/location/distance_service.dart';
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
						markers.add(Marker(markerId: const MarkerId('driver'), position: pos, infoWindow: const InfoWindow(title: 'Driver')));
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
					}

					return Column(
						children: [
							Expanded(
								child: Builder(builder: (context) {
									if (center == null) return const Center(child: Text('Waiting for provider...'));
									try {
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