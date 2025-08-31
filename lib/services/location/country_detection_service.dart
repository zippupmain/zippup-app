import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CountryDetectionService {
	static const String _countryKey = 'selected_country';

	static Future<String> detectUserCountry() async {
		try {
			// 1. Check if user has manually selected a country
			final savedCountry = await _getSavedCountry();
			if (savedCountry != null) {
				print('🌍 Using saved country: $savedCountry');
				return savedCountry;
			}

			// 2. Try GPS location detection
			final gpsCountry = await _getCountryFromGPS();
			if (gpsCountry != null) {
				print('📍 Detected country from GPS: $gpsCountry');
				return gpsCountry;
			}

			// 3. Try IP geolocation (especially for web)
			final ipCountry = await _getCountryFromIP();
			if (ipCountry != null) {
				print('🌐 Detected country from IP: $ipCountry');
				return ipCountry;
			}

			// 4. Default to Nigeria
			print('🇳🇬 Using default country: Nigeria');
			return 'NG';
		} catch (e) {
			print('❌ Country detection failed: $e');
			return 'NG'; // Default fallback
		}
	}

	static Future<String?> _getSavedCountry() async {
		try {
			final prefs = await SharedPreferences.getInstance();
			return prefs.getString(_countryKey);
		} catch (e) {
			return null;
		}
	}

	static Future<void> saveCountrySelection(String countryCode) async {
		try {
			final prefs = await SharedPreferences.getInstance();
			await prefs.setString(_countryKey, countryCode);
			print('💾 Saved country selection: $countryCode');
		} catch (e) {
			print('❌ Failed to save country: $e');
		}
	}

	static Future<String?> _getCountryFromGPS() async {
		try {
			// Check location permission
			LocationPermission permission = await Geolocator.checkPermission();
			if (permission == LocationPermission.denied) {
				permission = await Geolocator.requestPermission();
				if (permission == LocationPermission.denied) {
					print('📍 Location permission denied');
					return null;
				}
			}

			if (permission == LocationPermission.deniedForever) {
				print('📍 Location permission permanently denied');
				return null;
			}

			// Get current position
			final position = await Geolocator.getCurrentPosition(
				desiredAccuracy: LocationAccuracy.low,
				timeLimit: const Duration(seconds: 10),
			);

			// Reverse geocode to get country
			final placemarks = await placemarkFromCoordinates(
				position.latitude, 
				position.longitude,
			);

			if (placemarks.isNotEmpty) {
				final country = placemarks.first.isoCountryCode;
				if (country != null && country.isNotEmpty) {
					return country.toUpperCase();
				}
			}

			return null;
		} catch (e) {
			print('❌ GPS country detection failed: $e');
			return null;
		}
	}

	static Future<String?> _getCountryFromIP() async {
		try {
			// Use multiple IP geolocation services for reliability
			final services = [
				'https://ipapi.co/json/',
				'https://ip-api.com/json/',
				'https://ipinfo.io/json',
			];

			for (final serviceUrl in services) {
				try {
					final response = await http.get(
						Uri.parse(serviceUrl),
						headers: {'User-Agent': 'ZippUp/1.0'},
					).timeout(const Duration(seconds: 5));

					if (response.statusCode == 200) {
						final data = jsonDecode(response.body);
						
						String? countryCode;
						if (serviceUrl.contains('ipapi.co')) {
							countryCode = data['country_code'];
						} else if (serviceUrl.contains('ip-api.com')) {
							countryCode = data['countryCode'];
						} else if (serviceUrl.contains('ipinfo.io')) {
							countryCode = data['country'];
						}

						if (countryCode != null && countryCode.length == 2) {
							return countryCode.toUpperCase();
						}
					}
				} catch (e) {
					print('⚠️ IP service $serviceUrl failed: $e');
					continue; // Try next service
				}
			}

			return null;
		} catch (e) {
			print('❌ IP country detection failed: $e');
			return null;
		}
	}

	static String getCountryName(String countryCode) {
		final countries = {
			'NG': 'Nigeria',
			'KE': 'Kenya',
			'GH': 'Ghana',
			'ZA': 'South Africa',
			'UG': 'Uganda',
			'TZ': 'Tanzania',
			'RW': 'Rwanda',
			'US': 'United States',
			'CA': 'Canada',
			'GB': 'United Kingdom',
			'DE': 'Germany',
			'FR': 'France',
			'ES': 'Spain',
			'IT': 'Italy',
			'IN': 'India',
			'BR': 'Brazil',
			'MX': 'Mexico',
			'AU': 'Australia',
			'JP': 'Japan',
			'CN': 'China',
		};

		return countries[countryCode] ?? 'Unknown';
	}

	static Map<String, String> getCurrencyInfo(String countryCode) {
		final currencies = {
			'NG': {'symbol': '₦', 'code': 'NGN'},
			'KE': {'symbol': 'KSh', 'code': 'KES'},
			'GH': {'symbol': '₵', 'code': 'GHS'},
			'ZA': {'symbol': 'R', 'code': 'ZAR'},
			'UG': {'symbol': 'USh', 'code': 'UGX'},
			'TZ': {'symbol': 'TSh', 'code': 'TZS'},
			'RW': {'symbol': 'RF', 'code': 'RWF'},
			'US': {'symbol': '\$', 'code': 'USD'},
			'CA': {'symbol': 'C\$', 'code': 'CAD'},
			'GB': {'symbol': '£', 'code': 'GBP'},
			'DE': {'symbol': '€', 'code': 'EUR'},
			'FR': {'symbol': '€', 'code': 'EUR'},
			'ES': {'symbol': '€', 'code': 'EUR'},
			'IT': {'symbol': '€', 'code': 'EUR'},
			'IN': {'symbol': '₹', 'code': 'INR'},
			'BR': {'symbol': 'R\$', 'code': 'BRL'},
			'MX': {'symbol': '\$', 'code': 'MXN'},
			'AU': {'symbol': 'A\$', 'code': 'AUD'},
			'JP': {'symbol': '¥', 'code': 'JPY'},
			'CN': {'symbol': '¥', 'code': 'CNY'},
		};
		
		return currencies[countryCode] ?? currencies['NG']!;
	}

	static String getCountryFlag(String countryCode) {
		final flags = {
			'NG': '🇳🇬',
			'KE': '🇰🇪',
			'GH': '🇬🇭',
			'ZA': '🇿🇦',
			'UG': '🇺🇬',
			'TZ': '🇹🇿',
			'RW': '🇷🇼',
			'US': '🇺🇸',
			'CA': '🇨🇦',
			'GB': '🇬🇧',
			'DE': '🇩🇪',
			'FR': '🇫🇷',
			'ES': '🇪🇸',
			'IT': '🇮🇹',
			'IN': '🇮🇳',
			'BR': '🇧🇷',
			'MX': '🇲🇽',
			'AU': '🇦🇺',
			'JP': '🇯🇵',
			'CN': '🇨🇳',
		};

		return flags[countryCode] ?? '🌍';
	}
}