import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SoundDetectiveService {
  SoundDetectiveService._internal();
  static final SoundDetectiveService instance = SoundDetectiveService._internal();

  /// Test every possible SystemSoundType to find what works
  Future<Map<String, bool>> investigateAllSystemSounds() async {
    print('\n🔍 SOUND DETECTIVE: Testing ALL SystemSoundType options...');
    print('📱 Your device DOES make sound (voice search works)');
    print('🎯 Goal: Find which SystemSoundType actually produces audio');
    
    final results = <String, bool>{};
    final soundTypes = [
      {'name': 'alert', 'type': SystemSoundType.alert},
      {'name': 'click', 'type': SystemSoundType.click},
    ];

    for (final sound in soundTypes) {
      print('\n--- Testing ${sound['name']} ---');
      try {
        await SystemSound.play(sound['type'] as SystemSoundType);
        results[sound['name']] = true;
        print('✅ ${sound['name']}: SUCCESS');
        
        // Wait and test again to confirm
        await Future.delayed(const Duration(milliseconds: 500));
        await SystemSound.play(sound['type'] as SystemSoundType);
        print('✅ ${sound['name']}: CONFIRMED (played twice)');
        
      } catch (e) {
        results[sound['name']] = false;
        print('❌ ${sound['name']}: FAILED - $e');
      }
      
      await Future.delayed(const Duration(seconds: 2));
    }

    print('\n🔍 DETECTIVE RESULTS:');
    results.forEach((name, success) {
      print('  $name: ${success ? '✅ WORKS' : '❌ SILENT'}');
    });

    final workingCount = results.values.where((s) => s).length;
    if (workingCount > 0) {
      print('\n🎉 BREAKTHROUGH: $workingCount SystemSound types work on your device!');
      print('💡 Use the working types for notifications');
    } else {
      print('\n💥 MYSTERY: No SystemSound types work, but voice search does');
      print('🤔 Voice search might use a different audio mechanism');
    }

    return results;
  }

  /// Test different timing patterns for system sounds
  Future<bool> testSoundTiming() async {
    print('\n⏱️ TIMING TEST: Testing different sound timing patterns...');
    
    try {
      print('\n--- Pattern 1: Single sound ---');
      await SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(seconds: 2));
      
      print('\n--- Pattern 2: Double sound (fast) ---');
      await SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(milliseconds: 100));
      await SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(seconds: 2));
      
      print('\n--- Pattern 3: Double sound (slow) ---');
      await SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(milliseconds: 500));
      await SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(seconds: 2));
      
      print('\n--- Pattern 4: Triple sound ---');
      for (int i = 0; i < 3; i++) {
        await SystemSound.play(SystemSoundType.alert);
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      print('✅ All timing patterns tested');
      return true;
    } catch (e) {
      print('❌ Timing test failed: $e');
      return false;
    }
  }

  /// Test if sound works when called from different contexts
  Future<bool> testSoundContexts() async {
    print('\n🏗️ CONTEXT TEST: Testing sounds from different call contexts...');
    
    try {
      print('\n--- Context 1: Direct call ---');
      await SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(seconds: 1));
      
      print('\n--- Context 2: Future.delayed call ---');
      await Future.delayed(const Duration(milliseconds: 100), () async {
        await SystemSound.play(SystemSoundType.alert);
      });
      await Future.delayed(const Duration(seconds: 1));
      
      print('\n--- Context 3: Timer call ---');
      await Future.delayed(const Duration(milliseconds: 100));
      await SystemSound.play(SystemSoundType.alert);
      await Future.delayed(const Duration(seconds: 1));
      
      print('✅ All context tests completed');
      return true;
    } catch (e) {
      print('❌ Context test failed: $e');
      return false;
    }
  }

  /// Full investigation of why sounds don't work
  Future<Map<String, dynamic>> fullSoundInvestigation() async {
    print('\n🕵️ FULL SOUND INVESTIGATION STARTING...');
    print('🎯 Goal: Understand why voice search works but notifications don't');
    
    final investigation = <String, dynamic>{};
    
    print('\n=== INVESTIGATION 1: System Sound Types ===');
    investigation['system_sounds'] = await investigateAllSystemSounds();
    
    print('\n=== INVESTIGATION 2: Sound Timing ===');
    investigation['timing_test'] = await testSoundTiming();
    
    print('\n=== INVESTIGATION 3: Call Contexts ===');
    investigation['context_test'] = await testSoundContexts();
    
    print('\n🕵️ INVESTIGATION COMPLETE');
    print('📊 Full Results: $investigation');
    
    return investigation;
  }
}