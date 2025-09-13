import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:zippup/services/notifications/ride_notification_service.dart';

/// Main app integration for ride services
/// Add this to your main.dart file
class RideServiceIntegration {
  
  /// Initialize all ride-related services
  /// Call this in your main() function before runApp()
  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase (if not already done)
    // await Firebase.initializeApp();
    
    // Set background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    // Initialize ride notification service
    await RideNotificationService.initialize();
    
    print('✅ Ride services initialized successfully');
  }
  
  /// Setup ride services after app starts
  /// Call this in your app's initState() or main screen
  static Future<void> setupAfterAppStart() async {
    // Any additional setup that needs to happen after the app is running
    print('✅ Ride services setup completed');
  }
}

/// Example of how to integrate in main.dart:
/// 
/// ```dart
/// import 'package:firebase_core/firebase_core.dart';
/// import 'package:flutter/material.dart';
/// import 'package:zippup/services/rides/ride_service_integration.dart';
/// 
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   
///   // Initialize Firebase
///   await Firebase.initializeApp();
///   
///   // Initialize ride services
///   await RideServiceIntegration.initialize();
///   
///   runApp(MyApp());
/// }
/// 
/// class MyApp extends StatefulWidget {
///   @override
///   State<MyApp> createState() => _MyAppState();
/// }
/// 
/// class _MyAppState extends State<MyApp> {
///   @override
///   void initState() {
///     super.initState();
///     
///     // Setup ride services after app starts
///     RideServiceIntegration.setupAfterAppStart();
///   }
///   
///   @override
///   Widget build(BuildContext context) {
///     return MaterialApp(
///       title: 'ZippUp',
///       // ... your app configuration
///     );
///   }
/// }
/// ```

/// Example usage in a customer app screen:
/// 
/// ```dart
/// import 'package:flutter/material.dart';
/// import 'package:zippup/features/rides/presentation/ride_tracking_screen.dart';
/// import 'package:zippup/services/rides/ride_listener_service.dart';
/// 
/// class BookRideScreen extends StatefulWidget {
///   @override
///   State<BookRideScreen> createState() => _BookRideScreenState();
/// }
/// 
/// class _BookRideScreenState extends State<BookRideScreen> {
///   
///   Future<void> _bookRide() async {
///     try {
///       // Create ride document in Firestore with status 'requesting'
///       final rideDoc = await FirebaseFirestore.instance.collection('rides').add({
///         'customerId': FirebaseAuth.instance.currentUser?.uid,
///         'status': 'requesting',
///         'vehicleClass': 'Standard', // or whatever class user selected
///         'pickupLocation': GeoPoint(latitude, longitude),
///         'pickupAddress': 'User\'s pickup address',
///         'destinationLocation': GeoPoint(destLat, destLng),
///         'destinationAddress': 'User\'s destination',
///         'estimatedFare': 1500.0,
///         'passengerName': 'User Name',
///         'createdAt': FieldValue.serverTimestamp(),
///       });
///       
///       // Navigate to ride tracking screen
///       Navigator.of(context).push(
///         MaterialPageRoute(
///           builder: (context) => RideTrackingScreen(rideId: rideDoc.id),
///         ),
///       );
///       
///     } catch (e) {
///       ScaffoldMessenger.of(context).showSnackBar(
///         SnackBar(content: Text('Failed to book ride: $e')),
///       );
///     }
///   }
///   
///   @override
///   Widget build(BuildContext context) {
///     return Scaffold(
///       appBar: AppBar(title: Text('Book a Ride')),
///       body: Center(
///         child: ElevatedButton(
///           onPressed: _bookRide,
///           child: Text('Book Ride'),
///         ),
///       ),
///     );
///   }
/// }
/// ```