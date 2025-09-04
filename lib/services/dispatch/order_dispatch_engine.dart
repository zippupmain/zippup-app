import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Core order dispatch and matching engine for real-time service requests
/// 
/// This engine handles intelligent matching of customer requests with nearby providers
/// based on service type, class, availability, and proximity with robust timeout handling.
class OrderDispatchEngine {
  static final OrderDispatchEngine _instance = OrderDispatchEngine._internal();
  factory OrderDispatchEngine() => _instance;
  OrderDispatchEngine._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Map<String, Timer> _timeoutTimers = {};
  final Map<String, List<String>> _attemptedProviders = {};
  final Map<String, int> _dispatchAttempts = {};

  // Configuration constants
  static const int REQUEST_TIMEOUT_SECONDS = 60;
  static const double DEFAULT_SEARCH_RADIUS_KM = 5.0;
  static const int MAX_DISPATCH_ATTEMPTS = 5;
  static const int MAX_PROVIDERS_PER_ATTEMPT = 10;

  /// Core matching algorithm - finds eligible providers for a service request
  /// 
  /// Algorithm:
  /// 1. Query providers by service and online status
  /// 2. Filter by class availability and geographic proximity
  /// 3. Exclude providers who already declined/timed out
  /// 4. Sort by distance and provider rating
  /// 5. Return top candidates for dispatch
  Future<List<EligibleProvider>> findEligibleProviders({
    required String service,
    required String serviceClass,
    required double customerLat,
    required double customerLng,
    String? orderId,
    double radiusKm = DEFAULT_SEARCH_RADIUS_KM,
  }) async {
    try {
      print('🔍 Finding eligible providers for: $service/$serviceClass');
      print('📍 Customer location: ($customerLat, $customerLng)');
      print('📏 Search radius: ${radiusKm}km');

      // Step 1: Query base provider pool
      final baseQuery = _db.collection('provider_profiles')
          .where('service', isEqualTo: service)
          .where('status', isEqualTo: 'active')
          .where('availabilityOnline', isEqualTo: true)
          .where('availabilityStatus', whereIn: ['available', 'idle'])
          .limit(50);

      final providersSnap = await baseQuery.get();
      print('📊 Found ${providersSnap.docs.length} base providers for $service');

      if (providersSnap.docs.isEmpty) {
        print('❌ No active online providers found for service: $service');
        return [];
      }

      // Step 2: Filter and score providers
      final List<EligibleProvider> eligibleProviders = [];
      final attemptedList = orderId != null ? (_attemptedProviders[orderId] ?? []) : <String>[];

      for (final doc in providersSnap.docs) {
        final data = doc.data();
        final providerId = data['userId']?.toString();
        
        if (providerId == null || attemptedList.contains(providerId)) {
          continue; // Skip invalid or already attempted providers
        }

        // Step 2a: Service class matching
        if (!_isClassSupported(data, serviceClass)) {
          print('❌ Provider $providerId does not support class: $serviceClass');
          continue;
        }

        // Step 2b: Geographic proximity check
        final providerLat = (data['currentLocation']?['latitude'] as num?)?.toDouble();
        final providerLng = (data['currentLocation']?['longitude'] as num?)?.toDouble();
        
        if (providerLat == null || providerLng == null) {
          print('❌ Provider $providerId has no location data');
          continue;
        }

        final distance = _calculateDistance(customerLat, customerLng, providerLat, providerLng);
        if (distance > radiusKm) {
          print('❌ Provider $providerId too far: ${distance.toStringAsFixed(2)}km');
          continue;
        }

        // Step 2c: Additional service-specific filtering
        if (!_passesServiceSpecificFilters(service, serviceClass, data)) {
          continue;
        }

        // Step 3: Calculate provider score
        final score = _calculateProviderScore(
          distance: distance,
          rating: (data['rating'] as num?)?.toDouble() ?? 4.0,
          completedOrders: (data['completedOrders'] as num?)?.toInt() ?? 0,
          responseTime: (data['avgResponseTime'] as num?)?.toDouble() ?? 30.0,
        );

        eligibleProviders.add(EligibleProvider(
          id: providerId,
          profileId: doc.id,
          distance: distance,
          rating: (data['rating'] as num?)?.toDouble() ?? 4.0,
          score: score,
          location: ProviderLocation(lat: providerLat, lng: providerLng),
          metadata: data,
        ));

        print('✅ Eligible provider: $providerId (${distance.toStringAsFixed(2)}km, score: ${score.toStringAsFixed(2)})');
      }

      // Step 4: Sort by score (higher is better)
      eligibleProviders.sort((a, b) => b.score.compareTo(a.score));

      print('🎯 Found ${eligibleProviders.length} eligible providers');
      return eligibleProviders.take(MAX_PROVIDERS_PER_ATTEMPT).toList();

    } catch (e) {
      print('❌ Error in findEligibleProviders: $e');
      return [];
    }
  }

  /// Main dispatch function - orchestrates the entire matching and timeout process
  /// 
  /// Flow:
  /// 1. Find eligible providers
  /// 2. Select best provider
  /// 3. Update order with provider assignment
  /// 4. Start timeout timer
  /// 5. Handle timeout/acceptance
  Future<bool> dispatchRequest({
    required String orderId,
    required String service,
    required String serviceClass,
    required double customerLat,
    required double customerLng,
    String? customerId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      print('🚀 Dispatching order: $orderId');
      
      // Initialize tracking
      _dispatchAttempts[orderId] = (_dispatchAttempts[orderId] ?? 0) + 1;
      final attemptNumber = _dispatchAttempts[orderId]!;
      
      if (attemptNumber > MAX_DISPATCH_ATTEMPTS) {
        print('❌ Max dispatch attempts reached for order: $orderId');
        await _updateOrderStatus(orderId, 'failed', 'No providers available after $MAX_DISPATCH_ATTEMPTS attempts');
        return false;
      }

      print('📈 Dispatch attempt $attemptNumber/$MAX_DISPATCH_ATTEMPTS for order: $orderId');

      // Find eligible providers
      final providers = await findEligibleProviders(
        service: service,
        serviceClass: serviceClass,
        customerLat: customerLat,
        customerLng: customerLng,
        orderId: orderId,
      );

      if (providers.isEmpty) {
        print('❌ No eligible providers found for order: $orderId');
        
        if (attemptNumber >= MAX_DISPATCH_ATTEMPTS) {
          await _updateOrderStatus(orderId, 'failed', 'No providers available in area');
          return false;
        } else {
          // Retry with expanded radius after delay
          Timer(const Duration(seconds: 10), () {
            dispatchRequest(
              orderId: orderId,
              service: service,
              serviceClass: serviceClass,
              customerLat: customerLat,
              customerLng: customerLng,
              customerId: customerId,
              additionalData: additionalData,
            );
          });
          return false;
        }
      }

      // Select best provider (highest score)
      final selectedProvider = providers.first;
      print('🎯 Selected provider: ${selectedProvider.id} (score: ${selectedProvider.score.toStringAsFixed(2)})');

      // Update order with provider assignment
      await _assignProviderToOrder(orderId, selectedProvider, service, additionalData);

      // Track attempted provider
      _attemptedProviders.putIfAbsent(orderId, () => []).add(selectedProvider.id);

      // Start timeout timer
      _startTimeoutTimer(orderId, service, serviceClass, customerLat, customerLng, customerId, additionalData);

      return true;

    } catch (e) {
      print('❌ Error in dispatchRequest: $e');
      return false;
    }
  }

  /// Timeout handling - re-dispatches to next available provider
  void _startTimeoutTimer(
    String orderId,
    String service,
    String serviceClass,
    double customerLat,
    double customerLng,
    String? customerId,
    Map<String, dynamic>? additionalData,
  ) {
    // Cancel existing timer
    _timeoutTimers[orderId]?.cancel();

    _timeoutTimers[orderId] = Timer(const Duration(seconds: REQUEST_TIMEOUT_SECONDS), () async {
      print('⏰ Timeout reached for order: $orderId');
      
      try {
        // Check if order was accepted in the meantime
        final orderDoc = await _db.collection(_getCollectionForService(service)).doc(orderId).get();
        final orderData = orderDoc.data();
        
        if (orderData != null && orderData['status'] == 'accepted') {
          print('✅ Order $orderId was accepted, canceling timeout');
          _cleanupOrder(orderId);
          return;
        }

        // Update order status to show timeout
        await _updateOrderStatus(orderId, 'searching', 'Provider did not respond, finding another...');

        // Re-dispatch to next provider
        final success = await dispatchRequest(
          orderId: orderId,
          service: service,
          serviceClass: serviceClass,
          customerLat: customerLat,
          customerLng: customerLng,
          customerId: customerId,
          additionalData: additionalData,
        );

        if (!success) {
          print('❌ Failed to re-dispatch order: $orderId');
        }

      } catch (e) {
        print('❌ Error in timeout handler: $e');
      }
    });

    print('⏱️ Started ${REQUEST_TIMEOUT_SECONDS}s timeout timer for order: $orderId');
  }

  /// Service class support validation
  bool _isClassSupported(Map<String, dynamic> providerData, String requestedClass) {
    final enabledClasses = providerData['enabledClasses'] as Map<String, dynamic>? ?? {};
    final serviceClasses = providerData['serviceClasses'] as List<dynamic>? ?? [];
    final subcategory = providerData['subcategory']?.toString();

    // Check explicit class enablement
    if (enabledClasses.containsKey(requestedClass)) {
      return enabledClasses[requestedClass] == true;
    }

    // Check service classes array
    if (serviceClasses.contains(requestedClass)) {
      return true;
    }

    // Fallback: basic subcategory matching for backward compatibility
    return _isClassCompatibleWithSubcategory(requestedClass, subcategory);
  }

  /// Service-specific filtering logic
  bool _passesServiceSpecificFilters(String service, String serviceClass, Map<String, dynamic> providerData) {
    		switch (service) {
			case 'transport':
				return _validateTransportProvider(serviceClass, providerData);
			case 'emergency':
				return _validateEmergencyProvider(serviceClass, providerData);
			case 'hire':
				return _validateHireProvider(serviceClass, providerData);
			case 'moving':
				return _validateMovingProvider(serviceClass, providerData);
			case 'delivery':
				return _validateDeliveryProvider(serviceClass, providerData);
			default:
				return true; // Allow other services
		}
  }

  /// Transport-specific validation
  bool _validateTransportProvider(String requestedClass, Map<String, dynamic> data) {
    final subcategory = data['subcategory']?.toString();
    final vehicleCapacity = (data['vehicleCapacity'] as num?)?.toInt() ?? 1;
    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};

    // Class-subcategory mapping
    final classSubcategoryMap = {
      'tricycle': 'Tricycle',
      'compact': 'Taxi',
      'standard': 'Taxi', 
      'suv': 'Taxi',
      'bike_economy': 'Bike',
      'bike_luxury': 'Bike',
      'bus_charter': 'Bus',
      'bus_mini': 'Bus',
      'bus_standard': 'Bus',
      'bus_large': 'Bus',
    };

    final requiredSubcategory = classSubcategoryMap[requestedClass];
    if (requiredSubcategory != null && subcategory != requiredSubcategory) {
      print('❌ Transport subcategory mismatch: required $requiredSubcategory, provider has $subcategory');
      return false;
    }

    // Capacity validation for bus services
    if (requestedClass.startsWith('bus_')) {
      final requiredCapacity = _getBusCapacityRequirement(requestedClass);
      if (vehicleCapacity < requiredCapacity) {
        print('❌ Insufficient vehicle capacity: required $requiredCapacity, provider has $vehicleCapacity');
        return false;
      }
    }

    return true;
  }

  	/// Emergency service validation - strict matching required
	bool _validateEmergencyProvider(String requestedClass, Map<String, dynamic> data) {
		final enabledClasses = data['enabledClasses'] as Map<String, dynamic>? ?? {};
		
		// Emergency services must have explicit class enablement
		if (!enabledClasses.containsKey(requestedClass) || enabledClasses[requestedClass] != true) {
			print('❌ Emergency provider does not explicitly support: $requestedClass');
			return false;
		}

		// Additional emergency-specific validations
		switch (requestedClass) {
			case 'ambulance':
				return _validateAmbulanceProvider(data);
			case 'fire_services':
				return _validateFireServiceProvider(data);
			case 'security_services':
				return _validateSecurityProvider(data);
			case 'towing_van':
				return _validateTowingVanProvider(data);
			// Roadside assistance sub-classes
			case 'roadside_tyre_fix':
			case 'roadside_battery':
			case 'roadside_fuel':
			case 'roadside_mechanic':
			case 'roadside_lockout':
			case 'roadside_jumpstart':
				return _validateRoadsideProvider(requestedClass, data);
			default:
				return true;
		}
	}

  /// Hire service validation
  bool _validateHireProvider(String requestedClass, Map<String, dynamic> data) {
    final enabledClasses = data['enabledClasses'] as Map<String, dynamic>? ?? {};
    final skills = data['skills'] as List<dynamic>? ?? [];

    // Check explicit class enablement
    if (enabledClasses.containsKey(requestedClass) && enabledClasses[requestedClass] == true) {
      return true;
    }

    // Check skills array for backward compatibility
    if (skills.contains(requestedClass)) {
      return true;
    }

    print('❌ Hire provider does not support skill/class: $requestedClass');
    return false;
  }

  /// Moving service validation
  bool _validateMovingProvider(String requestedClass, Map<String, dynamic> data) {
    final enabledClasses = data['enabledClasses'] as Map<String, dynamic>? ?? {};
    final vehicleType = data['vehicleType']?.toString();
    final subcategory = data['subcategory']?.toString();

    // Check explicit class enablement
    if (enabledClasses.containsKey(requestedClass) && enabledClasses[requestedClass] == true) {
      return true;
    }

    // Validate vehicle type compatibility
    final vehicleClassMap = {
      'truck_small': ['truck', 'pickup'],
      'truck_medium': ['truck'],
      'truck_large': ['truck'],
      'pickup_small': ['pickup'],
      'pickup_large': ['pickup'],
      'courier_bike': ['bike', 'motorcycle'],
      'courier_intracity': ['bike', 'motorcycle', 'car'],
      'courier_intrastate': ['car', 'van'],
      'courier_nationwide': ['van', 'truck'],
    };

    final compatibleVehicles = vehicleClassMap[requestedClass] ?? [];
    if (compatibleVehicles.isNotEmpty && !compatibleVehicles.contains(vehicleType?.toLowerCase())) {
      print('❌ Moving vehicle type mismatch: required ${compatibleVehicles.join('/')}, provider has $vehicleType');
      return false;
    }

    return true;
  }

  /// Calculate provider matching score
  double _calculateProviderScore({
    required double distance,
    required double rating,
    required int completedOrders,
    required double responseTime,
  }) {
    // Scoring algorithm (higher is better)
    final distanceScore = math.max(0, 100 - (distance * 10)); // Closer = higher score
    final ratingScore = (rating / 5.0) * 100; // 5-star rating = 100 points
    final experienceScore = math.min(50, completedOrders * 0.5); // Max 50 points for experience
    final speedScore = math.max(0, 50 - responseTime); // Faster response = higher score

    final totalScore = (distanceScore * 0.4) + (ratingScore * 0.3) + (experienceScore * 0.2) + (speedScore * 0.1);
    
    return totalScore;
  }

  /// Assign provider to order and update database
  Future<void> _assignProviderToOrder(
    String orderId,
    EligibleProvider provider,
    String service,
    Map<String, dynamic>? additionalData,
  ) async {
    final collection = _getCollectionForService(service);
    final updateData = {
      'providerId': provider.id,
      'status': 'dispatched',
      'dispatchedAt': FieldValue.serverTimestamp(),
      'dispatchAttempt': _dispatchAttempts[orderId] ?? 1,
      'estimatedDistance': provider.distance,
      'estimatedArrival': DateTime.now().add(Duration(minutes: (provider.distance * 2).ceil())).toIso8601String(),
      ...?additionalData,
    };

    await _db.collection(collection).doc(orderId).update(updateData);
    
    // Update provider status
    await _db.collection('provider_profiles').doc(provider.profileId).update({
      'availabilityStatus': 'assigned',
      'currentOrderId': orderId,
      'lastAssignedAt': FieldValue.serverTimestamp(),
    });

    print('✅ Assigned provider ${provider.id} to order $orderId');
  }

  /// Update order status with message
  Future<void> _updateOrderStatus(String orderId, String status, [String? message]) async {
    // Determine collection based on order ID pattern or use generic orders collection
    final collections = ['rides', 'orders', 'emergency_bookings', 'moving_bookings', 'hire_bookings'];
    
    for (final collection in collections) {
      try {
        final doc = await _db.collection(collection).doc(orderId).get();
        if (doc.exists) {
          await doc.reference.update({
            'status': status,
            'statusMessage': message,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          print('✅ Updated $collection/$orderId status to: $status');
          return;
        }
      } catch (e) {
        // Continue to next collection
      }
    }
    
    print('❌ Could not find order $orderId in any collection');
  }

  /// Handle provider acceptance
  Future<void> handleProviderAcceptance(String orderId, String providerId) async {
    print('✅ Provider $providerId accepted order: $orderId');
    
    // Cancel timeout timer
    _timeoutTimers[orderId]?.cancel();
    _timeoutTimers.remove(orderId);
    
    // Update order status
    await _updateOrderStatus(orderId, 'accepted');
    
    // Clean up tracking
    _cleanupOrder(orderId);
  }

  /// Handle provider decline/timeout
  Future<void> handleProviderDecline(String orderId, String providerId, {bool isTimeout = false}) async {
    print('❌ Provider $providerId ${isTimeout ? 'timed out' : 'declined'} order: $orderId');
    
    // Add to attempted providers list
    _attemptedProviders.putIfAbsent(orderId, () => []).add(providerId);
    
    // Reset provider availability
    try {
      final providerQuery = await _db.collection('provider_profiles')
          .where('userId', isEqualTo: providerId)
          .limit(1)
          .get();
      
      if (providerQuery.docs.isNotEmpty) {
        await providerQuery.docs.first.reference.update({
          'availabilityStatus': 'available',
          'currentOrderId': null,
        });
      }
    } catch (e) {
      print('❌ Error resetting provider availability: $e');
    }
  }

  /// Clean up order tracking data
  void _cleanupOrder(String orderId) {
    _timeoutTimers[orderId]?.cancel();
    _timeoutTimers.remove(orderId);
    _attemptedProviders.remove(orderId);
    _dispatchAttempts.remove(orderId);
    print('🧹 Cleaned up tracking data for order: $orderId');
  }

  /// Utility methods
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000; // Convert to km
  }

  bool _isClassCompatibleWithSubcategory(String requestedClass, String? subcategory) {
    final compatibilityMap = {
      'Taxi': ['compact', 'standard', 'suv'],
      'Bike': ['bike_economy', 'bike_luxury'],
      'Bus': ['bus_charter', 'bus_mini', 'bus_standard', 'bus_large'],
      'Tricycle': ['tricycle'],
    };

    final compatibleClasses = compatibilityMap[subcategory] ?? [];
    return compatibleClasses.contains(requestedClass);
  }

  int _getBusCapacityRequirement(String busClass) {
    switch (busClass) {
      case 'bus_mini': return 8;
      case 'bus_standard': return 14;
      case 'bus_large': return 20;
      case 'bus_charter': return 30;
      default: return 4;
    }
  }

  String _getCollectionForService(String service) {
    switch (service) {
      case 'transport': return 'rides';
      case 'emergency': return 'emergency_bookings';
      case 'moving': return 'moving_bookings';
      case 'hire': return 'hire_bookings';
      case 'personal': return 'personal_bookings';
      default: return 'orders';
    }
  }

  // Emergency-specific validations
  bool _validateAmbulanceProvider(Map<String, dynamic> data) {
    final certifications = data['certifications'] as List<dynamic>? ?? [];
    final equipment = data['equipment'] as List<dynamic>? ?? [];
    
    return certifications.contains('medical_transport') && 
           equipment.contains('medical_equipment');
  }

  bool _validateFireServiceProvider(Map<String, dynamic> data) {
    final certifications = data['certifications'] as List<dynamic>? ?? [];
    return certifications.contains('fire_safety') || certifications.contains('emergency_response');
  }

  	bool _validateSecurityProvider(Map<String, dynamic> data) {
		final certifications = data['certifications'] as List<dynamic>? ?? [];
		return certifications.contains('security_license') || certifications.contains('law_enforcement');
	}

	bool _validateTowingVanProvider(Map<String, dynamic> data) {
		final certifications = data['certifications'] as List<dynamic>? ?? [];
		final equipment = data['equipment'] as List<dynamic>? ?? [];
		
		final hasLicense = certifications.contains('towing_license') || certifications.contains('commercial_driving_license');
		final hasEquipment = equipment.contains('towing_equipment') || equipment.contains('winch') || equipment.contains('tow_truck');
		
		return hasLicense && hasEquipment;
	}

	bool _validateRoadsideProvider(String requestedClass, Map<String, dynamic> data) {
		final enabledClasses = data['enabledClasses'] as Map<String, dynamic>? ?? {};
		final skills = data['skills'] as List<dynamic>? ?? [];
		final equipment = data['equipment'] as List<dynamic>? ?? [];
		
		// Check explicit enablement first
		if (enabledClasses[requestedClass] == true) {
			return true;
		}
		
		// Check skill-specific requirements
		switch (requestedClass) {
			case 'roadside_tyre_fix':
				return skills.contains('tyre_repair') || equipment.contains('tyre_tools');
			case 'roadside_battery':
				return skills.contains('battery_replacement') || equipment.contains('battery_tools');
			case 'roadside_fuel':
				return skills.contains('fuel_delivery') || equipment.contains('fuel_container');
			case 'roadside_mechanic':
				return skills.contains('automotive_repair') || skills.contains('mechanic');
			case 'roadside_lockout':
				return skills.contains('locksmith') || equipment.contains('lockout_tools');
			case 'roadside_jumpstart':
				return skills.contains('battery_jumpstart') || equipment.contains('jumper_cables');
			default:
				return false;
				}
	}

	/// Delivery service validation
	bool _validateDeliveryProvider(String requestedClass, Map<String, dynamic> data) {
		final enabledClasses = data['enabledClasses'] as Map<String, dynamic>? ?? {};
		final subcategory = data['subcategory']?.toString();
		final vehicleType = data['vehicleInfo']?['vehicleType']?.toString()?.toLowerCase();

		// Check explicit class enablement
		if (enabledClasses[requestedClass] == true) {
			return true;
		}

		// Vehicle type compatibility for delivery services
		final vehicleCompatibility = {
			'food_delivery': ['motorcycle', 'bicycle', 'car', 'scooter'],
			'package_delivery': ['motorcycle', 'car', 'van', 'bicycle'],
			'document_delivery': ['motorcycle', 'bicycle', 'car', 'scooter'],
			'express_delivery': ['motorcycle', 'car', 'scooter'],
			'bulk_delivery': ['van', 'small truck', 'car'],
		};

		final compatibleVehicles = vehicleCompatibility[requestedClass.toLowerCase()] ?? [];
		if (compatibleVehicles.isNotEmpty && vehicleType != null) {
			return compatibleVehicles.contains(vehicleType);
		}

		// Subcategory fallback matching
		final subcategoryCompatibility = {
			'Food Delivery': ['restaurant_delivery', 'fast_food', 'fine_dining', 'grocery_delivery'],
			'Package Delivery': ['same_day', 'next_day', 'express', 'standard'],
			'Document Delivery': ['legal_documents', 'business_documents', 'urgent_courier'],
			'Express Delivery': ['1_hour_express', '2_hour_express', 'same_day_express'],
			'Bulk Delivery': ['wholesale_delivery', 'b2b_logistics', 'multi_drop'],
		};

		final compatibleClasses = subcategoryCompatibility[subcategory] ?? [];
		return compatibleClasses.contains(requestedClass.toLowerCase());
	}

	/// Dispose method for cleanup
  void dispose() {
    for (final timer in _timeoutTimers.values) {
      timer.cancel();
    }
    _timeoutTimers.clear();
    _attemptedProviders.clear();
    _dispatchAttempts.clear();
  }
}

/// Data classes for matching results
class EligibleProvider {
  final String id;
  final String profileId;
  final double distance;
  final double rating;
  final double score;
  final ProviderLocation location;
  final Map<String, dynamic> metadata;

  const EligibleProvider({
    required this.id,
    required this.profileId,
    required this.distance,
    required this.rating,
    required this.score,
    required this.location,
    required this.metadata,
  });
}

class ProviderLocation {
  final double lat;
  final double lng;

  const ProviderLocation({required this.lat, required this.lng});
}

/// Order state management
enum OrderState {
  pending,        // Initial state
  searching,      // Looking for providers
  dispatched,     // Sent to a provider
  accepted,       // Provider accepted
  in_progress,    // Service in progress
  completed,      // Service completed
  cancelled,      // Cancelled by customer
  failed,         // No providers available
  timed_out,      // All providers timed out
}

/// Order dispatch request model
class DispatchRequest {
  final String orderId;
  final String customerId;
  final String service;
  final String serviceClass;
  final double customerLat;
  final double customerLng;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const DispatchRequest({
    required this.orderId,
    required this.customerId,
    required this.service,
    required this.serviceClass,
    required this.customerLat,
    required this.customerLng,
    required this.metadata,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'customerId': customerId,
    'service': service,
    'serviceClass': serviceClass,
    'customerLocation': {'latitude': customerLat, 'longitude': customerLng},
    'metadata': metadata,
    'createdAt': createdAt.toIso8601String(),
  };
}