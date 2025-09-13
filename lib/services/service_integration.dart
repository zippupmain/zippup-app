import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:zippup/services/notifications/ride_notification_service.dart';
import 'package:zippup/services/notifications/moving_notification_service.dart';
import 'package:zippup/services/notifications/emergency_notification_service.dart';

/// Comprehensive service integration for all ZippUp services
class ServiceIntegration {
  
  /// Initialize all service types
  static Future<void> initializeAllServices() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Set background message handlers for all services
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingMovingBackgroundHandler);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingEmergencyBackgroundHandler);
    
    // Initialize all notification services
    await Future.wait([
      RideNotificationService.initialize(),
      MovingNotificationService.initialize(),
      EmergencyNotificationService.initialize(),
    ]);
    
    print('✅ All ZippUp services initialized successfully');
  }
  
  /// Setup services after app starts
  static Future<void> setupAfterAppStart() async {
    print('✅ All ZippUp services setup completed');
  }

  /// Clear all notifications for all services
  static Future<void> clearAllNotifications() async {
    await Future.wait([
      RideNotificationService.clearRideNotifications(),
      MovingNotificationService.clearMovingNotifications(),
      EmergencyNotificationService.clearEmergencyNotifications(),
    ]);
    print('✅ All service notifications cleared');
  }
}

/// Master background message handler that routes to appropriate service
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📱 Handling background FCM message: ${message.messageId}');
  
  final data = message.data;
  final messageType = data['type'];
  
  switch (messageType) {
    case 'ride_request':
      await RideNotificationService._showRideRequestNotification(data);
      break;
    case 'moving_request':
      await MovingNotificationService._showMovingRequestNotification(data);
      break;
    case 'emergency_request':
      await EmergencyNotificationService._showEmergencyRequestNotification(data);
      break;
    default:
      print('⚠️ Unknown message type: $messageType');
  }
}

/// Service-specific background handlers
@pragma('vm:entry-point')
Future<void> firebaseMessagingMovingBackgroundHandler(RemoteMessage message) async {
  print('📦 Handling background moving FCM message: ${message.messageId}');
  
  final data = message.data;
  if (data['type'] == 'moving_request') {
    await MovingNotificationService._showMovingRequestNotification(data);
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingEmergencyBackgroundHandler(RemoteMessage message) async {
  print('🚨 Handling background emergency FCM message: ${message.messageId}');
  
  final data = message.data;
  if (data['type'] == 'emergency_request') {
    await EmergencyNotificationService._showEmergencyRequestNotification(data);
  }
}

/// Service type enumeration
enum ServiceType {
  transport,
  moving,
  emergency,
}

/// Extension for service type utilities
extension ServiceTypeExtension on ServiceType {
  String get name {
    switch (this) {
      case ServiceType.transport:
        return 'transport';
      case ServiceType.moving:
        return 'moving';
      case ServiceType.emergency:
        return 'emergency';
    }
  }

  String get displayName {
    switch (this) {
      case ServiceType.transport:
        return 'Transport';
      case ServiceType.moving:
        return 'Moving';
      case ServiceType.emergency:
        return 'Emergency';
    }
  }

  IconData get icon {
    switch (this) {
      case ServiceType.transport:
        return Icons.directions_car;
      case ServiceType.moving:
        return Icons.local_shipping;
      case ServiceType.emergency:
        return Icons.emergency;
    }
  }

  Color get color {
    switch (this) {
      case ServiceType.transport:
        return Colors.blue;
      case ServiceType.moving:
        return Colors.orange;
      case ServiceType.emergency:
        return Colors.red;
    }
  }
}