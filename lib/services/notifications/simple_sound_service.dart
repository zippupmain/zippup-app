import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:zippup/services/notifications/web_beep_service.dart';

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

    // Try web beep first (most reliable on web)
    if (kIsWeb) {
      try {
        final webSuccess = await WebBeepService.playNotificationBeep();
        if (webSuccess) {
          print('✅ [CUSTOMER] Web beep SUCCESS');
          success = true;
        } else {
          print('❌ [CUSTOMER] Web beep failed');
        }
      } catch (e) {
        print('❌ [CUSTOMER] Web beep error: $e');
      }
    }

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

    // Try web urgent beep first (most reliable on web)
    if (kIsWeb) {
      try {
        final webSuccess = await WebBeepService.playUrgentBeep();
        if (webSuccess) {
          print('✅ [DRIVER] Web urgent beep SUCCESS');
          success = true;
        } else {
          print('❌ [DRIVER] Web urgent beep failed');
        }
      } catch (e) {
        print('❌ [DRIVER] Web urgent beep error: $e');
      }
    }

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
        if (kIsWeb) {
          final success = await WebBeepService.playNotificationBeep();
          if (success) return 'WebBeepService.notification';
          throw Exception('Web beep failed');
        }
        throw Exception('Not web platform');
      },
      () async {
        if (kIsWeb) {
          final success = await WebBeepService.playUrgentBeep();
          if (success) return 'WebBeepService.urgent';
          throw Exception('Web urgent beep failed');
        }
        throw Exception('Not web platform');
      },
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