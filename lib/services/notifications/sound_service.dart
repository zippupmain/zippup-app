import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class SoundService {
	SoundService._internal();
	static final SoundService instance = SoundService._internal();
	final AudioPlayer _player = AudioPlayer();

	Future<void> playChirp() async {
		try {
			// Use system haptic feedback and beep for customer notifications
			await HapticFeedback.mediumImpact();
			await SystemSound.play(SystemSoundType.alert);
			print('🔔 Customer notification sound played');
		} catch (_) {
			print('Failed to play notification sound');
		}
	}

	Future<void> playCall() async {
		try {
			// Use strong haptic feedback and sound for driver notifications (more urgent)
			await HapticFeedback.heavyImpact();
			await SystemSound.play(SystemSoundType.click);
			await Future.delayed(const Duration(milliseconds: 200));
			await SystemSound.play(SystemSoundType.click);
			print('🔔 Driver notification sound played');
		} catch (_) {
			await playChirp();
		}
	}

	Future<void> playTrill() async {
		try {
			// Use light haptic feedback for completion
			await HapticFeedback.lightImpact();
			print('🎉 Completion notification sound played');
		} catch (_) {
			await playChirp();
		}
	}
}

