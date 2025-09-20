import 'package:zippup/services/location/location_config_service.dart';
import 'package:zippup/services/currency/currency_service.dart';
import 'package:geocoding/geocoding.dart';

/// Global service to ensure ALL location and currency operations use user's current country
class GlobalLocationBiasService {
  static bool _initialized = false;
  static String? _userCountry;
  static Map<String, dynamic>? _userConfig;

  /// Initialize global location bias for the entire app
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      print('🌍 Initializing global location bias...');
      
      // Get user's current location configuration
      _userConfig = await LocationConfigService.getCurrentConfig();
      _userCountry = _userConfig?['countryCode'];
      
      // Initialize currency cache
      await CurrencyService.getSymbol();
      await CurrencyService.getCode();
      
      _initialized = true;
      print('✅ Global location bias initialized for country: $_userCountry');
    } catch (e) {
      print('❌ Error initializing global location bias: $e');
    }
  }

  /// Get biased address suggestions for ANY address input in the app
  static Future<List<Map<String, dynamic>>> getBiasedAddressSuggestions(String query) async {
    if (!_initialized) await initialize();
    
    try {
      if (query.trim().isEmpty) return [];
      
      final config = _userConfig ?? await LocationConfigService.getCurrentConfig();
      final countryName = config['countryName']?.toString() ?? 'Nigeria';
      
      // ALWAYS add country bias to every address search
      final biasedQuery = '$query, $countryName';
      
      print('🔍 Global biased address search: "$biasedQuery"');
      
      final locations = await locationFromAddress(biasedQuery);
      
      final results = <Map<String, dynamic>>[];
      for (final location in locations.take(8)) {
        try {
          final placemarks = await placemarkFromCoordinates(
            location.latitude, 
            location.longitude,
          );
          
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            
            // ONLY include results from user's country
            final resultCountry = place.isoCountryCode?.toUpperCase();
            if (resultCountry == _userCountry) {
              final address = _formatAddress(place, config);
              
              results.add({
                'address': address,
                'latitude': location.latitude,
                'longitude': location.longitude,
                'country': place.country ?? '',
                'isLocal': true,
              });
            } else {
              print('🚫 Filtered out result from different country: $resultCountry');
            }
          }
        } catch (e) {
          print('❌ Error processing address result: $e');
        }
      }
      
      print('✅ Returned ${results.length} country-biased address results');
      return results;
    } catch (e) {
      print('❌ Error in global biased address search: $e');
      return [];
    }
  }

  /// Get biased place name suggestions for ANY place search in the app
  static Future<List<Map<String, dynamic>>> getBiasedPlaceSuggestions(String query) async {
    if (!_initialized) await initialize();
    
    try {
      if (query.trim().isEmpty) return [];
      
      final config = _userConfig ?? await LocationConfigService.getCurrentConfig();
      final countryName = config['countryName']?.toString() ?? 'Nigeria';
      
      // ALWAYS add country bias to every place search
      final biasedQuery = '$query, $countryName';
      
      print('🔍 Global biased place search: "$biasedQuery"');
      
      final locations = await locationFromAddress(biasedQuery);
      
      final results = <Map<String, dynamic>>[];
      for (final location in locations.take(5)) {
        try {
          final placemarks = await placemarkFromCoordinates(
            location.latitude, 
            location.longitude,
          );
          
          if (placemarks.isNotEmpty) {
            final place = placemarks.first;
            
            // ONLY include results from user's country
            final resultCountry = place.isoCountryCode?.toUpperCase();
            if (resultCountry == _userCountry) {
              final address = _formatAddress(place, config);
              
              results.add({
                'name': query,
                'address': address,
                'latitude': location.latitude,
                'longitude': location.longitude,
                'country': place.country ?? '',
                'isLocal': true,
              });
            }
          }
        } catch (e) {
          print('❌ Error processing place result: $e');
        }
      }
      
      print('✅ Returned ${results.length} country-biased place results');
      return results;
    } catch (e) {
      print('❌ Error in global biased place search: $e');
      return [];
    }
  }

  /// Get global currency symbol (cached)
  static String getGlobalCurrencySymbol() {
    return CurrencyService.getCachedSymbol();
  }

  /// Get global currency code (cached)
  static String getGlobalCurrencyCode() {
    return CurrencyService.getCachedCode();
  }

  /// Format address according to user's country conventions
  static String _formatAddress(Placemark place, Map<String, dynamic> config) {
    final parts = <String>[];
    
    if (place.street?.isNotEmpty == true) parts.add(place.street!);
    if (place.locality?.isNotEmpty == true) parts.add(place.locality!);
    if (place.administrativeArea?.isNotEmpty == true) parts.add(place.administrativeArea!);
    
    return parts.join(', ');
  }

  /// Force refresh global location bias
  static Future<void> refresh() async {
    _initialized = false;
    _userCountry = null;
    _userConfig = null;
    CurrencyService.clearCache();
    await initialize();
  }

  /// Get current user's country
  static String? get userCountry => _userCountry;

  /// Check if global bias is initialized
  static bool get isInitialized => _initialized;
}