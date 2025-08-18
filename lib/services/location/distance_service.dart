import 'package:cloud_functions/cloud_functions.dart';

class DistanceService {
	final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

	Future<Map<String, dynamic>> getMatrix({required String origin, required List<String> destinations}) async {
		try {
			final callable = _functions.httpsCallable('distanceMatrix');
			final res = await callable.call({'origin': origin, 'destinations': destinations});
			return Map<String, dynamic>.from(res.data as Map);
		} on FirebaseFunctionsException catch (e) {
			throw Exception(e.message ?? 'Distance matrix failed');
		}
	}

	Future<String?> getDirectionsPolyline({required String origin, required String destination}) async {
		try {
			final callable = _functions.httpsCallable('directions');
			final res = await callable.call({'origin': origin, 'destination': destination});
			final data = Map<String, dynamic>.from(res.data as Map);
			return data['polyline'] as String?;
		} on FirebaseFunctionsException catch (_) {
			return null;
		}
	}
}