import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart' as lm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:zippup/common/models/order.dart';
import 'package:zippup/features/food/providers/order_service.dart';
import 'package:zippup/features/orders/widgets/status_timeline.dart';
import 'package:zippup/services/location/distance_service.dart';

class TrackOrderScreen extends StatefulWidget {
	const TrackOrderScreen({super.key, required this.orderId});
	final String orderId;

	@override
	State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
	final _distance = DistanceService();
	Set<Polyline> _polylines = {};
	int? _etaMinutes;

	bool _isProviderOwner(Map<String, dynamic> data) {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		return uid != null && (uid == data['providerId'] || uid == data['deliveryId']);
	}

	List<String> _stepsFor(Order o) {
		switch (o.category) {
			case OrderCategory.food:
			case OrderCategory.groceries:
				return const ['Accepted', 'Preparing', 'Dispatched', 'Assigned', 'Enroute', 'Arrived', 'Delivered'];
			case OrderCategory.transport:
				return const ['Accepted', 'Arriving', 'Arrived', 'Enroute', 'Completed'];
			default:
				return const ['Accepted', 'Enroute', 'Completed'];
		}
	}

	int _indexFor(Order o, List<String> steps) {
		final map = {
			OrderStatus.accepted: 'Accepted',
			OrderStatus.preparing: 'Preparing',
			OrderStatus.dispatched: 'Dispatched',
			OrderStatus.assigned: 'Assigned',
			OrderStatus.enroute: 'Enroute',
			OrderStatus.arrived: 'Arrived',
			OrderStatus.delivered: 'Delivered',
			OrderStatus.cancelled: 'Completed',
		};
		final label = map[o.status] ?? 'Accepted';
		return steps.indexOf(label).clamp(0, steps.length - 1);
	}

	Future<void> _buildPolyline(String origin, String destination) async {
		final poly = await _distance.getDirectionsPolyline(origin: origin, destination: destination);
		if (poly == null) return;
		final points = _decodePolyline(poly);
		setState(() {
			_polylines = {Polyline(polylineId: const PolylineId('route'), points: points, color: Colors.blue, width: 5)};
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

	bool _cancelable(Order o) {
		if (o.category == OrderCategory.food || o.category == OrderCategory.groceries) {
			return o.status.index < OrderStatus.dispatched.index;
		}
		return o.status.index < OrderStatus.enroute.index;
	}

	Future<void> _promptCancel(BuildContext context, Order o) async {
		final reasons = <String>['Change of plans', 'Booked by mistake', 'Provider taking too long', 'Other'];
		String? selected = reasons.first;
		final controller = TextEditingController();
		final confirmed = await showDialog<bool>(
			context: context,
			builder: (context) => AlertDialog(
				title: const Text('Cancel'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						DropdownButtonFormField<String>(value: selected, items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), onChanged: (v) => selected = v),
						TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(labelText: 'Details (optional)')),
					],
				),
				actions: [
					TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
					FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel')),
				],
			),
		);
		if (confirmed == true) {
			final reason = selected == 'Other' && controller.text.trim().isNotEmpty ? controller.text.trim() : selected ?? 'Cancelled';
			await OrderService().cancel(orderId: widget.orderId, reason: reason, cancelledBy: FirebaseAuth.instance.currentUser?.uid ?? 'buyer');
			if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancelled')));
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('Track Order'),
				actions: [IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.maybePop(context))],
			),
			body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('orders').doc(widget.orderId).snapshots(),
				builder: (context, snapshot) {
					if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
					final data = snapshot.data!.data() ?? {};
					final order = Order.fromJson(widget.orderId, data);
					final steps = _stepsFor(order);
					final idx = _indexFor(order, steps);

					final courierLat = (data['courierLat'] as num?)?.toDouble() ?? (data['driverLat'] as num?)?.toDouble();
					final courierLng = (data['courierLng'] as num?)?.toDouble() ?? (data['driverLng'] as num?)?.toDouble();
					final pickupLat = (data['pickupLat'] as num?)?.toDouble();
					final pickupLng = (data['pickupLng'] as num?)?.toDouble();
					final destLat = (data['destLat'] as num?)?.toDouble();
					final destLng = (data['destLng'] as num?)?.toDouble();

					LatLng? center;
					final markers = <Marker>{};
					if (pickupLat != null && pickupLng != null) {
						markers.add(Marker(markerId: const MarkerId('pickup'), position: LatLng(pickupLat, pickupLng), infoWindow: const InfoWindow(title: 'Pickup')));
						center ??= LatLng(pickupLat, pickupLng);
					}
					if (destLat != null && destLng != null) {
						markers.add(Marker(markerId: const MarkerId('dest'), position: LatLng(destLat, destLng), infoWindow: const InfoWindow(title: 'Destination')));
						center ??= LatLng(destLat, destLng);
					}
					if (courierLat != null && courierLng != null) {
						markers.add(Marker(markerId: const MarkerId('courier'), position: LatLng(courierLat, courierLng), infoWindow: const InfoWindow(title: 'Courier')));
						center = LatLng(courierLat, courierLng);
					}

					final origin = pickupLat != null && pickupLng != null ? '$pickupLat,$pickupLng' : null;
					final dest = destLat != null && destLng != null ? '$destLat,$destLng' : null;
					if (origin != null && dest != null) {
						_buildPolyline(origin, dest);
					}

					if (courierLat != null && courierLng != null) {
						if (pickupLat != null && pickupLng != null && idx < steps.indexOf('Arrived')) {
							_updateEta(originLat: courierLat, originLng: courierLng, destLat: pickupLat, destLng: pickupLng);
						} else if (destLat != null && destLng != null) {
							_updateEta(originLat: courierLat, originLng: courierLng, destLat: destLat, destLng: destLng);
						}
					}

					return Column(children: [
						Expanded(
							child: Builder(builder: (context) {
								if (center == null) return const Center(child: Text('Waiting for provider/courier...'));
								try {
									if (kIsWeb) {
										final fmMarkers = markers.map<lm.Marker>((m) => lm.Marker(
											point: ll.LatLng(m.position.latitude, m.position.longitude),
											width: 36,
											height: 36,
											child: const Icon(Icons.location_on, color: Colors.redAccent),
										)).toList();
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
							child: Column(children: [
								StatusTimeline(steps: steps, currentIndex: idx),
								if (_etaMinutes != null) Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('ETA: $_etaMinutes min')),
								if ((order.category == OrderCategory.food || order.category == OrderCategory.groceries) && FirebaseAuth.instance.currentUser?.uid == order.buyerId && data['deliveryCode'] != null && (order.status.index < OrderStatus.delivered.index))
									Container(
										margin: const EdgeInsets.only(top: 16),
										padding: const EdgeInsets.all(16),
										decoration: BoxDecoration(
											gradient: LinearGradient(
												colors: [Colors.green.shade50, Colors.green.shade100],
											),
											borderRadius: BorderRadius.circular(12),
											border: Border.all(color: Colors.green.shade300, width: 2),
										),
										child: Column(
											children: [
												Row(
													mainAxisAlignment: MainAxisAlignment.center,
													children: [
														Icon(Icons.delivery_dining, color: Colors.green.shade700, size: 28),
														const SizedBox(width: 12),
														const Text(
															'Delivery Code',
															style: TextStyle(
																fontWeight: FontWeight.bold,
																fontSize: 18,
																color: Colors.black,
															),
														),
													],
												),
												const SizedBox(height: 12),
												Container(
													padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
													decoration: BoxDecoration(
														color: Colors.white,
														borderRadius: BorderRadius.circular(8),
														border: Border.all(color: Colors.green.shade400, width: 2),
													),
													child: Text(
														'${data['deliveryCode']}',
														style: TextStyle(
															fontSize: 32,
															fontWeight: FontWeight.bold,
															color: Colors.green.shade800,
															letterSpacing: 4,
														),
													),
												),
												const SizedBox(height: 8),
												const Text(
													'📱 Show this code to the delivery person',
													style: TextStyle(
														color: Colors.black87,
														fontSize: 14,
														fontWeight: FontWeight.w600,
													),
												),
											],
										),
									),
								if (_cancelable(order)) Align(
									alignment: Alignment.centerRight,
									child: TextButton.icon(onPressed: () => _promptCancel(context, order), icon: const Icon(Icons.cancel_outlined), label: const Text('Cancel')),
								),
							]),
						),
					]);
				},
			),
		);
	}
}