import 'package:firebase_auth/firebase_auth.dart';
import 'google_sign_in_service_stub.dart';

GoogleSignInService createGoogleSignInService() => WebGoogleSignInService();

class WebGoogleSignInService implements GoogleSignInService {
	@override
	Future<UserCredential> signIn() async {
		final auth = FirebaseAuth.instance;
		final googleProvider = GoogleAuthProvider();
		return await auth.signInWithPopup(googleProvider);
	}
}