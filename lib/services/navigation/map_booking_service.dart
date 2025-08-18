import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapBookingService {
	// Singleton instance
	static final MapBookingService _instance = MapBookingService._internal();
	factory MapBookingService() => _instance;
	MapBookingService._internal();

	// Current location
	LatLng? _currentLocation;
	String _currentAddress = 'Detecting location...';

	// Exposed notifiers for UI to react to changes
	final ValueNotifier<LatLng?> currentLocationNotifier = ValueNotifier<LatLng?>(null);
	final ValueNotifier<String> currentAddressNotifier = ValueNotifier<String>('Detecting location...');
	final ValueNotifier<Set<Marker>> markersNotifier = ValueNotifier<Set<Marker>>(<Marker>{});

	// Tracking variables
	LatLng? _driverLocation;
	Timer? _trackingTimer;

	// Getters
	LatLng? get currentLocation => _currentLocation;
	String get currentAddress => _currentAddress;
	Set<Marker> get markers => markersNotifier.value;

	/// Initialize location services and get current position
	Future<void> initializeLocation() async {
		try {
			final serviceEnabled = await Geolocator.isLocationServiceEnabled();
			if (!serviceEnabled) {
				throw Exception('Location services are disabled.');
			}

			LocationPermission permission = await Geolocator.checkPermission();
			if (permission == LocationPermission.denied) {
				permission = await Geolocator.requestPermission();
				if (permission == LocationPermission.denied) {
					throw Exception('Location permissions are denied');
				}
			}
			if (permission == LocationPermission.deniedForever) {
				throw Exception('Location permissions are permanently denied');
			}

			final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
			_currentLocation = LatLng(position.latitude, position.longitude);
			currentLocationNotifier.value = _currentLocation;

			// Get address from coordinates
			final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
			if (placemarks.isNotEmpty) {
				final place = placemarks[0];
				_currentAddress = [place.street, place.locality, place.country].where((e) => (e ?? '').toString().trim().isNotEmpty).join(', ');
			} else {
				_currentAddress = 'Address unavailable';
			}
			currentAddressNotifier.value = _currentAddress;
		} catch (e) {
			debugPrint('Location error: $e');
			_currentAddress = 'Location unavailable';
			currentAddressNotifier.value = _currentAddress;
		}
	}

	/// Initialize the map view by centering and adding simulated nearby markers
	Future<void> populateInitialMarkers() async {
		if (_currentLocation == null) return;
		final set = <Marker>{};
		// Add current location marker
		set.add(Marker(
			markerId: const MarkerId('current_location'),
			position: _currentLocation!,
			infoWindow: const InfoWindow(title: 'Your Location'),
			icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
		));
		// Add simulated nearby markers
		final rng = Random();
		for (int i = 0; i < 5; i++) {
			final latOffset = (rng.nextDouble() - 0.5) / 100;
			final lngOffset = (rng.nextDouble() - 0.5) / 100;
			set.add(Marker(
				markerId: MarkerId('driver_$i'),
				position: LatLng(_currentLocation!.latitude + latOffset, _currentLocation!.longitude + lngOffset),
				infoWindow: InfoWindow(title: 'Driver ${i + 1}'),
				icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
			));
		}
		markersNotifier.value = set;
	}

	/// Start live tracking for a booking
	void startLiveTracking({
		required LatLng destination,
		String? orderId,
		required void Function(String) onDriverArrived,
	}) {
		if (_currentLocation == null) return;
		_driverLocation = LatLng(_currentLocation!.latitude + 0.01, _currentLocation!.longitude + 0.01);

		void _emitMarkers() {
			final set = <Marker>{};
			// driver marker
			if (_driverLocation != null) {
				set.add(Marker(
					markerId: const MarkerId('tracking_driver'),
					position: _driverLocation!,
					infoWindow: const InfoWindow(title: 'Driver'),
					icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
				));
			}
			// destination marker
			set.add(Marker(
				markerId: const MarkerId('tracking_destination'),
				position: destination,
				infoWindow: const InfoWindow(title: 'Destination'),
				icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
			));
			markersNotifier.value = set;
		}

		_emitMarkers();

		_trackingTimer?.cancel();
		_trackingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
			if (_driverLocation == null) return;
			final latDiff = destination.latitude - _driverLocation!.latitude;
			final lngDiff = destination.longitude - _driverLocation!.longitude;
			_driverLocation = LatLng(
				_driverLocation!.latitude + latDiff / 20,
				_driverLocation!.longitude + lngDiff / 20,
			);
			_emitMarkers();
			final distance = Geolocator.distanceBetween(
				_driverLocation!.latitude,
				_driverLocation!.longitude,
				destination.latitude,
				destination.longitude,
			);
			if (distance < 30) {
				timer.cancel();
				onDriverArrived(orderId ?? '');
			}
		});
	}

	/// Stop live tracking
	void stopLiveTracking() {
		_trackingTimer?.cancel();
		_trackingTimer = null;
		_driverLocation = null;
	}

	/// Create a transport booking (simulated)
	Future<void> createTransportBooking({
		required LatLng pickup,
		required LatLng destination,
		required String driverName,
		required String driverId,
		required void Function(String) onTrackingStarted,
	}) async {
		await Future.delayed(const Duration(seconds: 1));
		final orderId = 'ride-${DateTime.now().millisecondsSinceEpoch}';
		Future.delayed(const Duration(seconds: 3), () => onTrackingStarted(orderId));
	}

	/// Create a service booking (simulated)
	Future<void> createServiceBooking({
		required String providerId,
		required String serviceType,
		required void Function(String) onTrackingStarted,
	}) async {
		await Future.delayed(const Duration(seconds: 1));
		final orderId = 'svc-${DateTime.now().millisecondsSinceEpoch}';
		Future.delayed(const Duration(seconds: 10), () => onTrackingStarted(orderId));
	}

	/// Dispose resources
	void dispose() {
		_trackingTimer?.cancel();
	}
}
