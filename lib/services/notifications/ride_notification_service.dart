import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';

class RideNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static AudioPlayer? _audioPlayer;
  
  static const String _channelId = 'ride_requests';
  static const String _channelName = 'Ride Requests';
  static const String _channelDescription = 'High priority notifications for incoming ride requests';

  /// Initialize notification services on app startup
  static Future<void> initialize() async {
    await _configureLocalNotifications();
    await _configureFCM();
    await _setupMessageHandlers();
  }

  /// Configure local notifications with high-importance channel
  static Future<void> _configureLocalNotifications() async {
    // Android notification settings
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS notification settings
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create high-importance notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('ride_request_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
      showBadge: true,
      enableLights: true,
      ledColor: Colors.blue,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print('✅ Local notifications configured with high-importance channel');
  }

  /// Configure Firebase Cloud Messaging
  static Future<void> _configureFCM() async {
    // Request notification permissions
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ FCM notification permissions granted');
    } else {
      print('❌ FCM notification permissions denied');
    }

    // Get and store FCM token
    String? token = await _messaging.getToken();
    if (token != null) {
      await _updateDriverFCMToken(token);
      print('✅ FCM token updated: ${token.substring(0, 20)}...');
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_updateDriverFCMToken);
  }

  /// Set up FCM message handlers
  static Future<void> _setupMessageHandlers() async {
    // Handle messages when app is in foreground
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle messages when app is in background but not terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessage);

    // Handle messages when app is terminated
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMessage(initialMessage);
    }

    print('✅ FCM message handlers configured');
  }

  /// Handle FCM messages when app is in foreground
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('📱 Received foreground FCM message: ${message.messageId}');
    
    final data = message.data;
    if (data['type'] == 'ride_request') {
      await _showRideRequestNotification(data);
    }
  }

  /// Handle FCM messages when app is opened from background
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    print('📱 Received background FCM message: ${message.messageId}');
    
    final data = message.data;
    if (data['type'] == 'ride_request') {
      // Navigate to ride request screen
      // This will be handled by your app's navigation logic
      _navigateToRideRequest(data['rideId']);
    }
  }

  /// Show full-screen persistent notification for ride requests
  static Future<void> _showRideRequestNotification(Map<String, dynamic> data) async {
    final rideId = data['rideId'];
    final pickupAddress = data['pickupAddress'] ?? 'Unknown location';
    final passengerName = data['passengerName'] ?? 'Passenger';
    final estimatedFare = data['estimatedFare'] ?? '0';
    final distance = data['distance'] ?? '0';

    // Start playing notification sound in loop
    await _playNotificationSound();

    // Create notification with action buttons
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true, // Makes notification persistent
      autoCancel: false,
      showWhen: true,
      when: null,
      usesChronometer: false,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('ride_request_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'accept_ride',
          '✅ ACCEPT',
          titleColor: Color.fromARGB(255, 0, 200, 0),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'decline_ride',
          '❌ DECLINE',
          titleColor: Color.fromARGB(255, 200, 0, 0),
          showsUserInterface: true,
        ),
      ],
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'ride_request_sound.wav',
      categoryIdentifier: 'RIDE_REQUEST',
      threadIdentifier: 'ride_requests',
      interruptionLevel: InterruptionLevel.critical,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      rideId.hashCode, // Use rideId hash as notification ID
      '🚗 New Ride Request!',
      '$passengerName • ₦$estimatedFare • ${distance}km\n📍 $pickupAddress',
      notificationDetails,
      payload: jsonEncode({
        'type': 'ride_request',
        'rideId': rideId,
        'pickupAddress': pickupAddress,
        'passengerName': passengerName,
        'estimatedFare': estimatedFare,
        'distance': distance,
      }),
    );

    print('🔔 Ride request notification shown for ride: $rideId');
  }

  /// Play notification sound in loop
  static Future<void> _playNotificationSound() async {
    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer!.play(AssetSource('sounds/ride_request_sound.mp3'));
      print('🔊 Playing ride request sound in loop');
    } catch (e) {
      print('❌ Error playing notification sound: $e');
    }
  }

  /// Stop notification sound
  static Future<void> _stopNotificationSound() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        print('🔇 Stopped ride request sound');
      }
    } catch (e) {
      print('❌ Error stopping notification sound: $e');
    }
  }

  /// Handle notification tap events
  static Future<void> _onNotificationTapped(NotificationResponse response) async {
    final payload = response.payload;
    final actionId = response.actionId;

    if (payload != null) {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final rideId = data['rideId'];

      print('🎯 Notification tapped - Action: $actionId, RideId: $rideId');

      // Stop notification sound
      await _stopNotificationSound();

      // Cancel the notification
      await _localNotifications.cancel(rideId.hashCode);

      if (actionId == 'accept_ride') {
        await _acceptRideRequest(rideId);
      } else if (actionId == 'decline_ride') {
        await _declineRideRequest(rideId);
      } else {
        // User tapped notification body - open ride request screen
        _navigateToRideRequest(rideId);
      }
    }
  }

  /// Accept ride request
  static Future<void> _acceptRideRequest(String rideId) async {
    try {
      final driverId = _auth.currentUser?.uid;
      if (driverId == null) {
        print('❌ No authenticated driver');
        return;
      }

      print('✅ Driver accepting ride: $rideId');

      // Update ride status to accepted
      await _firestore.collection('rides').doc(rideId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedBy': driverId,
      });

      // Update driver availability
      await _firestore.collection('drivers').doc(driverId).update({
        'isAvailable': false,
        'currentRideId': rideId,
        'onRide': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Navigate to active ride screen
      _navigateToActiveRide(rideId);

      print('✅ Successfully accepted ride: $rideId');
    } catch (e) {
      print('❌ Error accepting ride: $e');
    }
  }

  /// Decline ride request
  static Future<void> _declineRideRequest(String rideId) async {
    try {
      final driverId = _auth.currentUser?.uid;
      if (driverId == null) {
        print('❌ No authenticated driver');
        return;
      }

      print('❌ Driver declining ride: $rideId');

      // Update ride status to cancelled by driver
      await _firestore.collection('rides').doc(rideId).update({
        'status': 'cancelled_by_driver',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': driverId,
        'cancellationReason': 'declined_by_driver',
      });

      // The Cloud Function will handle making driver available again
      // and reassigning the ride to another driver

      print('❌ Successfully declined ride: $rideId');
    } catch (e) {
      print('❌ Error declining ride: $e');
    }
  }

  /// Update driver's FCM token in Firestore
  static Future<void> _updateDriverFCMToken(String token) async {
    try {
      final driverId = _auth.currentUser?.uid;
      if (driverId != null) {
        await _firestore.collection('drivers').doc(driverId).update({
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error updating FCM token: $e');
    }
  }

  /// Navigate to ride request screen
  static void _navigateToRideRequest(String rideId) {
    // Implement navigation logic based on your app's routing
    print('🧭 Navigating to ride request: $rideId');
    // Example: Get.toNamed('/ride-request', arguments: {'rideId': rideId});
  }

  /// Navigate to active ride screen
  static void _navigateToActiveRide(String rideId) {
    // Implement navigation logic based on your app's routing
    print('🧭 Navigating to active ride: $rideId');
    // Example: Get.toNamed('/active-ride', arguments: {'rideId': rideId});
  }

  /// Clear all ride request notifications
  static Future<void> clearRideNotifications() async {
    await _localNotifications.cancelAll();
    await _stopNotificationSound();
  }

  /// Cancel specific ride notification
  static Future<void> cancelRideNotification(String rideId) async {
    await _localNotifications.cancel(rideId.hashCode);
    await _stopNotificationSound();
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📱 Handling background FCM message: ${message.messageId}');
  
  final data = message.data;
  if (data['type'] == 'ride_request') {
    // Show notification even when app is in background
    await RideNotificationService._showRideRequestNotification(data);
  }
}