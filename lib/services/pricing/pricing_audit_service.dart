import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Comprehensive pricing audit and monitoring service
/// Tracks all pricing changes, detects violations, and provides transparency
class PricingAuditService {
  static final PricingAuditService _instance = PricingAuditService._internal();
  factory PricingAuditService() => _instance;
  PricingAuditService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Log pricing change event
  Future<void> logPricingChange({
    required String changeType,
    required String entityType,
    required String entityId,
    required Map<String, dynamic> changeDetails,
    required String reason,
    Map<String, dynamic>? additionalContext,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Determine user role
      final userRole = await _getUserRole(currentUser.uid);
      final vendorId = userRole == 'vendor' ? await _getVendorIdForUser(currentUser.uid) : null;

      // Create comprehensive audit entry
      final auditEntry = {
        // Change identification
        'changeType': changeType,
        'entityType': entityType,
        'entityId': entityId,
        'auditId': _generateAuditId(),
        
        // Change details
        'changeDetails': changeDetails,
        'changeContext': {
          'reason': reason,
          'category': _categorizeChange(changeType, changeDetails),
          'impactLevel': _calculateImpactLevel(changeDetails),
          'marketCondition': await _getCurrentMarketCondition(),
          ...?additionalContext,
        },
        
        // Actor information
        'actor': {
          'userId': currentUser.uid,
          'role': userRole,
          'name': await _getUserName(currentUser.uid),
          'email': currentUser.email,
          'vendorId': vendorId,
          'ipAddress': await _getClientIP(),
          'userAgent': await _getUserAgent(),
          'sessionId': await _getSessionId(),
        },
        
        // System context
        'systemContext': {
          'platform': defaultTargetPlatform.toString(),
          'appVersion': await _getAppVersion(),
          'timestamp': FieldValue.serverTimestamp(),
          'timezone': DateTime.now().timeZoneName,
          'processingTime': 0, // Will be updated after processing
        },
        
        // Impact analysis
        'impactAnalysis': await _calculateImpactAnalysis(
          changeType, entityType, entityId, changeDetails
        ),
        
        // Compliance tracking
        'compliance': {
          'policyCompliance': await _checkPolicyCompliance(changeType, changeDetails),
          'regulatoryCompliance': await _checkRegulatoryCompliance(changeDetails),
          'requiresReview': _requiresAdminReview(changeType, changeDetails),
          'riskLevel': _assessRiskLevel(changeType, changeDetails),
        },
      };

      // Store audit entry
      await _db.collection('pricing_audit_log').add(auditEntry);
      
      // Trigger real-time monitoring
      await _triggerRealTimeMonitoring(auditEntry);
      
      print('✅ Pricing change logged: ${auditEntry['auditId']}');

    } catch (e) {
      print('❌ Error logging pricing change: $e');
      // Don't throw - audit logging should not break the main flow
    }
  }

  /// Get comprehensive audit trail for entity
  Future<List<Map<String, dynamic>>> getAuditTrail({
    required String entityType,
    required String entityId,
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db.collection('pricing_audit_log')
          .where('entityType', isEqualTo: entityType)
          .where('entityId', isEqualTo: entityId)
          .orderBy('systemContext.timestamp', descending: true);

      if (startDate != null) {
        query = query.where('systemContext.timestamp', 
                   isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('systemContext.timestamp', 
                   isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final auditSnap = await query.limit(limit).get();
      
      return auditSnap.docs.map((doc) => {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          // Add computed fields
          'timeAgo': _formatTimeAgo(data['systemContext']?['timestamp']),
          'changeImpact': _formatChangeImpact(data['changeDetails']),
          'riskIndicators': _analyzeRiskIndicators(data),
        };
      }).toList();

    } catch (e) {
      print('❌ Error getting audit trail: $e');
      return [];
    }
  }

  /// Get pricing violation alerts
  Future<List<Map<String, dynamic>>> getPricingViolations({
    String? vendorId,
    String? serviceId,
    int days = 30,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));
      
      Query<Map<String, dynamic>> query = _db.collection('pricing_audit_log')
          .where('compliance.riskLevel', whereIn: ['high', 'critical'])
          .where('systemContext.timestamp', 
                 isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('systemContext.timestamp', descending: true);

      if (vendorId != null) {
        query = query.where('actor.vendorId', isEqualTo: vendorId);
      }

      final violationsSnap = await query.limit(100).get();
      
      return violationsSnap.docs.map((doc) => {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'severity': _calculateViolationSeverity(data),
          'recommendedAction': _getRecommendedAction(data),
        };
      }).toList();

    } catch (e) {
      print('❌ Error getting pricing violations: $e');
      return [];
    }
  }

  /// Generate pricing compliance report
  Future<Map<String, dynamic>> generateComplianceReport({
    String? vendorId,
    String? serviceId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db.collection('pricing_audit_log')
          .where('systemContext.timestamp', 
                 isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('systemContext.timestamp', 
                 isLessThanOrEqualTo: Timestamp.fromDate(endDate));

      if (vendorId != null) {
        query = query.where('actor.vendorId', isEqualTo: vendorId);
      }

      final auditSnap = await query.get();
      final auditEntries = auditSnap.docs.map((doc) => doc.data()).toList();

      // Analyze compliance metrics
      final report = {
        'reportPeriod': {
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
          'durationDays': endDate.difference(startDate).inDays,
        },
        
        'summary': {
          'totalPriceChanges': auditEntries.length,
          'vendorChanges': auditEntries.where((e) => e['actor']['role'] == 'vendor').length,
          'adminChanges': auditEntries.where((e) => e['actor']['role'] == 'admin').length,
          'autoApprovedChanges': auditEntries.where((e) => e['compliance']['requiresReview'] == false).length,
          'pendingReviewChanges': auditEntries.where((e) => e['compliance']['requiresReview'] == true).length,
        },
        
        'compliance': {
          'policyViolations': auditEntries.where((e) => e['compliance']['policyCompliance'] == false).length,
          'highRiskChanges': auditEntries.where((e) => e['compliance']['riskLevel'] == 'high').length,
          'criticalRiskChanges': auditEntries.where((e) => e['compliance']['riskLevel'] == 'critical').length,
          'complianceRate': _calculateComplianceRate(auditEntries),
        },
        
        'trends': {
          'priceIncreases': auditEntries.where((e) => (e['changeDetails']['changeAmount'] ?? 0) > 0).length,
          'priceDecreases': auditEntries.where((e) => (e['changeDetails']['changeAmount'] ?? 0) < 0).length,
          'averageChangeAmount': _calculateAverageChange(auditEntries),
          'largestIncrease': _findLargestChange(auditEntries, true),
          'largestDecrease': _findLargestChange(auditEntries, false),
        },
        
        'recommendations': await _generateComplianceRecommendations(auditEntries, vendorId),
        
        'generatedAt': DateTime.now().toIso8601String(),
        'generatedBy': FirebaseAuth.instance.currentUser?.uid,
      };

      return report;

    } catch (e) {
      print('❌ Error generating compliance report: $e');
      throw Exception('Failed to generate compliance report: $e');
    }
  }

  /// Real-time pricing monitoring
  Future<void> _triggerRealTimeMonitoring(Map<String, dynamic> auditEntry) async {
    try {
      final riskLevel = auditEntry['compliance']['riskLevel'];
      final changeType = auditEntry['changeType'];
      final impactLevel = auditEntry['changeContext']['impactLevel'];

      // Trigger alerts based on risk and impact
      if (riskLevel == 'critical' || impactLevel == 'critical') {
        await _sendCriticalPricingAlert(auditEntry);
      }

      if (riskLevel == 'high' && changeType == 'vendor_price_update') {
        await _sendHighRiskVendorAlert(auditEntry);
      }

      // Update real-time monitoring dashboard
      await _updateMonitoringDashboard(auditEntry);

    } catch (e) {
      print('❌ Error triggering real-time monitoring: $e');
    }
  }

  /// Send critical pricing alert to admin team
  Future<void> _sendCriticalPricingAlert(Map<String, dynamic> auditEntry) async {
    try {
      // Get admin users
      final adminUsers = await _getAdminUsers();
      
      for (final adminId in adminUsers) {
        await _db.collection('notifications').add({
          'userId': adminId,
          'type': 'critical_pricing_alert',
          'title': '🚨 Critical Pricing Change Alert',
          'body': _formatCriticalAlert(auditEntry),
          'priority': 'critical',
          'data': {
            'auditId': auditEntry['auditId'],
            'entityType': auditEntry['entityType'],
            'entityId': auditEntry['entityId'],
            'changeType': auditEntry['changeType'],
            'riskLevel': auditEntry['compliance']['riskLevel'],
          },
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

    } catch (e) {
      print('❌ Error sending critical pricing alert: $e');
    }
  }

  /// Detect pricing anomalies and outliers
  Future<List<Map<String, dynamic>>> detectPricingAnomalies({
    String? serviceId,
    String? vendorId,
    int analysisWindowDays = 7,
  }) async {
    try {
      final anomalies = <Map<String, dynamic>>[];
      final startDate = DateTime.now().subtract(Duration(days: analysisWindowDays));

      // Query recent pricing changes
      Query<Map<String, dynamic>> query = _db.collection('pricing_audit_log')
          .where('systemContext.timestamp', 
                 isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('changeType', isEqualTo: 'vendor_price_update');

      if (serviceId != null) {
        // Would need to join with items/vendors to filter by service
        // For now, filter in memory after retrieval
      }

      if (vendorId != null) {
        query = query.where('actor.vendorId', isEqualTo: vendorId);
      }

      final changesSnap = await query.get();
      final changes = changesSnap.docs.map((doc) => doc.data()).toList();

      // Anomaly detection algorithms
      
      // 1. Statistical outliers (price changes beyond 2 standard deviations)
      final priceChanges = changes.map((c) => 
        (c['changeDetails']['changePercentage'] as num?)?.toDouble() ?? 0.0
      ).toList();
      
      if (priceChanges.isNotEmpty) {
        final mean = priceChanges.reduce((a, b) => a + b) / priceChanges.length;
        final variance = priceChanges.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / priceChanges.length;
        final stdDev = math.sqrt(variance);
        
        for (int i = 0; i < changes.length; i++) {
          final change = priceChanges[i];
          if ((change - mean).abs() > 2 * stdDev) {
            anomalies.add({
              'type': 'statistical_outlier',
              'severity': 'medium',
              'description': 'Price change is a statistical outlier',
              'auditEntry': changes[i],
              'deviation': (change - mean) / stdDev,
            });
          }
        }
      }

      // 2. Rapid successive changes
      final vendorChanges = <String, List<Map<String, dynamic>>>{};
      for (final change in changes) {
        final vendorId = change['actor']['vendorId'];
        if (vendorId != null) {
          vendorChanges.putIfAbsent(vendorId, () => []).add(change);
        }
      }

      vendorChanges.forEach((vendorId, vendorChangesList) => {
        if (vendorChangesList.length > 10) { // More than 10 changes in analysis window
          anomalies.add({
            'type': 'rapid_price_changes',
            'severity': 'high',
            'description': 'Vendor made excessive price changes',
            'vendorId': vendorId,
            'changeCount': vendorChangesList.length,
            'timeWindow': '${analysisWindowDays} days',
          });
        }
      });

      // 3. Price manipulation patterns
      await _detectPriceManipulationPatterns(changes, anomalies);

      // 4. Market deviation analysis
      await _detectMarketDeviationAnomalies(changes, anomalies);

      // Sort by severity
      anomalies.sort((a, b) => _getSeverityScore(b['severity']).compareTo(_getSeverityScore(a['severity'])));

      return anomalies;

    } catch (e) {
      print('❌ Error detecting pricing anomalies: $e');
      return [];
    }
  }

  /// Generate pricing transparency report for customers
  Future<Map<String, dynamic>> generateTransparencyReport({
    required String orderId,
    required String serviceId,
    String? vendorId,
  }) async {
    try {
      // Get pricing calculation details for this order
      final pricingCalculation = await _getPricingCalculationForOrder(orderId);
      
      // Get service pricing information
      final servicePricing = await _getServicePricingInfo(serviceId);
      
      // Get vendor pricing info (if applicable)
      final vendorPricing = vendorId != null 
          ? await _getVendorPricingInfo(vendorId)
          : null;

      return {
        'orderId': orderId,
        'serviceId': serviceId,
        'vendorId': vendorId,
        
        // Pricing breakdown
        'pricingBreakdown': pricingCalculation['breakdown'] ?? {},
        
        // Pricing source explanation
        'pricingSource': {
          'type': pricingCalculation['pricingSource'] ?? 'unknown',
          'explanation': _explainPricingSource(pricingCalculation['pricingSource']),
          'lastUpdated': pricingCalculation['lastUpdated'],
        },
        
        // Service-level pricing info
        'servicePricing': servicePricing,
        
        // Vendor-level pricing info (if applicable)
        'vendorPricing': vendorPricing,
        
        // Market context
        'marketContext': await _getMarketContext(serviceId, vendorId),
        
        // Regulatory information
        'regulatory': {
          'taxBreakdown': pricingCalculation['breakdown']?['platformAdjustments']?['tax'] ?? 0,
          'platformFees': pricingCalculation['breakdown']?['platformAdjustments']?['serviceFee'] ?? 0,
          'vendorRevenue': _calculateVendorRevenue(pricingCalculation),
        },
        
        // Customer rights
        'customerRights': {
          'canDispute': true,
          'disputeWindow': '24 hours',
          'contactSupport': 'support@zippup.com',
          'pricingPolicy': 'https://zippup.com/pricing-policy',
        },
        
        'generatedAt': DateTime.now().toIso8601String(),
      };

    } catch (e) {
      print('❌ Error generating transparency report: $e');
      throw Exception('Failed to generate transparency report: $e');
    }
  }

  /// Monitor vendor pricing compliance in real-time
  Stream<List<Map<String, dynamic>>> monitorVendorCompliance(String vendorId) {
    return _db.collection('pricing_audit_log')
        .where('actor.vendorId', isEqualTo: vendorId)
        .where('compliance.riskLevel', whereIn: ['medium', 'high', 'critical'])
        .orderBy('systemContext.timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {
          final data = doc.data();
          return {
            'id': doc.id,
            ...data,
            'alertLevel': _getAlertLevel(data['compliance']['riskLevel']),
            'actionRequired': _getRequiredAction(data),
          };
        }).toList());
  }

  /// Calculate vendor pricing health score
  Future<Map<String, dynamic>> calculateVendorPricingHealthScore(String vendorId) async {
    try {
      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
      
      // Get vendor's pricing activity
      final auditQuery = await _db.collection('pricing_audit_log')
          .where('actor.vendorId', isEqualTo: vendorId)
          .where('systemContext.timestamp', 
                 isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .get();

      final auditEntries = auditQuery.docs.map((doc) => doc.data()).toList();

      // Calculate health metrics
      final totalChanges = auditEntries.length;
      final violations = auditEntries.where((e) => e['compliance']['policyCompliance'] == false).length;
      final highRiskChanges = auditEntries.where((e) => e['compliance']['riskLevel'] == 'high').length;
      final criticalRiskChanges = auditEntries.where((e) => e['compliance']['riskLevel'] == 'critical').length;

      // Calculate scores (0-100)
      final complianceScore = totalChanges > 0 ? ((totalChanges - violations) / totalChanges) * 100 : 100;
      final riskScore = totalChanges > 0 ? 
          100 - (((highRiskChanges * 0.5) + (criticalRiskChanges * 1.0)) / totalChanges) * 100 : 100;
      final frequencyScore = _calculateFrequencyScore(totalChanges);
      
      // Overall health score (weighted average)
      final overallScore = (complianceScore * 0.4) + (riskScore * 0.4) + (frequencyScore * 0.2);

      return {
        'vendorId': vendorId,
        'healthScore': overallScore.round(),
        'healthGrade': _getHealthGrade(overallScore),
        
        'metrics': {
          'complianceScore': complianceScore.round(),
          'riskScore': riskScore.round(),
          'frequencyScore': frequencyScore.round(),
        },
        
        'activity': {
          'totalChanges': totalChanges,
          'violations': violations,
          'highRiskChanges': highRiskChanges,
          'criticalRiskChanges': criticalRiskChanges,
        },
        
        'recommendations': _generateHealthRecommendations(overallScore, {
          'compliance': complianceScore,
          'risk': riskScore,
          'frequency': frequencyScore,
        }),
        
        'calculatedAt': DateTime.now().toIso8601String(),
        'validUntil': DateTime.now().add(const Duration(hours: 6)).toIso8601String(), // Cache for 6 hours
      };

    } catch (e) {
      print('❌ Error calculating vendor health score: $e');
      throw Exception('Failed to calculate health score: $e');
    }
  }

  // ===== PRIVATE HELPER METHODS =====

  String _generateAuditId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = math.Random().nextInt(10000);
    return 'audit_${timestamp}_$random';
  }

  String _categorizeChange(String changeType, Map<String, dynamic> changeDetails) {
    final changeAmount = (changeDetails['changeAmount'] as num?)?.toDouble() ?? 0.0;
    final changePercentage = (changeDetails['changePercentage'] as num?)?.toDouble() ?? 0.0;

    if (changeType.contains('bulk')) return 'bulk_adjustment';
    if (changePercentage.abs() > 50) return 'major_adjustment';
    if (changePercentage.abs() > 20) return 'significant_adjustment';
    if (changeAmount > 0) return 'price_increase';
    if (changeAmount < 0) return 'price_decrease';
    return 'minor_adjustment';
  }

  String _calculateImpactLevel(Map<String, dynamic> changeDetails) {
    final changePercentage = (changeDetails['changePercentage'] as num?)?.toDouble()?.abs() ?? 0.0;
    final changeAmount = (changeDetails['changeAmount'] as num?)?.toDouble()?.abs() ?? 0.0;

    if (changePercentage > 100 || changeAmount > 10000) return 'critical';
    if (changePercentage > 50 || changeAmount > 5000) return 'high';
    if (changePercentage > 20 || changeAmount > 1000) return 'medium';
    return 'low';
  }

  Future<Map<String, dynamic>> _calculateImpactAnalysis(
    String changeType,
    String entityType, 
    String entityId,
    Map<String, dynamic> changeDetails,
  ) async {
    try {
      // This would include sophisticated impact analysis
      // For now, return basic analysis
      return {
        'estimatedRevenueImpact': _estimateRevenueImpact(changeDetails),
        'customerDemandImpact': _estimateDemandImpact(changeDetails),
        'competitiveImpact': await _estimateCompetitiveImpact(entityId, changeDetails),
        'marketShareImpact': _estimateMarketShareImpact(changeDetails),
      };
    } catch (e) {
      return {
        'error': 'Impact analysis failed',
        'details': e.toString(),
      };
    }
  }

  double _estimateRevenueImpact(Map<String, dynamic> changeDetails) {
    // Simple revenue impact estimation
    final changeAmount = (changeDetails['changeAmount'] as num?)?.toDouble() ?? 0.0;
    final estimatedDailyOrders = 10; // This would come from historical data
    return changeAmount * estimatedDailyOrders;
  }

  double _estimateDemandImpact(Map<String, dynamic> changeDetails) {
    // Simple demand elasticity estimation
    final changePercentage = (changeDetails['changePercentage'] as num?)?.toDouble() ?? 0.0;
    final priceElasticity = -0.5; // Typical elasticity for food items
    return changePercentage * priceElasticity / 100;
  }

  String _getHealthGrade(double score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  int _getSeverityScore(String severity) {
    switch (severity) {
      case 'critical': return 4;
      case 'high': return 3;
      case 'medium': return 2;
      case 'low': return 1;
      default: return 0;
    }
  }

  double _calculateFrequencyScore(int totalChanges) {
    // Score based on change frequency (lower frequency = higher score)
    if (totalChanges <= 5) return 100.0;
    if (totalChanges <= 10) return 80.0;
    if (totalChanges <= 20) return 60.0;
    if (totalChanges <= 50) return 40.0;
    return 20.0;
  }

  // Additional helper methods would be implemented here...
}