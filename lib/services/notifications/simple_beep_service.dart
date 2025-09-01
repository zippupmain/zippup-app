import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class SimpleBeepService {
  SimpleBeepService._internal();
  static final SimpleBeepService instance = SimpleBeepService._internal();
  
  static bool _isPlaying = false;

  /// Play a single system sound - no conflicts, no complexity
  Future<bool> playSimpleBeep() async {
    if (_isPlaying) {
      print('🔊 Already playing sound, skipping...');
      return false;
    }
    
    _isPlaying = true;
    print('🔊 Playing simple system beep...');
    
    try {
      // Just play ONE system sound - same as voice search feedback
      await SystemSound.play(SystemSoundType.alert);
      print('✅ Simple beep SUCCESS');
      
      // Wait a moment to prevent conflicts
      await Future.delayed(const Duration(milliseconds: 500));
      _isPlaying = false;
      return true;
      
    } catch (e) {
      print('❌ Simple beep failed: $e');
      _isPlaying = false;
      return false;
    }
  }

  /// Play urgent beep (just two sounds with delay)
  Future<bool> playUrgentBeep() async {
    if (_isPlaying) {
      print('🔊 Already playing sound, skipping urgent...');
      return false;
    }
    
    _isPlaying = true;
    print('🚨 Playing urgent beep sequence...');
    
    try {
      // Play two sounds with delay (like voice search does)
      await SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(milliseconds: 400));
      await SystemSound.play(SystemSoundType.alert);
      print('✅ Urgent beep sequence SUCCESS');
      
      // Wait before allowing next sound
      await Future.delayed(const Duration(milliseconds: 500));
      _isPlaying = false;
      return true;
      
    } catch (e) {
      print('❌ Urgent beep failed: $e');
      _isPlaying = false;
      return false;
    }
  }

  /// Add haptic feedback separately (doesn't interfere with sound)
  Future<bool> playHapticOnly() async {
    if (kIsWeb) {
      print('🌐 Web platform - no haptic feedback available');
      return false;
    }
    
    try {
      await HapticFeedback.mediumImpact();
      print('✅ Haptic feedback SUCCESS');
      return true;
    } catch (e) {
      print('❌ Haptic feedback failed: $e');
      return false;
    }
  }

  /// Customer notification - simple beep + haptic
  Future<bool> playCustomerNotification() async {
    print('👤 [CUSTOMER] Playing simple notification...');
    
    final soundSuccess = await playSimpleBeep();
    final hapticSuccess = await playHapticOnly();
    
    final success = soundSuccess || hapticSuccess;
    print('👤 [CUSTOMER] Result: Sound=$soundSuccess, Haptic=$hapticSuccess, Overall=$success');
    return success;
  }

  /// Driver notification - urgent beep + haptic  
  Future<bool> playDriverNotification() async {
    print('🚗 [DRIVER] Playing urgent notification...');
    
    final soundSuccess = await playUrgentBeep();
    final hapticSuccess = await playHapticOnly();
    
    final success = soundSuccess || hapticSuccess;
    print('🚗 [DRIVER] Result: Sound=$soundSuccess, Haptic=$hapticSuccess, Overall=$success');
    return success;
  }

  /// Completion notification - same as customer
  Future<bool> playCompletionNotification() async {
    print('🎉 [COMPLETION] Playing completion notification...');
    return await playCustomerNotification();
  }

  /// Test individual sound methods
  Future<Map<String, bool>> testIndividualMethods() async {
    print('\n🧪 Testing INDIVIDUAL sound methods (no conflicts)...');
    
    final results = <String, bool>{};
    
    print('\n--- Test 1: Single System Alert ---');
    results['system_alert'] = await playSimpleBeep();
    await Future.delayed(const Duration(seconds: 2));
    
    print('\n--- Test 2: Double System Alert ---');
    results['urgent_alert'] = await playUrgentBeep();
    await Future.delayed(const Duration(seconds: 2));
    
    print('\n--- Test 3: Haptic Feedback Only ---');
    results['haptic_only'] = await playHapticOnly();
    await Future.delayed(const Duration(seconds: 1));
    
    print('\n--- Test 4: Customer Notification ---');
    results['customer'] = await playCustomerNotification();
    await Future.delayed(const Duration(seconds: 2));
    
    print('\n--- Test 5: Driver Notification ---');
    results['driver'] = await playDriverNotification();
    
    final successCount = results.values.where((s) => s).length;
    print('\n🎯 INDIVIDUAL TESTS: $successCount/5 methods worked');
    print('📊 Results: $results');
    
    return results;
  }

  /// Reset any playing state (emergency reset)
  void resetSoundState() {
    _isPlaying = false;
    print('🔄 Sound state reset');
  }
}