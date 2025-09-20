import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Service to manage location-based configuration (currency, address suggestions, etc.)
class LocationConfigService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Country configurations
  static const Map<String, Map<String, dynamic>> _countryConfigs = {
    'NG': {
      'currency': 'NGN',
      'currencySymbol': '₦',
      'countryCode': 'NG',
      'countryName': 'Nigeria',
      'geocodingBias': 'country:ng',
      'addressFormat': 'street, city, state, nigeria',
    },
    'US': {
      'currency': 'USD',
      'currencySymbol': '\$',
      'countryCode': 'US',
      'countryName': 'United States',
      'geocodingBias': 'country:us',
      'addressFormat': 'street, city, state, usa',
    },
    'GB': {
      'currency': 'GBP',
      'currencySymbol': '£',
      'countryCode': 'GB',
      'countryName': 'United Kingdom',
      'geocodingBias': 'country:gb',
      'addressFormat': 'street, city, country',
    },
    'CA': {
      'currency': 'CAD',
      'currencySymbol': 'C\$',
      'countryCode': 'CA',
      'countryName': 'Canada',
      'geocodingBias': 'country:ca',
      'addressFormat': 'street, city, province, canada',
    },
    'AU': {
      'currency': 'AUD',
      'currencySymbol': 'A\$',
      'countryCode': 'AU',
      'countryName': 'Australia',
      'geocodingBias': 'country:au',
      'addressFormat': 'street, city, state, australia',
    },
    'ZA': {
      'currency': 'ZAR',
      'currencySymbol': 'R',
      'countryCode': 'ZA',
      'countryName': 'South Africa',
      'geocodingBias': 'country:za',
      'addressFormat': 'street, city, province, south africa',
    },
  };
  
  static Map<String, dynamic>? _currentConfig;
  static String? _detectedCountry;

  /// Get current location-based configuration
  static Future<Map<String, dynamic>> getCurrentConfig() async {
    if (_currentConfig != null) return _currentConfig!;
    
    try {
      // First try to get from user profile
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final userDoc = await _db.collection('users').doc(uid).get();
        final userData = userDoc.data() ?? {};
        final savedCountry = userData['country']?.toString();
        
        if (savedCountry != null && _countryConfigs.containsKey(savedCountry)) {
          _currentConfig = _countryConfigs[savedCountry]!;
          _detectedCountry = savedCountry;
          print('✅ Using saved country config: $savedCountry');
          return _currentConfig!;
        }
      }
      
      // Try to detect from current location
      String? country = await _detectCountryFromLocation();
      
      // If GPS detection fails, try IP-based detection
      if (country == null) {
        country = await _detectCountryFromIP();
      }
      
      // If still no country, try to detect from timezone
      if (country == null) {
        country = _detectCountryFromTimezone();
      }
      
      if (country != null && _countryConfigs.containsKey(country)) {
        _currentConfig = _countryConfigs[country]!;
        _detectedCountry = country;
        
        // Save to user profile for future use
        if (uid != null) {
          await _db.collection('users').doc(uid).update({
            'country': country,
            'detectedAt': FieldValue.serverTimestamp(),
            'detectionMethod': 'auto',
          });
        }
        
        print('✅ Detected and saved country config: $country');
        return _currentConfig!;
      }
      
      // Fallback to Nigeria (default)
      _currentConfig = _countryConfigs['NG']!;
      _detectedCountry = 'NG';
      print('⚠️ Using fallback country config: NG');
      return _currentConfig!;
      
    } catch (e) {
      print('❌ Error getting location config: $e');
      // Fallback to Nigeria
      _currentConfig = _countryConfigs['NG']!;
      _detectedCountry = 'NG';
      return _currentConfig!;
    }
  }

  /// Detect country from current location
  static Future<String?> _detectCountryFromLocation() async {
    try {
      print('🌍 Starting location detection...');
      
      // Check location permissions first
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        print('❌ Location permission denied');
        return null;
      }
      
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services disabled');
        return null;
      }
      
      print('✅ Location permissions granted, getting position...');
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 15));
      
      print('✅ Position obtained: ${position.latitude}, ${position.longitude}');
      
      final placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final placemark = placemarks.first;
        final country = placemark.isoCountryCode?.toUpperCase();
        print('🌍 Detected country from location: $country');
        print('📍 Full location: ${placemark.country}, ${placemark.administrativeArea}, ${placemark.locality}');
        
        // Also try to detect from country name if ISO code fails
        if (country == null && placemark.country != null) {
          final countryName = placemark.country!.toLowerCase();
          if (countryName.contains('nigeria')) return 'NG';
          if (countryName.contains('united states') || countryName.contains('america')) return 'US';
          if (countryName.contains('united kingdom') || countryName.contains('britain')) return 'GB';
          if (countryName.contains('canada')) return 'CA';
          if (countryName.contains('australia')) return 'AU';
          if (countryName.contains('south africa')) return 'ZA';
        }
        
        return country;
      }
    } catch (e) {
      print('❌ Error detecting country from location: $e');
    }
    return null;
  }

  /// Get currency symbol for current location
  static Future<String> getCurrencySymbol() async {
    final config = await getCurrentConfig();
    return config['currencySymbol'] ?? '₦';
  }

  /// Get currency code for current location
  static Future<String> getCurrencyCode() async {
    final config = await getCurrentConfig();
    return config['currency'] ?? 'NGN';
  }

  /// Get country code for current location
  static Future<String> getCountryCode() async {
    final config = await getCurrentConfig();
    return config['countryCode'] ?? 'NG';
  }

  /// Get geocoding bias for address suggestions
  static Future<String> getGeocodingBias() async {
    final config = await getCurrentConfig();
    return config['geocodingBias'] ?? 'country:ng';
  }

  /// Search for places by name (e.g., "Lagos Airport", "Victoria Island")
  static Future<List<Map<String, dynamic>>> searchPlacesByName(String query) async {
    try {
      final config = await getCurrentConfig();
      final bias = config['geocodingBias'] ?? 'country:ng';
      
      // Add country bias to the search query
      final biasedQuery = '$query, ${config['countryName'] ?? 'Nigeria'}';
      
      print('🔍 Searching places: "$biasedQuery"');
      
      final locations = await locationFromAddress(biasedQuery);
      
      final results = <Map<String, dynamic>>[];
      for (final location in locations.take(5)) { // Limit to 5 results
        try {
          final placemarks = await placemarkFromCoordinates(
            location.latitude, 
            location.longitude,
          );
          
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            final address = _formatAddress(place, config);
            
            results.add({
              'name': query,
              'address': address,
              'latitude': location.latitude,
              'longitude': location.longitude,
              'street': place.street ?? '',
              'locality': place.locality ?? '',
              'administrativeArea': place.administrativeArea ?? '',
              'country': place.country ?? '',
            });
          }
        } catch (e) {
          print('❌ Error getting placemark for location: $e');
        }
      }
      
      print('✅ Found ${results.length} places for "$query"');
      return results;
    } catch (e) {
      print('❌ Error searching places by name: $e');
      return [];
    }
  }

  /// Search for addresses with location bias
  static Future<List<Map<String, dynamic>>> searchAddresses(String query) async {
    try {
      final config = await getCurrentConfig();
      
      // Add country bias to the search query if not already included
      String biasedQuery = query;
      final countryName = config['countryName']?.toString().toLowerCase() ?? 'nigeria';
      if (!query.toLowerCase().contains(countryName)) {
        biasedQuery = '$query, $countryName';
      }
      
      print('🔍 Searching addresses: "$biasedQuery"');
      
      final locations = await locationFromAddress(biasedQuery);
      
      final results = <Map<String, dynamic>>[];
      for (final location in locations.take(8)) { // More results for addresses
        try {
          final placemarks = await placemarkFromCoordinates(
            location.latitude, 
            location.longitude,
          );
          
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            final address = _formatAddress(place, config);
            
            results.add({
              'address': address,
              'latitude': location.latitude,
              'longitude': location.longitude,
              'street': place.street ?? '',
              'locality': place.locality ?? '',
              'administrativeArea': place.administrativeArea ?? '',
              'country': place.country ?? '',
              'formattedAddress': address,
            });
          }
        } catch (e) {
          print('❌ Error getting placemark for address: $e');
        }
      }
      
      print('✅ Found ${results.length} addresses for "$query"');
      return results;
    } catch (e) {
      print('❌ Error searching addresses: $e');
      return [];
    }
  }

  /// Format address according to country conventions
  static String _formatAddress(Placemark place, Map<String, dynamic> config) {
    final parts = <String>[];
    
    if (place.street?.isNotEmpty == true) parts.add(place.street!);
    if (place.locality?.isNotEmpty == true) parts.add(place.locality!);
    if (place.administrativeArea?.isNotEmpty == true) parts.add(place.administrativeArea!);
    
    // Add country if not the default country
    final countryCode = config['countryCode']?.toString() ?? 'NG';
    if (place.isoCountryCode?.toUpperCase() != countryCode) {
      if (place.country?.isNotEmpty == true) parts.add(place.country!);
    }
    
    return parts.join(', ');
  }

  /// Force refresh location configuration
  static Future<void> refreshLocationConfig() async {
    _currentConfig = null;
    _detectedCountry = null;
    await getCurrentConfig();
  }

  /// Get current detected country
  static String? get detectedCountry => _detectedCountry;

  /// Check if location is in supported country
  static Future<bool> isInSupportedCountry() async {
    final config = await getCurrentConfig();
    final countryCode = config['countryCode']?.toString();
    return countryCode != null && _countryConfigs.containsKey(countryCode);
  }

  /// Detect country from IP address (fallback method)
  static Future<String?> _detectCountryFromIP() async {
    try {
      print('🌐 Attempting IP-based country detection...');
      
      // Use a free IP geolocation service
      final response = await http.get(
        Uri.parse('https://ipapi.co/json/'),
        headers: {'User-Agent': 'ZippUp/1.0'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final countryCode = data['country_code']?.toString().toUpperCase();
        final countryName = data['country_name']?.toString();
        
        print('🌐 IP-based detection: $countryCode ($countryName)');
        
        if (countryCode != null && _countryConfigs.containsKey(countryCode)) {
          return countryCode;
        }
      }
    } catch (e) {
      print('❌ Error with IP-based detection: $e');
    }
    
    return null;
  }

  /// Detect country from timezone (last resort)
  static String? _detectCountryFromTimezone() {
    try {
      print('🕐 Attempting timezone-based country detection...');
      
      final timezone = DateTime.now().timeZoneName;
      print('🕐 Detected timezone: $timezone');
      
      // Map common timezones to countries
      final timezoneMap = {
        'WAT': 'NG', // West Africa Time (Nigeria)
        'CAT': 'ZA', // Central Africa Time (South Africa)
        'EST': 'US', // Eastern Standard Time (US)
        'PST': 'US', // Pacific Standard Time (US)
        'CST': 'US', // Central Standard Time (US)
        'MST': 'US', // Mountain Standard Time (US)
        'GMT': 'GB', // Greenwich Mean Time (UK)
        'BST': 'GB', // British Summer Time (UK)
        'AST': 'CA', // Atlantic Standard Time (Canada)
        'AEST': 'AU', // Australian Eastern Standard Time
      };
      
      final detectedCountry = timezoneMap[timezone];
      if (detectedCountry != null) {
        print('🕐 Timezone-based detection: $detectedCountry');
        return detectedCountry;
      }
      
      // Try partial matches
      if (timezone.contains('Africa')) return 'NG';
      if (timezone.contains('America')) return 'US';
      if (timezone.contains('Europe/London')) return 'GB';
      if (timezone.contains('Australia')) return 'AU';
      
    } catch (e) {
      print('❌ Error with timezone detection: $e');
    }
    
    return null;
  }

  /// Force detect and update user's country (for testing/debugging)
  static Future<void> forceDetectCountry() async {
    print('🔄 Force detecting user country...');
    
    _currentConfig = null;
    _detectedCountry = null;
    
    final config = await getCurrentConfig();
    print('🎯 Force detection result: ${config['countryCode']} (${config['countryName']})');
  }

  /// Manually set user's country (for user preference)
  static Future<void> setUserCountry(String countryCode) async {
    try {
      if (!_countryConfigs.containsKey(countryCode)) {
        print('❌ Unsupported country code: $countryCode');
        return;
      }
      
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _db.collection('users').doc(uid).update({
          'country': countryCode,
          'detectionMethod': 'manual',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Update cache
      _currentConfig = _countryConfigs[countryCode]!;
      _detectedCountry = countryCode;
      
      // Clear currency cache to force refresh
      // Note: This would need to be called from CurrencyService
      
      print('✅ Manually set country to: $countryCode');
    } catch (e) {
      print('❌ Error setting user country: $e');
    }
  }
}