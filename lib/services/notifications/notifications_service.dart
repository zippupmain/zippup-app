import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    if (!kIsWeb) {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const init = InitializationSettings(android: android);
      await _plugin.initialize(init);
    }
    _initialized = true;
  }

  static Future<void> scheduleReminder({required String id, required DateTime when, required String title, required String body}) async {
    await initialize();
    if (!kIsWeb) {
      final details = const NotificationDetails(
        android: AndroidNotificationDetails('rides', 'Rides', importance: Importance.defaultImportance, priority: Priority.defaultPriority),
      );
      final androidWhen = when;
      await _plugin.zonedSchedule(
        id.hashCode,
        title,
        body,
        androidWhen.toLocal(),
        details,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: true,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } else {
      // Web fallback: persist to Firestore for server-side trigger or polling
      await FirebaseFirestore.instance.collection('_scheduled_notifications').doc(id).set({
        'title': title,
        'body': body,
        'time': when.toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationsService {
	NotificationsService._();
	static final NotificationsService instance = NotificationsService._();

	final FirebaseMessaging _messaging = FirebaseMessaging.instance;
	final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

	Future<void> init() async {
		// Skip notifications setup on Web to avoid requiring service worker/VAPID at startup
		if (kIsWeb) {
			return;
		}

		// Request permission on Apple platforms; Android auto-permits
		await _messaging.requestPermission(alert: true, badge: true, sound: true);

		const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
		const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
		const InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
		await _local.initialize(initSettings);

		// Register token
		final token = await _messaging.getToken();
		await _saveToken(token);
		_messaging.onTokenRefresh.listen(_saveToken);

		FirebaseMessaging.onMessage.listen((RemoteMessage message) {
			final title = message.notification?.title ?? 'ZippUp';
			final body = message.notification?.body ?? '';
			_showLocalNotification(title, body);
		});
	}

	Future<void> _saveToken(String? token) async {
		final uid = FirebaseAuth.instance.currentUser?.uid;
		if (uid == null || token == null) return;
		await FirebaseFirestore.instance.collection('users').doc(uid).set({'fcmToken': token}, SetOptions(merge: true));
	}

	Future<void> _showLocalNotification(String title, String body) async {
		const AndroidNotificationDetails androidDetails = AndroidNotificationDetails('zippup_channel', 'ZippUp', importance: Importance.max, priority: Priority.high, playSound: true);
		const NotificationDetails details = NotificationDetails(android: androidDetails);
		await _local.show(0, title, body, details);
	}
}
