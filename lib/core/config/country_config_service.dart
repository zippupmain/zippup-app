import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CountryConfigService {
	static final CountryConfigService instance = CountryConfigService._();
	CountryConfigService._();

	String? _cachedCountryCode; // e.g., NG, GH, US
	Map<String, dynamic>? _countriesMap; // { "NG": { "currency": "NGN", "symbol": "₦" }, ... }

	Future<void> warmup() async {
		await Future.wait([
			_loadCountriesMap(),
			_resolveUserCountryCode(),
		]);
	}

	Future<Map<String, dynamic>> _loadCountriesMap() async {
		if (_countriesMap != null) return _countriesMap!;
		try {
			final doc = await FirebaseFirestore.instance.collection('_config').doc('countries').get();
			_countriesMap = doc.data() ?? const {};
		} catch (_) {
			_countriesMap = const {};
		}
		return _countriesMap!;
	}

	Future<String> _resolveUserCountryCode() async {
		if (_cachedCountryCode != null) return _cachedCountryCode!;
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid != null) {
				final user = await FirebaseFirestore.instance.collection('users').doc(uid).get();
				final cc = (user.data()?['countryCode']?.toString() ?? '').toUpperCase();
				if (cc.isNotEmpty) {
					_cachedCountryCode = cc;
					return cc;
				}
			}
		} catch (_) {}
		// fallback to device locale region code
		final locale = ui.PlatformDispatcher.instance.locale;
		final region = (locale.countryCode ?? '').toUpperCase();
		_cachedCountryCode = region.isNotEmpty ? region : 'US';
		return _cachedCountryCode!;
	}

	Future<String> getCountryCode() async {
		return await _resolveUserCountryCode();
	}

	Future<String> getCurrencyCode() async {
		final cc = await getCountryCode();
		final map = await _loadCountriesMap();
		return (map[cc]?['currency']?.toString() ?? 'USD');
	}

	Future<String> getCurrencySymbol() async {
		final cc = await getCountryCode();
		final map = await _loadCountriesMap();
		return (map[cc]?['symbol']?.toString() ?? '4B2'); // default: generic money symbol
	}

	Future<Map<String, dynamic>> getCountrySettings() async {
		final cc = await getCountryCode();
		final map = await _loadCountriesMap();
		return (map[cc] as Map<String, dynamic>?) ?? const {};
	}
}

