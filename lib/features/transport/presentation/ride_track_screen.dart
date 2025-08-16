import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:zippup/common/models/ride.dart';
import 'package:zippup/features/orders/widgets/status_timeline.dart';

class RideTrackScreen extends StatelessWidget {
	const RideTrackScreen({super.key, required this.rideId});
	final String rideId;

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

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Track Ride')),
			body: StreamBuilder<DocumentSnapshot<Map<String, dynamic}}>(
				stream: FirebaseFirestore.instance.collection('rides').doc(rideId).snapshots(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final data = snap.data!.data() ?? {};
					final ride = Ride.fromJson(rideId, data);
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

					return Column(
						children: [
							Expanded(
								child: center == null
										? const Center(child: Text('Waiting for location...'))
										: GoogleMap(
											initialCameraPosition: CameraPosition(target: center!, zoom: 14),
											markers: markers,
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