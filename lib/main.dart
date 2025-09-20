import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:zippup/core/config/firebase_options.dart';
import 'package:zippup/core/routing/app_router.dart';
import 'package:zippup/core/theme/app_theme.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:zippup/services/notifications/notifications_service.dart';
import 'package:zippup/services/notifications/notification_cleanup_service.dart';
import 'package:zippup/services/localization/app_localizations.dart';
import 'package:zippup/providers/locale_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:zippup/core/config/payments_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'dart:js' as js; // disabled for wasm compatibility
import 'dart:async';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zippup/features/notifications/widgets/global_incoming_listener.dart';

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
		final locale = ref.watch(localeProvider);
		
		return MaterialApp.router(
			title: 'ZippUp',
			theme: AppTheme.light(),
			themeMode: ThemeMode.light, // Force light theme on all devices
			routerConfig: router,
			debugShowCheckedModeBanner: false,
			// Internationalization support
			locale: locale, // Use the selected locale
			localizationsDelegates: const [
				AppLocalizations.delegate,
				GlobalMaterialLocalizations.delegate,
				GlobalWidgetsLocalizations.delegate,
				GlobalCupertinoLocalizations.delegate,
			],
			supportedLocales: AppLocalizations.supportedLocales,
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
				// Long polling hint is set via Firebase SDK query params; avoid dart:js for wasm
			}
			if (!kIsWeb) {
				await NotificationsService.instance.init();
			}
			
			// Set up auth state listener for notification cleanup
			FirebaseAuth.instance.authStateChanges().listen((user) async {
				if (user != null) {
					// User logged in - perform notification cleanup
					await NotificationCleanupService.performStartupCleanup();
				}
			});
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
				return const GlobalIncomingApp();
			},
		);
	}
}

class GlobalIncomingApp extends StatelessWidget {
	const GlobalIncomingApp({super.key});
	@override
	Widget build(BuildContext context) {
		return GlobalIncomingListener(child: const ZippUpApp());
	}
}