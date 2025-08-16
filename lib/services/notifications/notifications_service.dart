import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
