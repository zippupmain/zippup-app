import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock/wakelock.dart';

/// Phone-call style notification service for incoming requests
class IncomingCallNotificationService {
  static final IncomingCallNotificationService _instance = IncomingCallNotificationService._internal();
  factory IncomingCallNotificationService() => _instance;
  IncomingCallNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  AudioPlayer? _ringtonePlayer;
  Timer? _vibrationTimer;
  
  // Notification channels
  static const String _highPriorityChannelId = 'incoming_requests_critical';
  static const String _statusUpdatesChannelId = 'order_status_updates';

  /// Initialize notification system
  Future<void> initialize() async {
    try {
      // Android initialization
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS initialization
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

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      // Create notification channels
      await _createNotificationChannels();
      
      print('✅ Notification service initialized');

    } catch (e) {
      print('❌ Error initializing notifications: $e');
    }
  }

  /// Create high-priority notification channels
  Future<void> _createNotificationChannels() async {
    if (Platform.isAndroid) {
      // High-priority channel for incoming requests
      const highPriorityChannel = AndroidNotificationChannel(
        _highPriorityChannelId,
        'Incoming Service Requests',
        description: 'Critical notifications for incoming service requests',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        ledColor: Color.fromARGB(255, 255, 107, 53),
        sound: RawResourceAndroidNotificationSound('urgent_request_ringtone'),
        showBadge: true,
      );

      // Status updates channel
      const statusUpdatesChannel = AndroidNotificationChannel(
        _statusUpdatesChannelId,
        'Order Status Updates',
        description: 'Notifications for order status changes',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(highPriorityChannel);

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(statusUpdatesChannel);
    }
  }

  /// Show incoming call-style notification for providers
  Future<void> showIncomingRequestNotification({
    required String orderId,
    required Map<String, dynamic> requestData,
    required BuildContext context,
  }) async {
    try {
      print('📞 Showing incoming call notification for order: $orderId');

      // 1. Wake up screen and ensure visibility
      await _ensureScreenVisibility();

      // 2. Show full-screen incoming call UI
      await _showFullScreenIncomingCall(context, orderId, requestData);

      // 3. Start phone-call effects
      await _startIncomingCallEffects();

      // 4. Show backup push notification
      await _showHighPriorityPushNotification(orderId, requestData);

      print('✅ Incoming call notification displayed');

    } catch (e) {
      print('❌ Error showing incoming call notification: $e');
    }
  }

  /// Full-screen incoming call interface
  Future<void> _showFullScreenIncomingCall(
    BuildContext context,
    String orderId,
    Map<String, dynamic> requestData,
  ) async {
    await Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) => IncomingRequestCallScreen(
          orderId: orderId,
          requestData: requestData,
          onAccept: () => _handleAcceptRequest(context, orderId),
          onDecline: () => _handleDeclineRequest(context, orderId),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          );
        },
      ),
    );
  }

  /// Start phone-call like effects
  Future<void> _startIncomingCallEffects() async {
    // Start vibration pattern
    await _startVibrationPattern();
    
    // Play ringtone
    await _playUrgentRingtone();
    
    // Keep screen awake
    Wakelock.enable();
  }

  /// Stop all incoming call effects
  Future<void> stopIncomingCallEffects() async {
    try {
      // Stop vibration
      if (await Vibration.hasVibrator() ?? false) {
        Vibration.cancel();
      }
      
      // Stop ringtone
      await _ringtonePlayer?.stop();
      await _ringtonePlayer?.dispose();
      _ringtonePlayer = null;
      
      // Cancel vibration timer
      _vibrationTimer?.cancel();
      _vibrationTimer = null;
      
      // Cancel notification
      await _notificationsPlugin.cancelAll();
      
      // Allow screen to sleep
      Wakelock.disable();
      
      print('✅ Stopped all incoming call effects');

    } catch (e) {
      print('❌ Error stopping call effects: $e');
    }
  }

  /// Vibration pattern like incoming phone call
  Future<void> _startVibrationPattern() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        // Continuous vibration pattern until answered
        _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
          Vibration.vibrate(
            pattern: [0, 800, 400, 800], // Ring pattern
            intensities: [0, 255, 0, 255], // Full intensity
          );
        });
      }
    } catch (e) {
      print('❌ Vibration error: $e');
    }
  }

  /// Play urgent ringtone
  Future<void> _playUrgentRingtone() async {
    try {
      _ringtonePlayer = AudioPlayer();
      
      // Set to loop until stopped
      await _ringtonePlayer!.setReleaseMode(ReleaseMode.loop);
      
      // Play at maximum volume
      await _ringtonePlayer!.setVolume(1.0);
      
      // Play urgent ringtone
      await _ringtonePlayer!.play(AssetSource('sounds/urgent_request_ringtone.mp3'));
      
      print('🔊 Playing urgent ringtone');

    } catch (e) {
      print('❌ Ringtone error: $e');
    }
  }

  /// High-priority push notification
  Future<void> _showHighPriorityPushNotification(
    String orderId,
    Map<String, dynamic> requestData,
  ) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        _highPriorityChannelId,
        'Incoming Service Requests',
        channelDescription: 'Critical notifications for incoming service requests',
        importance: Importance.max,
        priority: Priority.high,
        
        // Full-screen and persistent
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        
        // Rich content
        style: AndroidNotificationStyle.bigText,
        bigText: _buildNotificationText(requestData),
        
        // Visual styling
        color: Color.fromARGB(255, 255, 107, 53),
        ledColor: Color.fromARGB(255, 255, 107, 53),
        ledOnMs: 1000,
        ledOffMs: 500,
        
        // Action buttons
        actions: [
          AndroidNotificationAction(
            'accept_request',
            'ACCEPT',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'decline_request',
            'DECLINE', 
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'urgent_request_ringtone.caf',
        
        // Critical alert (requires Apple entitlement)
        interruptionLevel: InterruptionLevel.critical,
        
        // Rich content
        subtitle: _buildIOSSubtitle(requestData),
        categoryIdentifier: 'INCOMING_REQUEST',
      );

      await _notificationsPlugin.show(
        orderId.hashCode,
        '🚗 New ${requestData['serviceType']} Request',
        _buildNotificationTitle(requestData),
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: orderId,
      );

      print('📱 High-priority push notification sent');

    } catch (e) {
      print('❌ Push notification error: $e');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final orderId = response.payload;
    final actionId = response.actionId;
    
    print('📱 Notification tapped: $actionId for order $orderId');
    
    switch (actionId) {
      case 'accept_request':
        _handleAcceptFromNotification(orderId);
        break;
      case 'decline_request':
        _handleDeclineFromNotification(orderId);
        break;
      default:
        // Default tap - open order details
        _openOrderDetails(orderId);
        break;
    }
  }

  /// Ensure screen visibility for incoming call
  Future<void> _ensureScreenVisibility() async {
    try {
      // Wake up screen
      Wakelock.enable();
      
      // Bring app to foreground
      if (Platform.isAndroid) {
        // Request to show over lock screen
        await _requestShowOnLockScreen();
      }
      
      // Set screen brightness
      await Screen.setBrightness(1.0);
      
    } catch (e) {
      print('❌ Screen visibility error: $e');
    }
  }

  /// Request permission to show over lock screen (Android)
  Future<void> _requestShowOnLockScreen() async {
    try {
      const platform = MethodChannel('zippup/system_overlay');
      await platform.invokeMethod('requestOverlayPermission');
    } catch (e) {
      print('❌ Overlay permission error: $e');
    }
  }

  // Helper methods for notification content
  String _buildNotificationText(Map<String, dynamic> data) {
    final customerName = data['customerName'] ?? 'Customer';
    final customerTrips = data['customerTrips'] ?? 0;
    final paymentMethod = data['paymentMethod'] ?? 'card';
    final pickup = data['pickupAddress'] ?? 'Unknown pickup';
    final destination = data['destinationAddress'] ?? 'Unknown destination';
    
    return '$customerName ($customerTrips trips)\n'
           '${paymentMethod.toUpperCase()} Payment\n'
           'From: $pickup\n'
           'To: $destination';
  }

  String _buildNotificationTitle(Map<String, dynamic> data) {
    final customerName = data['customerName'] ?? 'Customer';
    final pickup = data['pickupAddress'] ?? 'Unknown';
    return '$customerName • $pickup';
  }

  String _buildIOSSubtitle(Map<String, dynamic> data) {
    final trips = data['customerTrips'] ?? 0;
    final payment = data['paymentMethod'] ?? 'card';
    return '$trips trips • ${payment.toUpperCase()} payment';
  }

  // Action handlers
  Future<void> _handleAcceptRequest(BuildContext context, String orderId) async {
    await stopIncomingCallEffects();
    Navigator.pop(context);
    // Handle accept logic
  }

  Future<void> _handleDeclineRequest(BuildContext context, String orderId) async {
    await stopIncomingCallEffects();
    Navigator.pop(context);
    // Handle decline logic
  }

  void _handleAcceptFromNotification(String? orderId) {
    // Handle accept from notification action
  }

  void _handleDeclineFromNotification(String? orderId) {
    // Handle decline from notification action
  }

  void _openOrderDetails(String? orderId) {
    // Open order details screen
  }
}