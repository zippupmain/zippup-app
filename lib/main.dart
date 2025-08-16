import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/config/firebase_options.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/panic/presentation/panic_screen.dart';
import 'features/marketplace/presentation/marketplace_screen.dart';

Future<void> main() async {
	WidgetsFlutterBinding.ensureInitialized();
	await dotenv.load(fileName: '.env');
	await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
	runApp(const ProviderScope(child: ZippUpApp()));
}

class ZippUpApp extends ConsumerWidget {
	const ZippUpApp({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final router = ref.watch(goRouterProvider).copyWith(
			routes: ref.watch(goRouterProvider).routes.map((r) {
				if (r is GoRoute) {
					switch (r.name) {
						case 'home':
							return GoRoute(path: r.path, name: r.name, builder: (c, s) => const HomeScreen());
						case 'panic':
							return GoRoute(path: r.path, name: r.name, builder: (c, s) => const PanicScreen());
						case 'marketplace':
							return GoRoute(path: r.path, name: r.name, builder: (c, s) => const MarketplaceScreen());
						default:
							return r;
					}
				}
				return r;
			}).toList(),
		);
		return MaterialApp.router(
			title: 'ZippUp',
			theme: AppTheme.light(),
			darkTheme: AppTheme.dark(),
			routerConfig: router,
			debugShowCheckedModeBanner: false,
		);
	}
}
