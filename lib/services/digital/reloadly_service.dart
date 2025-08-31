import 'dart:convert';
import 'package:http/http.dart' as http;

class ReloadlyService {
	static const String _baseUrl = 'https://topups.reloadly.com';
	static const String _authUrl = 'https://auth.reloadly.com/oauth/token';
	
	// TODO: Replace with your actual Reloadly credentials
	static const String _clientId = 'your_reloadly_client_id';
	static const String _clientSecret = 'your_reloadly_client_secret';
	
	static String? _accessToken;
	static DateTime? _tokenExpiry;

	static Future<String> _getAccessToken() async {
		if (_accessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
			return _accessToken!;
		}

		try {
			final response = await http.post(
				Uri.parse(_authUrl),
				headers: {
					'Content-Type': 'application/json',
				},
				body: jsonEncode({
					'client_id': _clientId,
					'client_secret': _clientSecret,
					'grant_type': 'client_credentials',
					'audience': 'https://topups.reloadly.com',
				}),
			);

			if (response.statusCode == 200) {
				final data = jsonDecode(response.body);
				_accessToken = data['access_token'];
				final expiresIn = data['expires_in'] as int;
				_tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 300)); // 5 min buffer
				return _accessToken!;
			} else {
				throw Exception('Failed to get access token: ${response.statusCode}');
			}
		} catch (e) {
			throw Exception('Authentication failed: $e');
		}
	}

	static Future<List<Map<String, dynamic>>> getCountries() async {
		try {
			final token = await _getAccessToken();
			final response = await http.get(
				Uri.parse('$_baseUrl/countries'),
				headers: {
					'Authorization': 'Bearer $token',
					'Content-Type': 'application/json',
				},
			);

			if (response.statusCode == 200) {
				final List<dynamic> data = jsonDecode(response.body);
				return data.cast<Map<String, dynamic>>();
			} else {
				throw Exception('Failed to get countries: ${response.statusCode}');
			}
		} catch (e) {
			throw Exception('Error fetching countries: $e');
		}
	}

	static Future<List<Map<String, dynamic>>> getOperatorsByCountry(String countryCode) async {
		try {
			final token = await _getAccessToken();
			final response = await http.get(
				Uri.parse('$_baseUrl/operators/countries/$countryCode'),
				headers: {
					'Authorization': 'Bearer $token',
					'Content-Type': 'application/json',
				},
			);

			if (response.statusCode == 200) {
				final List<dynamic> data = jsonDecode(response.body);
				return data.cast<Map<String, dynamic>>();
			} else {
				throw Exception('Failed to get operators: ${response.statusCode}');
			}
		} catch (e) {
			throw Exception('Error fetching operators: $e');
		}
	}

	static Future<Map<String, dynamic>> purchaseAirtime({
		required String phoneNumber,
		required double amount,
		required int operatorId,
		required String countryCode,
	}) async {
		try {
			final token = await _getAccessToken();
			final response = await http.post(
				Uri.parse('$_baseUrl/topups'),
				headers: {
					'Authorization': 'Bearer $token',
					'Content-Type': 'application/json',
				},
				body: jsonEncode({
					'operatorId': operatorId,
					'amount': amount,
					'useLocalAmount': false,
					'customIdentifier': 'zippup_${DateTime.now().millisecondsSinceEpoch}',
					'recipientPhone': {
						'countryCode': countryCode,
						'number': phoneNumber,
					},
				}),
			);

			if (response.statusCode == 200) {
				return jsonDecode(response.body);
			} else {
				throw Exception('Airtime purchase failed: ${response.statusCode} - ${response.body}');
			}
		} catch (e) {
			throw Exception('Error purchasing airtime: $e');
		}
	}

	static Future<List<Map<String, dynamic>>> getDataBundles(int operatorId) async {
		try {
			final token = await _getAccessToken();
			final response = await http.get(
				Uri.parse('$_baseUrl/operators/$operatorId/data-bundles'),
				headers: {
					'Authorization': 'Bearer $token',
					'Content-Type': 'application/json',
				},
			);

			if (response.statusCode == 200) {
				final List<dynamic> data = jsonDecode(response.body);
				return data.cast<Map<String, dynamic>>();
			} else {
				throw Exception('Failed to get data bundles: ${response.statusCode}');
			}
		} catch (e) {
			throw Exception('Error fetching data bundles: $e');
		}
	}

	static Future<Map<String, dynamic>> purchaseDataBundle({
		required String phoneNumber,
		required int bundleId,
		required int operatorId,
		required String countryCode,
	}) async {
		try {
			final token = await _getAccessToken();
			final response = await http.post(
				Uri.parse('$_baseUrl/topups/data'),
				headers: {
					'Authorization': 'Bearer $token',
					'Content-Type': 'application/json',
				},
				body: jsonEncode({
					'operatorId': operatorId,
					'bundleId': bundleId,
					'customIdentifier': 'zippup_data_${DateTime.now().millisecondsSinceEpoch}',
					'recipientPhone': {
						'countryCode': countryCode,
						'number': phoneNumber,
					},
				}),
			);

			if (response.statusCode == 200) {
				return jsonDecode(response.body);
			} else {
				throw Exception('Data purchase failed: ${response.statusCode} - ${response.body}');
			}
		} catch (e) {
			throw Exception('Error purchasing data: $e');
		}
	}

	static Future<double> getAccountBalance() async {
		try {
			final token = await _getAccessToken();
			final response = await http.get(
				Uri.parse('$_baseUrl/accounts/balance'),
				headers: {
					'Authorization': 'Bearer $token',
					'Content-Type': 'application/json',
				},
			);

			if (response.statusCode == 200) {
				final data = jsonDecode(response.body);
				return (data['balance'] ?? 0.0).toDouble();
			} else {
				throw Exception('Failed to get balance: ${response.statusCode}');
			}
		} catch (e) {
			throw Exception('Error fetching balance: $e');
		}
	}

	// Country detection helper
	static String getCountryCodeFromPhone(String phoneNumber) {
		// Remove any non-digit characters
		final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
		
		// Common country codes (extend as needed)
		final countryCodes = {
			'234': 'NG', // Nigeria
			'254': 'KE', // Kenya  
			'233': 'GH', // Ghana
			'27': 'ZA',  // South Africa
			'1': 'US',   // USA/Canada
			'44': 'GB',  // UK
			'33': 'FR',  // France
			'49': 'DE',  // Germany
			'91': 'IN',  // India
		};
		
		for (final entry in countryCodes.entries) {
			if (cleanNumber.startsWith(entry.key)) {
				return entry.value;
			}
		}
		
		return 'NG'; // Default to Nigeria
	}

	// Currency helper
	static Map<String, String> getCurrencyInfo(String countryCode) {
		final currencies = {
			'NG': {'symbol': '₦', 'code': 'NGN'},
			'KE': {'symbol': 'KSh', 'code': 'KES'},
			'GH': {'symbol': '₵', 'code': 'GHS'},
			'ZA': {'symbol': 'R', 'code': 'ZAR'},
			'US': {'symbol': '\$', 'code': 'USD'},
			'GB': {'symbol': '£', 'code': 'GBP'},
			'FR': {'symbol': '€', 'code': 'EUR'},
			'DE': {'symbol': '€', 'code': 'EUR'},
			'IN': {'symbol': '₹', 'code': 'INR'},
		};
		
		return currencies[countryCode] ?? currencies['NG']!;
	}
}