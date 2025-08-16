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
		return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
	}
}