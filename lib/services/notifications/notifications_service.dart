import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationsService {
	NotificationsService._();
	static final NotificationsService instance = NotificationsService._();

	final FirebaseMessaging _messaging = FirebaseMessaging.instance;
	final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

	Future<void> init() async {
		if (Platform.isIOS) {
			await _messaging.requestPermission(alert: true, badge: true, sound: true);
		}

		const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
		const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
		const InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
		await _local.initialize(initSettings);

		FirebaseMessaging.onMessage.listen((RemoteMessage message) {
			_showLocalNotification(message.notification?.title ?? 'ZippUp', message.notification?.body ?? '');
		});
	}

	Future<void> _showLocalNotification(String title, String body) async {
		const AndroidNotificationDetails androidDetails = AndroidNotificationDetails('zippup_channel', 'ZippUp', importance: Importance.max, priority: Priority.high);
		const NotificationDetails details = NotificationDetails(android: androidDetails);
		await _local.show(0, title, body, details);
	}
}