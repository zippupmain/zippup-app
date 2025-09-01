import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

class WebBeepService {
  static Future<bool> playBeep({int frequency = 800, int duration = 200}) async {
    if (!kIsWeb) {
      print('❌ WebBeepService only works on web platform');
      return false;
    }

    try {
      print('🔊 [WEB] Attempting to create AudioContext beep...');
      
      // Create audio context
      final audioContext = html.AudioContext();
      print('✅ [WEB] AudioContext created');
      
      // Create oscillator for beep sound
      final oscillator = audioContext.createOscillator();
      final gainNode = audioContext.createGain();
      
      // Configure oscillator
      oscillator.frequency?.value = frequency; // Hz
      oscillator.type = 'sine';
      
      // Configure gain (volume)
      gainNode.gain?.value = 0.1; // 10% volume
      
      // Connect audio nodes
      oscillator.connectNode(gainNode);
      gainNode.connectNode(audioContext.destination!);
      
      // Start and stop the beep
      final currentTime = audioContext.currentTime!;
      oscillator.start(currentTime);
      oscillator.stop(currentTime + (duration / 1000)); // Convert ms to seconds
      
      print('✅ [WEB] Beep sound played successfully');
      return true;
      
    } catch (e) {
      print('❌ [WEB] Beep generation failed: $e');
      return false;
    }
  }

  static Future<bool> playNotificationBeep() async {
    print('🔔 [WEB] Playing notification beep...');
    return await playBeep(frequency: 800, duration: 300);
  }

  static Future<bool> playUrgentBeep() async {
    print('🚨 [WEB] Playing urgent beep...');
    // Play double beep for urgency
    final success1 = await playBeep(frequency: 1000, duration: 200);
    await Future.delayed(const Duration(milliseconds: 100));
    final success2 = await playBeep(frequency: 1000, duration: 200);
    return success1 || success2;
  }

  static Future<bool> playCompletionBeep() async {
    print('🎉 [WEB] Playing completion beep...');
    return await playBeep(frequency: 600, duration: 400);
  }
}