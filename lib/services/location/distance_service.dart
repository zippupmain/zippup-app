import 'package:cloud_functions/cloud_functions.dart';

class DistanceService {
	final _functions = FirebaseFunctions.instance;

	Future<Map<String, dynamic>> getMatrix({required String origin, required List<String> destinations}) async {
		final callable = _functions.httpsCallable('distanceMatrix');
		final res = await callable.call({'origin': origin, 'destinations': destinations});
		return Map<String, dynamic>.from(res.data as Map);
	}

	Future<String?> getDirectionsPolyline({required String origin, required String destination}) async {
		final callable = _functions.httpsCallable('directions');
		final res = await callable.call({'origin': origin, 'destination': destination});
		final data = Map<String, dynamic>.from(res.data as Map);
		return data['polyline'] as String?;
	}
}