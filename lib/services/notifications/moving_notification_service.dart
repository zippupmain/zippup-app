import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';

class MovingNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static AudioPlayer? _audioPlayer;
  
  static const String _channelId = 'moving_requests';
  static const String _channelName = 'Moving Requests';
  static const String _channelDescription = 'High priority notifications for incoming moving requests';

  /// Initialize moving notification services
  static Future<void> initialize() async {
    await _configureLocalNotifications();
    await _configureFCM();
    await _setupMessageHandlers();
  }

  /// Configure local notifications with high-importance channel for moving
  static Future<void> _configureLocalNotifications() async {
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
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

    // Create high-importance notification channel for moving requests
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('moving_request_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 300, 300]),
      showBadge: true,
      enableLights: true,
      ledColor: Colors.orange,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print('✅ Moving notifications configured with high-importance channel');
  }

  /// Configure Firebase Cloud Messaging for moving providers
  static Future<void> _configureFCM() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Moving FCM notification permissions granted');
    } else {
      print('❌ Moving FCM notification permissions denied');
    }

    String? token = await _messaging.getToken();
    if (token != null) {
      await _updateMovingProviderFCMToken(token);
      print('✅ Moving provider FCM token updated: ${token.substring(0, 20)}...');
    }

    _messaging.onTokenRefresh.listen(_updateMovingProviderFCMToken);
  }

  /// Set up FCM message handlers for moving requests
  static Future<void> _setupMessageHandlers() async {
    FirebaseMessaging.onMessage.listen(_handleForegroundMovingMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMovingMessage);

    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundMovingMessage(initialMessage);
    }

    print('✅ Moving FCM message handlers configured');
  }

  /// Handle FCM messages when app is in foreground
  static Future<void> _handleForegroundMovingMessage(RemoteMessage message) async {
    print('📦 Received foreground moving FCM message: ${message.messageId}');
    
    final data = message.data;
    if (data['type'] == 'moving_request') {
      await _showMovingRequestNotification(data);
    }
  }

  /// Handle FCM messages when app is opened from background
  static Future<void> _handleBackgroundMovingMessage(RemoteMessage message) async {
    print('📦 Received background moving FCM message: ${message.messageId}');
    
    final data = message.data;
    if (data['type'] == 'moving_request') {
      _navigateToMovingRequest(data['requestId']);
    }
  }

  /// Show full-screen persistent notification for moving requests
  static Future<void> _showMovingRequestNotification(Map<String, dynamic> data) async {
    final requestId = data['requestId'];
    final movingType = data['movingType'] ?? 'Moving service';
    final pickupAddress = data['pickupAddress'] ?? 'Unknown location';
    final destinationAddress = data['destinationAddress'] ?? 'Unknown destination';
    final customerName = data['customerName'] ?? 'Customer';
    final estimatedCost = data['estimatedCost'] ?? '0';
    final distance = data['distance'] ?? '0';
    final rooms = data['rooms'] ?? '0';
    final movingDate = data['movingDate'] ?? '';

    // Start playing notification sound in loop
    await _playMovingNotificationSound();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('moving_request_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 300, 300]),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'accept_moving',
          '✅ ACCEPT JOB',
          titleColor: Color.fromARGB(255, 0, 150, 0),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'decline_moving',
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
      sound: 'moving_request_sound.wav',
      categoryIdentifier: 'MOVING_REQUEST',
      threadIdentifier: 'moving_requests',
      interruptionLevel: InterruptionLevel.critical,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      requestId.hashCode,
      '📦 New Moving Request!',
      '$movingType • $rooms rooms • ₦$estimatedCost\n📍 From: $pickupAddress\n📍 To: $destinationAddress\n👤 $customerName • ${distance}km away',
      notificationDetails,
      payload: jsonEncode({
        'type': 'moving_request',
        'requestId': requestId,
        'movingType': movingType,
        'pickupAddress': pickupAddress,
        'destinationAddress': destinationAddress,
        'customerName': customerName,
        'estimatedCost': estimatedCost,
        'distance': distance,
        'rooms': rooms,
        'movingDate': movingDate,
      }),
    );

    print('🔔 Moving request notification shown for request: $requestId');
  }

  /// Play moving notification sound in loop
  static Future<void> _playMovingNotificationSound() async {
    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer!.play(AssetSource('sounds/moving_request_sound.mp3'));
      print('🔊 Playing moving request sound in loop');
    } catch (e) {
      print('❌ Error playing moving notification sound: $e');
    }
  }

  /// Stop moving notification sound
  static Future<void> _stopMovingNotificationSound() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        print('🔇 Stopped moving request sound');
      }
    } catch (e) {
      print('❌ Error stopping moving notification sound: $e');
    }
  }

  /// Handle notification tap events for moving requests
  static Future<void> _onNotificationTapped(NotificationResponse response) async {
    final payload = response.payload;
    final actionId = response.actionId;

    if (payload != null) {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final requestId = data['requestId'];

      print('🎯 Moving notification tapped - Action: $actionId, RequestId: $requestId');

      await _stopMovingNotificationSound();
      await _localNotifications.cancel(requestId.hashCode);

      if (actionId == 'accept_moving') {
        await _acceptMovingRequest(requestId);
      } else if (actionId == 'decline_moving') {
        await _declineMovingRequest(requestId);
      } else {
        _navigateToMovingRequest(requestId);
      }
    }
  }

  /// Accept moving request
  static Future<void> _acceptMovingRequest(String requestId) async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        print('❌ No authenticated moving provider');
        return;
      }

      print('✅ Moving provider accepting request: $requestId');

      await _firestore.collection('moving_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedBy': providerId,
      });

      await _firestore.collection('moving_providers').doc(providerId).update({
        'isAvailable': false,
        'currentRequestId': requestId,
        'onJob': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _navigateToActiveMovingJob(requestId);
      print('✅ Successfully accepted moving request: $requestId');
    } catch (e) {
      print('❌ Error accepting moving request: $e');
    }
  }

  /// Decline moving request
  static Future<void> _declineMovingRequest(String requestId) async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId == null) {
        print('❌ No authenticated moving provider');
        return;
      }

      print('❌ Moving provider declining request: $requestId');

      await _firestore.collection('moving_requests').doc(requestId).update({
        'status': 'cancelled_by_provider',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': providerId,
        'cancellationReason': 'declined_by_provider',
      });

      print('❌ Successfully declined moving request: $requestId');
    } catch (e) {
      print('❌ Error declining moving request: $e');
    }
  }

  /// Update moving provider's FCM token
  static Future<void> _updateMovingProviderFCMToken(String token) async {
    try {
      final providerId = _auth.currentUser?.uid;
      if (providerId != null) {
        await _firestore.collection('moving_providers').doc(providerId).update({
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error updating moving provider FCM token: $e');
    }
  }

  /// Navigate to moving request screen
  static void _navigateToMovingRequest(String requestId) {
    print('🧭 Navigating to moving request: $requestId');
    // Implement navigation logic based on your app's routing
  }

  /// Navigate to active moving job screen
  static void _navigateToActiveMovingJob(String requestId) {
    print('🧭 Navigating to active moving job: $requestId');
    // Implement navigation logic based on your app's routing
  }

  /// Clear all moving request notifications
  static Future<void> clearMovingNotifications() async {
    await _localNotifications.cancelAll();
    await _stopMovingNotificationSound();
  }

  /// Cancel specific moving notification
  static Future<void> cancelMovingNotification(String requestId) async {
    await _localNotifications.cancel(requestId.hashCode);
    await _stopMovingNotificationSound();
  }
}

/// Background message handler for moving requests
@pragma('vm:entry-point')
Future<void> firebaseMessagingMovingBackgroundHandler(RemoteMessage message) async {
  print('📦 Handling background moving FCM message: ${message.messageId}');
  
  final data = message.data;
  if (data['type'] == 'moving_request') {
    await MovingNotificationService._showMovingRequestNotification(data);
  }
}