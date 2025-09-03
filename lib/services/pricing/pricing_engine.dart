import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Dynamic Pricing Calculation Engine
/// Handles admin-controlled vs vendor-autonomous pricing with real-time factors
class PricingEngine {
  static final PricingEngine _instance = PricingEngine._internal();
  factory PricingEngine() => _instance;
  PricingEngine._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Calculate final price for any service/item
  /// 
  /// This is the core function that determines pricing authority and calculates
  /// the final price based on admin templates or vendor-set prices
  Future<PricingResult> calculateFinalPrice({
    String? itemId,
    String? vendorId,
    required String serviceId,
    String? serviceClass,
    double distance = 0.0,
    double duration = 0.0, // in minutes
    Map<String, dynamic>? customerLocation,
    Map<String, dynamic>? orderMetadata,
  }) async {
    try {
      print('💰 Calculating price for $serviceId${serviceClass != null ? '/$serviceClass' : ''}');
      
      // Step 1: Determine pricing authority
      final authority = await _determinePricingAuthority(serviceId, vendorId);
      print('📋 Pricing authority: ${authority.source}');

      // Step 2: Calculate base price based on authority
      double basePrice = 0.0;
      Map<String, dynamic> basePricingDetails = {};

      switch (authority.source) {
        case PricingSource.vendorAutonomous:
          if (itemId == null) {
            throw Exception('Item ID required for vendor pricing');
          }
          final vendorPricing = await _calculateVendorPrice(itemId, vendorId!);
          basePrice = vendorPricing.price;
          basePricingDetails = vendorPricing.details;
          break;

        case PricingSource.adminControlled:
          final adminPricing = await _calculateAdminPrice(serviceId, serviceClass, distance, duration);
          basePrice = adminPricing.price;
          basePricingDetails = adminPricing.details;
          break;

        case PricingSource.adminOverride:
          if (itemId == null) {
            throw Exception('Item ID required for override pricing');
          }
          final overridePricing = await _calculateOverridePrice(itemId, vendorId!);
          basePrice = overridePricing.price;
          basePricingDetails = overridePricing.details;
          break;
      }

      print('💵 Base price calculated: ₦$basePrice');

      // Step 3: Apply dynamic factors (if enabled)
      Map<String, double> dynamicFactors = {};
      if (authority.allowsDynamicPricing) {
        dynamicFactors = await _calculateDynamicFactors(
          serviceId: serviceId,
          basePrice: basePrice,
          customerLocation: customerLocation,
          orderMetadata: orderMetadata ?? {},
        );
        
        basePrice = _applyDynamicFactors(basePrice, dynamicFactors);
        print('⚡ Price after dynamic factors: ₦$basePrice');
      }

      // Step 4: Apply platform adjustments
      final platformAdjustments = await _calculatePlatformAdjustments(basePrice, serviceId, vendorId);
      final finalPrice = _applyPlatformAdjustments(basePrice, platformAdjustments);

      // Step 5: Validate constraints
      await _validatePricingConstraints(finalPrice, serviceId, vendorId, authority.constraints);

      // Step 6: Build comprehensive result
      final result = PricingResult(
        success: true,
        finalPrice: finalPrice,
        currency: 'NGN',
        pricingSource: authority.source,
        breakdown: PricingBreakdown(
          basePricing: basePricingDetails,
          dynamicFactors: dynamicFactors,
          platformAdjustments: platformAdjustments,
          finalPrice: finalPrice,
        ),
        calculatedAt: DateTime.now(),
      );

      // Step 7: Log calculation for audit
      await _logPricingCalculation(result, {
        'itemId': itemId,
        'vendorId': vendorId,
        'serviceId': serviceId,
        'serviceClass': serviceClass,
        'distance': distance,
        'duration': duration,
      });

      print('✅ Final price: ₦${finalPrice.toStringAsFixed(2)}');
      return result;

    } catch (e) {
      print('❌ Pricing calculation error: $e');
      
      // Return fallback pricing
      final fallbackPrice = await _getFallbackPrice(serviceId, serviceClass);
      return PricingResult(
        success: false,
        finalPrice: fallbackPrice,
        currency: 'NGN',
        pricingSource: PricingSource.fallback,
        error: e.toString(),
        calculatedAt: DateTime.now(),
      );
    }
  }

  /// Determine who has pricing authority for this service/vendor
  Future<PricingAuthority> _determinePricingAuthority(String serviceId, String? vendorId) async {
    try {
      // Get service configuration
      final serviceDoc = await _db.collection('services').doc(serviceId).get();
      
      if (!serviceDoc.exists) {
        throw Exception('Service not found: $serviceId');
      }

      final serviceData = serviceDoc.data()!;
      final hasPricingAutonomy = serviceData['hasPricingAutonomy'] as bool? ?? false;

      // If service doesn't allow vendor pricing, admin controls everything
      if (!hasPricingAutonomy) {
        return PricingAuthority(
          source: PricingSource.adminControlled,
          allowsDynamicPricing: serviceData['pricingModel']?['surgeEnabled'] as bool? ?? false,
          constraints: Map<String, dynamic>.from(serviceData['adminControls'] ?? {}),
        );
      }

      // Check vendor pricing rights
      if (vendorId != null) {
        final vendorDoc = await _db.collection('vendors').doc(vendorId).get();
        
        if (vendorDoc.exists) {
          final vendorData = vendorDoc.data()!;
          final pricingConfig = Map<String, dynamic>.from(vendorData['pricingConfiguration'] ?? {});
          
          final hasPricingRights = pricingConfig['hasPricingRights'] as bool? ?? false;
          final isPricingEnabled = pricingConfig['isPricingEnabled'] as bool? ?? false;

          if (hasPricingRights && isPricingEnabled) {
            // Check for admin override/suspension
            final adminControls = Map<String, dynamic>.from(pricingConfig['adminControls'] ?? {});
            
            if (adminControls['suspendedBy'] != null) {
              return PricingAuthority(
                source: PricingSource.adminOverride,
                allowsDynamicPricing: false,
                constraints: Map<String, dynamic>.from(adminControls),
                suspensionReason: adminControls['suspensionReason'] as String?,
              );
            }

            return PricingAuthority(
              source: PricingSource.vendorAutonomous,
              allowsDynamicPricing: pricingConfig['canSetSurgePricing'] as bool? ?? false,
              constraints: Map<String, dynamic>.from(pricingConfig['constraints'] ?? {}),
            );
          }
        }
      }

      // Default to admin control
      return PricingAuthority(
        source: PricingSource.adminControlled,
        allowsDynamicPricing: serviceData['pricingModel']?['surgeEnabled'] as bool? ?? false,
        constraints: Map<String, dynamic>.from(serviceData['adminControls'] ?? {}),
      );

    } catch (e) {
      print('❌ Error determining pricing authority: $e');
      return PricingAuthority(
        source: PricingSource.adminControlled,
        allowsDynamicPricing: false,
        constraints: {},
        error: e.toString(),
      );
    }
  }

  /// Calculate vendor-set item price
  Future<BasePricingResult> _calculateVendorPrice(String itemId, String vendorId) async {
    try {
      final itemDoc = await _db.collection('items').doc(itemId).get();
      
      if (!itemDoc.exists) {
        throw Exception('Item not found: $itemId');
      }

      final itemData = itemDoc.data()!;
      
      // Validate vendor ownership
      if (itemData['vendorId'] != vendorId) {
        throw Exception('Vendor does not own this item');
      }

      final pricing = Map<String, dynamic>.from(itemData['pricing'] ?? {});
      final isUsingCustomPrice = pricing['isUsingCustomPrice'] as bool? ?? false;

      if (isUsingCustomPrice) {
        final currentPrice = (pricing['currentPrice'] as num?)?.toDouble() ?? 0.0;
        
        return BasePricingResult(
          price: currentPrice,
          details: {
            'source': 'vendor_custom',
            'itemId': itemId,
            'vendorId': vendorId,
            'lastUpdated': pricing['lastPriceUpdate'],
            'updatedBy': pricing['priceUpdatedBy'],
          },
        );
      } else {
        // Item uses admin template pricing
        final serviceId = itemData['serviceId'] as String;
        final serviceClass = itemData['serviceClass'] as String?;
        
        return await _calculateAdminPrice(serviceId, serviceClass, 0, 0);
      }

    } catch (e) {
      print('❌ Error calculating vendor price: $e');
      rethrow;
    }
  }

  /// Calculate admin-controlled template pricing
  Future<BasePricingResult> _calculateAdminPrice(
    String serviceId,
    String? serviceClass,
    double distance,
    double duration,
  ) async {
    try {
      // Find applicable pricing template
      Query<Map<String, dynamic>> query = _db.collection('pricing_templates')
          .where('serviceId', isEqualTo: serviceId)
          .where('isActive', isEqualTo: true);

      if (serviceClass != null) {
        query = query.where('serviceClass', isEqualTo: serviceClass);
      }

      final templateSnap = await query.limit(1).get();
      
      if (templateSnap.docs.isEmpty) {
        throw Exception('No pricing template found for $serviceId${serviceClass != null ? '/$serviceClass' : ''}');
      }

      final template = templateSnap.docs.first.data();
      final basePricing = Map<String, dynamic>.from(template['basePricing'] ?? {});

      // Calculate price components
      double calculatedPrice = (basePricing['basePrice'] as num?)?.toDouble() ?? 0.0;
      
      final priceBreakdown = <String, double>{
        'basePrice': calculatedPrice,
      };

      // Distance-based pricing
      if (distance > 0) {
        final pricePerKm = (basePricing['pricePerKm'] as num?)?.toDouble() ?? 0.0;
        final distancePrice = distance * pricePerKm;
        calculatedPrice += distancePrice;
        priceBreakdown['distancePrice'] = distancePrice;
      }

      // Time-based pricing
      if (duration > 0) {
        final pricePerMinute = (basePricing['pricePerMinute'] as num?)?.toDouble() ?? 0.0;
        final timePrice = duration * pricePerMinute;
        calculatedPrice += timePrice;
        priceBreakdown['timePrice'] = timePrice;
      }

      // Apply minimum fare
      final minimumFare = (basePricing['minimumFare'] as num?)?.toDouble() ?? 0.0;
      if (calculatedPrice < minimumFare) {
        priceBreakdown['minimumFareAdjustment'] = minimumFare - calculatedPrice;
        calculatedPrice = minimumFare;
      }

      // Apply maximum fare
      final maximumFare = (basePricing['maximumFare'] as num?)?.toDouble();
      if (maximumFare != null && calculatedPrice > maximumFare) {
        priceBreakdown['maximumFareAdjustment'] = maximumFare - calculatedPrice;
        calculatedPrice = maximumFare;
      }

      return BasePricingResult(
        price: calculatedPrice,
        details: {
          'source': 'admin_template',
          'templateId': templateSnap.docs.first.id,
          'serviceId': serviceId,
          'serviceClass': serviceClass,
          'breakdown': priceBreakdown,
          'template': basePricing,
        },
      );

    } catch (e) {
      print('❌ Error calculating admin price: $e');
      rethrow;
    }
  }

  /// Calculate dynamic pricing factors
  Future<Map<String, double>> _calculateDynamicFactors({
    required String serviceId,
    required double basePrice,
    Map<String, dynamic>? customerLocation,
    required Map<String, dynamic> orderMetadata,
  }) async {
    try {
      final factors = <String, double>{
        'surge': 1.0,
        'timeOfDay': 1.0,
        'dayOfWeek': 1.0,
        'weather': 1.0,
        'demand': 1.0,
        'supply': 1.0,
      };

      // Get pricing template for dynamic factors
      final templateSnap = await _db.collection('pricing_templates')
          .where('serviceId', isEqualTo: serviceId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (templateSnap.docs.isEmpty) {
        return factors;
      }

      final template = templateSnap.docs.first.data();
      final dynamicFactors = Map<String, dynamic>.from(template['dynamicFactors'] ?? {});

      // Time-based pricing
      final now = DateTime.now();
      final timeOfDayMultipliers = Map<String, double>.from(dynamicFactors['timeOfDayMultipliers'] ?? {});
      factors['timeOfDay'] = _getTimeOfDayMultiplier(now, timeOfDayMultipliers);

      // Day of week pricing
      final dayOfWeekMultipliers = Map<String, double>.from(dynamicFactors['dayOfWeekMultipliers'] ?? {});
      factors['dayOfWeek'] = _getDayOfWeekMultiplier(now, dayOfWeekMultipliers);

      // Surge pricing (based on current demand)
      if (customerLocation != null) {
        factors['surge'] = await _getCurrentSurgeMultiplier(serviceId, customerLocation);
      }

      // Weather-based pricing
      if (customerLocation != null) {
        factors['weather'] = await _getWeatherMultiplier(customerLocation);
      }

      // Real-time demand/supply analysis
      if (customerLocation != null) {
        final demandSupply = await _analyzeDemandSupply(serviceId, customerLocation);
        factors['demand'] = demandSupply['demand'] ?? 1.0;
        factors['supply'] = demandSupply['supply'] ?? 1.0;
      }

      print('⚡ Dynamic factors: ${factors.toString()}');
      return factors;

    } catch (e) {
      print('❌ Error calculating dynamic factors: $e');
      return {'surge': 1.0, 'timeOfDay': 1.0, 'dayOfWeek': 1.0, 'weather': 1.0, 'demand': 1.0, 'supply': 1.0};
    }
  }

  /// Apply dynamic factors to base price
  double _applyDynamicFactors(double basePrice, Map<String, double> factors) {
    double adjustedPrice = basePrice;
    
    factors.forEach((factor, multiplier) {
      adjustedPrice *= multiplier;
      print('  $factor: ${multiplier.toStringAsFixed(2)}x');
    });
    
    return adjustedPrice;
  }

  /// Calculate platform fees and adjustments
  Future<Map<String, double>> _calculatePlatformAdjustments(
    double basePrice,
    String serviceId,
    String? vendorId,
  ) async {
    try {
      final adjustments = <String, double>{
        'serviceFee': 0.0,
        'platformCommission': 0.0,
        'processingFee': 0.0,
        'tax': 0.0,
      };

      // Get service configuration
      final serviceDoc = await _db.collection('services').doc(serviceId).get();
      if (serviceDoc.exists) {
        final serviceData = serviceDoc.data()!;
        final pricingModel = Map<String, dynamic>.from(serviceData['pricingModel'] ?? {});
        
        // Platform service fee (flat fee)
        adjustments['serviceFee'] = (pricingModel['serviceFee'] as num?)?.toDouble() ?? 0.0;
        
        // Processing fee (percentage of base price)
        final processingFeeRate = (pricingModel['processingFeeRate'] as num?)?.toDouble() ?? 0.0;
        adjustments['processingFee'] = basePrice * processingFeeRate;
      }

      // Vendor-specific commission
      if (vendorId != null) {
        final vendorDoc = await _db.collection('vendors').doc(vendorId).get();
        if (vendorDoc.exists) {
          final vendorData = vendorDoc.data()!;
          final commissionRate = (vendorData['financialInfo']?['platformCommissionRate'] as num?)?.toDouble() ?? 0.15;
          adjustments['platformCommission'] = basePrice * commissionRate;
        }
      }

      // Tax calculation (VAT, etc.)
      adjustments['tax'] = basePrice * 0.075; // 7.5% VAT

      return adjustments;

    } catch (e) {
      print('❌ Error calculating platform adjustments: $e');
      return {'serviceFee': 0.0, 'platformCommission': 0.0, 'processingFee': 0.0, 'tax': 0.0};
    }
  }

  /// Apply platform adjustments to get final customer price
  double _applyPlatformAdjustments(double basePrice, Map<String, double> adjustments) {
    final serviceFee = adjustments['serviceFee'] ?? 0.0;
    final processingFee = adjustments['processingFee'] ?? 0.0;
    final tax = adjustments['tax'] ?? 0.0;
    
    // Note: Platform commission is deducted from vendor, not added to customer price
    return basePrice + serviceFee + processingFee + tax;
  }

  /// Get time-of-day pricing multiplier
  double _getTimeOfDayMultiplier(DateTime now, Map<String, double> multipliers) {
    final hour = now.hour;
    final minute = now.minute;
    final timeString = '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    
    // Find applicable time range
    for (final entry in multipliers.entries) {
      final timeRange = entry.key;
      final multiplier = entry.value;
      
      if (_isTimeInRange(timeString, timeRange)) {
        return multiplier;
      }
    }
    
    return 1.0; // Default multiplier
  }

  /// Get day-of-week pricing multiplier
  double _getDayOfWeekMultiplier(DateTime now, Map<String, double> multipliers) {
    final dayNames = ['sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday'];
    final dayName = dayNames[now.weekday % 7];
    
    return multipliers[dayName] ?? 1.0;
  }

  /// Get current surge multiplier based on demand
  Future<double> _getCurrentSurgeMultiplier(String serviceId, Map<String, dynamic> location) async {
    try {
      // This would integrate with real-time demand analysis
      // For now, return a simple calculation based on active orders
      
      final lat = location['latitude'] as double?;
      final lng = location['longitude'] as double?;
      
      if (lat == null || lng == null) return 1.0;

      // Count active orders in area (5km radius)
      final now = DateTime.now();
      final oneHourAgo = now.subtract(const Duration(hours: 1));

      final activeOrdersSnap = await _db.collection('orders')
          .where('serviceId', isEqualTo: serviceId)
          .where('status', whereIn: ['pending', 'accepted', 'in_progress'])
          .where('createdAt', isGreaterThan: Timestamp.fromDate(oneHourAgo))
          .get();

      // Simple demand calculation (this could be much more sophisticated)
      final orderCount = activeOrdersSnap.docs.length;
      
      if (orderCount > 50) return 2.0; // High surge
      if (orderCount > 30) return 1.5; // Medium surge
      if (orderCount > 15) return 1.2; // Low surge
      
      return 1.0; // No surge

    } catch (e) {
      print('❌ Error calculating surge: $e');
      return 1.0;
    }
  }

  /// Validate pricing constraints
  Future<void> _validatePricingConstraints(
    double finalPrice,
    String serviceId,
    String? vendorId,
    Map<String, dynamic> constraints,
  ) async {
    // Service-level constraints
    final minPrice = (constraints['minimumPrice'] as num?)?.toDouble();
    final maxPrice = (constraints['maximumPrice'] as num?)?.toDouble();

    if (minPrice != null && finalPrice < minPrice) {
      throw Exception('Price below service minimum: ₦$finalPrice < ₦$minPrice');
    }

    if (maxPrice != null && finalPrice > maxPrice) {
      throw Exception('Price above service maximum: ₦$finalPrice > ₦$maxPrice');
    }

    // Vendor-specific constraints
    if (vendorId != null) {
      final vendorMinPrice = (constraints['minimumItemPrice'] as num?)?.toDouble();
      final vendorMaxPrice = (constraints['maximumItemPrice'] as num?)?.toDouble();

      if (vendorMinPrice != null && finalPrice < vendorMinPrice) {
        throw Exception('Price below vendor minimum: ₦$finalPrice < ₦$vendorMinPrice');
      }

      if (vendorMaxPrice != null && finalPrice > vendorMaxPrice) {
        throw Exception('Price above vendor maximum: ₦$finalPrice > ₦$vendorMaxPrice');
      }
    }
  }

  /// Get fallback price for error cases
  Future<double> _getFallbackPrice(String serviceId, String? serviceClass) async {
    try {
      // Use the most basic pricing template
      final fallbackSnap = await _db.collection('pricing_templates')
          .where('serviceId', isEqualTo: serviceId)
          .where('isActive', isEqualTo: true)
          .orderBy('version')
          .limit(1)
          .get();

      if (fallbackSnap.docs.isNotEmpty) {
        final basePricing = fallbackSnap.docs.first.data()['basePricing'] ?? {};
        return (basePricing['minimumFare'] as num?)?.toDouble() ?? 500.0;
      }

      // Ultimate fallback
      return 500.0; // ₦500 minimum

    } catch (e) {
      print('❌ Error getting fallback price: $e');
      return 500.0;
    }
  }

  /// Log pricing calculation for audit
  Future<void> _logPricingCalculation(PricingResult result, Map<String, dynamic> params) async {
    try {
      await _db.collection('pricing_calculations_log').add({
        'calculationId': _generateCalculationId(),
        'params': params,
        'result': {
          'finalPrice': result.finalPrice,
          'pricingSource': result.pricingSource.toString(),
          'success': result.success,
          'error': result.error,
        },
        'breakdown': result.breakdown?.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
        'calculationTime': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('❌ Error logging pricing calculation: $e');
    }
  }

  // Utility methods
  bool _isTimeInRange(String currentTime, String timeRange) {
    try {
      final parts = timeRange.split('-');
      if (parts.length != 2) return false;
      
      final startTime = parts[0];
      final endTime = parts[1];
      
      return currentTime.compareTo(startTime) >= 0 && currentTime.compareTo(endTime) <= 0;
    } catch (e) {
      return false;
    }
  }

  String _generateCalculationId() {
    return 'calc_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}';
  }
}

/// Data classes for pricing results
class PricingResult {
  final bool success;
  final double finalPrice;
  final String currency;
  final PricingSource pricingSource;
  final PricingBreakdown? breakdown;
  final DateTime calculatedAt;
  final String? error;

  const PricingResult({
    required this.success,
    required this.finalPrice,
    required this.currency,
    required this.pricingSource,
    this.breakdown,
    required this.calculatedAt,
    this.error,
  });

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'finalPrice': finalPrice,
      'currency': currency,
      'pricingSource': pricingSource.toString(),
      'breakdown': breakdown?.toMap(),
      'calculatedAt': calculatedAt.toIso8601String(),
      'error': error,
    };
  }
}

class PricingBreakdown {
  final Map<String, dynamic> basePricing;
  final Map<String, double> dynamicFactors;
  final Map<String, double> platformAdjustments;
  final double finalPrice;

  const PricingBreakdown({
    required this.basePricing,
    required this.dynamicFactors,
    required this.platformAdjustments,
    required this.finalPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'basePricing': basePricing,
      'dynamicFactors': dynamicFactors,
      'platformAdjustments': platformAdjustments,
      'finalPrice': finalPrice,
    };
  }
}

class BasePricingResult {
  final double price;
  final Map<String, dynamic> details;

  const BasePricingResult({required this.price, required this.details});
}

class PricingAuthority {
  final PricingSource source;
  final bool allowsDynamicPricing;
  final Map<String, dynamic> constraints;
  final String? suspensionReason;
  final String? error;

  const PricingAuthority({
    required this.source,
    required this.allowsDynamicPricing,
    required this.constraints,
    this.suspensionReason,
    this.error,
  });
}

enum PricingSource {
  adminControlled,    // Admin sets all prices via templates
  vendorAutonomous,   // Vendor has full pricing control
  adminOverride,      // Admin has overridden vendor pricing
  fallback,           // Error fallback pricing
}

/// Pricing validation service
class PricingValidationService {
  
  /// Validate price change against business rules
  static Future<ValidationResult> validatePriceChange({
    required String vendorId,
    required String itemId,
    required double oldPrice,
    required double newPrice,
    required Map<String, dynamic> constraints,
  }) async {
    try {
      final validationErrors = <String>[];

      // Calculate change metrics
      final changeAmount = newPrice - oldPrice;
      final changePercentage = oldPrice > 0 ? (changeAmount / oldPrice) * 100 : 0;

      // Check price increase limits
      final maxIncreasePerDay = (constraints['maxPriceIncreasePerDay'] as num?)?.toDouble() ?? 0.20;
      if (changePercentage > (maxIncreasePerDay * 100)) {
        validationErrors.add('Price increase exceeds daily limit (${(maxIncreasePerDay * 100).toStringAsFixed(0)}%)');
      }

      // Check price decrease limits
      final maxDecreasePerDay = (constraints['maxPriceDecreasePerDay'] as num?)?.toDouble() ?? 0.50;
      if (changePercentage < -(maxDecreasePerDay * 100)) {
        validationErrors.add('Price decrease exceeds daily limit (${(maxDecreasePerDay * 100).toStringAsFixed(0)}%)');
      }

      // Check absolute price limits
      final minItemPrice = (constraints['minimumItemPrice'] as num?)?.toDouble() ?? 0;
      final maxItemPrice = (constraints['maximumItemPrice'] as num?)?.toDouble() ?? double.infinity;

      if (newPrice < minItemPrice) {
        validationErrors.add('Price below minimum allowed (₦$minItemPrice)');
      }

      if (newPrice > maxItemPrice) {
        validationErrors.add('Price above maximum allowed (₦$maxItemPrice)');
      }

      // Check cooldown period
      final cooldownViolation = await _checkCooldownPeriod(itemId, constraints);
      if (cooldownViolation != null) {
        validationErrors.add(cooldownViolation);
      }

      // Check for suspicious pricing patterns
      final suspiciousPattern = await _detectSuspiciousPricing(vendorId, itemId, oldPrice, newPrice);
      if (suspiciousPattern != null) {
        validationErrors.add('Suspicious pricing pattern detected: $suspiciousPattern');
      }

      return ValidationResult(
        isValid: validationErrors.isEmpty,
        errors: validationErrors,
        warnings: await _generatePricingWarnings(changePercentage, newPrice, constraints),
        requiresApproval: await _checkApprovalRequirement(changeAmount, changePercentage, constraints),
      );

    } catch (e) {
      return ValidationResult(
        isValid: false,
        errors: ['Validation error: $e'],
        warnings: [],
        requiresApproval: true,
      );
    }
  }

  /// Check if price change requires admin approval
  static Future<bool> _checkApprovalRequirement(
    double changeAmount,
    double changePercentage,
    Map<String, dynamic> constraints,
  ) async {
    final autoApprovalThresholds = Map<String, dynamic>.from(constraints['autoApprovalThresholds'] ?? {});
    
    final maxAutoApprovalIncrease = (autoApprovalThresholds['priceIncrease'] as num?)?.toDouble() ?? 0.10;
    final maxAutoApprovalDecrease = (autoApprovalThresholds['priceDecrease'] as num?)?.toDouble() ?? 0.30;
    final maxAutoApprovalAmount = (autoApprovalThresholds['absoluteAmount'] as num?)?.toDouble() ?? 1000;

    // Require approval for large changes
    if (changePercentage > (maxAutoApprovalIncrease * 100) || 
        changePercentage < -(maxAutoApprovalDecrease * 100) ||
        changeAmount.abs() > maxAutoApprovalAmount) {
      return true;
    }

    return false;
  }

  /// Detect suspicious pricing patterns
  static Future<String?> _detectSuspiciousPricing(
    String vendorId,
    String itemId,
    double oldPrice,
    double newPrice,
  ) async {
    try {
      // Check recent price changes for this item
      final recentChanges = await FirebaseFirestore.instance
          .collection('pricing_audit_log')
          .where('entityId', isEqualTo: itemId)
          .where('changeType', isEqualTo: 'vendor_price_update')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(const Duration(days: 1))))
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      // Pattern 1: Rapid price changes (more than 5 in 24 hours)
      if (recentChanges.docs.length >= 5) {
        return 'Too many price changes in 24 hours';
      }

      // Pattern 2: Extreme price swings
      if (recentChanges.docs.isNotEmpty) {
        final prices = recentChanges.docs.map((doc) => 
          (doc.data()['changeDetails']['newValue'] as num).toDouble()
        ).toList();
        
        prices.add(newPrice);
        
        final minPrice = prices.reduce(math.min);
        final maxPrice = prices.reduce(math.max);
        
        if ((maxPrice - minPrice) / minPrice > 1.0) { // 100% price swing
          return 'Extreme price volatility detected';
        }
      }

      // Pattern 3: Price significantly different from market average
      final marketAverage = await _getMarketAveragePrice(vendorId, itemId);
      if (marketAverage != null) {
        final deviation = (newPrice - marketAverage) / marketAverage;
        if (deviation > 2.0) { // 200% above market average
          return 'Price significantly above market average';
        }
        if (deviation < -0.7) { // 70% below market average
          return 'Price significantly below market average (possible predatory pricing)';
        }
      }

      return null; // No suspicious patterns detected

    } catch (e) {
      print('❌ Error detecting suspicious pricing: $e');
      return null;
    }
  }
}

class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final bool requiresApproval;

  const ValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    required this.requiresApproval,
  });
}