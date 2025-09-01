import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class VoiceHijackService {
  VoiceHijackService._internal();
  static final VoiceHijackService instance = VoiceHijackService._internal();
  
  stt.SpeechToText? _speech;
  bool _initialized = false;

  /// Initialize the speech service (same as voice search)
  Future<void> _initSpeech() async {
    if (_initialized) return;
    
    try {
      _speech = stt.SpeechToText();
      _initialized = true;
      print('✅ Speech service initialized for notification sounds');
    } catch (e) {
      print('❌ Speech service initialization failed: $e');
    }
  }

  /// Play notification by briefly activating speech recognition (hijacks its audio)
  Future<bool> playNotificationUsingVoiceSystem({bool isUrgent = false}) async {
    await _initSpeech();
    
    if (_speech == null) {
      print('❌ Speech service not available');
      return false;
    }

    final type = isUrgent ? 'URGENT' : 'NORMAL';
    print('🎤 [$type] Hijacking voice search audio system...');

    try {
      // Initialize speech recognition (this triggers audio context)
      final available = await _speech!.initialize(
        onStatus: (status) {
          print('🎤 [$type] Speech status: $status');
        },
        onError: (error) {
          print('🎤 [$type] Speech error (expected): $error');
        },
      );

      if (available) {
        print('✅ [$type] Speech audio context activated');
        
        // Start listening briefly (this activates audio)
        _speech!.listen(
          onResult: (result) {
            // We don't care about the result, just want the audio activation
            print('🎤 [$type] Speech audio system activated');
          },
          listenFor: const Duration(milliseconds: 100), // Very brief
        );
        
        // Stop immediately and play our notification sound
        await Future.delayed(const Duration(milliseconds: 50));
        await _speech!.stop();
        
        // Now play system sound (should work because audio context is active)
        if (isUrgent) {
          await SystemSound.play(SystemSoundType.alert);
          await Future.delayed(const Duration(milliseconds: 300));
          await SystemSound.play(SystemSoundType.alert);
        } else {
          await SystemSound.play(SystemSoundType.alert);
        }
        
        print('✅ [$type] Notification played using voice audio context');
        return true;
      } else {
        print('❌ [$type] Speech recognition not available');
        return false;
      }
    } catch (e) {
      print('❌ [$type] Voice hijack failed: $e');
      return false;
    }
  }

  /// Customer notification using voice system
  Future<bool> playCustomerNotification() async {
    return await playNotificationUsingVoiceSystem(isUrgent: false);
  }

  /// Driver notification using voice system (urgent)
  Future<bool> playDriverNotification() async {
    return await playNotificationUsingVoiceSystem(isUrgent: true);
  }

  /// Test the voice hijack method
  Future<bool> testVoiceHijack() async {
    print('\n🧪 Testing VOICE HIJACK notification method...');
    print('🎤 This uses the SAME audio system as working voice search');
    
    try {
      print('\n--- Testing Customer (via voice system) ---');
      final customerResult = await playCustomerNotification();
      await Future.delayed(const Duration(seconds: 2));
      
      print('\n--- Testing Driver (via voice system) ---');
      final driverResult = await playDriverNotification();
      
      final success = customerResult || driverResult;
      print('\n🎯 VOICE HIJACK RESULT: ${success ? 'SUCCESS' : 'FAILED'}');
      
      if (success) {
        print('🎉 Voice hijack worked! Notifications can use speech audio system');
      } else {
        print('💥 Even voice hijack failed - may be device/permission issue');
      }
      
      return success;
    } catch (e) {
      print('❌ Voice hijack test failed: $e');
      return false;
    }
  }

  /// Emergency fallback - just try to make ANY sound
  Future<bool> playAnySoundPossible() async {
    print('🚨 EMERGENCY: Trying to make ANY sound possible...');
    
    // Method 1: Try direct SystemSound (simplest)
    try {
      await SystemSound.play(SystemSoundType.alert);
      print('✅ EMERGENCY: Direct SystemSound worked!');
      return true;
    } catch (e) {
      print('❌ EMERGENCY: Direct SystemSound failed: $e');
    }

    // Method 2: Try via speech system
    try {
      final result = await playNotificationUsingVoiceSystem(isUrgent: false);
      if (result) {
        print('✅ EMERGENCY: Voice hijack worked!');
        return true;
      }
    } catch (e) {
      print('❌ EMERGENCY: Voice hijack failed: $e');
    }

    // Method 3: Try haptic only
    if (!kIsWeb) {
      try {
        await HapticFeedback.heavyImpact();
        print('✅ EMERGENCY: At least haptic feedback worked');
        return true;
      } catch (e) {
        print('❌ EMERGENCY: Even haptic failed: $e');
      }
    }

    print('💥 EMERGENCY: NO sound methods worked - device may have all audio disabled');
    return false;
  }
}