import 'package:zippup/services/location/location_config_service.dart';

/// Service to handle currency display consistently across the app
class CurrencyService {
  static String? _cachedSymbol;
  static String? _cachedCode;

  /// Get currency symbol for current location
  static Future<String> getSymbol() async {
    if (_cachedSymbol != null) return _cachedSymbol!;
    
    _cachedSymbol = await LocationConfigService.getCurrencySymbol();
    return _cachedSymbol!;
  }

  /// Get currency code for current location
  static Future<String> getCode() async {
    if (_cachedCode != null) return _cachedCode!;
    
    _cachedCode = await LocationConfigService.getCurrencyCode();
    return _cachedCode!;
  }

  /// Format amount with currency symbol
  static Future<String> formatAmount(double amount) async {
    final symbol = await getSymbol();
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  /// Format amount with currency code
  static Future<String> formatAmountWithCode(double amount) async {
    final code = await getCode();
    return '${amount.toStringAsFixed(2)} $code';
  }

  /// Clear cache to force refresh
  static void clearCache() {
    _cachedSymbol = null;
    _cachedCode = null;
  }

  /// Get cached symbol (synchronous, returns default if not cached)
  static String getCachedSymbol() {
    return _cachedSymbol ?? '₦';
  }

  /// Get cached code (synchronous, returns default if not cached)
  static String getCachedCode() {
    return _cachedCode ?? 'NGN';
  }
}