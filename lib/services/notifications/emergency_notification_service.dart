import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';

class EmergencyNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static AudioPlayer? _audioPlayer;

  // Emergency service channels
  static const Map<String, String> _emergencyChannels = {
    'ambulance': 'ambulance_requests',
    'fire_service': 'fire_service_requests',
    'security_service': 'security_service_requests',
    'towing_van': 'towing_van_requests',
  };

  static const Map<String, String> _emergencyChannelNames = {
    'ambulance': 'Ambulance Requests',
    'fire_service': 'Fire Service Requests',
    'security_service': 'Security Service Requests',
    'towing_van': 'Towing Van Requests',
  };

  static const Map<String, String> _emergencyEmojis = {
    'ambulance': '🚑',
    'fire_service': '🚒',
    'security_service': '🚔',
    'towing_van': '🚛',
  };

  /// Initialize emergency notification services
  static Future<void> initialize() async {
    await _configureLocalNotifications();
    await _configureFCM();
    await _setupMessageHandlers();
  }

  /// Configure local notifications with CRITICAL channels for each emergency type
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

    // Create CRITICAL importance channels for each emergency service
    for (final entry in _emergencyChannels.entries) {
      final emergencyType = entry.key;
      final channelId = entry.value;
      final channelName = _emergencyChannelNames[emergencyType]!;

      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'CRITICAL priority notifications for $emergencyType emergency requests',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('${emergencyType}_emergency_sound'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 200, 200, 200, 200, 200]),
        showBadge: true,
        enableLights: true,
        ledColor: Colors.red,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    print('✅ Emergency notifications configured with CRITICAL channels');
  }

  /// Configure Firebase Cloud Messaging for emergency responders
  static Future<void> _configureFCM() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Emergency FCM notification permissions granted');
    } else {
      print('❌ Emergency FCM notification permissions denied');
    }

    String? token = await _messaging.getToken();
    if (token != null) {
      await _updateEmergencyResponderFCMToken(token);
      print('✅ Emergency responder FCM token updated: ${token.substring(0, 20)}...');
    }

    _messaging.onTokenRefresh.listen(_updateEmergencyResponderFCMToken);
  }

  /// Set up FCM message handlers for emergency requests
  static Future<void> _setupMessageHandlers() async {
    FirebaseMessaging.onMessage.listen(_handleForegroundEmergencyMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundEmergencyMessage);

    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleBackgroundEmergencyMessage(initialMessage);
    }

    print('✅ Emergency FCM message handlers configured');
  }

  /// Handle FCM messages when app is in foreground
  static Future<void> _handleForegroundEmergencyMessage(RemoteMessage message) async {
    print('🚨 Received foreground emergency FCM message: ${message.messageId}');
    
    final data = message.data;
    if (data['type'] == 'emergency_request') {
      await _showEmergencyRequestNotification(data);
    }
  }

  /// Handle FCM messages when app is opened from background
  static Future<void> _handleBackgroundEmergencyMessage(RemoteMessage message) async {
    print('🚨 Received background emergency FCM message: ${message.messageId}');
    
    final data = message.data;
    if (data['type'] == 'emergency_request') {
      _navigateToEmergencyRequest(data['requestId'], data['emergencyType']);
    }
  }

  /// Show CRITICAL full-screen notification for emergency requests
  static Future<void> _showEmergencyRequestNotification(Map<String, dynamic> data) async {
    final requestId = data['requestId'];
    final emergencyType = data['emergencyType'];
    final priority = data['priority']?.toUpperCase() ?? 'MEDIUM';
    final location = data['location'] ?? 'Unknown location';
    final description = data['description'] ?? '';
    final contactName = data['contactName'] ?? 'Emergency Contact';
    final distance = data['distance'] ?? '0';

    final emoji = _emergencyEmojis[emergencyType] ?? '🚨';
    final channelId = _emergencyChannels[emergencyType] ?? 'emergency_requests';

    // Start playing CRITICAL emergency sound
    await _playEmergencySound(emergencyType);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      _emergencyChannelNames[emergencyType] ?? 'Emergency Requests',
      channelDescription: 'CRITICAL priority notifications for $emergencyType emergency requests',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('${emergencyType}_emergency_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 200, 200, 200, 200, 200]),
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'accept_emergency',
          '🚨 RESPOND NOW',
          titleColor: Color.fromARGB(255, 255, 255, 255),
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'decline_emergency',
          '❌ CANNOT RESPOND',
          titleColor: Color.fromARGB(255, 150, 150, 150),
          showsUserInterface: true,
        ),
      ],
      color: Colors.red,
      colorized: true,
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: '${emergencyType}_emergency_sound.wav',
      categoryIdentifier: 'EMERGENCY_REQUEST',
      threadIdentifier: emergencyType,
      interruptionLevel: InterruptionLevel.critical,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      requestId.hashCode,
      '$emoji EMERGENCY - $priority PRIORITY',
      '$contactName • ${distance}km away\n📍 $location\n${description.isNotEmpty ? '📝 $description' : ''}',
      notificationDetails,
      payload: jsonEncode({
        'type': 'emergency_request',
        'requestId': requestId,
        'emergencyType': emergencyType,
        'priority': priority,
        'location': location,
        'description': description,
        'contactName': contactName,
        'distance': distance,
      }),
    );

    print('🚨 CRITICAL emergency notification shown for $emergencyType request: $requestId');
  }

  /// Play CRITICAL emergency sound based on service type
  static Future<void> _playEmergencySound(String emergencyType) async {
    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer!.play(AssetSource('sounds/${emergencyType}_emergency_sound.mp3'));
      print('🔊 Playing CRITICAL $emergencyType emergency sound');
    } catch (e) {
      print('❌ Error playing emergency sound: $e');
      // Fallback to generic emergency sound
      try {
        await _audioPlayer!.play(AssetSource('sounds/emergency_alert_sound.mp3'));
      } catch (fallbackError) {
        print('❌ Error playing fallback emergency sound: $fallbackError');
      }
    }
  }

  /// Stop emergency sound
  static Future<void> _stopEmergencySound() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        print('🔇 Stopped emergency sound');
      }
    } catch (e) {
      print('❌ Error stopping emergency sound: $e');
    }
  }

  /// Handle emergency notification tap events
  static Future<void> _onNotificationTapped(NotificationResponse response) async {
    final payload = response.payload;
    final actionId = response.actionId;

    if (payload != null) {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final requestId = data['requestId'];
      final emergencyType = data['emergencyType'];

      print('🚨 Emergency notification tapped - Action: $actionId, RequestId: $requestId, Type: $emergencyType');

      await _stopEmergencySound();
      await _localNotifications.cancel(requestId.hashCode);

      if (actionId == 'accept_emergency') {
        await _acceptEmergencyRequest(requestId, emergencyType);
      } else if (actionId == 'decline_emergency') {
        await _declineEmergencyRequest(requestId, emergencyType);
      } else {
        _navigateToEmergencyRequest(requestId, emergencyType);
      }
    }
  }

  /// Accept emergency request
  static Future<void> _acceptEmergencyRequest(String requestId, String emergencyType) async {
    try {
      final responderId = _auth.currentUser?.uid;
      if (responderId == null) {
        print('❌ No authenticated emergency responder');
        return;
      }

      print('🚨 Emergency responder accepting $emergencyType request: $requestId');

      await _firestore.collection('emergency_requests').doc(requestId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
        'acceptedBy': responderId,
      });

      await _firestore.collection('emergency_responders').doc(responderId).update({
        'isAvailable': false,
        'currentRequestId': requestId,
        'onEmergency': true,
        'emergencyType': emergencyType,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _navigateToActiveEmergency(requestId, emergencyType);
      print('✅ Successfully accepted $emergencyType emergency: $requestId');
    } catch (e) {
      print('❌ Error accepting emergency request: $e');
    }
  }

  /// Decline emergency request
  static Future<void> _declineEmergencyRequest(String requestId, String emergencyType) async {
    try {
      final responderId = _auth.currentUser?.uid;
      if (responderId == null) {
        print('❌ No authenticated emergency responder');
        return;
      }

      print('❌ Emergency responder declining $emergencyType request: $requestId');

      await _firestore.collection('emergency_requests').doc(requestId).update({
        'status': 'cancelled_by_responder',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': responderId,
        'cancellationReason': 'declined_by_responder',
      });

      print('❌ Successfully declined $emergencyType emergency: $requestId');
    } catch (e) {
      print('❌ Error declining emergency request: $e');
    }
  }

  /// Update emergency responder's FCM token
  static Future<void> _updateEmergencyResponderFCMToken(String token) async {
    try {
      final responderId = _auth.currentUser?.uid;
      if (responderId != null) {
        await _firestore.collection('emergency_responders').doc(responderId).update({
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error updating emergency responder FCM token: $e');
    }
  }

  /// Navigate to emergency request screen
  static void _navigateToEmergencyRequest(String requestId, String emergencyType) {
    print('🧭 Navigating to $emergencyType emergency request: $requestId');
    // Implement navigation logic based on your app's routing
  }

  /// Navigate to active emergency screen
  static void _navigateToActiveEmergency(String requestId, String emergencyType) {
    print('🧭 Navigating to active $emergencyType emergency: $requestId');
    // Implement navigation logic based on your app's routing
  }

  /// Clear all emergency notifications
  static Future<void> clearEmergencyNotifications() async {
    await _localNotifications.cancelAll();
    await _stopEmergencySound();
  }

  /// Cancel specific emergency notification
  static Future<void> cancelEmergencyNotification(String requestId) async {
    await _localNotifications.cancel(requestId.hashCode);
    await _stopEmergencySound();
  }

  /// Get priority color for UI
  static Color getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Colors.red.shade900;
      case 'high':
        return Colors.red.shade600;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.yellow.shade700;
      default:
        return Colors.orange;
    }
  }

  /// Get priority icon for UI
  static IconData getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Icons.warning;
      case 'high':
        return Icons.priority_high;
      case 'medium':
        return Icons.info;
      case 'low':
        return Icons.info_outline;
      default:
        return Icons.info;
    }
  }
}

/// Background message handler for emergency requests
@pragma('vm:entry-point')
Future<void> firebaseMessagingEmergencyBackgroundHandler(RemoteMessage message) async {
  print('🚨 Handling background emergency FCM message: ${message.messageId}');
  
  final data = message.data;
  if (data['type'] == 'emergency_request') {
    await EmergencyNotificationService._showEmergencyRequestNotification(data);
  }
}