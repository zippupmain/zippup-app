import 'package:zippup/services/currency/currency_service.dart';
import 'package:zippup/services/location/global_location_bias_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Global currency service that ensures ALL pricing across the platform uses user's location currency
class GlobalCurrencyService {
  static bool _initialized = false;
  static String? _globalCurrencyCode;
  static String? _globalCurrencySymbol;

  /// Initialize global currency for the entire platform
  static Future<void> initializeGlobalCurrency() async {
    if (_initialized) return;

    try {
      print('💰 Initializing global currency system...');
      
      // Ensure location bias is initialized first
      await GlobalLocationBiasService.initialize();
      
      // Get user's currency
      _globalCurrencyCode = await CurrencyService.getCode();
      _globalCurrencySymbol = await CurrencyService.getSymbol();
      
      print('✅ Global currency initialized: $_globalCurrencySymbol ($_globalCurrencyCode)');
      
      // Update all existing user documents to use correct currency
      await _updateUserCurrencyPreference();
      
      _initialized = true;
    } catch (e) {
      print('❌ Error initializing global currency: $e');
    }
  }

  /// Update user's currency preference in their profile
  static Future<void> _updateUserCurrencyPreference() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'preferredCurrency': _globalCurrencyCode,
        'currencySymbol': _globalCurrencySymbol,
        'currencyUpdatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Updated user currency preference: $_globalCurrencyCode');
    } catch (e) {
      print('❌ Error updating user currency preference: $e');
    }
  }

  /// Get global currency symbol (fast, cached)
  static String getGlobalSymbol() {
    return _globalCurrencySymbol ?? CurrencyService.getCachedSymbol();
  }

  /// Get global currency code (fast, cached)
  static String getGlobalCode() {
    return _globalCurrencyCode ?? CurrencyService.getCachedCode();
  }

  /// Format amount with global currency
  static String formatGlobalAmount(double amount) {
    return '${getGlobalSymbol()}${amount.toStringAsFixed(2)}';
  }

  /// Format amount with global currency (no decimals)
  static String formatGlobalAmountWhole(double amount) {
    return '${getGlobalSymbol()}${amount.toStringAsFixed(0)}';
  }

  /// Replace hardcoded currency in any text
  static String replaceHardcodedCurrency(String text) {
    final symbol = getGlobalSymbol();
    
    // Replace common hardcoded currencies
    return text
        .replaceAll('₦', symbol)
        .replaceAll('NGN', getGlobalCode())
        .replaceAll('\$', symbol)
        .replaceAll('USD', getGlobalCode())
        .replaceAll('R', symbol)
        .replaceAll('ZAR', getGlobalCode())
        .replaceAll('£', symbol)
        .replaceAll('GBP', getGlobalCode());
  }

  /// Get pricing data with correct currency
  static Map<String, dynamic> getPricingDataWithCurrency(Map<String, dynamic> originalData) {
    final data = Map<String, dynamic>.from(originalData);
    data['currency'] = getGlobalCode();
    data['currencySymbol'] = getGlobalSymbol();
    return data;
  }

  /// Refresh global currency (when location changes)
  static Future<void> refreshGlobalCurrency() async {
    _initialized = false;
    _globalCurrencyCode = null;
    _globalCurrencySymbol = null;
    CurrencyService.clearCache();
    await initializeGlobalCurrency();
  }

  /// Check if global currency is initialized
  static bool get isInitialized => _initialized;
}