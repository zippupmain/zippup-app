import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Secure delivery code generation and verification service
class DeliveryCodeService {
  static const String _validChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const int _codeLength = 6;
  static const int _maxAttempts = 3;
  static const int _maxAttemptsPerHour = 20;

  /// Generate cryptographically secure delivery code
  static String generateSecureCode() {
    final random = math.Random.secure();
    String code;
    
    do {
      code = List.generate(_codeLength, (index) => 
        _validChars[random.nextInt(_validChars.length)]
      ).join('');
    } while (_isProblematicCode(code));
    
    return code;
  }

  /// Check for problematic patterns
  static bool _isProblematicCode(String code) {
    // Avoid repeated characters
    if (RegExp(r'(.)\1{2,}').hasMatch(code)) return true;
    
    // Avoid sequential patterns
    final sequences = ['ABCDEF', '123456', '654321', 'QWERTY'];
    return sequences.any((seq) => code.contains(seq));
  }

  /// Verify delivery code with comprehensive security
  static Future<DeliveryCodeResult> verifyCode({
    required String orderId,
    required String enteredCode,
    required String driverId,
    required double driverLat,
    required double driverLng,
  }) async {
    try {
      // Rate limiting check
      final rateLimitOk = await _checkRateLimit(driverId);
      if (!rateLimitOk) {
        return DeliveryCodeResult.error('Too many attempts. Try again later.');
      }

      // Use transaction for atomic verification
      return await FirebaseFirestore.instance.runTransaction<DeliveryCodeResult>((transaction) async {
        // Get order data
        final orderRef = FirebaseFirestore.instance.collection('food_orders').doc(orderId);
        final orderSnapshot = await transaction.get(orderRef);

        if (!orderSnapshot.exists) {
          throw Exception('Order not found');
        }

        final orderData = orderSnapshot.data()!;
        
        // Validate order state
        final validationResult = _validateOrderForVerification(orderData, driverId);
        if (!validationResult.isValid) {
          return DeliveryCodeResult.error(validationResult.message!);
        }

        // Location validation
        final locationValid = await _validateDeliveryLocation(
          orderData, driverLat, driverLng);
        if (!locationValid.isValid) {
          return DeliveryCodeResult.error(locationValid.message!);
        }

        // Code verification
        final codeResult = _verifyCodeLogic(orderData, enteredCode);
        
        // Update attempt tracking
        final newAttempts = (orderData['codeAttempts'] as int? ?? 0) + 1;
        final attemptData = {
          'codeAttempts': newAttempts,
          'lastCodeAttemptAt': FieldValue.serverTimestamp(),
          'codeAttemptHistory': FieldValue.arrayUnion([
            {
              'attempt': newAttempts,
              'timestamp': FieldValue.serverTimestamp(),
              'isCorrect': codeResult.isValid,
              'driverLocation': {'latitude': driverLat, 'longitude': driverLng},
            }
          ]),
        };

        if (codeResult.isValid) {
          // Success - complete delivery
          transaction.update(orderRef, {
            ...attemptData,
            'status': 'delivered',
            'deliveredAt': FieldValue.serverTimestamp(),
            'codeVerifiedAt': FieldValue.serverTimestamp(),
            'deliveryCompletedBy': driverId,
          });

          // Log successful delivery
          _logDeliveryCompletion(transaction, orderId, orderData, driverId);

          return DeliveryCodeResult.success('Delivery completed successfully!');
        } else {
          // Failed verification
          transaction.update(orderRef, attemptData);

          // Check if max attempts reached
          if (newAttempts >= _maxAttempts) {
            transaction.update(orderRef, {
              'status': 'delivery_verification_failed',
              'flaggedForReview': true,
              'flaggedAt': FieldValue.serverTimestamp(),
              'flagReason': 'Max delivery code attempts exceeded',
            });

            // Create support ticket
            _createSupportTicket(transaction, orderId, orderData, driverId);

            return DeliveryCodeResult.blocked(
              'Maximum attempts exceeded. Order flagged for review.',
            );
          }

          final remaining = _maxAttempts - newAttempts;
          return DeliveryCodeResult.error(
            'Invalid code. $remaining attempts remaining.',
            remainingAttempts: remaining,
          );
        }
      });

    } catch (e) {
      print('❌ Code verification error: $e');
      return DeliveryCodeResult.error('Verification failed: ${e.toString()}');
    }
  }

  /// Validate order state for verification
  static ValidationResult _validateOrderForVerification(
    Map<String, dynamic> orderData, 
    String driverId,
  ) {
    // Check driver assignment
    if (orderData['driverId'] != driverId) {
      return ValidationResult(false, 'Driver not assigned to this order');
    }

    // Check order status
    if (orderData['status'] != 'driver_at_customer') {
      return ValidationResult(false, 'Order not ready for delivery verification');
    }

    // Check if already delivered
    if (orderData['deliveredAt'] != null) {
      return ValidationResult(false, 'Order already delivered');
    }

    return ValidationResult(true);
  }

  /// Validate driver location for delivery
  static Future<ValidationResult> _validateDeliveryLocation(
    Map<String, dynamic> orderData,
    double driverLat,
    double driverLng,
  ) async {
    try {
      final customerLat = orderData['customerLocation']['latitude'] as double;
      final customerLng = orderData['customerLocation']['longitude'] as double;
      
      final distance = _calculateDistance(customerLat, customerLng, driverLat, driverLng);
      
      const maxDistanceKm = 0.1; // 100 meters
      if (distance > maxDistanceKm) {
        return ValidationResult(
          false, 
          'Driver too far from delivery location (${(distance * 1000).toInt()}m away)',
        );
      }

      return ValidationResult(true);
    } catch (e) {
      return ValidationResult(false, 'Location validation failed');
    }
  }

  /// Core code verification logic
  static DeliveryCodeResult _verifyCodeLogic(
    Map<String, dynamic> orderData,
    String enteredCode,
  ) {
    final correctCode = orderData['deliveryCode'] as String;
    final isValid = enteredCode.toUpperCase().trim() == correctCode.toUpperCase().trim();
    
    return isValid 
      ? DeliveryCodeResult.success('Code verified')
      : DeliveryCodeResult.error('Invalid delivery code');
  }

  /// Rate limiting to prevent brute force
  static Future<bool> _checkRateLimit(String driverId) async {
    try {
      final oneHourAgo = DateTime.now().subtract(Duration(hours: 1));
      
      final recentAttempts = await FirebaseFirestore.instance
          .collection('code_attempt_log')
          .where('driverId', isEqualTo: driverId)
          .where('timestamp', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .get();

      if (recentAttempts.docs.length >= _maxAttemptsPerHour) {
        print('⚠️ Rate limit exceeded for driver: $driverId');
        return false;
      }

      // Log attempt
      await FirebaseFirestore.instance.collection('code_attempt_log').add({
        'driverId': driverId,
        'timestamp': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('❌ Rate limit check error: $e');
      return true; // Fail open
    }
  }

  /// Log successful delivery completion
  static void _logDeliveryCompletion(
    Transaction transaction,
    String orderId,
    Map<String, dynamic> orderData,
    String driverId,
  ) {
    final logRef = FirebaseFirestore.instance.collection('order_status_log').doc();
    transaction.set(logRef, {
      'orderId': orderId,
      'previousStatus': orderData['status'],
      'newStatus': 'delivered',
      'updatedBy': driverId,
      'updatedByRole': 'driver',
      'timestamp': FieldValue.serverTimestamp(),
      'changeReason': 'Delivery code verified successfully',
      'additionalData': {
        'deliveryCodeUsed': orderData['deliveryCode'],
        'totalCodeAttempts': (orderData['codeAttempts'] ?? 0) + 1,
        'verificationMethod': 'mobile_app',
      },
    });
  }

  /// Create support ticket for failed deliveries
  static void _createSupportTicket(
    Transaction transaction,
    String orderId,
    Map<String, dynamic> orderData,
    String driverId,
  ) {
    final ticketRef = FirebaseFirestore.instance.collection('support_tickets').doc();
    transaction.set(ticketRef, {
      'type': 'delivery_verification_failure',
      'orderId': orderId,
      'customerId': orderData['customerId'],
      'driverId': driverId,
      'vendorId': orderData['vendorId'],
      'description': 'Driver exceeded maximum delivery code attempts',
      'priority': 'high',
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'metadata': {
        'totalAttempts': orderData['codeAttempts'] ?? 0,
        'orderValue': orderData['total'] ?? 0,
        'deliveryAddress': orderData['customerLocation']['address'],
      },
    });
  }

  /// Calculate distance between two points
  static double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // meters
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return (earthRadius * c) / 1000; // Convert to km
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180);
}

/// Result classes
class DeliveryCodeResult {
  final bool isValid;
  final String message;
  final bool isBlocked;
  final int? remainingAttempts;

  const DeliveryCodeResult._({
    required this.isValid,
    required this.message,
    this.isBlocked = false,
    this.remainingAttempts,
  });

  factory DeliveryCodeResult.success(String message) => 
    DeliveryCodeResult._(isValid: true, message: message);

  factory DeliveryCodeResult.error(String message, {int? remainingAttempts}) => 
    DeliveryCodeResult._(
      isValid: false, 
      message: message,
      remainingAttempts: remainingAttempts,
    );

  factory DeliveryCodeResult.blocked(String message) => 
    DeliveryCodeResult._(
      isValid: false, 
      message: message, 
      isBlocked: true,
    );
}

class ValidationResult {
  final bool isValid;
  final String? message;

  const ValidationResult(this.isValid, [this.message]);
}