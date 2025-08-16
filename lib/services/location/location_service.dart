import 'package:geocoding/geocoding.dart' as gc;
import 'package:geolocator/geolocator.dart';

class LocationService {
	static Future<bool> ensurePermissions() async {
		LocationPermission permission = await Geolocator.checkPermission();
		if (permission == LocationPermission.denied) {
			permission = await Geolocator.requestPermission();
		}
		return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
	}

	static Future<Position?> getCurrentPosition() async {
		final hasPermission = await ensurePermissions();
		if (!hasPermission) return null;
		return Geolocator.getCurrentPosition(
			locationSettings: const LocationSettings(
				accuracy: LocationAccuracy.best,
			),
		);
	}

	static Future<String?> reverseGeocode(Position p) async {
		final places = await gc.placemarkFromCoordinates(p.latitude, p.longitude);
		if (places.isEmpty) return null;
		final pm = places.first;
		return [pm.street, pm.locality, pm.administrativeArea].where((e) => (e ?? '').isNotEmpty).join(', ');
	}
}
