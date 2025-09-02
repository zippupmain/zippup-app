import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class ReliableSoundService {
  ReliableSoundService._internal();
  static final ReliableSoundService instance = ReliableSoundService._internal();
  final AudioPlayer _player = AudioPlayer();

  /// Play notification with maximum compatibility
  Future<bool> playNotification({bool isUrgent = false}) async {
    final type = isUrgent ? 'URGENT' : 'NORMAL';
    print('🔔 [$type] Starting reliable notification...');
    
    bool anySuccess = false;
    final results = <String, bool>{};

    // 1. Try haptic feedback (mobile only, most reliable)
    if (!kIsWeb) {
      try {
        if (isUrgent) {
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.heavyImpact();
        } else {
          await HapticFeedback.mediumImpact();
        }
        results['haptic'] = true;
        anySuccess = true;
        print('✅ [$type] Haptic feedback SUCCESS');
      } catch (e) {
        results['haptic'] = false;
        print('❌ [$type] Haptic failed: $e');
      }
    }

    // 2. Try SystemSound.alert (most compatible)
    try {
      await SystemSound.play(SystemSoundType.alert);
      results['system_alert'] = true;
      anySuccess = true;
      print('✅ [$type] System alert SUCCESS');
    } catch (e) {
      results['system_alert'] = false;
      print('❌ [$type] System alert failed: $e');
    }

    // 3. Try data URL audio (most reliable for actual sound)
    try {
      if (isUrgent) {
        // Triple beeps for urgent notifications
        for (int i = 0; i < 3; i++) {
          await _player.play(UrlSource('data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBjmL0fPTgjMGJXTA7+ONQQ0PU6/r77BdGAg+ltryxnkpBSl+zPLaizsIGGS57OihUgwKUKXh8bllHgg2jdT0z4IyBSJ0wO/jkEEND1Ov6++wXRgIPpba8sZ5KQUpfszy2os7CBhkuezoIVIMClCl4fG5ZR4INozU9M+CMgUidMDv45BBDw9Tr+vvsF0YCD6W2vLGeSsFKX7M8tqLOwgYZLns6CFSDApQpeHxuWUeCDaM1PTPgjIFInTA7+OQQw8PU6/r77BdGAg+ltryxnkpBSl+zPLaizsIGGS57OghUgwKUKXh8bllHgg2jNT0z4IyBSJ0wO/jkEMPD1Ov6++wXRgIPpba8sZ5KQUpfszy2os7CBhkuezoIVIMClCl4fG5ZR4INozU9M+CMgUidMDv45BDDw9Tr+vvsF0YCD6W2vLGeSsFKX7M8tqLOwgYZLns6CFSDApQpeHxuWUeCDaM1PTPgjIFInTA7+OQQw8PU6/r77BdGAg+ltryxnkpBSl+zPLaizsIGGS57OghUgwKUKXh8bllHgg2jNT0z4IyBSJ0wO/jkEMPD1Ov6++wXRgIPpba8sZ5KQUpfszy2os7CBhkuezoIVIMClCl4fG5ZR4INozU9M+CMgUidMDv45BDDw9Tr+vvsF0YCD6W2vLGeSsFKX7M8tqLOwgYZLns6CFSDApQpeHxuWUeCDaM1PTPgjIFInTA7+OQQw8PU6/r77BdGAg+ltryxnkpBSl+zPLaizsIGGS57OghUgwKUKXh8bllHgg2jNT0z4IyBSJ0wO/jkEMPD1Ov6++wXRgIPpba8sZ5KQUpfszy'));
          if (i < 2) await Future.delayed(const Duration(milliseconds: 300));
        }
      } else {
        // Single beep for normal notifications
        await _player.play(UrlSource('data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBjmL0fPTgjMGJXTA7+ONQQ0PU6/r77BdGAg+ltryxnkpBSl+zPLaizsIGGS57OihUgwKUKXh8bllHgg2jdT0z4IyBSJ0wO/jkEEND1Ov6++wXRgIPpba8sZ5KQUpfszy2os7CBhkuezoIVIMClCl4fG5ZR4INozU9M+CMgUidMDv45BBDw9Tr+vvsF0YCD6W2vLGeSsFKX7M8tqLOwgYZLns6CFSDApQpeHxuWUeCDaM1PTPgjIFInTA7+OQQw8PU6/r77BdGAg+ltryxnkpBSl+zPLaizsIGGS57OghUgwKUKXh8bllHgg2jNT0z4IyBSJ0wO/jkEMPD1Ov6++wXRgIPpba8sZ5KQUpfszy2os7CBhkuezoIVIMClCl4fG5ZR4INozU9M+CMgUidMDv45BDDw9Tr+vvsF0YCD6W2vLGeSsFKX7M8tqLOwgYZLns6CFSDApQpeHxuWUeCDaM1PTPgjIFInTA7+OQQw8PU6/r77BdGAg+ltryxnkpBSl+zPLaizsIGGS57OghUgwKUKXh8bllHgg2jNT0z4IyBSJ0wO/jkEMPD1Ov6++wXRgIPpba8sZ5KQUpfszy2os7CBhkuezoIVIMClCl4fG5ZR4INozU9M+CMgUidMDv45BDDw9Tr+vvsF0YCD6W2vLGeSsFKX7M8tqLOwgYZLns6CFSDApQpeHxuWUeCDaM1PTPgjIFInTA7+OQQw8PU6/r77BdGAg+ltryxnkpBSl+zPLaizsIGGS57OghUgwKUKXh8bllHgg2jNT0z4IyBSJ0wO/jkEMPD1Ov6++wXRgIPpba8sZ5KQUpfszy'));
      }
      results['data_url_audio'] = true;
      anySuccess = true;
      print('✅ [$type] Data URL audio SUCCESS');
    } catch (e) {
      results['data_url_audio'] = false;
      print('❌ [$type] Data URL audio failed: $e');
    }

    // 4. Try SystemSound.click (backup)
    try {
      await SystemSound.play(SystemSoundType.click);
      if (isUrgent) {
        await Future.delayed(const Duration(milliseconds: 150));
        await SystemSound.play(SystemSoundType.click);
      }
      results['system_click'] = true;
      anySuccess = true;
      print('✅ [$type] System click SUCCESS');
    } catch (e) {
      results['system_click'] = false;
      print('❌ [$type] System click failed: $e');
    }

    // 5. Try vibration as final fallback (mobile only)
    if (!anySuccess && !kIsWeb) {
      try {
        await HapticFeedback.vibrate();
        results['vibration'] = true;
        anySuccess = true;
        print('✅ [$type] Vibration fallback SUCCESS');
      } catch (e) {
        results['vibration'] = false;
        print('❌ [$type] Vibration failed: $e');
      }
    }

    // Report results
    final successCount = results.values.where((s) => s).length;
    final totalCount = results.length;
    
    print('📊 [$type] Sound test results: $successCount/$totalCount methods worked');
    print('📋 [$type] Method results: $results');
    
    if (anySuccess) {
      print('🎉 [$type] NOTIFICATION SUCCESS - At least one method worked!');
    } else {
      print('💥 [$type] NOTIFICATION FAILED - All methods failed!');
      print('🔍 [$type] Platform: ${kIsWeb ? 'WEB' : 'MOBILE'}');
      print('💡 [$type] Suggestion: Check device volume and browser permissions');
    }

    return anySuccess;
  }

  /// Test all notification types with detailed reporting
  Future<Map<String, bool>> testAllNotifications() async {
    print('\n🧪 [RELIABLE TEST] Starting comprehensive notification test...');
    print('🖥️ Platform: ${kIsWeb ? 'WEB' : 'MOBILE'}');
    
    final results = <String, bool>{};
    
    print('\n--- Testing Customer Notification ---');
    results['customer'] = await playNotification(isUrgent: false);
    await Future.delayed(const Duration(milliseconds: 1000));
    
    print('\n--- Testing Driver/Urgent Notification ---');
    results['driver'] = await playNotification(isUrgent: true);
    await Future.delayed(const Duration(milliseconds: 1000));
    
    print('\n--- Testing Completion Notification ---');
    results['completion'] = await playNotification(isUrgent: false);
    
    final successCount = results.values.where((success) => success).length;
    print('\n🎯 [FINAL RESULTS] $successCount/3 notification types working');
    print('📊 [SUMMARY] $results');
    
    if (successCount == 0) {
      print('\n💥 [CRITICAL] NO notification methods are working!');
      print('🔧 [DEBUG] Possible issues:');
      print('   • Device volume is muted');
      print('   • Browser has disabled auto-play audio');
      print('   • System sounds are disabled in device settings');
      print('   • App lacks audio permissions');
    } else if (successCount < 3) {
      print('\n⚠️ [WARNING] Some notification methods not working');
      print('🔧 [DEBUG] Check console logs above for specific failures');
    } else {
      print('\n🎉 [SUCCESS] All notification methods working perfectly!');
    }
    
    return results;
  }

  /// Simple customer notification
  Future<bool> playCustomerNotification() async {
    return await playNotification(isUrgent: false);
  }

  /// Simple driver notification (urgent)
  Future<bool> playDriverNotification() async {
    return await playNotification(isUrgent: true);
  }

  /// Simple completion notification
  Future<bool> playCompletionNotification() async {
    return await playNotification(isUrgent: false);
  }
}