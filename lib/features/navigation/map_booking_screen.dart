import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:zippup/services/navigation/map_booking_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart' as lm;
import 'package:latlong2/latlong.dart' as ll;

class MapBookingScreen extends StatefulWidget {
	const MapBookingScreen({super.key});

	@override
	State<MapBookingScreen> createState() => _MapBookingScreenState();
}

class _MapBookingScreenState extends State<MapBookingScreen> {
	final MapBookingService _mapService = MapBookingService();
	GoogleMapController? _mapController;
	bool _isTracking = false;

	@override
	void initState() {
		super.initState();
		_init();
		_mapService.currentLocationNotifier.addListener(_onLocationUpdate);
	}

	void _onLocationUpdate() {
		final loc = _mapService.currentLocationNotifier.value;
		if (!kIsWeb && loc != null && _mapController != null) {
			_mapController!.animateCamera(CameraUpdate.newLatLngZoom(loc, 15));
		}
		setState(() {});
	}

	Future<void> _init() async {
		await _mapService.initializeLocation();
		await _mapService.populateInitialMarkers();
		if (mounted) setState(() {});
	}

	Widget _buildMap() {
		final current = _mapService.currentLocation;
		if (kIsWeb) {
			final center = current == null ? const ll.LatLng(0, 0) : ll.LatLng(current.latitude, current.longitude);
			final markers = _mapService.markers.map<lm.Marker>((m) => lm.Marker(
				point: ll.LatLng(m.position.latitude, m.position.longitude),
				width: 40,
				height: 40,
				child: const Icon(Icons.location_on, color: Colors.redAccent),
			)).toList();
			return lm.FlutterMap(
				options: lm.MapOptions(initialCenter: center, initialZoom: current != null ? 15 : 2),
				children: [
					lm.TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a','b','c']),
					lm.MarkerLayer(markers: markers),
				],
			);
		}
		// Mobile: Google Map
		return ValueListenableBuilder<Set<Marker>>(
			valueListenable: _mapService.markersNotifier,
			builder: (context, markers, _) {
				final initial = _mapService.currentLocation ?? const LatLng(0, 0);
				return GoogleMap(
					initialCameraPosition: CameraPosition(target: initial, zoom: _mapService.currentLocation != null ? 15 : 2),
					markers: markers,
					onMapCreated: (c) {
						_mapController = c;
						if (_mapService.currentLocation != null) {
							c.animateCamera(CameraUpdate.newLatLngZoom(_mapService.currentLocation!, 15));
						}
					},
					myLocationEnabled: true,
					myLocationButtonEnabled: true,
				);
			},
		);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Map & Booking')),
			body: Column(children: [
				// Location info
				Padding(
					padding: const EdgeInsets.all(8.0),
					child: ValueListenableBuilder<String>(
						valueListenable: _mapService.currentAddressNotifier,
						builder: (context, value, _) => Text(value, style: Theme.of(context).textTheme.bodySmall),
					),
				),
				// Map
				Expanded(
					child: Column(children: [
						Expanded(child: _buildMap()),
						if (_mapService.currentLocation == null)
							Padding(
								padding: const EdgeInsets.all(8),
								child: TextButton.icon(
									icon: const Icon(Icons.my_location),
									label: const Text('Enable location / Retry'),
									onPressed: () async { await _mapService.initializeLocation(); await _mapService.populateInitialMarkers(); setState(() {}); },
								),
							),
					]),
				),
				// Booking controls
				Padding(
					padding: const EdgeInsets.all(16.0),
					child: Column(children: [
						if (!_isTracking) ElevatedButton(onPressed: _bookTransport, child: const Text('Book Transport')),
						if (!_isTracking) const SizedBox(height: 8),
						if (!_isTracking) ElevatedButton(onPressed: _bookService, child: const Text('Book Service')),
						if (_isTracking)
							ElevatedButton(
								onPressed: _stopTracking,
								style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
								child: const Text('Cancel Booking'),
							),
					]),
				),
			]),
		);
	}

	Future<void> _bookTransport() async {
		if (_mapService.currentLocation == null) return;
		final destination = LatLng(_mapService.currentLocation!.latitude + 0.02, _mapService.currentLocation!.longitude + 0.02);
		await showModalBottomSheet(
			context: context,
			builder: (ctx) {
				final drivers = _mapService.simulatedNearbyDrivers();
				return SafeArea(
					child: ListView.separated(
						padding: const EdgeInsets.all(12),
						itemCount: drivers.length,
						separatorBuilder: (_, __) => const Divider(height: 1),
						itemBuilder: (_, i) {
							final d = drivers[i];
							return ListTile(
								title: Text('${d['name']} • ${d['kind']}'),
								subtitle: Text('${d['distance']} • ETA ${d['eta']} • Fare ${d['fare']} • Seats ${d['seats']}'),
								trailing: const Icon(Icons.chevron_right),
								onTap: () async {
									Navigator.pop(ctx);
									await _mapService.createTransportBooking(
										pickup: _mapService.currentLocation!,
										destination: destination,
										driverName: d['name'] as String,
										driverId: d['id'] as String,
										onTrackingStarted: (orderId) {
											setState(() => _isTracking = true);
											_showTrackingDialog(orderId, destination);
										},
									);
								},
							);
						},
					),
				);
			},
		);
	}

	Future<void> _bookService() async {
		await _mapService.createServiceBooking(
			providerId: 'p456',
			serviceType: 'Plumber',
			onTrackingStarted: (orderId) {
				setState(() => _isTracking = true);
				_showTrackingDialog(orderId, _mapService.currentLocation!);
			},
		);
		if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service booking requested')));
	}

	void _stopTracking() {
		setState(() => _isTracking = false);
		_mapService.stopLiveTracking();
	}

	void _showTrackingDialog(String orderId, LatLng destination) {
		showDialog(
			context: context,
			barrierDismissible: false,
			builder: (context) => AlertDialog(
				title: const Text('Tracking Booking'),
				content: SizedBox(
					height: 300,
					width: double.maxFinite,
					child: kIsWeb
						? _buildMap()
						: ValueListenableBuilder<Set<Marker>>(
							valueListenable: _mapService.markersNotifier,
							builder: (context, markers, _) {
								return GoogleMap(
									initialCameraPosition: CameraPosition(target: _mapService.currentLocation ?? const LatLng(0, 0), zoom: 15),
									markers: markers,
									onMapCreated: (controller) {
										_mapService.startLiveTracking(
											destination: destination,
											orderId: orderId,
											onDriverArrived: (id) {
												Navigator.pop(context);
												ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Driver has arrived!')));
												setState(() => _isTracking = false);
											},
										);
								},
							);
						},
					),
				),
				actions: [
					TextButton(
						onPressed: () {
							Navigator.pop(context);
							_stopTracking();
						},
						child: const Text('Cancel'),
					),
				],
			),
		);
	}

	@override
	void dispose() {
		_mapController?.dispose();
		_mapService.currentLocationNotifier.removeListener(_onLocationUpdate);
		_mapService.dispose();
		super.dispose();
	}
}
