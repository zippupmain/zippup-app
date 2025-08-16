import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:zippup/features/auth/services/google_sign_in_service.dart';

class SignInScreen extends StatefulWidget {
	const SignInScreen({super.key});

	@override
	State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
	final TextEditingController _emailController = TextEditingController();
	final TextEditingController _passwordController = TextEditingController();
	final TextEditingController _phoneController = TextEditingController();
	String? _verificationId;
	bool _loading = false;
	bool _isSignUp = false;

	Future<void> _signInWithGoogle() async {
		setState(() => _loading = true);
		try {
			final service = createGoogleSignInService();
			await service.signIn();
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Google sign-in failed: $e')));
			}
		} finally {
			if (mounted) setState(() => _loading = false);
		}
	}

	Future<void> _emailAuth() async {
		setState(() => _loading = true);
		try {
			if (_isSignUp) {
				await FirebaseAuth.instance.createUserWithEmailAndPassword(
					email: _emailController.text.trim(),
					password: _passwordController.text,
				);
			} else {
				await FirebaseAuth.instance.signInWithEmailAndPassword(
					email: _emailController.text.trim(),
					password: _passwordController.text,
				);
			}
		} on FirebaseAuthException catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Authentication error')));
			}
		} finally {
			if (mounted) setState(() => _loading = false);
		}
	}

	Future<void> _sendCode() async {
		setState(() => _loading = true);
		await FirebaseAuth.instance.verifyPhoneNumber(
			phoneNumber: _phoneController.text.trim(),
			codeSent: (verificationId, forceResendingToken) {
				setState(() => _verificationId = verificationId);
			},
			verificationCompleted: (cred) async {
				await FirebaseAuth.instance.signInWithCredential(cred);
			},
			verificationFailed: (e) {
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Verification failed')));
				}
			},
			codeAutoRetrievalTimeout: (id) {},
		);
		if (mounted) setState(() => _loading = false);
	}

	Future<void> _verifyCode(String smsCode) async {
		if (_verificationId == null) return;
		setState(() => _loading = true);
		final cred = PhoneAuthProvider.credential(verificationId: _verificationId!, smsCode: smsCode);
		await FirebaseAuth.instance.signInWithCredential(cred);
		if (mounted) setState(() => _loading = false);
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Sign in')),
			body: SingleChildScrollView(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.stretch,
					children: [
						// Logo space
						Container(
							height: 80,
							alignment: Alignment.center,
							child: const Text('ZippUp Logo Here'),
						),
						const SizedBox(height: 8),
						Text(
							'ZippUp! Your safety. Your services. One app.',
							textAlign: TextAlign.center,
							style: Theme.of(context).textTheme.titleMedium,
						),
						const SizedBox(height: 16),
						// Email auth form
						TextField(
							controller: _emailController,
							keyboardType: TextInputType.emailAddress,
							decoration: const InputDecoration(labelText: 'Email'),
						),
						TextField(
							controller: _passwordController,
							obscureText: true,
							decoration: const InputDecoration(labelText: 'Password'),
						),
						const SizedBox(height: 8),
						FilledButton(
							onPressed: _loading ? null : _emailAuth,
							child: Text(_isSignUp ? 'Sign up with email' : 'Sign in with email'),
						),
						TextButton(
							onPressed: _loading ? null : () => setState(() => _isSignUp = !_isSignUp),
							child: Text(_isSignUp ? 'Have an account? Sign in' : 'New here? Create account'),
						),
						const Divider(),
						ElevatedButton.icon(
							icon: const Icon(Icons.login),
							label: const Text('Continue with Google'),
							onPressed: _loading ? null : _signInWithGoogle,
						),
						const SizedBox(height: 12),
						TextField(
							controller: _phoneController,
							keyboardType: TextInputType.phone,
							decoration: const InputDecoration(labelText: 'Phone number'),
						),
						requiredSmsCodeField(),
						const SizedBox(height: 8),
						FilledButton(
							onPressed: _loading ? null : _sendCode,
							child: Text(_verificationId == null ? 'Send code' : 'Resend code'),
						),
					],
				),
			),
		);
	}

	Widget requiredSmsCodeField() {
		if (_verificationId == null) return const SizedBox.shrink();
		return Padding(
			padding: const EdgeInsets.only(top: 8.0),
			child: TextField(
				keyboardType: TextInputType.number,
				decoration: const InputDecoration(labelText: 'SMS code'),
				onSubmitted: (code) => _verifyCode(code.trim()),
			),
		);
	}
}