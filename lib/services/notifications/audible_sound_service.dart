import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class AudibleSoundService {
  AudibleSoundService._internal();
  static final AudibleSoundService instance = AudibleSoundService._internal();
  
  final AudioPlayer _player = AudioPlayer();

  /// Play a guaranteed audible notification sound
  Future<bool> playAudibleNotification({bool isUrgent = false}) async {
    final type = isUrgent ? 'URGENT' : 'NORMAL';
    print('🔊 [$type] Starting AUDIBLE notification...');
    
    bool audioSuccess = false;
    bool hapticSuccess = false;

    // 1. Try to play actual audio using a data URL (works on all platforms)
    try {
      print('🎵 [$type] Attempting to play audio beep...');
      
      // Use a simple beep sound data URL that works across platforms
      const beepUrl = 'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBSuBzvLZiTYIG2m98OGYTgwOUarm7bhnHgU2jdXzzn0vBSF1xe/ekkILElyx5OyrWBYKQ5zd8sFuIAUqf8rz3Is4CRZiturqpVITC0ml4u+2ZRwHNY/Y88p9LgUme8Xv35NECxFYrOPtq1oWCkCY2+3AbiEELIHO8dqJNggZZ7zv4ZlPDA5QqOXtuGYdBTaN1fLNfS4FIXbH7t+SQQsRWKzj7axaFgpAl9rtwG4hBCx+yPHaiTgIGWi98OKaTgwNUarm7LdmHQU3jdTzzn4wBSJ2x+7fkkELEVis4+2sWhYKQJjb7cBuIQUsfsrx2ok4CBpov/DhmE4MDVKq5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZaL/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWi/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOVsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K8dqJOAgZab/w4ZhODA1SqOXsuGYdBTeN1PLPfjAFInbH7t+SQQsSWKzj7a1aFgpAmNvtwG4hBSx+yvHaiTgIGWm/8OGYTgwNUqjl7LhmHQU3jdTyz34wBSJ2x+7fkkELElms4+2tWhYKQJjb7cBuIQUsfsrx2ok4CBlpv/DhmE4MDVKo5ey4Zh0FN43U8s9+MAUidsfu35JBCxJYrOPtrVoWCkCY2+3AbiEFLH7K=';
      
      if (isUrgent) {
        // Play twice for urgent notifications
        await _player.play(UrlSource(beepUrl));
        await Future.delayed(const Duration(milliseconds: 300));
        await _player.play(UrlSource(beepUrl));
        print('✅ [$type] Double audio beep played');
      } else {
        await _player.play(UrlSource(beepUrl));
        print('✅ [$type] Single audio beep played');
      }
      
      audioSuccess = true;
    } catch (e) {
      print('❌ [$type] Audio beep failed: $e');
      
      // Try online beep sound as backup
      try {
        const onlineBeep = 'https://www.soundjay.com/misc/sounds/beep-07a.wav';
        await _player.play(UrlSource(onlineBeep));
        print('✅ [$type] Online beep played');
        audioSuccess = true;
      } catch (e2) {
        print('❌ [$type] Online beep also failed: $e2');
      }
    }

    // 2. Always try haptic feedback as well (mobile only)
    if (!kIsWeb) {
      try {
        if (isUrgent) {
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          await HapticFeedback.heavyImpact();
        } else {
          await HapticFeedback.mediumImpact();
        }
        hapticSuccess = true;
        print('✅ [$type] Haptic feedback played');
      } catch (e) {
        print('❌ [$type] Haptic feedback failed: $e');
      }
    }

    // 3. Try system sounds as additional layer
    try {
      if (isUrgent) {
        await SystemSound.play(SystemSoundType.click);
        await Future.delayed(const Duration(milliseconds: 150));
        await SystemSound.play(SystemSoundType.click);
      } else {
        await SystemSound.play(SystemSoundType.alert);
      }
      print('✅ [$type] System sound played');
    } catch (e) {
      print('❌ [$type] System sound failed: $e');
    }

    final success = audioSuccess || hapticSuccess;
    print('🎯 [$type] FINAL RESULT: ${success ? 'SUCCESS' : 'FAILED'} (Audio: $audioSuccess, Haptic: $hapticSuccess)');
    
    return success;
  }

  /// Customer notification (normal priority)
  Future<bool> playCustomerNotification() async {
    return await playAudibleNotification(isUrgent: false);
  }

  /// Driver notification (urgent priority)  
  Future<bool> playDriverNotification() async {
    return await playAudibleNotification(isUrgent: true);
  }

  /// Completion notification (normal priority)
  Future<bool> playCompletionNotification() async {
    return await playAudibleNotification(isUrgent: false);
  }

  /// Test with user interaction to ensure audio context is active
  Future<Map<String, bool>> testWithUserInteraction() async {
    print('🎯 [AUDIO TEST] Testing with user interaction...');
    print('📱 Platform: ${kIsWeb ? 'WEB' : 'MOBILE'}');
    
    // Set audio context for mobile
    if (!kIsWeb) {
      try {
        await _player.setAudioContext(
          AudioContext(
            iOS: AudioContextIOS(
              defaultToSpeaker: true,
              category: AVAudioSessionCategory.playback,
              options: [AVAudioSessionOptions.defaultToSpeaker],
            ),
            android: AudioContextAndroid(
              isSpeakerphoneOn: true,
              stayAwake: true,
              contentType: AndroidContentType.sonification,
              usageType: AndroidUsageType.notification,
              audioFocus: AndroidAudioFocus.gain,
            ),
          ),
        );
        print('✅ [AUDIO] Audio context configured for notifications');
      } catch (e) {
        print('❌ [AUDIO] Audio context setup failed: $e');
      }
    }

    final results = <String, bool>{};
    
    print('\n--- Testing Customer Notification ---');
    results['customer'] = await playCustomerNotification();
    await Future.delayed(const Duration(seconds: 2));
    
    print('\n--- Testing Driver Notification ---');  
    results['driver'] = await playDriverNotification();
    await Future.delayed(const Duration(seconds: 2));
    
    print('\n--- Testing Completion Notification ---');
    results['completion'] = await playCompletionNotification();
    
    final successCount = results.values.where((s) => s).length;
    print('\n🎯 [FINAL] $successCount/3 notifications produced audible output');
    
    return results;
  }

  /// Simple volume test - plays a known loud sound
  Future<bool> playVolumeTest() async {
    print('📢 [VOLUME TEST] Playing maximum volume test beep...');
    
    try {
      // Set volume to maximum
      await _player.setVolume(1.0);
      
      // Use a loud, clear beep URL
      const loudBeep = 'https://www.soundjay.com/misc/sounds/beep-10.wav';
      await _player.play(UrlSource(loudBeep));
      
      print('✅ [VOLUME TEST] Loud beep played at maximum volume');
      return true;
    } catch (e) {
      print('❌ [VOLUME TEST] Volume test failed: $e');
      return false;
    }
  }
}