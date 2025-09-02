import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class SoundService {
	SoundService._internal();
	static final SoundService instance = SoundService._internal();
	final AudioPlayer _player = AudioPlayer();
	bool _soundsEnabled = true;

	Future<void> playChirp() async {
		try {
			print('🔔 Playing customer notification...');
			
			// Multiple sound attempts for better reliability
			if (!kIsWeb) {
				// Try haptic feedback first (mobile only)
				await HapticFeedback.mediumImpact();
				print('✅ Haptic feedback triggered');
			}
			
			// Use multiple approaches for better sound reliability
			await SystemSound.play(SystemSoundType.alert);
			await HapticFeedback.lightImpact();
			
			// Try audio player with a simple beep
			try {
				// Create a simple audio context for web
				if (kIsWeb) {
					// Use a data URL for a simple beep sound
					await _player.play(UrlSource('data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBjmL0fPTgjMGJXTA7+ONQQ0PU6/r77BdGAg+ltryxnkpBSl+zPLaizsIGGS57OihUgwKUKXh8bllHgg2jdT0z4IyBSJ0wO/jkEEND1Ov6++wXRgIPpba8sZ5KQUpfszy2os7CBhkuezoIVIMClCl4fG5ZR4INozU9M+CMgUidMDv45BBDw9Tr+vvsF0YCD6W2vLGeSsFKX7M8tqLOwgYZLns6CFSDApQpeHxuWUeCDaM1PTPgjIFInTA7+OQQw8PU6/r77BdGAg+ltryxnkpBSl+zPLaizsIGGS57OghUgwKUKXh8bllHgg2jNT0z4IyBSJ0wO/jkEMPD1Ov6++wXRgIPpba8sZ5KQUpfszy2os7CBhkuezoIVIMClCl4fG5ZR4INozU9M+CMgUidMDv45BDDw9Tr+vvsF0YCD6W2vLGeSsFKX7M8tqLOwgYZLns6CFSDApQpeHxuWUeCDaM1PTPgjIFInTA7+OQQw8PU6/r77BdGAg+ltryxnkpBSl+zPLaizsIGGS57OghUgwKUKXh8bllHgg2jNT0z4IyBSJ0wO/jkEMPD1Ov6++wXRgIPpba8sZ5KQUpfszy2os7CBhkuezoIVIMClCl4fG5ZR4INozU9M+CMgUidMDv45BDDw9Tr+vvsF0YCD6W2vLGeSsFKX7M8tqLOwgYZLns6CFSDApQpeHxuWUeCDaM1PTPgjIFInTA7+OQQw8PU6/r77BdGAg+ltryxnkpBSl+zPLaizsIGGS57OghUgwKUKXh8bllHgg2jNT0z4IyBSJ0wO/jkEMPD1Ov6++wXRgIPpba8sZ5KQUpfszy2os7CBhkuezoIVIMClCl4fG5ZR4INozU9M+CMgUidMDv45BDDw9Tr+vvsF0YCD6W2vLGeSsFKX7M8tqLOwgYZLns6CFSDApQpeHxuWUeCDaM1PTPgjIFInTA7+OQQw8PU6/r77BdGAg+ltryxnkpBSl+zPLaizsIGGS57OghUgwKUKXh8bllHgg2jNT0z4IyBSJ0wO/jkEMPD1Ov6++wXRgIPpba8sZ5KQUpfszy'));
					print('✅ Data URL beep played');
				}
			} catch (e) {
				print('❌ Audio beep failed: $e');
			}
			
			print('🔔 Customer notification sound completed');
		} catch (e) {
			print('❌ Failed to play customer notification sound: $e');
			// Final fallback - try just vibration
			try {
				await HapticFeedback.vibrate();
				print('✅ Fallback vibration played');
			} catch (fallbackError) {
				print('❌ Even fallback vibration failed: $fallbackError');
			}
		}
	}

	Future<void> playCall() async {
		try {
			print('🔔 Playing driver notification...');
			
			if (!kIsWeb) {
				// Strong haptic for drivers (more urgent)
				await HapticFeedback.heavyImpact();
				print('✅ Heavy haptic feedback triggered');
			}
			
			// Multiple system sounds for urgency
			await SystemSound.play(SystemSoundType.click);
			await Future.delayed(const Duration(milliseconds: 200));
			await SystemSound.play(SystemSoundType.click);
			print('✅ Double system click sounds played');
			
			// Try audio player as backup
			try {
				await _player.play(AssetSource('sounds/driver_notification.mp3'));
				print('✅ Driver audio file played');
			} catch (e) {
				print('⚠️ Driver audio file failed: $e');
			}
			
			print('🔔 Driver notification sound completed');
		} catch (e) {
			print('❌ Driver notification failed, falling back to customer sound: $e');
			await playChirp();
		}
	}

	Future<void> playTrill() async {
		try {
			print('🎉 Playing completion notification...');
			
			if (!kIsWeb) {
				await HapticFeedback.lightImpact();
				print('✅ Light haptic feedback triggered');
			}
			
			await SystemSound.play(SystemSoundType.alert);
			print('✅ Completion system sound played');
			
			// Try audio player
			try {
				await _player.play(AssetSource('sounds/completion.mp3'));
				print('✅ Completion audio file played');
			} catch (e) {
				print('⚠️ Completion audio file failed: $e');
			}
			
			print('🎉 Completion notification sound completed');
		} catch (e) {
			print('❌ Completion notification failed, falling back: $e');
			await playChirp();
		}
	}

	// Test method to verify sound system works
	Future<bool> testSounds() async {
		try {
			print('🧪 Testing notification sound system...');
			await playChirp();
			await Future.delayed(const Duration(milliseconds: 500));
			await playCall();
			await Future.delayed(const Duration(milliseconds: 500));
			await playTrill();
			print('✅ Sound system test completed');
			return true;
		} catch (e) {
			print('❌ Sound system test failed: $e');
			return false;
		}
	}
}

