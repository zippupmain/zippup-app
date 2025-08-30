import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class SoundService {
	SoundService._internal();
	static final SoundService instance = SoundService._internal();
	final AudioPlayer _player = AudioPlayer();

	Future<void> playChirp() async {
		try {
			await _player.stop();
			await _player.setReleaseMode(ReleaseMode.stop);
			await _player.setVolume(0.7); // Comfortable volume level
			// Use hummingbird chirp for ride notifications
			await _player.play(AssetSource('sounds/hummingbird_chirp.mp3'));
		} catch (_) {
			// Fallback to system notification sound
			print('Failed to play custom chirp sound');
		}
	}

	Future<void> playCall() async {
		try {
			await _player.stop();
			await _player.setReleaseMode(ReleaseMode.stop);
			await _player.setVolume(0.8); // Slightly louder for urgent notifications
			// Use hummingbird call for urgent notifications
			await _player.play(AssetSource('sounds/hummingbird_call.mp3'));
		} catch (_) {
			// Fallback to chirp if call sound not available
			await playChirp();
		}
	}

	Future<void> playTrill() async {
		try {
			await _player.stop();
			await _player.setReleaseMode(ReleaseMode.stop);
			await _player.setVolume(0.6); // Softer for completion notifications
			// Use hummingbird trill for completion notifications
			await _player.play(AssetSource('sounds/hummingbird_trill.mp3'));
		} catch (_) {
			// Fallback to chirp if trill sound not available
			await playChirp();
		}
	}
}

