import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Order State Transition Management System
/// 
/// Manages the complete lifecycle of service orders with automatic state transitions,
/// validation, and event handling for real-time dispatch and matching.
class OrderStateManager {
  static final OrderStateManager _instance = OrderStateManager._internal();
  factory OrderStateManager() => _instance;
  OrderStateManager._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, StreamSubscription> _orderListeners = {};

  /// Order State Definitions
  static const Map<String, List<String>> allowedTransitions = {
    'pending': ['searching', 'cancelled'],
    'searching': ['dispatched', 'failed', 'cancelled'],
    'dispatched': ['accepted', 'searching', 'cancelled'], // Can go back to searching on timeout
    'accepted': ['in_progress', 'cancelled'],
    'in_progress': ['completed', 'cancelled'],
    'completed': [], // Terminal state
    'cancelled': [], // Terminal state
    'failed': [], // Terminal state
  };

  /// Service-specific state mappings
  static const Map<String, Map<String, String>> serviceStateMapping = {
    'transport': {
      'pending': 'requested',
      'searching': 'searching',
      'dispatched': 'dispatched',
      'accepted': 'accepted',
      'in_progress': 'enroute',
      'completed': 'completed',
      'cancelled': 'cancelled',
      'failed': 'failed'
    },
    'emergency': {
      'pending': 'requested',
      'searching': 'dispatching',
      'dispatched': 'dispatched',
      'accepted': 'assigned',
      'in_progress': 'responding',
      'completed': 'resolved',
      'cancelled': 'cancelled',
      'failed': 'failed'
    },
    'hire': {
      'pending': 'requested',
      'searching': 'finding_provider',
      'dispatched': 'provider_notified',
      'accepted': 'scheduled',
      'in_progress': 'in_progress',
      'completed': 'completed',
      'cancelled': 'cancelled',
      'failed': 'no_providers'
    }
  };

  /// Initialize order state tracking
  Future<void> initializeOrder({
    required String orderId,
    required String service,
    required String customerId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final collection = _getCollectionForService(service);
      final serviceState = _getServiceState(service, 'pending');
      
      final orderData = {
        'customerId': customerId,
        'service': service,
        'status': serviceState,
        'internalState': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'stateHistory': [
          {
            'state': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
            'reason': 'Order created'
          }
        ],
        ...?additionalData,
      };

      await _db.collection(collection).doc(orderId).set(orderData);
      
      // Start state monitoring
      _startOrderMonitoring(orderId, service);
      
      print('✅ Initialized order state: $orderId ($service)');
      
    } catch (e) {
      print('❌ Error initializing order state: $e');
      rethrow;
    }
  }

  /// Transition order to new state with validation
  Future<bool> transitionOrderState({
    required String orderId,
    required String service,
    required String newState,
    String? reason,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final collection = _getCollectionForService(service);
      final orderDoc = await _db.collection(collection).doc(orderId).get();
      
      if (!orderDoc.exists) {
        print('❌ Order not found: $orderId');
        return false;
      }

      final currentData = orderDoc.data()!;
      final currentState = currentData['internalState'] ?? currentData['status'];
      
      // Validate transition
      if (!_isValidTransition(currentState, newState)) {
        print('❌ Invalid state transition: $currentState -> $newState');
        return false;
      }

      // Prepare update data
      final serviceState = _getServiceState(service, newState);
      final updateData = {
        'internalState': newState,
        'status': serviceState,
        'updatedAt': FieldValue.serverTimestamp(),
        'stateHistory': FieldValue.arrayUnion([
          {
            'state': newState,
            'timestamp': FieldValue.serverTimestamp(),
            'reason': reason ?? 'State transition',
            'previousState': currentState
          }
        ]),
        ...?additionalData,
      };

      // Add state-specific data
      switch (newState) {
        case 'searching':
          updateData['searchStartedAt'] = FieldValue.serverTimestamp();
          break;
        case 'dispatched':
          updateData['dispatchedAt'] = FieldValue.serverTimestamp();
          break;
        case 'accepted':
          updateData['acceptedAt'] = FieldValue.serverTimestamp();
          break;
        case 'in_progress':
          updateData['startedAt'] = FieldValue.serverTimestamp();
          break;
        case 'completed':
          updateData['completedAt'] = FieldValue.serverTimestamp();
          _stopOrderMonitoring(orderId);
          break;
        case 'cancelled':
        case 'failed':
          updateData['endedAt'] = FieldValue.serverTimestamp();
          _stopOrderMonitoring(orderId);
          break;
      }

      await orderDoc.reference.update(updateData);
      
      print('✅ Order $orderId: $currentState -> $newState');
      
      // Trigger state-specific actions
      await _handleStateTransitionEffects(orderId, service, currentState, newState, currentData);
      
      return true;

    } catch (e) {
      print('❌ Error transitioning order state: $e');
      return false;
    }
  }

  /// Handle side effects of state transitions
  Future<void> _handleStateTransitionEffects(
    String orderId,
    String service,
    String fromState,
    String toState,
    Map<String, dynamic> orderData,
  ) async {
    try {
      switch (toState) {
        case 'searching':
          await _triggerProviderSearch(orderId, service, orderData);
          break;
          
        case 'accepted':
          await _notifyCustomerOfAcceptance(orderId, service, orderData);
          await _updateProviderMetrics(orderData['providerId'], 'acceptance');
          break;
          
        case 'completed':
          await _processOrderCompletion(orderId, service, orderData);
          await _updateProviderMetrics(orderData['providerId'], 'completion');
          break;
          
        case 'cancelled':
          await _handleOrderCancellation(orderId, service, orderData, fromState);
          break;
          
        case 'failed':
          await _handleOrderFailure(orderId, service, orderData);
          break;
      }
    } catch (e) {
      print('❌ Error handling state transition effects: $e');
    }
  }

  /// Monitor order for automatic state transitions
  void _startOrderMonitoring(String orderId, String service) {
    final collection = _getCollectionForService(service);
    
    final subscription = _db.collection(collection).doc(orderId).snapshots().listen(
      (snapshot) async {
        if (!snapshot.exists) return;
        
        final data = snapshot.data()!;
        await _checkAutomaticTransitions(orderId, service, data);
      },
      onError: (error) {
        print('❌ Error monitoring order $orderId: $error');
      }
    );
    
    _orderListeners[orderId] = subscription;
  }

  /// Check for automatic state transitions based on conditions
  Future<void> _checkAutomaticTransitions(
    String orderId,
    String service,
    Map<String, dynamic> data,
  ) async {
    final currentState = data['internalState'] ?? data['status'];
    final now = DateTime.now();
    
    try {
      // Auto-transition from searching to failed after max attempts
      if (currentState == 'searching') {
        final searchStarted = (data['searchStartedAt'] as Timestamp?)?.toDate();
        final maxSearchTime = Duration(minutes: 10); // 10 minutes max search
        
        if (searchStarted != null && now.difference(searchStarted) > maxSearchTime) {
          await transitionOrderState(
            orderId: orderId,
            service: service,
            newState: 'failed',
            reason: 'Search timeout - no providers available'
          );
        }
      }
      
      // Auto-transition from dispatched to searching on provider timeout
      if (currentState == 'dispatched') {
        final dispatchedAt = (data['dispatchedAt'] as Timestamp?)?.toDate();
        final timeoutDuration = Duration(seconds: 60);
        
        if (dispatchedAt != null && now.difference(dispatchedAt) > timeoutDuration) {
          // This should be handled by the timeout timer, but this is a safety net
          print('⚠️ Safety net: Order $orderId dispatch timeout detected');
        }
      }
      
    } catch (e) {
      print('❌ Error in automatic transitions: $e');
    }
  }

  /// Trigger provider search
  Future<void> _triggerProviderSearch(String orderId, String service, Map<String, dynamic> orderData) async {
    // This would integrate with the MatchingEngine
    print('🔍 Triggering provider search for order: $orderId');
    
    // Import and use the matching engine
    // final matchingEngine = OrderDispatchEngine();
    // await matchingEngine.dispatchRequest(orderId: orderId, ...);
  }

  /// Notify customer of provider acceptance
  Future<void> _notifyCustomerOfAcceptance(String orderId, String service, Map<String, dynamic> orderData) async {
    try {
      final customerId = orderData['customerId'];
      final providerId = orderData['providerId'];
      
      if (customerId == null || providerId == null) return;

      // Create notification for customer
      await _db.collection('notifications').add({
        'userId': customerId,
        'title': '✅ ${_getServiceDisplayName(service)} Request Accepted',
        'body': 'Your provider is on the way!',
        'type': 'order_accepted',
        'orderId': orderId,
        'providerId': providerId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('✅ Notified customer $customerId of acceptance for order $orderId');

    } catch (e) {
      print('❌ Error notifying customer of acceptance: $e');
    }
  }

  /// Process order completion
  Future<void> _processOrderCompletion(String orderId, String service, Map<String, dynamic> orderData) async {
    try {
      final customerId = orderData['customerId'];
      final providerId = orderData['providerId'];
      
      // Update provider availability
      if (providerId != null) {
        await _updateProviderAvailability(providerId, available: true);
      }

      // Create completion notification
      if (customerId != null) {
        await _db.collection('notifications').add({
          'userId': customerId,
          'title': '🎉 ${_getServiceDisplayName(service)} Completed',
          'body': 'Your service has been completed. Please rate your experience.',
          'type': 'order_completed',
          'orderId': orderId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      print('✅ Processed completion for order: $orderId');

    } catch (e) {
      print('❌ Error processing order completion: $e');
    }
  }

  /// Handle order cancellation
  Future<void> _handleOrderCancellation(
    String orderId,
    String service,
    Map<String, dynamic> orderData,
    String fromState,
  ) async {
    try {
      final providerId = orderData['providerId'];
      
      // Free up provider if assigned
      if (providerId != null && ['dispatched', 'accepted', 'in_progress'].contains(fromState)) {
        await _updateProviderAvailability(providerId, available: true);
        
        // Notify provider of cancellation
        await _db.collection('notifications').add({
          'userId': providerId,
          'title': '❌ Order Cancelled',
          'body': 'Customer cancelled the ${_getServiceDisplayName(service)} request.',
          'type': 'order_cancelled',
          'orderId': orderId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      print('✅ Handled cancellation for order: $orderId');

    } catch (e) {
      print('❌ Error handling order cancellation: $e');
    }
  }

  /// Handle order failure
  Future<void> _handleOrderFailure(String orderId, String service, Map<String, dynamic> orderData) async {
    try {
      final customerId = orderData['customerId'];
      
      // Notify customer of failure
      if (customerId != null) {
        await _db.collection('notifications').add({
          'userId': customerId,
          'title': '😞 ${_getServiceDisplayName(service)} Request Failed',
          'body': 'We couldn\'t find available providers in your area. Please try again later.',
          'type': 'order_failed',
          'orderId': orderId,
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      print('✅ Handled failure for order: $orderId');

    } catch (e) {
      print('❌ Error handling order failure: $e');
    }
  }

  /// Update provider availability status
  Future<void> _updateProviderAvailability(String providerId, {required bool available}) async {
    try {
      final snapshot = await _db.collection('provider_profiles')
        .where('userId', '==', providerId)
        .limit(1)
        .get();

      if (!snapshot.empty) {
        await snapshot.docs.first.reference.update({
          'availabilityStatus': available ? 'available' : 'busy',
          'currentOrderId': available ? null : FieldValue.delete(),
          'lastStatusUpdate': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('❌ Error updating provider availability: $e');
    }
  }

  /// Update provider performance metrics
  Future<void> _updateProviderMetrics(String? providerId, String metricType) async {
    if (providerId == null) return;

    try {
      final snapshot = await _db.collection('provider_profiles')
        .where('userId', '==', providerId)
        .limit(1)
        .get();

      if (!snapshot.empty) {
        final doc = snapshot.docs.first;
        final data = doc.data();
        
        Map<String, dynamic> updates = {};
        
        switch (metricType) {
          case 'acceptance':
            final acceptedCount = (data['acceptedOrders'] ?? 0) + 1;
            final totalRequests = data['totalRequests'] ?? 1;
            updates = {
              'acceptedOrders': acceptedCount,
              'acceptanceRate': acceptedCount / totalRequests,
              'lastAcceptedAt': FieldValue.serverTimestamp(),
            };
            break;
            
          case 'completion':
            final completedCount = (data['completedOrders'] ?? 0) + 1;
            final acceptedCount = data['acceptedOrders'] ?? 1;
            updates = {
              'completedOrders': completedCount,
              'completionRate': completedCount / acceptedCount,
              'lastCompletedAt': FieldValue.serverTimestamp(),
            };
            break;
        }

        if (updates.isNotEmpty) {
          await doc.reference.update(updates);
          print('✅ Updated provider metrics: $providerId ($metricType)');
        }
      }
    } catch (e) {
      print('❌ Error updating provider metrics: $e');
    }
  }

  /// Get current order state
  Future<String?> getOrderState(String orderId, String service) async {
    try {
      final collection = _getCollectionForService(service);
      final doc = await _db.collection(collection).doc(orderId).get();
      
      if (doc.exists) {
        final data = doc.data()!;
        return data['internalState'] ?? data['status'];
      }
      
      return null;
    } catch (e) {
      print('❌ Error getting order state: $e');
      return null;
    }
  }

  /// Check if state transition is valid
  bool _isValidTransition(String currentState, String newState) {
    final allowed = allowedTransitions[currentState] ?? [];
    return allowed.contains(newState);
  }

  /// Get service-specific state name
  String _getServiceState(String service, String internalState) {
    final mapping = serviceStateMapping[service] ?? {};
    return mapping[internalState] ?? internalState;
  }

  /// Get collection name for service
  String _getCollectionForService(String service) {
    const mapping = {
      'transport': 'rides',
      'emergency': 'emergency_bookings',
      'moving': 'moving_bookings',
      'hire': 'hire_bookings',
      'personal': 'personal_bookings',
    };
    return mapping[service] ?? 'orders';
  }

  /// Get display name for service
  String _getServiceDisplayName(String service) {
    const mapping = {
      'transport': 'Ride',
      'emergency': 'Emergency Service',
      'moving': 'Moving Service',
      'hire': 'Professional Service',
      'personal': 'Personal Service',
    };
    return mapping[service] ?? 'Service';
  }

  /// Stop monitoring order
  void _stopOrderMonitoring(String orderId) {
    final subscription = _orderListeners[orderId];
    if (subscription != null) {
      subscription.cancel();
      _orderListeners.remove(orderId);
      print('🛑 Stopped monitoring order: $orderId');
    }
  }

  /// Cleanup all resources
  void dispose() {
    for (final subscription in _orderListeners.values) {
      subscription.cancel();
    }
    _orderListeners.clear();
    print('🧹 OrderStateManager disposed');
  }
}

/// Order State Transition Events
abstract class OrderStateEvent {
  final String orderId;
  final String service;
  final DateTime timestamp;

  const OrderStateEvent({
    required this.orderId,
    required this.service,
    required this.timestamp,
  });
}

class OrderCreatedEvent extends OrderStateEvent {
  final String customerId;
  final String serviceClass;
  final Map<String, dynamic> orderData;

  const OrderCreatedEvent({
    required super.orderId,
    required super.service,
    required super.timestamp,
    required this.customerId,
    required this.serviceClass,
    required this.orderData,
  });
}

class OrderDispatchedEvent extends OrderStateEvent {
  final String providerId;
  final int attemptNumber;

  const OrderDispatchedEvent({
    required super.orderId,
    required super.service,
    required super.timestamp,
    required this.providerId,
    required this.attemptNumber,
  });
}

class OrderAcceptedEvent extends OrderStateEvent {
  final String providerId;
  final Duration responseTime;

  const OrderAcceptedEvent({
    required super.orderId,
    required super.service,
    required super.timestamp,
    required this.providerId,
    required this.responseTime,
  });
}

class OrderCompletedEvent extends OrderStateEvent {
  final String providerId;
  final Duration totalDuration;
  final Map<String, dynamic> completionData;

  const OrderCompletedEvent({
    required super.orderId,
    required super.service,
    required super.timestamp,
    required this.providerId,
    required this.totalDuration,
    required this.completionData,
  });
}

class OrderTimeoutEvent extends OrderStateEvent {
  final String providerId;
  final int attemptNumber;

  const OrderTimeoutEvent({
    required super.orderId,
    required super.service,
    required super.timestamp,
    required this.providerId,
    required this.attemptNumber,
  });
}

/// State transition validation rules
class StateTransitionRules {
  static const Map<String, Map<String, bool>> rules = {
    'pending': {
      'searching': true,
      'cancelled': true,
    },
    'searching': {
      'dispatched': true,
      'failed': true,
      'cancelled': true,
    },
    'dispatched': {
      'accepted': true,
      'searching': true, // On timeout/decline
      'cancelled': true,
    },
    'accepted': {
      'in_progress': true,
      'cancelled': true,
    },
    'in_progress': {
      'completed': true,
      'cancelled': true,
    },
    // Terminal states
    'completed': {},
    'cancelled': {},
    'failed': {},
  };

  static bool isValidTransition(String from, String to) {
    return rules[from]?[to] ?? false;
  }

  static List<String> getAllowedTransitions(String currentState) {
    return (rules[currentState] ?? {}).keys.toList();
  }
}

/// Order lifecycle metrics and analytics
class OrderMetrics {
  static Future<Map<String, dynamic>> getOrderAnalytics(String orderId, String service) async {
    try {
      final collection = _getCollectionForService(service);
      final doc = await FirebaseFirestore.instance.collection(collection).doc(orderId).get();
      
      if (!doc.exists) return {};
      
      final data = doc.data()!;
      final stateHistory = List<Map<String, dynamic>>.from(data['stateHistory'] ?? []);
      
      // Calculate metrics
      final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
      final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
      final acceptedAt = (data['acceptedAt'] as Timestamp?)?.toDate();
      final dispatchedAt = (data['dispatchedAt'] as Timestamp?)?.toDate();
      
      Map<String, dynamic> metrics = {
        'orderId': orderId,
        'service': service,
        'totalStateTransitions': stateHistory.length,
        'dispatchAttempts': data['dispatchAttempt'] ?? 0,
      };

      if (createdAt != null) {
        if (dispatchedAt != null) {
          metrics['timeToFirstDispatch'] = dispatchedAt.difference(createdAt).inSeconds;
        }
        if (acceptedAt != null) {
          metrics['timeToAcceptance'] = acceptedAt.difference(createdAt).inSeconds;
        }
        if (completedAt != null) {
          metrics['totalDuration'] = completedAt.difference(createdAt).inSeconds;
        }
      }

      return metrics;
      
    } catch (e) {
      print('❌ Error calculating order metrics: $e');
      return {};
    }
  }

  static String _getCollectionForService(String service) {
    const mapping = {
      'transport': 'rides',
      'emergency': 'emergency_bookings',
      'moving': 'moving_bookings',
      'hire': 'hire_bookings',
      'personal': 'personal_bookings',
    };
    return mapping[service] ?? 'orders';
  }
}