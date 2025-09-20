import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
      final country = await _detectCountryFromLocation();
      if (country != null && _countryConfigs.containsKey(country)) {
        _currentConfig = _countryConfigs[country]!;
        _detectedCountry = country;
        
        // Save to user profile for future use
        if (uid != null) {
          await _db.collection('users').doc(uid).update({
            'country': country,
            'detectedAt': FieldValue.serverTimestamp(),
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
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 10));
      
      final placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final country = placemarks.first.isoCountryCode?.toUpperCase();
        print('🌍 Detected country from location: $country');
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
}