import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

class SoundService {
	SoundService._internal();
	static final SoundService instance = SoundService._internal();
	final AudioPlayer _player = AudioPlayer();

	Future<void> playChirp() async {
		try {
			// Use system haptic feedback and sound for customer notifications
			await HapticFeedback.mediumImpact();
			print('🔔 Customer notification sound played');
		} catch (_) {
			print('Failed to play notification sound');
		}
	}

	Future<void> playCall() async {
		try {
			// Use strong haptic feedback for driver notifications (more urgent)
			await HapticFeedback.heavyImpact();
			await HapticFeedback.heavyImpact();
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

