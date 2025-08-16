import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return const FirebaseOptions(
      apiKey: 'REPLACE_ME',
      appId: 'REPLACE_ME',
      messagingSenderId: 'REPLACE_ME',
      projectId: 'REPLACE_ME',
    );
  }
}
