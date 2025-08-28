import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:zippup/core/config/firebase_options.dart';
import 'package:zippup/core/routing/app_router.dart';
import 'package:zippup/core/theme/app_theme.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:zippup/services/notifications/notifications_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:zippup/core/config/payments_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:js' as js;
import 'dart:async';
import 'dart:ui' as ui;

Future<void> main() async {
	WidgetsFlutterBinding.ensureInitialized();
	FlutterError.onError = (FlutterErrorDetails details) {
		// Log and continue
		// ignore: avoid_print
		print('FlutterError: ' + details.exceptionAsString());
		// ignore: avoid_print
		print(details.stack);
	};
	ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
		// ignore: avoid_print
		print('Top-level error: ' + error.toString());
		// ignore: avoid_print
		print(stack);
		return true;
	};
	// Dotenv not used on web
	if (!kIsWeb) {
		await dotenv.load(fileName: '.env');
		final stripeKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
		if (stripeKey != null && stripeKey.isNotEmpty) {
			Stripe.publishableKey = stripeKey;
		}
	}
	// Configure Stripe on web from config (guarded)
	if (kIsWeb) {
		try {
			if (Stripe.publishableKey.isEmpty) {
				Stripe.publishableKey = stripePublishableKeyWeb;
			}
		} catch (_) {
			// ignore any Stripe init issues on web to avoid startup crash
		}
	}
	runZonedGuarded(() {
		runApp(const ProviderScope(child: _BootstrapApp()));
	}, (error, stack) {
		// ignore: avoid_print
		print('Zone error: ' + error.toString());
		// ignore: avoid_print
		print(stack);
	});
}

class ZippUpApp extends ConsumerWidget {
	const ZippUpApp({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final router = ref.watch(goRouterProvider);
		return MaterialApp.router(
			title: 'ZippUp',
			theme: AppTheme.light(),
			darkTheme: AppTheme.dark(),
			routerConfig: router,
			debugShowCheckedModeBanner: false,
		);
	}
}

class _BootstrapApp extends StatefulWidget {
	const _BootstrapApp();
	@override
	State<_BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<_BootstrapApp> {
	late final Future<void> _initFuture = _init();

	Future<void> _init() async {
		try {
			await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
			if (kIsWeb) {
				// Stabilize Firestore on web
				FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
				// Force long polling
				try {
					// ignore: undefined_prefixed_name
					js.context['FIRESTORE_FORCE_LONG_POLLING'] = true;
				} catch (_) {}
			}
			if (!kIsWeb) {
				await NotificationsService.instance.init();
			}
		} catch (e, s) {
			// ignore: avoid_print
			print('Init error: ' + e.toString());
			// ignore: avoid_print
			print(s);
			rethrow;
		}
	}

	@override
	Widget build(BuildContext context) {
		ErrorWidget.builder = (FlutterErrorDetails details) {
			return Material(
				child: Center(
					child: Padding(
						padding: const EdgeInsets.all(16),
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								const CircularProgressIndicator(),
								const SizedBox(height: 12),
								Text('Loading…', style: Theme.of(context).textTheme.bodyMedium),
							],
						),
					),
				),
			);
		};

		return FutureBuilder<void>(
			future: _initFuture,
			builder: (context, snapshot) {
				if (snapshot.connectionState == ConnectionState.waiting) {
					return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
				}
				if (snapshot.hasError) {
					return MaterialApp(
						home: Scaffold(
							body: Center(
								child: Column(
									mainAxisSize: MainAxisSize.min,
									children: [
										const Text('Failed to initialize. Tap to retry.'),
										const SizedBox(height: 8),
										FilledButton(onPressed: () => setState(() {}), child: const Text('Retry')),
									],
								),
							),
						),
					);
				}
				return const ZippUpApp();
			},
		);
	}
}