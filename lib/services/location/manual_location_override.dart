import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zippup/services/location/location_config_service.dart';
import 'package:zippup/services/currency/currency_service.dart';
import 'package:zippup/services/currency/global_currency_service.dart';

/// Manual location override service to force specific countries for testing and fixing
class ManualLocationOverride {
  
  /// Force set user to Nigeria (NGN ₦ currency, Nigerian addresses)
  static Future<void> forceNigeria() async {
    await _forceCountry('NG', 'Nigeria');
  }
  
  /// Force set user to United States (USD $ currency, US addresses)
  static Future<void> forceUS() async {
    await _forceCountry('US', 'United States');
  }
  
  /// Force set user to United Kingdom (GBP £ currency, UK addresses)
  static Future<void> forceUK() async {
    await _forceCountry('GB', 'United Kingdom');
  }
  
  /// Force set user to South Africa (ZAR R currency, SA addresses)
  static Future<void> forceSouthAfrica() async {
    await _forceCountry('ZA', 'South Africa');
  }
  
  /// Force set user to India (INR ₹ currency, Indian addresses)
  static Future<void> forceIndia() async {
    await _forceCountry('IN', 'India');
  }
  
  /// Force set user to Germany (EUR € currency, German addresses)
  static Future<void> forceGermany() async {
    await _forceCountry('DE', 'Germany');
  }
  
  /// Force set user to Australia (AUD A$ currency, Australian addresses)
  static Future<void> forceAustralia() async {
    await _forceCountry('AU', 'Australia');
  }
  
  /// Force set user to Singapore (SGD S$ currency, Singapore addresses)
  static Future<void> forceSingapore() async {
    await _forceCountry('SG', 'Singapore');
  }
  
  /// Force set user to specific country
  static Future<void> _forceCountry(String countryCode, String countryName) async {
    try {
      print('🔧 MANUALLY FORCING country to: $countryCode ($countryName)');
      
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        // Update user profile with forced country
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'country': countryCode,
          'detectionMethod': 'manual_override',
          'forcedAt': FieldValue.serverTimestamp(),
          'forcedCountryName': countryName,
        });
        
        print('✅ Updated user profile with forced country: $countryCode');
      }
      
      // Clear all caches and force refresh
      await LocationConfigService.setUserCountry(countryCode);
      await GlobalCurrencyService.refreshGlobalCurrency();
      
      print('✅ FORCED location to $countryName - currency and addresses should now be correct');
      
    } catch (e) {
      print('❌ Error forcing country: $e');
    }
  }
  
  /// Get current detection status for debugging
  static Future<Map<String, dynamic>> getDetectionStatus() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return {'error': 'No user logged in'};
      
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      
      final config = await LocationConfigService.getCurrentConfig();
      
      return {
        'detectedCountry': LocationConfigService.detectedCountry,
        'configCountry': config['countryCode'],
        'configCurrency': config['currency'],
        'configSymbol': config['currencySymbol'],
        'userSavedCountry': userData['country'],
        'detectionMethod': userData['detectionMethod'],
        'lastDetected': userData['detectedAt']?.toString(),
        'currentCurrency': await CurrencyService.getCode(),
        'currentSymbol': await CurrencyService.getSymbol(),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
  
  /// Clear all location data and force re-detection
  static Future<void> clearAndRedetect() async {
    try {
      print('🔄 Clearing all location data and forcing re-detection...');
      
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        // Clear saved country from user profile
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'country': FieldValue.delete(),
          'detectionMethod': FieldValue.delete(),
          'detectedAt': FieldValue.delete(),
        });
      }
      
      // Clear all caches
      await LocationConfigService.refreshLocationConfig();
      await GlobalCurrencyService.refreshGlobalCurrency();
      
      print('✅ Cleared location data and forced re-detection');
      
    } catch (e) {
      print('❌ Error clearing location data: $e');
    }
  }
}