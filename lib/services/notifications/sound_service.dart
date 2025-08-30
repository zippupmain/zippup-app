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
			// Use bundled asset; on web, ensure asset is in pubspec assets
			await _player.play(AssetSource('sounds/chirp.mp3'));
		} catch (_) {}
	}
}

