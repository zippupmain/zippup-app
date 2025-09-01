import 'package:zippup/services/payments/payments_service.dart';

class GlobalPaymentRouter {
	static const Map<String, List<String>> _gatewaysByRegion = {
		// Africa - Use Flutterwave (best for African markets)
		'africa': ['flutterwave', 'paystack'],
		// Americas - Use Stripe (best for US/Canada/Latin America)
		'americas': ['stripe', 'paypal'],
		// Europe - Use Stripe (best for EU)
		'europe': ['stripe', 'paypal'],
		// Asia - Use Stripe + local gateways
		'asia': ['stripe', 'razorpay'],
		// Oceania - Use Stripe
		'oceania': ['stripe', 'paypal'],
	};

	static const Map<String, String> _countryToRegion = {
		// Africa
		'NG': 'africa', 'KE': 'africa', 'GH': 'africa', 'ZA': 'africa',
		'UG': 'africa', 'TZ': 'africa', 'RW': 'africa', 'ET': 'africa',
		'EG': 'africa', 'MA': 'africa', 'DZ': 'africa', 'TN': 'africa',
		
		// Americas
		'US': 'americas', 'CA': 'americas', 'BR': 'americas', 'MX': 'americas',
		'AR': 'americas', 'CL': 'americas', 'CO': 'americas', 'PE': 'americas',
		
		// Europe
		'GB': 'europe', 'DE': 'europe', 'FR': 'europe', 'ES': 'europe',
		'IT': 'europe', 'NL': 'europe', 'SE': 'europe', 'NO': 'europe',
		'DK': 'europe', 'FI': 'europe', 'PL': 'europe', 'CH': 'europe',
		
		// Asia
		'IN': 'asia', 'CN': 'asia', 'JP': 'asia', 'KR': 'asia',
		'TH': 'asia', 'VN': 'asia', 'PH': 'asia', 'ID': 'asia',
		'MY': 'asia', 'SG': 'asia', 'BD': 'asia', 'PK': 'asia',
		
		// Oceania
		'AU': 'oceania', 'NZ': 'oceania', 'FJ': 'oceania',
	};

	static String getPrimaryGateway(String countryCode) {
		final region = _countryToRegion[countryCode] ?? 'africa';
		final gateways = _gatewaysByRegion[region] ?? ['stripe'];
		return gateways.first;
	}

	static List<String> getAvailableGateways(String countryCode) {
		final region = _countryToRegion[countryCode] ?? 'africa';
		return _gatewaysByRegion[region] ?? ['stripe'];
	}

	static Future<String> createCheckout({
		required double amount,
		required String currency,
		required String countryCode,
		required List<Map<String, dynamic>> items,
		String? preferredGateway,
	}) async {
		final gateway = preferredGateway ?? getPrimaryGateway(countryCode);
		final paymentsService = PaymentsService();

		print('🌍 Using $gateway gateway for $countryCode ($currency)');

		switch (gateway) {
			case 'flutterwave':
				return await paymentsService.createFlutterwaveCheckout(
					amount: amount,
					currency: currency,
					items: items,
				);
			
			case 'stripe':
				return await paymentsService.createStripeCheckout(
					amount: amount,
					currency: currency,
					items: items,
				);
			
			case 'paystack':
				// TODO: Implement Paystack integration
				return await paymentsService.createFlutterwaveCheckout(
					amount: amount,
					currency: currency,
					items: items,
				);
			
			default:
				// Fallback to Stripe for unknown gateways
				return await paymentsService.createStripeCheckout(
					amount: amount,
					currency: currency,
					items: items,
				);
		}
	}

	static bool isGatewaySupported(String gateway, String countryCode) {
		final availableGateways = getAvailableGateways(countryCode);
		return availableGateways.contains(gateway);
	}

	static String getGatewayDisplayName(String gateway) {
		final names = {
			'flutterwave': 'Flutterwave',
			'stripe': 'Stripe',
			'paystack': 'Paystack',
			'paypal': 'PayPal',
			'razorpay': 'Razorpay',
		};
		return names[gateway] ?? gateway.toUpperCase();
	}

	static String getGatewayDescription(String gateway, String countryCode) {
		final region = _countryToRegion[countryCode] ?? 'africa';
		
		switch (gateway) {
			case 'flutterwave':
				return 'Best for African markets - Bank transfer, Mobile money, USSD';
			case 'stripe':
				return region == 'americas' ? 'Best for US/Canada - Cards, ACH, Apple Pay' :
					   region == 'europe' ? 'Best for Europe - Cards, SEPA, iDEAL' :
					   'Global card processing - Visa, Mastercard, Amex';
			case 'paystack':
				return 'Best for Nigeria/Ghana - Bank transfer, USSD, Cards';
			case 'paypal':
				return 'Global wallet - PayPal balance, Cards, Bank account';
			case 'razorpay':
				return 'Best for India - UPI, Net banking, Wallets, Cards';
			default:
				return 'Secure payment processing';
		}
	}

	// Currency conversion helpers (for display purposes)
	static double convertCurrency(double amount, String fromCurrency, String toCurrency) {
		// TODO: Implement real-time currency conversion
		// For now, return the same amount
		// In production, integrate with a currency API like exchangerate-api.com
		
		if (fromCurrency == toCurrency) return amount;
		
		// Basic conversion rates (should be real-time in production)
		final rates = {
			'NGN_USD': 0.0012,
			'NGN_GBP': 0.001,
			'NGN_EUR': 0.0011,
			'USD_NGN': 830.0,
			'GBP_NGN': 1000.0,
			'EUR_NGN': 910.0,
		};
		
		final conversionKey = '${fromCurrency}_$toCurrency';
		final rate = rates[conversionKey];
		
		if (rate != null) {
			return amount * rate;
		}
		
		return amount; // No conversion available
	}

	static String formatCurrency(double amount, String currency) {
		final symbols = {
			'NGN': '₦',
			'USD': '\$',
			'GBP': '£',
			'EUR': '€',
			'KES': 'KSh',
			'GHS': '₵',
			'ZAR': 'R',
			'INR': '₹',
			'JPY': '¥',
			'CNY': '¥',
		};
		
		final symbol = symbols[currency] ?? currency;
		return '$symbol${amount.toStringAsFixed(2)}';
	}
}