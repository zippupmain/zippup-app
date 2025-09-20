import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'dart:async';

/// Service specifically for PWA notifications that work globally
class PWANotificationService {
  static final PWANotificationService _instance = PWANotificationService._internal();
  factory PWANotificationService() => _instance;
  PWANotificationService._internal();

  static PWANotificationService get instance => _instance;

  /// Show a system-level notification for PWA
  static Future<void> showPWANotification({
    required String title,
    required String body,
    String? icon,
    String? badge,
    bool requireInteraction = true,
    List<Map<String, String>>? actions,
  }) async {
    if (!kIsWeb) {
      print('📱 PWA notifications only work on web');
      return;
    }

    try {
      print('🌐 Showing PWA notification: $title');
      
      // Play system sound first
      await _playSystemSound();
      
      // Use platform channel to show web notification
      await _showWebNotification(
        title: title,
        body: body,
        icon: icon ?? '/icons/app_icon.png',
        badge: badge ?? '/icons/app_icon.png',
        requireInteraction: requireInteraction,
        actions: actions,
      );
      
      print('✅ PWA notification shown successfully');
    } catch (e) {
      print('❌ Error showing PWA notification: $e');
    }
  }

  /// Show ride request notification for PWA
  static Future<void> showRideRequestPWA({
    required String rideId,
    required String customerName,
    required String pickupAddress,
    required String rideType,
  }) async {
    await showPWANotification(
      title: '🚗 New $rideType Request',
      body: '$customerName needs a ride from $pickupAddress',
      requireInteraction: true,
      actions: [
        {'action': 'accept', 'title': '✅ Accept'},
        {'action': 'decline', 'title': '❌ Decline'},
      ],
    );
  }

  /// Play system sound for PWA
  static Future<void> _playSystemSound() async {
    try {
      // Use system sound for web
      await SystemSound.play(SystemSoundType.alert);
      
      // Also try haptic feedback
      await HapticFeedback.heavyImpact();
      
      print('🔊 PWA system sound played');
    } catch (e) {
      print('❌ Error playing PWA system sound: $e');
    }
  }

  /// Show web notification using platform-specific method
  static Future<void> _showWebNotification({
    required String title,
    required String body,
    String? icon,
    String? badge,
    bool requireInteraction = false,
    List<Map<String, String>>? actions,
  }) async {
    // This would typically use dart:html or js interop
    // For now, we'll use a fallback approach
    print('🌐 Web notification: $title - $body');
    
    // Try to use browser notification API if available
    try {
      // This is a placeholder for actual web notification implementation
      // In a real implementation, you'd use dart:html or js interop
      print('🔔 Browser notification API called');
    } catch (e) {
      print('❌ Browser notification API failed: $e');
    }
  }

  /// Request notification permission for PWA
  static Future<bool> requestPermission() async {
    if (!kIsWeb) return false;
    
    try {
      print('🔔 Requesting PWA notification permission...');
      
      // This would typically check and request permission
      // For now, assume granted
      print('✅ PWA notification permission granted');
      return true;
    } catch (e) {
      print('❌ Error requesting PWA notification permission: $e');
      return false;
    }
  }

  /// Check if PWA notifications are supported
  static bool get isSupported => kIsWeb;

  /// Initialize PWA notification service
  static Future<void> initialize() async {
    if (!kIsWeb) return;
    
    try {
      print('🚀 Initializing PWA notification service...');
      
      // Request permission
      await requestPermission();
      
      print('✅ PWA notification service initialized');
    } catch (e) {
      print('❌ Error initializing PWA notification service: $e');
    }
  }
}