import 'package:firebase_auth/firebase_auth.dart';

abstract class GoogleSignInService {
	Future<UserCredential> signIn();
}

GoogleSignInService createGoogleSignInService() => UnsupportedGoogleSignInService();

class UnsupportedGoogleSignInService implements GoogleSignInService {
	@override
	Future<UserCredential> signIn() {
		throw UnimplementedError('Google Sign-In not supported on this platform');
	}
}