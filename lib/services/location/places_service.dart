import 'package:cloud_functions/cloud_functions.dart';

class PlacesService {
	final FirebaseFunctions _functions;
	PlacesService({FirebaseFunctions? functions}) : _functions = functions ?? FirebaseFunctions.instance;

	Future<List<PlacePrediction>> autocomplete(String input, {String? sessionToken}) async {
		if (input.trim().length < 3) return const <PlacePrediction>[];
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