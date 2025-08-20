import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PlacesService {
	final FirebaseFunctions _functions;
	PlacesService({FirebaseFunctions? functions}) : _functions = (functions ?? FirebaseFunctions.instanceFor(region: 'us-central1'));
	final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 12)));

	Future<List<PlacePrediction>> autocomplete(String input, {String? sessionToken}) async {
		if (input.trim().length < 3) return const <PlacePrediction>[];
		if (kIsWeb) {
			// Use OpenStreetMap Nominatim on web to avoid CORS with callable functions
			final url = 'https://nominatim.openstreetmap.org/search';
			final res = await _dio.get(url, queryParameters: {'q': input, 'format': 'json', 'addressdetails': 1, 'limit': 5});
			final list = (res.data as List?) ?? const [];
			return list.map((e) {
				final display = (e['display_name']?.toString() ?? '').trim();
				return PlacePrediction(description: display, placeId: (e['osm_id']?.toString() ?? ''));
			}).toList();
		}
		final res = await _functions.httpsCallable('placesAutocomplete').call(<String, dynamic>{
			'input': input,
			'sessiontoken': sessionToken,
		});
		final data = res.data as Map;
		final List preds = (data['predictions'] as List? ?? const []);
		return preds.map((e) => PlacePrediction(description: e['description']?.toString() ?? '', placeId: e['place_id']?.toString() ?? '')).toList();
	}
}

class PlacePrediction {
	final String description;
	final String placeId;
	const PlacePrediction({required this.description, required this.placeId});
	@override
	String toString() => description;
}