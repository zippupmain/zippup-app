import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificationsService {
	NotificationsService._();
	static final NotificationsService instance = NotificationsService._();

	final FirebaseMessaging _messaging = FirebaseMessaging.instance;
	final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
	bool _initialized = false;

	Future<void> init() async {
		if (_initialized) return;
		if (!kIsWeb) {
			await _messaging.requestPermission(alert: true, badge: true, sound: true);
			const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
			const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
			const InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
			await _local.initialize(initSettings);
			final token = await _messaging.getToken();
			await _saveToken(token);
			_messaging.onTokenRefresh.listen(_saveToken);
			FirebaseMessaging.onMessage.listen((RemoteMessage message) {
				final title = message.notification?.title ?? 'ZippUp';
				final body = message.notification?.body ?? '';
				_showLocalNotification(title, body);
			});
		}
		_initialized = true;
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

	Future<void> scheduleReminder({required String id, required DateTime when, required String title, required String body}) async {
		await init();
		if (!kIsWeb) {
			const NotificationDetails details = NotificationDetails(
				android: AndroidNotificationDetails('rides', 'Rides', importance: Importance.defaultImportance, priority: Priority.defaultPriority),
			);
			await _local.schedule(
				id.hashCode,
				title,
				body,
				when.toLocal(),
				details,
				androidAllowWhileIdle: true,
			);
		} else {
			await FirebaseFirestore.instance.collection('_scheduled_notifications').doc(id).set({
				'title': title,
				'body': body,
				'time': when.toIso8601String(),
				'createdAt': DateTime.now().toIso8601String(),
			});
		}
	}

	// Static helper to keep existing call sites working
	static Future<void> scheduleReminderStatic({required String id, required DateTime when, required String title, required String body}) {
		return instance.scheduleReminder(id: id, when: when, title: title, body: body);
	}
}
