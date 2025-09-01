import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class SimpleSoundService {
  SimpleSoundService._internal();
  static final SimpleSoundService instance = SimpleSoundService._internal();
  
  // Force enable verbose logging for debugging
  static const bool _debugMode = true;

  /// Play customer notification sound
  Future<bool> playCustomerNotification() async {
    print('🔔 [CUSTOMER] Starting notification...');
    bool success = false;

    // Try haptic feedback first (most reliable)
    if (!kIsWeb) {
      try {
        await HapticFeedback.mediumImpact();
        print('✅ [CUSTOMER] Haptic feedback SUCCESS');
        success = true;
      } catch (e) {
        print('❌ [CUSTOMER] Haptic failed: $e');
      }
    }

    // Try system sounds (works on all platforms)
    print('🔊 [CUSTOMER] Attempting system sounds...');

    // Try system alert sound
    if (!success) {
      try {
        await SystemSound.play(SystemSoundType.alert);
        print('✅ [CUSTOMER] System alert sound SUCCESS');
        success = true;
      } catch (e) {
        print('❌ [CUSTOMER] System alert failed: $e');
      }
    }

    // Try system click as backup
    if (!success) {
      try {
        await SystemSound.play(SystemSoundType.click);
        print('✅ [CUSTOMER] System click SUCCESS');
        success = true;
      } catch (e) {
        print('❌ [CUSTOMER] System click failed: $e');
      }
    }

    // Final fallback - vibration
    if (!success && !kIsWeb) {
      try {
        await HapticFeedback.vibrate();
        print('✅ [CUSTOMER] Vibration SUCCESS');
        success = true;
      } catch (e) {
        print('❌ [CUSTOMER] Vibration failed: $e');
      }
    }

    print(success ? '🎉 [CUSTOMER] Notification SUCCESS' : '💥 [CUSTOMER] All methods FAILED');
    return success;
  }

  /// Play driver notification sound (more urgent)
  Future<bool> playDriverNotification() async {
    print('🔔 [DRIVER] Starting urgent notification...');
    bool success = false;

    // Strong haptic for drivers
    if (!kIsWeb) {
      try {
        await HapticFeedback.heavyImpact();
        print('✅ [DRIVER] Heavy haptic SUCCESS');
        success = true;
      } catch (e) {
        print('❌ [DRIVER] Heavy haptic failed: $e');
      }
    }

    // Try urgent system sounds
    print('🔊 [DRIVER] Attempting urgent system sounds...');

    // Double click for urgency
    if (!success) {
      try {
        await SystemSound.play(SystemSoundType.click);
        await Future.delayed(const Duration(milliseconds: 200));
        await SystemSound.play(SystemSoundType.click);
        print('✅ [DRIVER] Double click SUCCESS');
        success = true;
      } catch (e) {
        print('❌ [DRIVER] Double click failed: $e');
      }
    }

    // Try alert sound as backup
    if (!success) {
      try {
        await SystemSound.play(SystemSoundType.alert);
        print('✅ [DRIVER] Alert sound SUCCESS');
        success = true;
      } catch (e) {
        print('❌ [DRIVER] Alert sound failed: $e');
      }
    }

    // Fallback to customer notification
    if (!success) {
      print('🔄 [DRIVER] Falling back to customer notification');
      success = await playCustomerNotification();
    }

    print(success ? '🎉 [DRIVER] Notification SUCCESS' : '💥 [DRIVER] All methods FAILED');
    return success;
  }

  /// Play completion notification sound
  Future<bool> playCompletionNotification() async {
    print('🎉 [COMPLETION] Starting completion notification...');
    bool success = false;

    // Light haptic for completion
    if (!kIsWeb) {
      try {
        await HapticFeedback.lightImpact();
        print('✅ [COMPLETION] Light haptic SUCCESS');
        success = true;
      } catch (e) {
        print('❌ [COMPLETION] Light haptic failed: $e');
      }
    }

    // System alert for completion
    try {
      await SystemSound.play(SystemSoundType.alert);
      print('✅ [COMPLETION] Alert sound SUCCESS');
      success = true;
    } catch (e) {
      print('❌ [COMPLETION] Alert sound failed: $e');
      // Fallback to customer notification
      success = await playCustomerNotification();
    }

    print(success ? '🎉 [COMPLETION] Notification SUCCESS' : '💥 [COMPLETION] All methods FAILED');
    return success;
  }

  /// Test all notification types
  Future<Map<String, bool>> testAllNotifications() async {
    print('🧪 [TEST] Starting comprehensive sound test...');
    
    final results = <String, bool>{};
    
    print('\n--- Testing Customer Notification ---');
    results['customer'] = await playCustomerNotification();
    await Future.delayed(const Duration(seconds: 1));
    
    print('\n--- Testing Driver Notification ---');
    results['driver'] = await playDriverNotification();
    await Future.delayed(const Duration(seconds: 1));
    
    print('\n--- Testing Completion Notification ---');
    results['completion'] = await playCompletionNotification();
    
    final successCount = results.values.where((success) => success).length;
    print('\n🧪 [TEST RESULTS] $successCount/3 notification types working');
    print('📊 [TEST SUMMARY] ${results.toString()}');
    
    return results;
  }

  /// Force play any available sound (emergency fallback)
  Future<bool> forcePlayAnySound() async {
    print('🚨 [EMERGENCY] Attempting to play ANY available sound...');
    
    final methods = [
      () async {
        await SystemSound.play(SystemSoundType.alert);
        return 'SystemSound.alert';
      },
      () async {
        await SystemSound.play(SystemSoundType.click);
        return 'SystemSound.click';
      },
      () async {
        if (!kIsWeb) {
          await HapticFeedback.mediumImpact();
          return 'HapticFeedback.mediumImpact';
        }
        throw Exception('Web platform');
      },
      () async {
        if (!kIsWeb) {
          await HapticFeedback.vibrate();
          return 'HapticFeedback.vibrate';
        }
        throw Exception('Web platform');
      },
    ];

    for (final method in methods) {
      try {
        final result = await method();
        print('✅ [EMERGENCY] SUCCESS with: $result');
        return true;
      } catch (e) {
        print('❌ [EMERGENCY] Failed method: $e');
      }
    }

    print('💥 [EMERGENCY] ALL methods failed - device may have sound disabled');
    return false;
  }
}