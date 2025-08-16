import 'google_sign_in_service_stub.dart'
	if (dart.library.js) 'google_sign_in_service_web.dart'
	if (dart.library.io) 'google_sign_in_service_mobile.dart' as platform;

import 'google_sign_in_service_stub.dart';

GoogleSignInService createGoogleSignInService() => platform.createGoogleSignInService();