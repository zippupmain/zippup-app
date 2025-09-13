import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EmergencyListenerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Set up real-time listener for a specific emergency request
  static StreamSubscription<DocumentSnapshot> listenToEmergencyRequest({
    required String requestId,
    required Function(EmergencyStatus status, Map<String, dynamic> requestData) onStatusChange,
    required Function(String error) onError,
  }) {
    print('🚨 Setting up emergency request listener for: $requestId');
    
    return _firestore
        .collection('emergency_requests')
        .doc(requestId)
        .snapshots()
        .listen(
          (DocumentSnapshot snapshot) async {
            if (!snapshot.exists) {
              onError('Emergency request document not found');
              return;
            }

            final requestData = snapshot.data() as Map<String, dynamic>;
            final statusString = requestData['status'] as String?;
            
            if (statusString == null) {
              onError('Emergency request status is null');
              return;
            }

            final status = _parseEmergencyStatus(statusString);
            print('🚨 Emergency request $requestId status changed to: $statusString');
            
            await onStatusChange(status, requestData);
          },
          onError: (error) {
            print('❌ Error listening to emergency request $requestId: $error');
            onError(error.toString());
          },
        );
  }

  /// Parse string status to EmergencyStatus enum
  static EmergencyStatus _parseEmergencyStatus(String statusString) {
    switch (statusString.toLowerCase()) {
      case 'requesting':
        return EmergencyStatus.requesting;
      case 'responder_assigned':
        return EmergencyStatus.responderAssigned;
      case 'accepted':
        return EmergencyStatus.accepted;
      case 'responder_dispatched':
        return EmergencyStatus.responderDispatched;
      case 'responder_arriving':
        return EmergencyStatus.responderArriving;
      case 'responder_arrived':
        return EmergencyStatus.responderArrived;
      case 'service_started':
        return EmergencyStatus.serviceStarted;
      case 'service_in_progress':
        return EmergencyStatus.serviceInProgress;
      case 'service_completed':
        return EmergencyStatus.serviceCompleted;
      case 'transport_required':
        return EmergencyStatus.transportRequired;
      case 'transporting':
        return EmergencyStatus.transporting;
      case 'completed':
        return EmergencyStatus.completed;
      case 'cancelled_by_requester':
        return EmergencyStatus.cancelledByRequester;
      case 'cancelled_by_responder':
        return EmergencyStatus.cancelledByResponder;
      case 'timeout':
        return EmergencyStatus.timeout;
      case 'no_responders_available':
        return EmergencyStatus.noRespondersAvailable;
      case 'assignment_error':
        return EmergencyStatus.assignmentError;
      default:
        return EmergencyStatus.unknown;
    }
  }

  /// Get emergency responder information
  static Future<Map<String, dynamic>?> getEmergencyResponderInfo(String responderId) async {
    try {
      final responderDoc = await _firestore.collection('emergency_responders').doc(responderId).get();
      
      if (responderDoc.exists) {
        return responderDoc.data();
      } else {
        print('❌ Emergency responder document not found: $responderId');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching emergency responder info: $e');
      return null;
    }
  }

  /// Update emergency request status
  static Future<void> updateEmergencyRequestStatus({
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

      await _firestore.collection('emergency_requests').doc(requestId).update(updateData);
      print('✅ Updated emergency request $requestId status to: $newStatus');
    } catch (e) {
      print('❌ Error updating emergency request status: $e');
      rethrow;
    }
  }

  /// Add emergency update/note (responder side)
  static Future<void> addEmergencyUpdate({
    required String requestId,
    required String update,
    String? updateType,
  }) async {
    try {
      await _firestore.collection('emergency_requests').doc(requestId).update({
        'updates': FieldValue.arrayUnion([{
          'message': update,
          'type': updateType ?? 'info',
          'timestamp': FieldValue.serverTimestamp(),
          'responderId': FirebaseAuth.instance.currentUser?.uid,
        }]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Added update to emergency request: $requestId');
    } catch (e) {
      print('❌ Error adding emergency update: $e');
      rethrow;
    }
  }

  /// Request additional resources
  static Future<void> requestAdditionalResources({
    required String requestId,
    required String resourceType,
    required String reason,
    String? urgency,
  }) async {
    try {
      await _firestore.collection('emergency_requests').doc(requestId).update({
        'additionalResources': FieldValue.arrayUnion([{
          'type': resourceType,
          'reason': reason,
          'urgency': urgency ?? 'medium',
          'requestedAt': FieldValue.serverTimestamp(),
          'requestedBy': FirebaseAuth.instance.currentUser?.uid,
          'status': 'requested',
        }]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Requested additional resources for emergency: $requestId');
    } catch (e) {
      print('❌ Error requesting additional resources: $e');
      rethrow;
    }
  }
}

/// Enum for emergency request statuses
enum EmergencyStatus {
  requesting,
  responderAssigned,
  accepted,
  responderDispatched,
  responderArriving,
  responderArrived,
  serviceStarted,
  serviceInProgress,
  serviceCompleted,
  transportRequired,
  transporting,
  completed,
  cancelledByRequester,
  cancelledByResponder,
  timeout,
  noRespondersAvailable,
  assignmentError,
  unknown,
}

/// Extension for emergency status display
extension EmergencyStatusExtension on EmergencyStatus {
  String get displayText {
    switch (this) {
      case EmergencyStatus.requesting:
        return 'Dispatching emergency responder...';
      case EmergencyStatus.responderAssigned:
        return 'Emergency responder assigned!';
      case EmergencyStatus.accepted:
        return 'Responder confirmed - help is coming';
      case EmergencyStatus.responderDispatched:
        return 'Emergency responder dispatched';
      case EmergencyStatus.responderArriving:
        return 'Responder is arriving';
      case EmergencyStatus.responderArrived:
        return 'Emergency responder has arrived';
      case EmergencyStatus.serviceStarted:
        return 'Emergency service started';
      case EmergencyStatus.serviceInProgress:
        return 'Emergency service in progress';
      case EmergencyStatus.serviceCompleted:
        return 'Emergency service completed';
      case EmergencyStatus.transportRequired:
        return 'Transport to facility required';
      case EmergencyStatus.transporting:
        return 'Transporting to medical facility';
      case EmergencyStatus.completed:
        return 'Emergency response completed';
      case EmergencyStatus.cancelledByRequester:
        return 'Emergency request cancelled';
      case EmergencyStatus.cancelledByResponder:
        return 'Finding another responder...';
      case EmergencyStatus.timeout:
        return 'Finding another responder...';
      case EmergencyStatus.noRespondersAvailable:
        return 'No responders available - trying expanded search';
      case EmergencyStatus.assignmentError:
        return 'Error dispatching responder';
      case EmergencyStatus.unknown:
        return 'Unknown status';
    }
  }

  Color get statusColor {
    switch (this) {
      case EmergencyStatus.requesting:
      case EmergencyStatus.cancelledByResponder:
      case EmergencyStatus.timeout:
        return Colors.orange;
      case EmergencyStatus.responderAssigned:
      case EmergencyStatus.accepted:
      case EmergencyStatus.responderDispatched:
      case EmergencyStatus.responderArriving:
        return Colors.blue;
      case EmergencyStatus.responderArrived:
      case EmergencyStatus.serviceStarted:
      case EmergencyStatus.serviceInProgress:
        return Colors.green;
      case EmergencyStatus.serviceCompleted:
      case EmergencyStatus.transportRequired:
      case EmergencyStatus.transporting:
        return Colors.indigo;
      case EmergencyStatus.completed:
        return Colors.green;
      case EmergencyStatus.cancelledByRequester:
      case EmergencyStatus.noRespondersAvailable:
      case EmergencyStatus.assignmentError:
        return Colors.red;
      case EmergencyStatus.unknown:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (this) {
      case EmergencyStatus.requesting:
      case EmergencyStatus.cancelledByResponder:
      case EmergencyStatus.timeout:
        return Icons.search;
      case EmergencyStatus.responderAssigned:
        return Icons.emergency;
      case EmergencyStatus.accepted:
      case EmergencyStatus.responderDispatched:
      case EmergencyStatus.responderArriving:
        return Icons.directions_car;
      case EmergencyStatus.responderArrived:
        return Icons.location_on;
      case EmergencyStatus.serviceStarted:
      case EmergencyStatus.serviceInProgress:
        return Icons.medical_services;
      case EmergencyStatus.serviceCompleted:
        return Icons.check_circle_outline;
      case EmergencyStatus.transportRequired:
      case EmergencyStatus.transporting:
        return Icons.local_hospital;
      case EmergencyStatus.completed:
        return Icons.check_circle;
      case EmergencyStatus.cancelledByRequester:
      case EmergencyStatus.noRespondersAvailable:
      case EmergencyStatus.assignmentError:
        return Icons.error;
      case EmergencyStatus.unknown:
        return Icons.help;
    }
  }

  bool get isCriticalStatus {
    return [
      EmergencyStatus.requesting,
      EmergencyStatus.responderAssigned,
      EmergencyStatus.accepted,
      EmergencyStatus.responderDispatched,
      EmergencyStatus.responderArriving,
      EmergencyStatus.responderArrived,
      EmergencyStatus.serviceStarted,
      EmergencyStatus.serviceInProgress,
      EmergencyStatus.transportRequired,
      EmergencyStatus.transporting,
    ].contains(this);
  }

  bool get isActiveStatus {
    return [
      EmergencyStatus.accepted,
      EmergencyStatus.responderDispatched,
      EmergencyStatus.responderArriving,
      EmergencyStatus.responderArrived,
      EmergencyStatus.serviceStarted,
      EmergencyStatus.serviceInProgress,
      EmergencyStatus.serviceCompleted,
      EmergencyStatus.transportRequired,
      EmergencyStatus.transporting,
    ].contains(this);
  }

  bool get isCompletedStatus {
    return [
      EmergencyStatus.completed,
      EmergencyStatus.cancelledByRequester,
      EmergencyStatus.cancelledByResponder,
    ].contains(this);
  }
}

/// Widget for displaying emergency request status
class EmergencyStatusWidget extends StatelessWidget {
  final EmergencyStatus status;
  final Map<String, dynamic>? requestData;
  final Map<String, dynamic>? responderData;
  final VoidCallback? onCancel;
  final VoidCallback? onRequestAdditionalHelp;

  const EmergencyStatusWidget({
    super.key,
    required this.status,
    this.requestData,
    this.responderData,
    this.onCancel,
    this.onRequestAdditionalHelp,
  });

  @override
  Widget build(BuildContext context) {
    final emergencyType = requestData?['emergencyType'] ?? 'emergency';
    final priority = requestData?['priority'] ?? 'medium';
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: status.isCriticalStatus ? Colors.red : status.statusColor,
            width: status.isCriticalStatus ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emergency header with priority
              Row(
                children: [
                  Icon(
                    status.statusIcon,
                    color: status.statusColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          status.displayText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: status.statusColor,
                          ),
                        ),
                        Text(
                          '${emergencyType.toUpperCase()} • ${priority.toUpperCase()} PRIORITY',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getPriorityColor(priority),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status.isCriticalStatus)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Responder information (if available)
              if (responderData != null) _buildResponderInfo(emergencyType),
              
              // Request details
              if (requestData != null) _buildRequestDetails(emergencyType),
              
              // Emergency updates (if available)
              if (requestData?['updates'] != null) _buildEmergencyUpdates(),
              
              // Action buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponderInfo(String emergencyType) {
    final serviceNames = {
      'ambulance': 'Medical Team',
      'fire_service': 'Fire Department',
      'security_service': 'Security Team',
      'towing_van': 'Towing Service',
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            serviceNames[emergencyType] ?? 'Emergency Responder',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.red,
                backgroundImage: responderData!['photoUrl'] != null
                    ? NetworkImage(responderData!['photoUrl'])
                    : null,
                child: responderData!['photoUrl'] == null
                    ? const Icon(Icons.emergency, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      responderData!['name'] ?? responderData!['teamName'] ?? 'Emergency Responder',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (responderData!['certification'] != null)
                      Text(
                        'Certified: ${responderData!['certification']}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    if (responderData!['vehicleInfo'] != null)
                      Text(
                        'Unit: ${responderData!['vehicleInfo']?['unitNumber'] ?? 'N/A'}',
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
                        '${responderData!['rating']?.toStringAsFixed(1) ?? '0.0'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Text(
                    '${responderData!['totalResponses'] ?? 0} responses',
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

  Widget _buildRequestDetails(String emergencyType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Emergency Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        // Location
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                requestData!['address'] ?? requestData!['location'] ?? 'Location provided',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 4),
        
        // Description
        if (requestData!['description'] != null) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  requestData!['description'],
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        
        // Contact info
        if (requestData!['contactName'] != null || requestData!['contactPhone'] != null) ...[
          Row(
            children: [
              const Icon(Icons.person, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(
                '${requestData!['contactName'] ?? 'Contact'} ${requestData!['contactPhone'] != null ? '• ${requestData!['contactPhone']}' : ''}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        
        // ETA and distance
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (requestData!['estimatedArrival'] != null)
              Text(
                'ETA: ${_formatETA(requestData!['estimatedArrival'])}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
            if (requestData!['responderDistance'] != null)
              Text(
                'Distance: ${requestData!['responderDistance'].toStringAsFixed(1)}km',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmergencyUpdates() {
    final updates = requestData!['updates'] as List<dynamic>;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Emergency Updates',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: updates.take(3).map((update) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _getUpdateIcon(update['type']),
                      size: 16,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        update['message'],
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (status == EmergencyStatus.requesting || 
        status == EmergencyStatus.responderAssigned) {
      return Column(
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              if (onRequestAdditionalHelp != null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRequestAdditionalHelp,
                    child: const Text('Request Additional Help'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: onCancel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Cancel Emergency'),
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    if (status.isActiveStatus && onRequestAdditionalHelp != null) {
      return Column(
        children: [
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onRequestAdditionalHelp,
              icon: const Icon(Icons.add),
              label: const Text('Request Additional Resources'),
            ),
          ),
        ],
      );
    }
    
    return const SizedBox.shrink();
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'critical':
        return Colors.red.shade900;
      case 'high':
        return Colors.red.shade600;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.yellow.shade700;
      default:
        return Colors.orange;
    }
  }

  IconData _getUpdateIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'info':
        return Icons.info;
      case 'warning':
        return Icons.warning;
      case 'success':
        return Icons.check_circle;
      case 'error':
        return Icons.error;
      default:
        return Icons.update;
    }
  }

  String _formatETA(String isoString) {
    try {
      final eta = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = eta.difference(now);
      
      if (difference.isNegative) return 'Overdue';
      
      final minutes = difference.inMinutes;
      if (minutes < 60) return '${minutes}min';
      
      final hours = difference.inHours;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}min';
    } catch (e) {
      return 'Unknown';
    }
  }
}