import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zippup/services/rides/ride_listener_service.dart';

class RideTrackingScreen extends StatefulWidget {
  final String rideId;

  const RideTrackingScreen({
    super.key,
    required this.rideId,
  });

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  StreamSubscription<DocumentSnapshot>? _rideSubscription;
  RideStatus _currentStatus = RideStatus.requesting;
  Map<String, dynamic>? _rideData;
  Map<String, dynamic>? _driverData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupRideListener();
  }

  @override
  void dispose() {
    _rideSubscription?.cancel();
    super.dispose();
  }

  void _setupRideListener() {
    _rideSubscription = RideListenerService.listenToRide(
      rideId: widget.rideId,
      onStatusChange: _handleStatusChange,
      onError: _handleError,
    );
  }

  Future<void> _handleStatusChange(RideStatus status, Map<String, dynamic> rideData) async {
    setState(() {
      _currentStatus = status;
      _rideData = rideData;
      _isLoading = false;
      _error = null;
    });

    // Handle specific status changes
    switch (status) {
      case RideStatus.driverAssigned:
        await _handleDriverAssigned(rideData);
        break;
      case RideStatus.accepted:
        await _handleDriverAccepted(rideData);
        break;
      case RideStatus.driverArrived:
        _handleDriverArrived();
        break;
      case RideStatus.cancelledByDriver:
      case RideStatus.timeout:
        _handleDriverCancelled();
        break;
      case RideStatus.noDriversAvailable:
        _handleNoDriversAvailable();
        break;
      case RideStatus.completed:
        _handleRideCompleted();
        break;
      default:
        break;
    }
  }

  void _handleError(String error) {
    setState(() {
      _error = error;
      _isLoading = false;
    });
  }

  Future<void> _handleDriverAssigned(Map<String, dynamic> rideData) async {
    final driverId = rideData['driverId'] as String?;
    if (driverId != null) {
      // Show driver found message
      _showStatusMessage(
        '🚗 Driver Found!',
        'We found a driver for you. Waiting for confirmation...',
        Colors.blue,
      );

      // Fetch driver information
      final driverInfo = await RideListenerService.getDriverInfo(driverId);
      if (driverInfo != null) {
        setState(() {
          _driverData = driverInfo;
        });
      }
    }
  }

  Future<void> _handleDriverAccepted(Map<String, dynamic> rideData) async {
    final driverId = rideData['driverId'] as String?;
    if (driverId != null) {
      // Show driver accepted message
      _showStatusMessage(
        '✅ Driver Accepted!',
        'Your driver is on the way to pick you up.',
        Colors.green,
      );

      // Fetch driver information if not already loaded
      if (_driverData == null) {
        final driverInfo = await RideListenerService.getDriverInfo(driverId);
        if (driverInfo != null) {
          setState(() {
            _driverData = driverInfo;
          });
        }
      }

      // Start showing map (implement based on your map solution)
      _showMapView();
    }
  }

  void _handleDriverArrived() {
    _showStatusMessage(
      '📍 Driver Arrived!',
      'Your driver has arrived at the pickup location.',
      Colors.green,
    );

    // Play arrival sound or show more prominent notification
    _showArrivalNotification();
  }

  void _handleDriverCancelled() {
    _showStatusMessage(
      '🔄 Finding New Driver...',
      'The previous driver cancelled. We\'re finding you another driver.',
      Colors.orange,
    );

    // Clear driver data
    setState(() {
      _driverData = null;
    });
  }

  void _handleNoDriversAvailable() {
    _showStatusMessage(
      '😔 No Drivers Available',
      'No drivers are available in your area right now. Please try again later.',
      Colors.red,
    );
  }

  void _handleRideCompleted() {
    _showStatusMessage(
      '🎉 Trip Completed!',
      'Thank you for using our service. Please rate your experience.',
      Colors.green,
    );

    // Navigate to rating screen after a delay
    Future.delayed(const Duration(seconds: 2), () {
      _navigateToRatingScreen();
    });
  }

  void _showStatusMessage(String title, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(message),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showMapView() {
    // Implement map view showing driver location and route
    print('🗺️ Showing map view with driver location');
    // You can integrate Google Maps, Apple Maps, or any other mapping solution here
  }

  void _showArrivalNotification() {
    // Show more prominent arrival notification
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.green),
            SizedBox(width: 8),
            Text('Driver Arrived!'),
          ],
        ),
        content: const Text(
          'Your driver has arrived at the pickup location. Please proceed to the vehicle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToRatingScreen() {
    // Navigate to rating screen
    print('🧭 Navigating to rating screen');
    // Example: context.push('/rate-ride', extra: {'rideId': widget.rideId});
  }

  Future<void> _cancelRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride'),
        content: const Text('Are you sure you want to cancel this ride?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await RideListenerService.updateRideStatus(
          rideId: widget.rideId,
          newStatus: 'cancelled_by_customer',
          additionalData: {
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancellationReason': 'cancelled_by_customer',
          },
        );

        if (mounted) {
          Navigator.of(context).pop(); // Go back to previous screen
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel ride: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Ride'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          if (_currentStatus == RideStatus.requesting || 
              _currentStatus == RideStatus.driverAssigned)
            IconButton(
              onPressed: _cancelRide,
              icon: const Icon(Icons.close),
              tooltip: 'Cancel Ride',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading ride information...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _setupRideListener();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Ride status widget
          RideStatusWidget(
            status: _currentStatus,
            rideData: _rideData,
            driverData: _driverData,
            onCancel: (_currentStatus == RideStatus.requesting || 
                      _currentStatus == RideStatus.driverAssigned)
                ? _cancelRide
                : null,
          ),

          // Map placeholder (implement with your preferred mapping solution)
          if (_currentStatus == RideStatus.accepted ||
              _currentStatus == RideStatus.driverArriving ||
              _currentStatus == RideStatus.driverArrived ||
              _currentStatus == RideStatus.inProgress) ...[
            Container(
              height: 300,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map, size: 64, color: Colors.grey),
                    SizedBox(height: 8),
                    Text(
                      'Map View',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      'Integrate your preferred mapping solution here',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Additional action buttons based on status
          if (_currentStatus == RideStatus.driverArrived) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await RideListenerService.updateRideStatus(
                      rideId: widget.rideId,
                      newStatus: 'in_progress',
                      additionalData: {
                        'tripStartedAt': FieldValue.serverTimestamp(),
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Start Trip',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],

          if (_currentStatus == RideStatus.inProgress) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await RideListenerService.updateRideStatus(
                      rideId: widget.rideId,
                      newStatus: 'completed',
                      additionalData: {
                        'tripCompletedAt': FieldValue.serverTimestamp(),
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Complete Trip',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}