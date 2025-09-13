import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RideListenerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Set up real-time listener for a specific ride document
  static StreamSubscription<DocumentSnapshot> listenToRide({
    required String rideId,
    required Function(RideStatus status, Map<String, dynamic> rideData) onStatusChange,
    required Function(String error) onError,
  }) {
    print('🎧 Setting up ride listener for: $rideId');
    
    return _firestore
        .collection('rides')
        .doc(rideId)
        .snapshots()
        .listen(
          (DocumentSnapshot snapshot) async {
            if (!snapshot.exists) {
              onError('Ride document not found');
              return;
            }

            final rideData = snapshot.data() as Map<String, dynamic>;
            final statusString = rideData['status'] as String?;
            
            if (statusString == null) {
              onError('Ride status is null');
              return;
            }

            final status = _parseRideStatus(statusString);
            print('🔄 Ride $rideId status changed to: $statusString');
            
            // Call the status change handler
            await onStatusChange(status, rideData);
          },
          onError: (error) {
            print('❌ Error listening to ride $rideId: $error');
            onError(error.toString());
          },
        );
  }

  /// Parse string status to RideStatus enum
  static RideStatus _parseRideStatus(String statusString) {
    switch (statusString.toLowerCase()) {
      case 'requesting':
        return RideStatus.requesting;
      case 'driver_assigned':
        return RideStatus.driverAssigned;
      case 'accepted':
        return RideStatus.accepted;
      case 'driver_arriving':
        return RideStatus.driverArriving;
      case 'driver_arrived':
        return RideStatus.driverArrived;
      case 'in_progress':
        return RideStatus.inProgress;
      case 'completed':
        return RideStatus.completed;
      case 'cancelled_by_customer':
        return RideStatus.cancelledByCustomer;
      case 'cancelled_by_driver':
        return RideStatus.cancelledByDriver;
      case 'timeout':
        return RideStatus.timeout;
      case 'no_drivers_available':
        return RideStatus.noDriversAvailable;
      case 'assignment_error':
        return RideStatus.assignmentError;
      default:
        return RideStatus.unknown;
    }
  }

  /// Get driver information from drivers collection
  static Future<Map<String, dynamic>?> getDriverInfo(String driverId) async {
    try {
      final driverDoc = await _firestore.collection('drivers').doc(driverId).get();
      
      if (driverDoc.exists) {
        return driverDoc.data();
      } else {
        print('❌ Driver document not found: $driverId');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching driver info: $e');
      return null;
    }
  }

  /// Update ride status (for driver actions)
  static Future<void> updateRideStatus({
    required String rideId,
    required String newStatus,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        ...?additionalData,
      };

      await _firestore.collection('rides').doc(rideId).update(updateData);
      print('✅ Updated ride $rideId status to: $newStatus');
    } catch (e) {
      print('❌ Error updating ride status: $e');
      rethrow;
    }
  }
}

/// Enum for ride statuses
enum RideStatus {
  requesting,
  driverAssigned,
  accepted,
  driverArriving,
  driverArrived,
  inProgress,
  completed,
  cancelledByCustomer,
  cancelledByDriver,
  timeout,
  noDriversAvailable,
  assignmentError,
  unknown,
}

/// Extension to get display text for ride statuses
extension RideStatusExtension on RideStatus {
  String get displayText {
    switch (this) {
      case RideStatus.requesting:
        return 'Looking for a driver...';
      case RideStatus.driverAssigned:
        return 'Driver found!';
      case RideStatus.accepted:
        return 'Driver is on the way';
      case RideStatus.driverArriving:
        return 'Driver is arriving';
      case RideStatus.driverArrived:
        return 'Your driver has arrived';
      case RideStatus.inProgress:
        return 'Trip in progress';
      case RideStatus.completed:
        return 'Trip completed';
      case RideStatus.cancelledByCustomer:
        return 'Trip cancelled';
      case RideStatus.cancelledByDriver:
        return 'Looking for a new driver...';
      case RideStatus.timeout:
        return 'Looking for a new driver...';
      case RideStatus.noDriversAvailable:
        return 'No drivers available nearby';
      case RideStatus.assignmentError:
        return 'Error finding driver';
      case RideStatus.unknown:
        return 'Unknown status';
    }
  }

  Color get statusColor {
    switch (this) {
      case RideStatus.requesting:
      case RideStatus.cancelledByDriver:
      case RideStatus.timeout:
        return Colors.orange;
      case RideStatus.driverAssigned:
      case RideStatus.accepted:
      case RideStatus.driverArriving:
        return Colors.blue;
      case RideStatus.driverArrived:
        return Colors.green;
      case RideStatus.inProgress:
        return Colors.purple;
      case RideStatus.completed:
        return Colors.green;
      case RideStatus.cancelledByCustomer:
      case RideStatus.noDriversAvailable:
      case RideStatus.assignmentError:
        return Colors.red;
      case RideStatus.unknown:
        return Colors.grey;
    }
  }

  IconData get statusIcon {
    switch (this) {
      case RideStatus.requesting:
      case RideStatus.cancelledByDriver:
      case RideStatus.timeout:
        return Icons.search;
      case RideStatus.driverAssigned:
        return Icons.person_pin_circle;
      case RideStatus.accepted:
      case RideStatus.driverArriving:
        return Icons.directions_car;
      case RideStatus.driverArrived:
        return Icons.location_on;
      case RideStatus.inProgress:
        return Icons.navigation;
      case RideStatus.completed:
        return Icons.check_circle;
      case RideStatus.cancelledByCustomer:
      case RideStatus.noDriversAvailable:
      case RideStatus.assignmentError:
        return Icons.error;
      case RideStatus.unknown:
        return Icons.help;
    }
  }
}

/// Widget for displaying ride status
class RideStatusWidget extends StatelessWidget {
  final RideStatus status;
  final Map<String, dynamic>? rideData;
  final Map<String, dynamic>? driverData;
  final VoidCallback? onCancel;

  const RideStatusWidget({
    super.key,
    required this.status,
    this.rideData,
    this.driverData,
    this.onCancel,
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
            
            // Driver information (if available)
            if (driverData != null) _buildDriverInfo(),
            
            // Ride details
            if (rideData != null) _buildRideDetails(),
            
            // Action buttons
            if (status == RideStatus.requesting || 
                status == RideStatus.driverAssigned) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onCancel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Cancel Ride'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDriverInfo() {
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
            'Your Driver',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                backgroundImage: driverData!['photoUrl'] != null
                    ? NetworkImage(driverData!['photoUrl'])
                    : null,
                child: driverData!['photoUrl'] == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverData!['name'] ?? 'Driver',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${driverData!['vehicleInfo']?['make']} ${driverData!['vehicleInfo']?['model']}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Plate: ${driverData!['vehicleInfo']?['plateNumber']}',
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
                        '${driverData!['rating']?.toStringAsFixed(1) ?? '0.0'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Text(
                    '${driverData!['totalTrips'] ?? 0} trips',
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

  Widget _buildRideDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trip Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        
        // Pickup location
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.radio_button_checked, color: Colors.green, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                rideData!['pickupAddress'] ?? 'Pickup location',
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
                rideData!['destinationAddress'] ?? 'Destination',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        // Fare and distance
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Fare: ₦${rideData!['estimatedFare']?.toStringAsFixed(0) ?? '0'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.green,
              ),
            ),
            if (rideData!['driverDistance'] != null)
              Text(
                'Distance: ${rideData!['driverDistance'].toStringAsFixed(1)}km',
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
}