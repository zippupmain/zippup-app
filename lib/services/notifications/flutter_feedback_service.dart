import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FlutterFeedbackService {
  FlutterFeedbackService._internal();
  static final FlutterFeedbackService instance = FlutterFeedbackService._internal();

  /// Use Flutter's built-in feedback mechanisms that definitely work
  Future<bool> playFlutterFeedback({bool isUrgent = false}) async {
    final type = isUrgent ? 'URGENT' : 'NORMAL';
    print('🎯 [$type] Using Flutter built-in feedback...');
    
    bool success = false;

    try {
      if (isUrgent) {
        // Urgent: Multiple feedback types
        print('🚨 [$type] Playing urgent Flutter feedback...');
        
        // Method 1: Impact feedback (like button press)
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 200));
        await HapticFeedback.heavyImpact();
        
        // Method 2: Selection feedback (like scrolling)
        await HapticFeedback.selectionClick();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.selectionClick();
        
        print('✅ [$type] Urgent Flutter feedback completed');
      } else {
        // Normal: Single feedback
        print('🔔 [$type] Playing normal Flutter feedback...');
        
        // Method 1: Medium impact
        await HapticFeedback.mediumImpact();
        
        // Method 2: Light impact as backup
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.lightImpact();
        
        print('✅ [$type] Normal Flutter feedback completed');
      }
      
      success = true;
    } catch (e) {
      print('❌ [$type] Flutter feedback failed: $e');
    }

    // Always try system sound as additional feedback
    try {
      await SystemSound.play(SystemSoundType.alert);
      print('✅ [$type] System sound added');
      success = true;
    } catch (e) {
      print('❌ [$type] System sound failed: $e');
    }

    print(success ? '🎉 [$type] Flutter feedback SUCCESS' : '💥 [$type] Flutter feedback FAILED');
    return success;
  }

  /// Customer notification
  Future<bool> playCustomerNotification() async {
    return await playFlutterFeedback(isUrgent: false);
  }

  /// Driver notification (urgent)
  Future<bool> playDriverNotification() async {
    return await playFlutterFeedback(isUrgent: true);
  }

  /// Test using Flutter's widget feedback (like button taps)
  Future<bool> testWidgetFeedback(BuildContext context) async {
    print('🎯 Testing Flutter widget feedback...');
    
    try {
      // Method 1: Simulate button tap feedback
      print('🔘 Simulating button tap feedback...');
      await HapticFeedback.lightImpact(); // Like tapping a button
      
      // Method 2: Simulate long press feedback  
      await Future.delayed(const Duration(milliseconds: 200));
      print('🔘 Simulating long press feedback...');
      await HapticFeedback.heavyImpact(); // Like long pressing
      
      // Method 3: Show snackbar with sound (built-in Flutter feedback)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔊 Flutter feedback test - did you feel/hear this?'),
          duration: Duration(seconds: 2),
        ),
      );
      
      print('✅ Widget feedback test completed');
      return true;
    } catch (e) {
      print('❌ Widget feedback test failed: $e');
      return false;
    }
  }

  /// Test all Flutter feedback methods
  Future<Map<String, bool>> testAllFlutterFeedback(BuildContext context) async {
    print('\n🎯 Testing ALL Flutter feedback methods...');
    
    final results = <String, bool>{};
    
    print('\n--- Test 1: Light Impact (Button Tap) ---');
    try {
      await HapticFeedback.lightImpact();
      results['light_impact'] = true;
      print('✅ Light impact SUCCESS');
    } catch (e) {
      results['light_impact'] = false;
      print('❌ Light impact failed: $e');
    }
    await Future.delayed(const Duration(seconds: 1));
    
    print('\n--- Test 2: Medium Impact (Notification) ---');
    try {
      await HapticFeedback.mediumImpact();
      results['medium_impact'] = true;
      print('✅ Medium impact SUCCESS');
    } catch (e) {
      results['medium_impact'] = false;
      print('❌ Medium impact failed: $e');
    }
    await Future.delayed(const Duration(seconds: 1));
    
    print('\n--- Test 3: Heavy Impact (Alert) ---');
    try {
      await HapticFeedback.heavyImpact();
      results['heavy_impact'] = true;
      print('✅ Heavy impact SUCCESS');
    } catch (e) {
      results['heavy_impact'] = false;
      print('❌ Heavy impact failed: $e');
    }
    await Future.delayed(const Duration(seconds: 1));
    
    print('\n--- Test 4: Selection Click (Scroll) ---');
    try {
      await HapticFeedback.selectionClick();
      results['selection_click'] = true;
      print('✅ Selection click SUCCESS');
    } catch (e) {
      results['selection_click'] = false;
      print('❌ Selection click failed: $e');
    }
    await Future.delayed(const Duration(seconds: 1));
    
    print('\n--- Test 5: Vibrate (Generic) ---');
    try {
      await HapticFeedback.vibrate();
      results['vibrate'] = true;
      print('✅ Vibrate SUCCESS');
    } catch (e) {
      results['vibrate'] = false;
      print('❌ Vibrate failed: $e');
    }
    
    final successCount = results.values.where((s) => s).length;
    print('\n🎯 FLUTTER FEEDBACK RESULTS: $successCount/5 methods worked');
    print('📊 Results: $results');
    
    if (successCount > 0) {
      print('🎉 SUCCESS: Flutter feedback system is working!');
      print('💡 The "shaking" you feel is Flutter haptic feedback working correctly');
    } else {
      print('💥 CRITICAL: Even Flutter haptic feedback is disabled');
      print('🔧 CHECK: Device haptic feedback settings');
    }
    
    return results;
  }
}