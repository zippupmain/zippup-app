import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:typed_data';

/// Service to handle background notifications and wake up the app
class BackgroundNotificationService {
  static final BackgroundNotificationService _instance = BackgroundNotificationService._internal();
  factory BackgroundNotificationService() => _instance;
  BackgroundNotificationService._internal();

  static BackgroundNotificationService get instance => _instance;

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _soundTimer;

  /// Initialize background notification service
  Future<void> initialize() async {
    if (kIsWeb) {
      print('🌐 Background notifications not supported on web');
      return;
    }

    try {
      // Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
        requestCriticalPermission: true, // For critical alerts
      );
      
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Request permissions
      await _requestPermissions();

      print('✅ Background notification service initialized');
    } catch (e) {
      print('❌ Error initializing background notifications: $e');
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    if (kIsWeb) return;

    try {
      // Request Firebase Messaging permissions
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true, // For high-priority notifications
        provisional: false,
        sound: true,
      );

      print('🔔 Notification permissions: ${settings.authorizationStatus}');

      // Request local notification permissions (Android 13+)
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // Request exact alarm permissions for critical notifications
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestExactAlarmsPermission();

    } catch (e) {
      print('❌ Error requesting notification permissions: $e');
    }
  }

  /// Show a critical ride request notification that can wake up the phone
  Future<void> showRideRequestNotification({
    required String rideId,
    required String customerName,
    required String pickupAddress,
    required String rideType,
  }) async {
    if (kIsWeb) {
      print('🌐 Showing web notification for ride request');
      _showWebNotification(
        title: '🚗 New $rideType Request',
        body: '$customerName needs a ride from $pickupAddress',
      );
      return;
    }

    try {
      // Play urgent notification sound continuously
      await _playUrgentSound();

      // Show high-priority local notification
      final vibrationPattern = Int64List.fromList([0, 1000, 500, 1000, 500, 1000]);
      final ticker = 'New ride request from $customerName';
      
      final androidDetails = AndroidNotificationDetails(
        'ride_requests',
        'Ride Requests',
        channelDescription: 'Urgent ride request notifications',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call, // Treat as call
        fullScreenIntent: true, // Show full screen even when locked
        showWhen: true,
        when: null,
        usesChronometer: false,
        autoCancel: false, // Don't auto-dismiss
        ongoing: true, // Keep notification persistent
        sound: const RawResourceAndroidNotificationSound('notification_beep'),
        playSound: true,
        enableVibration: true,
        vibrationPattern: vibrationPattern,
        ledColor: const Color(0xFF2196F3),
        ledOnMs: 1000,
        ledOffMs: 500,
        ticker: ticker,
        visibility: NotificationVisibility.public,
        timeoutAfter: 30000, // Auto-dismiss after 30 seconds
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'notification_beep.mp3',
        badgeNumber: 1,
        categoryIdentifier: 'RIDE_REQUEST',
        interruptionLevel: InterruptionLevel.critical, // Critical alert
        threadIdentifier: 'ride_requests',
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _localNotifications.show(
        rideId.hashCode, // Unique ID based on ride ID
        '🚗 New $rideType Request',
        '$customerName needs a ride from $pickupAddress',
        notificationDetails,
        payload: 'ride_request:$rideId',
      );

      print('✅ Showed critical ride request notification');
    } catch (e) {
      print('❌ Error showing ride request notification: $e');
    }
  }

  /// Play urgent sound that continues until dismissed
  Future<void> _playUrgentSound() async {
    try {
      // Stop any existing sound
      await _audioPlayer.stop();
      _soundTimer?.cancel();

      // Play urgent beep sound on loop
      await _audioPlayer.play(AssetSource('sounds/notification_beep.mp3'));
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);

      // Stop sound after 30 seconds if not dismissed
      _soundTimer = Timer(const Duration(seconds: 30), () async {
        await _audioPlayer.stop();
      });

      print('🔊 Playing urgent notification sound');
    } catch (e) {
      print('❌ Error playing urgent sound: $e');
    }
  }

  /// Stop urgent sound
  Future<void> stopUrgentSound() async {
    try {
      await _audioPlayer.stop();
      _soundTimer?.cancel();
      print('🔇 Stopped urgent notification sound');
    } catch (e) {
      print('❌ Error stopping urgent sound: $e');
    }
  }

  /// Show web notification
  void _showWebNotification({required String title, required String body}) {
    // Web notifications would be handled by Firebase Messaging
    print('🌐 Web notification: $title - $body');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    print('🔔 Notification tapped: $payload');

    if (payload != null && payload.startsWith('ride_request:')) {
      final rideId = payload.split(':')[1];
      // Navigate to ride tracking screen
      // This would need to be handled by the main app
      print('🚗 Opening ride request: $rideId');
    }

    // Stop urgent sound when notification is tapped
    stopUrgentSound();
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int notificationId) async {
    try {
      await _localNotifications.cancel(notificationId);
      print('✅ Cancelled notification: $notificationId');
    } catch (e) {
      print('❌ Error cancelling notification: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _localNotifications.cancelAll();
      await stopUrgentSound();
      print('✅ Cancelled all notifications');
    } catch (e) {
      print('❌ Error cancelling all notifications: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _soundTimer?.cancel();
    _audioPlayer.dispose();
  }
}