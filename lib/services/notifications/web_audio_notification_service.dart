import 'package:flutter/services.dart';
import 'dart:html' as html;
import 'dart:typed_data';

class WebAudioNotificationService {
  static WebAudioNotificationService? _instance;
  static WebAudioNotificationService get instance => _instance ??= WebAudioNotificationService._();
  WebAudioNotificationService._();

  html.AudioContext? _audioContext;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    
    try {
      _audioContext = html.AudioContext();
      _initialized = true;
      print('✅ Web audio context initialized');
    } catch (e) {
      print('❌ Failed to initialize web audio: $e');
    }
  }

  Future<void> playNotificationBeep({bool isUrgent = false}) async {
    try {
      await _ensureInitialized();
      if (_audioContext == null) {
        print('❌ Audio context not available, using haptic feedback');
        await HapticFeedback.vibrate();
        return;
      }

      // Create audible beep using Web Audio API
      final oscillator = _audioContext!.createOscillator();
      final gainNode = _audioContext!.createGain();

      // Connect audio nodes
      oscillator.connectNode(gainNode, 0, 0);
      gainNode.connectNode(_audioContext!.destination!, 0, 0);

      // Configure beep sound
      oscillator.frequency!.value = isUrgent ? 800 : 400; // Higher frequency for urgent
      gainNode.gain!.value = 0.3; // Volume level

      // Play beep
      oscillator.start();
      
      // Stop after duration
      final duration = isUrgent ? 0.3 : 0.2;
      Future.delayed(Duration(milliseconds: (duration * 1000).round()), () {
        try {
          oscillator.stop();
        } catch (e) {
          // Ignore stop errors
        }
      });

      print('🔊 Played ${isUrgent ? 'URGENT' : 'NORMAL'} web audio beep');
      
      // Also add haptic feedback
      await HapticFeedback.lightImpact();

    } catch (e) {
      print('❌ Web audio beep failed: $e');
      // Fallback to haptic feedback
      try {
        await HapticFeedback.vibrate();
        print('✅ Fallback haptic feedback triggered');
      } catch (e2) {
        print('❌ Haptic feedback also failed: $e2');
      }
    }
  }

  Future<void> playUrgentNotification() async {
    try {
      // Play 3 urgent beeps with pauses
      for (int i = 0; i < 3; i++) {
        await playNotificationBeep(isUrgent: true);
        if (i < 2) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
      print('🚨 Played 3 urgent notification beeps');
    } catch (e) {
      print('❌ Urgent notification failed: $e');
    }
  }

  Future<void> playNormalNotification() async {
    try {
      await playNotificationBeep(isUrgent: false);
      print('🔔 Played normal notification beep');
    } catch (e) {
      print('❌ Normal notification failed: $e');
    }
  }

  Future<void> testAllSounds() async {
    try {
      print('🧪 Testing web audio notification sounds...');
      
      await playNormalNotification();
      await Future.delayed(const Duration(milliseconds: 500));
      
      await playUrgentNotification();
      await Future.delayed(const Duration(milliseconds: 500));
      
      print('✅ Web audio sound test completed');
    } catch (e) {
      print('❌ Sound test failed: $e');
    }
  }
}