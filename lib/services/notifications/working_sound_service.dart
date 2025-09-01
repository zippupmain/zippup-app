import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class WorkingSoundService {
  WorkingSoundService._internal();
  static final WorkingSoundService instance = WorkingSoundService._internal();

  /// Play notification using only methods that actually work
  Future<bool> playWorkingNotification({bool isUrgent = false}) async {
    final type = isUrgent ? 'URGENT' : 'NORMAL';
    print('🔊 [$type] Playing WORKING notification...');
    
    bool success = false;
    
    // Method 1: Multiple system sounds (most reliable)
    try {
      if (isUrgent) {
        // Urgent: Multiple rapid system sounds
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(const Duration(milliseconds: 100));
        await SystemSound.play(SystemSoundType.click);
        await Future.delayed(const Duration(milliseconds: 100));
        await SystemSound.play(SystemSoundType.alert);
        print('✅ [$type] Triple system sound SUCCESS');
      } else {
        // Normal: Single system sound
        await SystemSound.play(SystemSoundType.alert);
        print('✅ [$type] Single system sound SUCCESS');
      }
      success = true;
    } catch (e) {
      print('❌ [$type] System sounds failed: $e');
    }

    // Method 2: Haptic feedback (mobile only)
    if (!kIsWeb) {
      try {
        if (isUrgent) {
          // Urgent: Multiple strong haptics
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 150));
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 150));
          await HapticFeedback.heavyImpact();
          print('✅ [$type] Triple haptic SUCCESS');
        } else {
          // Normal: Single medium haptic
          await HapticFeedback.mediumImpact();
          print('✅ [$type] Single haptic SUCCESS');
        }
        success = true;
      } catch (e) {
        print('❌ [$type] Haptic feedback failed: $e');
      }
    }

    // Method 3: Vibration fallback
    if (!success && !kIsWeb) {
      try {
        await HapticFeedback.vibrate();
        print('✅ [$type] Vibration fallback SUCCESS');
        success = true;
      } catch (e) {
        print('❌ [$type] Vibration failed: $e');
      }
    }

    print(success ? '🎉 [$type] WORKING notification SUCCESS' : '💥 [$type] ALL methods FAILED');
    return success;
  }

  /// Customer notification
  Future<bool> playCustomerNotification() async {
    return await playWorkingNotification(isUrgent: false);
  }

  /// Driver notification (urgent)
  Future<bool> playDriverNotification() async {
    return await playWorkingNotification(isUrgent: true);
  }

  /// Completion notification
  Future<bool> playCompletionNotification() async {
    return await playWorkingNotification(isUrgent: false);
  }

  /// Emergency notification (most urgent)
  Future<bool> playEmergencyNotification() async {
    print('🚨 Playing EMERGENCY notification...');
    
    bool success = false;
    
    // Emergency: Maximum system sound sequence
    try {
      for (int i = 0; i < 5; i++) {
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(const Duration(milliseconds: 200));
        await SystemSound.play(SystemSoundType.click);
        await Future.delayed(const Duration(milliseconds: 200));
      }
      print('✅ [EMERGENCY] 5x double system sound SUCCESS');
      success = true;
    } catch (e) {
      print('❌ [EMERGENCY] System sounds failed: $e');
    }

    // Emergency: Maximum haptic sequence (mobile)
    if (!kIsWeb) {
      try {
        for (int i = 0; i < 5; i++) {
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
        }
        print('✅ [EMERGENCY] 5x heavy haptic SUCCESS');
        success = true;
      } catch (e) {
        print('❌ [EMERGENCY] Haptic sequence failed: $e');
      }
    }

    print(success ? '🎉 [EMERGENCY] Maximum notification SUCCESS' : '💥 [EMERGENCY] Even maximum failed');
    return success;
  }

  /// Test all notification types with working methods only
  Future<Map<String, bool>> testWorkingNotifications() async {
    print('\n🧪 Testing WORKING notification methods only...');
    print('🔊 Using: SystemSound + HapticFeedback (no external audio)');
    
    final results = <String, bool>{};
    
    print('\n--- Testing Customer (1 beep + 1 haptic) ---');
    results['customer'] = await playCustomerNotification();
    await Future.delayed(const Duration(seconds: 2));
    
    print('\n--- Testing Driver (3 beeps + 3 haptics) ---');
    results['driver'] = await playDriverNotification();
    await Future.delayed(const Duration(seconds: 2));
    
    print('\n--- Testing Completion (1 beep + 1 haptic) ---');
    results['completion'] = await playCompletionNotification();
    await Future.delayed(const Duration(seconds: 2));
    
    print('\n--- Testing Emergency (5x beeps + 5x haptics) ---');
    results['emergency'] = await playEmergencyNotification();
    
    final successCount = results.values.where((s) => s).length;
    print('\n🎯 WORKING METHODS RESULTS: $successCount/4 notification types successful');
    
    if (successCount > 0) {
      print('🎉 SUCCESS: At least some notification methods are working!');
      print('💡 TIP: If you heard/felt any feedback, the system is working');
    } else {
      print('💥 CRITICAL: No notification methods worked');
      print('🔧 CHECK: Device volume, system sound settings, haptic feedback settings');
    }
    
    return results;
  }
}