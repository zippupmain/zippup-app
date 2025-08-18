import 'package:cloud_functions/cloud_functions.dart';

class PaymentsService {
	final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

	Future<String> createStripeCheckout({required double amount, required String currency, List<Map<String, dynamic>> items = const []}) async {
		try {
			final callable = _functions.httpsCallable('createStripeCheckout');
			final res = await callable.call({'amount': amount, 'currency': currency, 'items': items});
			return (res.data as Map)['checkoutUrl'] as String;
		} on FirebaseFunctionsException catch (e) {
			throw Exception(e.message ?? 'Stripe checkout failed (${e.code})');
		}
	}

	Future<String> createFlutterwaveCheckout({required double amount, required String currency, List<Map<String, dynamic>> items = const []}) async {
		try {
			final callable = _functions.httpsCallable('createFlutterwaveCheckout');
			final res = await callable.call({'amount': amount, 'currency': currency, 'items': items});
			return (res.data as Map)['checkoutUrl'] as String;
		} on FirebaseFunctionsException catch (e) {
			throw Exception(e.message ?? 'Flutterwave checkout failed (${e.code})');
		}
	}
}