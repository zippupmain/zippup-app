import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_platform_interface/src/types/utils/patterns.dart' show PolylinePatterns; // ignore: implementation_imports
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart' show MapsObjectId;
import 'package:zippup/common/models/ride.dart';
import 'package:zippup/features/orders/widgets/status_timeline.dart';
import 'package:zippup/services/location/distance_service.dart';

class RideTrackScreen extends StatefulWidget {
	const RideTrackScreen({super.key, required this.rideId});
	final String rideId;

	@override
	State<RideTrackScreen> createState() => _RideTrackScreenState();
}

class _RideTrackScreenState extends State<RideTrackScreen> {
	final _distance = DistanceService();
	Set<Polyline> _polylines = {};

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

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Track Ride')),
			body: StreamBuilder<DocumentSnapshot<Map<String, dynamic}}>(
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

					LatLng? center;
					final markers = <Marker>{};
					if (pickupLat != null && pickupLng != null) {
						final pos = LatLng(pickupLat, pickupLng);
						markers.add(const Marker(markerId: MarkerId('pickup'), infoWindow: InfoWindow(title: 'Pickup')));
						center ??= pos;
					}
					if (destLat != null && destLng != null) {
						final pos = LatLng(destLat, destLng);
						markers.add(const Marker(markerId: MarkerId('dest'), infoWindow: InfoWindow(title: 'Destination')));
						center ??= pos;
					}
					if (driverLat != null && driverLng != null) {
						final pos = LatLng(driverLat, driverLng);
						markers.add(const Marker(markerId: MarkerId('driver'), infoWindow: InfoWindow(title: 'Driver')));
						center = pos;
					}

					final origin = pickupLat != null && pickupLng != null ? '${pickupLat},${pickupLng}' : null;
					final dest = destLat != null && destLng != null ? '${destLat},${destLng}' : null;
					if (origin != null && dest != null) {
						_buildPolyline(origin, dest);
					}

					return Column(
						children: [
							Expanded(
								child: center == null
										? const Center(child: Text('Waiting for location...'))
										: GoogleMap(
											initialCameraPosition: CameraPosition(target: center!, zoom: 14),
											markers: markers,
											polylines: _polylines,
											myLocationEnabled: false,
											compassEnabled: false,
										),
							),
							Padding(
								padding: const EdgeInsets.all(16),
								child: StatusTimeline(steps: steps, currentIndex: idx),
							),
						],
					);
				},
			),
		);
	}
}