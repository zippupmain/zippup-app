import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MovingListenerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Set up real-time listener for a specific moving request
  static StreamSubscription<DocumentSnapshot> listenToMovingRequest({
    required String requestId,
    required Function(MovingStatus status, Map<String, dynamic> requestData) onStatusChange,
    required Function(String error) onError,
  }) {
    print('🎧 Setting up moving request listener for: $requestId');
    
    return _firestore
        .collection('moving_requests')
        .doc(requestId)
        .snapshots()
        .listen(
          (DocumentSnapshot snapshot) async {
            if (!snapshot.exists) {
              onError('Moving request document not found');
              return;
            }

            final requestData = snapshot.data() as Map<String, dynamic>;
            final statusString = requestData['status'] as String?;
            
            if (statusString == null) {
              onError('Moving request status is null');
              return;
            }

            final status = _parseMovingStatus(statusString);
            print('🔄 Moving request $requestId status changed to: $statusString');
            
            await onStatusChange(status, requestData);
          },
          onError: (error) {
            print('❌ Error listening to moving request $requestId: $error');
            onError(error.toString());
          },
        );
  }

  /// Parse string status to MovingStatus enum
  static MovingStatus _parseMovingStatus(String statusString) {
    switch (statusString.toLowerCase()) {
      case 'requesting':
        return MovingStatus.requesting;
      case 'provider_assigned':
        return MovingStatus.providerAssigned;
      case 'accepted':
        return MovingStatus.accepted;
      case 'provider_arriving':
        return MovingStatus.providerArriving;
      case 'provider_arrived':
        return MovingStatus.providerArrived;
      case 'survey_started':
        return MovingStatus.surveyStarted;
      case 'quote_provided':
        return MovingStatus.quoteProvided;
      case 'quote_accepted':
        return MovingStatus.quoteAccepted;
      case 'loading_started':
        return MovingStatus.loadingStarted;
      case 'in_transit':
        return MovingStatus.inTransit;
      case 'unloading_started':
        return MovingStatus.unloadingStarted;
      case 'completed':
        return MovingStatus.completed;
      case 'cancelled_by_customer':
        return MovingStatus.cancelledByCustomer;
      case 'cancelled_by_provider':
        return MovingStatus.cancelledByProvider;
      case 'timeout':
        return MovingStatus.timeout;
      case 'no_providers_available':
        return MovingStatus.noProvidersAvailable;
      case 'assignment_error':
        return MovingStatus.assignmentError;
      default:
        return MovingStatus.unknown;
    }
  }

  /// Get moving provider information
  static Future<Map<String, dynamic>?> getMovingProviderInfo(String providerId) async {
    try {
      final providerDoc = await _firestore.collection('moving_providers').doc(providerId).get();
      
      if (providerDoc.exists) {
        return providerDoc.data();
      } else {
        print('❌ Moving provider document not found: $providerId');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching moving provider info: $e');
      return null;
    }
  }

  /// Update moving request status
  static Future<void> updateMovingRequestStatus({
    required String requestId,
    required String newStatus,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        ...?additionalData,
      };

      await _firestore.collection('moving_requests').doc(requestId).update(updateData);
      print('✅ Updated moving request $requestId status to: $newStatus');
    } catch (e) {
      print('❌ Error updating moving request status: $e');
      rethrow;
    }
  }

  /// Submit quote for moving request (provider side)
  static Future<void> submitMovingQuote({
    required String requestId,
    required double quotedPrice,
    required String breakdown,
    String? estimatedDuration,
    String? additionalNotes,
  }) async {
    try {
      await _firestore.collection('moving_requests').doc(requestId).update({
        'status': 'quote_provided',
        'quote': {
          'price': quotedPrice,
          'breakdown': breakdown,
          'estimatedDuration': estimatedDuration,
          'additionalNotes': additionalNotes,
          'providedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Submitted quote for moving request: $requestId');
    } catch (e) {
      print('❌ Error submitting moving quote: $e');
      rethrow;
    }
  }

  /// Accept quote (customer side)
  static Future<void> acceptMovingQuote(String requestId) async {
    try {
      await _firestore.collection('moving_requests').doc(requestId).update({
        'status': 'quote_accepted',
        'quoteAcceptedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Accepted quote for moving request: $requestId');
    } catch (e) {
      print('❌ Error accepting moving quote: $e');
      rethrow;
    }
  }
}

/// Enum for moving request statuses
enum MovingStatus {
  requesting,
  providerAssigned,
  accepted,
  providerArriving,
  providerArrived,
  surveyStarted,
  quoteProvided,
  quoteAccepted,
  loadingStarted,
  inTransit,
  unloadingStarted,
  completed,
  cancelledByCustomer,
  cancelledByProvider,
  timeout,
  noProvidersAvailable,
  assignmentError,
  unknown,
}

/// Extension for moving status display
extension MovingStatusExtension on MovingStatus {
  String get displayText {
    switch (this) {
      case MovingStatus.requesting:
        return 'Looking for moving providers...';
      case MovingStatus.providerAssigned:
        return 'Moving provider found!';
      case MovingStatus.accepted:
        return 'Provider is on the way';
      case MovingStatus.providerArriving:
        return 'Provider is arriving';
      case MovingStatus.providerArrived:
        return 'Provider has arrived';
      case MovingStatus.surveyStarted:
        return 'Provider is surveying items';
      case MovingStatus.quoteProvided:
        return 'Quote provided - please review';
      case MovingStatus.quoteAccepted:
        return 'Quote accepted - preparing to move';
      case MovingStatus.loadingStarted:
        return 'Loading items in progress';
      case MovingStatus.inTransit:
        return 'Items are being transported';
      case MovingStatus.unloadingStarted:
        return 'Unloading items at destination';
      case MovingStatus.completed:
        return 'Moving completed successfully';
      case MovingStatus.cancelledByCustomer:
        return 'Moving cancelled';
      case MovingStatus.cancelledByProvider:
        return 'Looking for another provider...';
      case MovingStatus.timeout:
        return 'Looking for another provider...';
      case MovingStatus.noProvidersAvailable:
        return 'No providers available nearby';
      case MovingStatus.assignmentError:
        return 'Error finding provider';
      case MovingStatus.unknown:
        return 'Unknown status';
    }
  }

  Color get statusColor {
    switch (this) {
      case MovingStatus.requesting:
      case MovingStatus.cancelledByProvider:
      case MovingStatus.timeout:
        return Colors.orange;
      case MovingStatus.providerAssigned:
      case MovingStatus.accepted:
      case MovingStatus.providerArriving:
        return Colors.blue;
      case MovingStatus.providerArrived:
      case MovingStatus.surveyStarted:
        return Colors.green;
      case MovingStatus.quoteProvided:
        return Colors.purple;
      case MovingStatus.quoteAccepted:
      case MovingStatus.loadingStarted:
      case MovingStatus.inTransit:
      case MovingStatus.unloadingStarted:
        return Colors.indigo;
      case MovingStatus.completed:
        return Colors.green;
      case MovingStatus.cancelledByCustomer:
      case MovingStatus.noProvidersAvailable:
      case MovingStatus.assignmentError:
        return Colors.red;
      case MovingStatus.unknown:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (this) {
      case MovingStatus.requesting:
      case MovingStatus.cancelledByProvider:
      case MovingStatus.timeout:
        return Icons.search;
      case MovingStatus.providerAssigned:
        return Icons.local_shipping;
      case MovingStatus.accepted:
      case MovingStatus.providerArriving:
        return Icons.directions_car;
      case MovingStatus.providerArrived:
        return Icons.location_on;
      case MovingStatus.surveyStarted:
        return Icons.assignment;
      case MovingStatus.quoteProvided:
        return Icons.receipt;
      case MovingStatus.quoteAccepted:
        return Icons.check_circle;
      case MovingStatus.loadingStarted:
        return Icons.inbox;
      case MovingStatus.inTransit:
        return Icons.local_shipping;
      case MovingStatus.unloadingStarted:
        return Icons.outbox;
      case MovingStatus.completed:
        return Icons.check_circle;
      case MovingStatus.cancelledByCustomer:
      case MovingStatus.noProvidersAvailable:
      case MovingStatus.assignmentError:
        return Icons.error;
      case MovingStatus.unknown:
        return Icons.help;
    }
  }

  bool get isActiveStatus {
    return [
      MovingStatus.accepted,
      MovingStatus.providerArriving,
      MovingStatus.providerArrived,
      MovingStatus.surveyStarted,
      MovingStatus.quoteProvided,
      MovingStatus.quoteAccepted,
      MovingStatus.loadingStarted,
      MovingStatus.inTransit,
      MovingStatus.unloadingStarted,
    ].contains(this);
  }

  bool get isCompletedStatus {
    return [
      MovingStatus.completed,
      MovingStatus.cancelledByCustomer,
      MovingStatus.cancelledByProvider,
    ].contains(this);
  }
}

/// Widget for displaying moving request status
class MovingStatusWidget extends StatelessWidget {
  final MovingStatus status;
  final Map<String, dynamic>? requestData;
  final Map<String, dynamic>? providerData;
  final VoidCallback? onCancel;
  final VoidCallback? onAcceptQuote;
  final VoidCallback? onDeclineQuote;

  const MovingStatusWidget({
    super.key,
    required this.status,
    this.requestData,
    this.providerData,
    this.onCancel,
    this.onAcceptQuote,
    this.onDeclineQuote,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header
            Row(
              children: [
                Icon(
                  status.statusIcon,
                  color: status.statusColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    status.displayText,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: status.statusColor,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Provider information (if available)
            if (providerData != null) _buildProviderInfo(),
            
            // Request details
            if (requestData != null) _buildRequestDetails(),
            
            // Quote details (if available)
            if (status == MovingStatus.quoteProvided && requestData?['quote'] != null)
              _buildQuoteDetails(),
            
            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Moving Provider',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                backgroundImage: providerData!['photoUrl'] != null
                    ? NetworkImage(providerData!['photoUrl'])
                    : null,
                child: providerData!['photoUrl'] == null
                    ? const Icon(Icons.local_shipping)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerData!['companyName'] ?? providerData!['name'] ?? 'Moving Provider',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Vehicle: ${providerData!['vehicleInfo']?['type']} ${providerData!['vehicleInfo']?['model'] ?? ''}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (providerData!['phone'] != null)
                      Text(
                        'Phone: ${providerData!['phone']}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      Text(
                        '${providerData!['rating']?.toStringAsFixed(1) ?? '0.0'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Text(
                    '${providerData!['totalJobs'] ?? 0} jobs',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Moving Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        // Moving type and rooms
        Row(
          children: [
            const Icon(Icons.home, color: Colors.blue, size: 16),
            const SizedBox(width: 8),
            Text(
              '${requestData!['movingType'] ?? 'Moving'} • ${requestData!['rooms'] ?? 0} rooms',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        
        const SizedBox(height: 4),
        
        // Pickup location
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.radio_button_checked, color: Colors.green, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'From: ${requestData!['pickupAddress'] ?? 'Pickup location'}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 4),
        
        // Destination
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'To: ${requestData!['destinationAddress'] ?? 'Destination'}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Moving date and estimated cost
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (requestData!['movingDate'] != null)
              Text(
                'Date: ${requestData!['movingDate']}',
                style: const TextStyle(fontSize: 14),
              ),
            if (requestData!['estimatedCost'] != null)
              Text(
                'Est. Cost: ₦${requestData!['estimatedCost']?.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuoteDetails() {
    final quote = requestData!['quote'] as Map<String, dynamic>;
    
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Moving Quote',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.purple,
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            'Total Price: ₦${quote['price']?.toStringAsFixed(0) ?? '0'}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          
          if (quote['breakdown'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Breakdown: ${quote['breakdown']}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
          
          if (quote['estimatedDuration'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Duration: ${quote['estimatedDuration']}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
          
          if (quote['additionalNotes'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Notes: ${quote['additionalNotes']}',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (status == MovingStatus.quoteProvided) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: onDeclineQuote,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
              ),
              child: const Text('Decline Quote'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: onAcceptQuote,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Accept Quote'),
            ),
          ),
        ],
      );
    }
    
    if (status == MovingStatus.requesting || 
        status == MovingStatus.providerAssigned) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onCancel,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Cancel Moving Request'),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }
}