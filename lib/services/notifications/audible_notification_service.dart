import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class AudibleNotificationService {
  AudibleNotificationService._internal();
  static final AudibleNotificationService instance = AudibleNotificationService._internal();
  
  final AudioPlayer _player = AudioPlayer();
  bool _isInitialized = false;

  /// Initialize audio player with proper settings
  Future<void> _initializeAudio() async {
    if (_isInitialized) return;
    
    try {
      print('🔊 Initializing audio player for notifications...');
      
      // Set audio context for mobile to ensure notifications are audible
      if (!kIsWeb) {
        try {
          await _player.setAudioContext(
            AudioContext(
              iOS: AudioContextIOS(
                category: AVAudioSessionCategory.playback,
              ),
              android: AudioContextAndroid(
                contentType: AndroidContentType.sonification,
                usageType: AndroidUsageType.notification,
                audioFocus: AndroidAudioFocus.gain,
              ),
            ),
          );
          print('✅ Mobile audio context configured for audible notifications');
        } catch (e) {
          print('⚠️ Audio context setup failed, using defaults: $e');
        }
      }
      
      // Set volume to maximum to ensure audibility
      await _player.setVolume(1.0);
      print('✅ Audio volume set to maximum');
      
      _isInitialized = true;
      print('✅ Audio player initialized successfully');
    } catch (e) {
      print('❌ Audio initialization failed: $e');
    }
  }

  /// Play a guaranteed audible beep sound
  Future<bool> playAudibleBeep({bool isUrgent = false, int repeat = 1}) async {
    await _initializeAudio();
    
    print('🔊 Playing ${isUrgent ? 'URGENT' : 'NORMAL'} audible beep (repeat: $repeat)...');
    
    bool success = false;
    
    try {
      // Use multiple online beep URLs as fallbacks
      final beepUrls = [
        'https://www.soundjay.com/misc/sounds/beep-07a.wav',
        'https://www.soundjay.com/misc/sounds/beep-10.wav', 
        'https://www.soundjay.com/misc/sounds/beep-3.wav',
        'https://freesound.org/data/previews/316/316847_5123451-lq.mp3',
      ];
      
      for (int i = 0; i < repeat; i++) {
        bool played = false;
        
        // Try each URL until one works
        for (final url in beepUrls) {
          try {
            print('🎵 Attempting to play: $url');
            await _player.play(UrlSource(url));
            print('✅ Successfully played beep from: $url');
            played = true;
            success = true;
            break;
          } catch (e) {
            print('❌ Failed to play $url: $e');
          }
        }
        
        if (!played) {
          print('⚠️ All URLs failed, trying system sound...');
          try {
            await SystemSound.play(SystemSoundType.alert);
            print('✅ System sound played as fallback');
            success = true;
          } catch (e) {
            print('❌ System sound also failed: $e');
          }
        }
        
        // Wait between repeats
        if (i < repeat - 1) {
          await Future.delayed(Duration(milliseconds: isUrgent ? 300 : 500));
        }
      }
      
      // Add haptic feedback for mobile
      if (!kIsWeb) {
        try {
          if (isUrgent) {
            await HapticFeedback.heavyImpact();
            await Future.delayed(const Duration(milliseconds: 100));
            await HapticFeedback.heavyImpact();
          } else {
            await HapticFeedback.mediumImpact();
          }
          print('✅ Haptic feedback added');
        } catch (e) {
          print('❌ Haptic feedback failed: $e');
        }
      }
      
    } catch (e) {
      print('❌ Critical error in audible beep: $e');
    }
    
    print(success ? '🎉 Audible beep SUCCESS' : '💥 Audible beep FAILED');
    return success;
  }

  /// Customer notification (single beep)
  Future<bool> playCustomerNotification() async {
    print('👤 Playing CUSTOMER notification...');
    return await playAudibleBeep(isUrgent: false, repeat: 1);
  }

  /// Driver notification (urgent double beep)
  Future<bool> playDriverNotification() async {
    print('🚗 Playing DRIVER notification...');
    return await playAudibleBeep(isUrgent: true, repeat: 2);
  }

  /// Completion notification (single beep)
  Future<bool> playCompletionNotification() async {
    print('🎉 Playing COMPLETION notification...');
    return await playAudibleBeep(isUrgent: false, repeat: 1);
  }

  /// Emergency notification (triple urgent beep)
  Future<bool> playEmergencyNotification() async {
    print('🚨 Playing EMERGENCY notification...');
    return await playAudibleBeep(isUrgent: true, repeat: 3);
  }

  /// Test all notification sounds with user interaction
  Future<Map<String, bool>> testAllSounds() async {
    print('\n🧪 Testing AUDIBLE notification system...');
    print('🔊 Volume: Maximum, Context: Notification');
    
    final results = <String, bool>{};
    
    print('\n--- Testing Customer (1 beep) ---');
    results['customer'] = await playCustomerNotification();
    await Future.delayed(const Duration(seconds: 2));
    
    print('\n--- Testing Driver (2 urgent beeps) ---');
    results['driver'] = await playDriverNotification();
    await Future.delayed(const Duration(seconds: 2));
    
    print('\n--- Testing Completion (1 beep) ---');
    results['completion'] = await playCompletionNotification();
    await Future.delayed(const Duration(seconds: 2));
    
    print('\n--- Testing Emergency (3 urgent beeps) ---');
    results['emergency'] = await playEmergencyNotification();
    
    final successCount = results.values.where((s) => s).length;
    print('\n🎯 AUDIBLE TEST RESULTS: $successCount/4 sounds played successfully');
    
    if (successCount == 0) {
      print('💥 CRITICAL: No audible sounds could be played!');
      print('🔧 Check: Device volume, app permissions, internet connection');
    } else {
      print('🎉 SUCCESS: At least some audible notifications are working!');
    }
    
    return results;
  }

  /// Force play loudest possible notification
  Future<bool> playLoudestNotification() async {
    print('📢 PLAYING LOUDEST POSSIBLE NOTIFICATION...');
    
    await _initializeAudio();
    
    // Set maximum volume
    await _player.setVolume(1.0);
    
    // Try the loudest beep URLs
    final loudUrls = [
      'https://www.soundjay.com/misc/sounds/beep-10.wav', // Loud beep
      'https://www.soundjay.com/misc/sounds/bell-ringing-05.wav', // Bell
      'https://freesound.org/data/previews/316/316847_5123451-lq.mp3', // Alert
    ];
    
    bool success = false;
    for (final url in loudUrls) {
      try {
        print('📢 Playing LOUD notification: $url');
        await _player.play(UrlSource(url));
        success = true;
        print('✅ LOUD notification played successfully');
        break;
      } catch (e) {
        print('❌ LOUD notification failed: $e');
      }
    }
    
    // Add maximum haptic feedback
    if (!kIsWeb) {
      try {
        for (int i = 0; i < 3; i++) {
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 200));
        }
        print('✅ Maximum haptic feedback triggered');
      } catch (e) {
        print('❌ Haptic feedback failed: $e');
      }
    }
    
    return success;
  }
}