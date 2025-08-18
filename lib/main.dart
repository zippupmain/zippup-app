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

Future<void> main() async {
	WidgetsFlutterBinding.ensureInitialized();
	// Dotenv not used on web
	if (!kIsWeb) {
		await dotenv.load(fileName: '.env');
		final stripeKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
		if (stripeKey != null && stripeKey.isNotEmpty) {
			Stripe.publishableKey = stripeKey;
		}
	}
	await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
	// Initialize notifications (skip on web)
	if (!kIsWeb) {
		await NotificationsService.instance.init();
	}
	runApp(const ProviderScope(child: ZippUpApp()));
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