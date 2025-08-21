import 'package:cloud_functions/cloud_functions.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PaymentsService {
	final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'us-central1');
	final Dio _dio = Dio(
		BaseOptions(
			connectTimeout: const Duration(seconds: 15),
			receiveTimeout: const Duration(seconds: 20),
		),
	);
	static const String _functionsBase = 'https://us-central1-zippup-3b5c6.cloudfunctions.net';

	Future<String> createStripeCheckout({required double amount, required String currency, List<Map<String, dynamic>> items = const []}) async {
		if (kIsWeb) {
			final response = await _dio.post('$_functionsBase/createStripeCheckout', data: {
				'items': items.map((e) => {
					'name': e['title'] ?? 'Item',
					'amount': ((e['price'] ?? 0) * 100).round(),
					'quantity': e['quantity'] ?? 1,
				}).toList(),
				'currency': currency,
			});
			final data = response.data is Map ? response.data as Map : <String, dynamic>{};
			final hostedUrl = data['url'] ?? data['checkoutUrl'];
			if (hostedUrl is String && hostedUrl.isNotEmpty) return hostedUrl;
			final sessionId = data['id'];
			if (sessionId is String && sessionId.isNotEmpty) {
				throw Exception('Stripe session created (id=$sessionId), but backend did not return a hosted URL.');
			}
			throw Exception('Stripe checkout unavailable on web.');
		}
		try {
			final callable = _functions.httpsCallable('createStripeCheckout');
			final res = await callable.call({'amount': amount, 'currency': currency, 'items': items});
			return (res.data as Map)['checkoutUrl'] as String;
		} on FirebaseFunctionsException catch (_) {
			final response = await _dio.post('$_functionsBase/createStripeCheckout', data: {
				'items': items.map((e) => {
					'name': e['title'] ?? 'Item',
					'amount': ((e['price'] ?? 0) * 100).round(),
					'quantity': e['quantity'] ?? 1,
				}).toList(),
				'currency': currency,
			});
			final data = response.data is Map ? response.data as Map : <String, dynamic>{};
			final hostedUrl = data['url'] ?? data['checkoutUrl'];
			if (hostedUrl is String && hostedUrl.isNotEmpty) return hostedUrl;
			final sessionId = data['id'];
			if (sessionId is String && sessionId.isNotEmpty) {
				throw Exception('Stripe session created (id=$sessionId), but no hosted URL returned.');
			}
			throw Exception('Stripe checkout unavailable.');
		}
	}

	Future<String> createFlutterwaveCheckout({required double amount, required String currency, List<Map<String, dynamic>> items = const []}) async {
		if (kIsWeb) {
			final response = await _dio.post('$_functionsBase/createFlutterwaveCheckout', data: {
				'amount': amount,
				'currency': currency,
			});
			final data = response.data is Map ? response.data as Map : <String, dynamic>{};
			final hostedUrl = data['checkoutUrl'];
			if (hostedUrl is String && hostedUrl.isNotEmpty) return hostedUrl;
			throw Exception('Flutterwave checkout unavailable on web.');
		}
		try {
			final callable = _functions.httpsCallable('createFlutterwaveCheckout');
			final res = await callable.call({'amount': amount, 'currency': currency, 'items': items});
			return (res.data as Map)['checkoutUrl'] as String;
		} on FirebaseFunctionsException catch (e) {
			throw Exception(e.message ?? 'Flutterwave checkout unavailable.');
		}
	}
}