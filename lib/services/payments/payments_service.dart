import 'package:cloud_functions/cloud_functions.dart';

class PaymentsService {
	final _functions = FirebaseFunctions.instance;

	Future<String> createStripeCheckout({required double amount, required String currency, List<Map<String, dynamic>> items = const []}) async {
		final callable = _functions.httpsCallable('createStripeCheckout');
		final res = await callable.call({'amount': amount, 'currency': currency, 'items': items});
		return (res.data as Map)['checkoutUrl'] as String;
	}

	Future<String> createFlutterwaveCheckout({required double amount, required String currency, List<Map<String, dynamic>> items = const []}) async {
		final callable = _functions.httpsCallable('createFlutterwaveCheckout');
		final res = await callable.call({'amount': amount, 'currency': currency, 'items': items});
		return (res.data as Map)['checkoutUrl'] as String;
	}
}