import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class SystemOnlyService {
  SystemOnlyService._internal();
  static final SystemOnlyService instance = SystemOnlyService._internal();

  /// Play notification using ONLY SystemSound (no external URLs, no AudioPlayer)
  Future<bool> playSystemNotification({bool isUrgent = false}) async {
    final type = isUrgent ? 'URGENT' : 'NORMAL';
    print('🔊 [$type] Playing SYSTEM-ONLY notification...');
    print('🎯 [$type] Using ONLY SystemSound - no external URLs, no CORS issues');
    
    bool success = false;

    try {
      if (isUrgent) {
        // Urgent: Multiple system sounds with delays
        print('🚨 [$type] Playing urgent system sound sequence...');
        
        await SystemSound.play(SystemSoundType.alert);
        print('✅ [$type] System alert 1 played');
        
        await Future.delayed(const Duration(milliseconds: 300));
        await SystemSound.play(SystemSoundType.click);
        print('✅ [$type] System click played');
        
        await Future.delayed(const Duration(milliseconds: 300));
        await SystemSound.play(SystemSoundType.alert);
        print('✅ [$type] System alert 2 played');
        
        success = true;
      } else {
        // Normal: Single system sound
        print('🔔 [$type] Playing single system sound...');
        
        await SystemSound.play(SystemSoundType.alert);
        print('✅ [$type] System alert played');
        
        success = true;
      }
    } catch (e) {
      print('❌ [$type] SystemSound failed: $e');
      success = false;
    }

    // Add haptic feedback separately (mobile only)
    if (!kIsWeb) {
      try {
        if (isUrgent) {
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 200));
          await HapticFeedback.heavyImpact();
          print('✅ [$type] Heavy haptic feedback played');
        } else {
          await HapticFeedback.mediumImpact();
          print('✅ [$type] Medium haptic feedback played');
        }
      } catch (e) {
        print('❌ [$type] Haptic feedback failed: $e');
      }
    }

    print(success ? '🎉 [$type] SYSTEM-ONLY notification SUCCESS' : '💥 [$type] SYSTEM-ONLY notification FAILED');
    return success;
  }

  /// Customer notification
  Future<bool> playCustomerNotification() async {
    return await playSystemNotification(isUrgent: false);
  }

  /// Driver notification (urgent)
  Future<bool> playDriverNotification() async {
    return await playSystemNotification(isUrgent: true);
  }

  /// Test SystemSound types individually
  Future<Map<String, bool>> testSystemSoundTypes() async {
    print('\n🔊 Testing SYSTEM SOUND types individually...');
    print('🎯 Goal: Identify which SystemSound types are audible');
    
    final results = <String, bool>{};
    
    print('\n--- Testing SystemSoundType.alert ---');
    try {
      await SystemSound.play(SystemSoundType.alert);
      results['alert'] = true;
      print('✅ SystemSoundType.alert: SUCCESS');
      
      // Test again to confirm
      await Future.delayed(const Duration(seconds: 1));
      await SystemSound.play(SystemSoundType.alert);
      print('✅ SystemSoundType.alert: CONFIRMED');
    } catch (e) {
      results['alert'] = false;
      print('❌ SystemSoundType.alert: FAILED - $e');
    }
    
    await Future.delayed(const Duration(seconds: 2));
    
    print('\n--- Testing SystemSoundType.click ---');
    try {
      await SystemSound.play(SystemSoundType.click);
      results['click'] = true;
      print('✅ SystemSoundType.click: SUCCESS');
      
      // Test again to confirm
      await Future.delayed(const Duration(seconds: 1));
      await SystemSound.play(SystemSoundType.click);
      print('✅ SystemSoundType.click: CONFIRMED');
    } catch (e) {
      results['click'] = false;
      print('❌ SystemSoundType.click: FAILED - $e');
    }

    print('\n🔊 SYSTEM SOUND RESULTS:');
    results.forEach((type, works) {
      print('  $type: ${works ? '✅ WORKS' : '❌ FAILS'}');
    });

    final workingCount = results.values.where((s) => s).length;
    print('\n🎯 CONCLUSION: $workingCount/2 SystemSound types work');
    
    if (workingCount > 0) {
      print('🎉 SUCCESS: SystemSound IS working on your device!');
      print('💡 If you don\'t hear anything, check:');
      print('   • Device system sound volume');
      print('   • Browser tab not muted');
      print('   • System sound settings enabled');
    } else {
      print('💥 PROBLEM: SystemSound not working at all');
      print('🔧 This means system sounds are disabled on your device');
    }

    return results;
  }

  /// Test with maximum possible system feedback
  Future<bool> playMaximumSystemFeedback() async {
    print('\n📢 MAXIMUM SYSTEM FEEDBACK TEST...');
    print('🎯 Using ALL available system feedback methods');
    
    bool anySuccess = false;

    // Test 1: Rapid system sound sequence
    try {
      print('\n🔊 Rapid SystemSound sequence...');
      for (int i = 0; i < 5; i++) {
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(const Duration(milliseconds: 200));
        await SystemSound.play(SystemSoundType.click);
        await Future.delayed(const Duration(milliseconds: 200));
      }
      print('✅ Rapid system sound sequence completed');
      anySuccess = true;
    } catch (e) {
      print('❌ Rapid system sounds failed: $e');
    }

    // Test 2: Maximum haptic feedback (mobile)
    if (!kIsWeb) {
      try {
        print('\n📳 Maximum haptic feedback...');
        for (int i = 0; i < 10; i++) {
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
        }
        print('✅ Maximum haptic feedback completed');
        anySuccess = true;
      } catch (e) {
        print('❌ Maximum haptic failed: $e');
      }
    }

    print(anySuccess ? '🎉 MAXIMUM FEEDBACK: SUCCESS' : '💥 MAXIMUM FEEDBACK: FAILED');
    return anySuccess;
  }
}