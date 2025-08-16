import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zippup/features/auth/presentation/sign_in_screen.dart';

class AuthGate extends StatelessWidget {
	const AuthGate({super.key, required this.child});
	final Widget child;

	@override
	Widget build(BuildContext context) {
		return StreamBuilder<User?>(
			stream: FirebaseAuth.instance.authStateChanges(),
			builder: (context, snapshot) {
				final user = snapshot.data;
				if (snapshot.connectionState == ConnectionState.waiting) {
					return const Scaffold(body: Center(child: CircularProgressIndicator()));
				}
				if (user == null) {
					return const SignInScreen();
				}
				return child;
			},
		);
	}
}