import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geocoding/geocoding.dart' as gc;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class LocationService {
	static Future<bool> ensurePermissions() async {
		final serviceEnabled = await Geolocator.isLocationServiceEnabled();
		if (!serviceEnabled) {
			await Geolocator.openLocationSettings();
			if (!await Geolocator.isLocationServiceEnabled()) {
				return false;
			}
		}
		LocationPermission permission = await Geolocator.checkPermission();
		if (permission == LocationPermission.denied) {
			permission = await Geolocator.requestPermission();
		}
		if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
			await Geolocator.openAppSettings();
			return false;
		}
		return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
	}

	static Future<Position?> getCurrentPosition() async {
		try {
			final hasPermission = await ensurePermissions();
			if (!hasPermission) {
				Position? last;
				if (!kIsWeb) {
					try { last = await Geolocator.getLastKnownPosition(); } catch (_) { last = null; }
				}
				if (last != null) return last;
				return _fallbackTestPosition();
			}
			return await Geolocator.getCurrentPosition(
				locationSettings: const LocationSettings(
					accuracy: LocationAccuracy.best,
				),
			);
		} catch (_) {
			final last = await Geolocator.getLastKnownPosition();
			if (last != null) return last;
			return _fallbackTestPosition();
		}
	}

	static Position _fallbackTestPosition() {
		// Lagos Island as default test coordinate
		return Position(
			latitude: 6.45407,
			longitude: 3.39467,
			accuracy: 0,
			altitude: 0,
			altitudeAccuracy: 0,
			heading: 0,
			headingAccuracy: 0,
			speed: 0,
			speedAccuracy: 0,
			timestamp: DateTime.now(),
		);
	}

	static Future<String?> reverseGeocode(Position p) async {
		// Prefer platform geocoding where supported
		if (!kIsWeb) {
			try {
				final places = await gc.placemarkFromCoordinates(p.latitude, p.longitude);
				if (places.isNotEmpty) {
					final pm = places.first;
					return [pm.street, pm.locality, pm.administrativeArea]
						.where((e) => (e ?? '').isNotEmpty)
						.map((e) => e!)
						.join(', ');
				}
			} catch (_) {
				// fall through
			}
		}
		// Use open reverse geocoding (Nominatim) on web or as fallback
		try {
			final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${p.latitude}&lon=${p.longitude}');
			final resp = await http.get(uri, headers: {'User-Agent': 'ZippUp/1.0'});
			if (resp.statusCode == 200) {
				final json = jsonDecode(resp.body) as Map<String, dynamic>;
				return (json['display_name'] as String?) ?? 'Address unavailable';
			}
			return null;
		} catch (_) {
			return null;
		}
	}

	static Future<void> updateUserLocationProfile(Position p) async {
		if (kIsWeb) return; // skip on web to avoid CORS
		try {
			final fn = FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('geocode');
			final res = await fn.call({'lat': p.latitude, 'lng': p.longitude});
			final data = Map<String, dynamic>.from(res.data as Map);
			final address = data['address']?.toString();
			final country = data['country']?.toString();
			final countryCode = data['countryCode']?.toString();
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) return;
			await FirebaseFirestore.instance.collection('users').doc(uid).set({
				'address': address,
				'country': country,
				'countryCode': countryCode,
			}, SetOptions(merge: true));
		} catch (_) {}
	}
}