import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart' as lm;
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

/// Delivery Tracking Screen for Delivery Drivers
/// Similar to transport tracking but for delivery assignments
class DeliveryTrackingScreen extends StatefulWidget {
  final String deliveryId;

  const DeliveryTrackingScreen({super.key, required this.deliveryId});

  @override
  State<DeliveryTrackingScreen> createState() => _DeliveryTrackingScreenState();
}

class _DeliveryTrackingScreenState extends State<DeliveryTrackingScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Map<String, dynamic>? _deliveryData;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  GoogleMapController? _mapController;
  bool _isDriver = false;
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _startDeliveryTracking();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  void _startDeliveryTracking() {
    _db.collection('food_orders').doc(widget.deliveryId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _deliveryData = snapshot.data();
        });
        _updateMapMarkers();
        _checkDriverRole();
      }
    });
  }

  void _checkDriverRole() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final driverId = _deliveryData?['driverId'];
    setState(() {
      _isDriver = currentUserId != null && currentUserId == driverId;
    });

    // Start location updates if driver
    if (_isDriver && _deliveryData?['status'] != 'delivered') {
      _startLocationUpdates();
    }
  }

  void _startLocationUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      // Update driver location (implementation would use actual GPS)
      await _updateDriverLocation();
    });
  }

  Future<void> _updateDriverLocation() async {
    // This would use actual GPS location in production
    // For now, simulate location updates
    try {
      await _db.collection('food_orders').doc(widget.deliveryId).update({
        'driverLocation': {
          'latitude': 6.5244 + (DateTime.now().millisecondsSinceEpoch % 1000) / 100000,
          'longitude': 3.3792 + (DateTime.now().millisecondsSinceEpoch % 1000) / 100000,
          'lastUpdated': FieldValue.serverTimestamp(),
          'heading': 0.0,
          'speed': 25.0,
        },
      });
    } catch (e) {
      print('❌ Error updating driver location: $e');
    }
  }

  void _updateMapMarkers() {
    if (_deliveryData == null) return;

    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // Customer location
    final customerLoc = _deliveryData!['customerLocation'] as Map<String, dynamic>?;
    if (customerLoc != null) {
      markers.add(Marker(
        markerId: const MarkerId('customer'),
        position: LatLng(customerLoc['latitude'], customerLoc['longitude']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Delivery Address'),
      ));
    }

    // Vendor/Restaurant location
    final vendorLoc = _deliveryData!['vendorLocation'] as Map<String, dynamic>?;
    if (vendorLoc != null) {
      markers.add(Marker(
        markerId: const MarkerId('vendor'),
        position: LatLng(vendorLoc['latitude'], vendorLoc['longitude']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: _deliveryData!['vendorName'] ?? 'Pickup Location'),
      ));
    }

    // Driver location (if active)
    final driverLoc = _deliveryData!['driverLocation'] as Map<String, dynamic>?;
    final status = _deliveryData!['status'] as String;
    
    if (driverLoc != null && _isDriverActiveStatus(status)) {
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(driverLoc['latitude'], driverLoc['longitude']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Delivery Driver',
          snippet: _getDriverStatusText(status),
        ),
      ));

      // Add route polyline
      if (customerLoc != null && vendorLoc != null) {
        List<LatLng> routePoints = [];

        if (['driver_en_route_to_vendor', 'driver_at_vendor'].contains(status)) {
          // Driver going to restaurant
          routePoints = [
            LatLng(driverLoc['latitude'], driverLoc['longitude']),
            LatLng(vendorLoc['latitude'], vendorLoc['longitude']),
          ];
        } else {
          // Driver going to customer
          routePoints = [
            LatLng(driverLoc['latitude'], driverLoc['longitude']),
            LatLng(customerLoc['latitude'], customerLoc['longitude']),
          ];
        }

        polylines.add(Polyline(
          polylineId: const PolylineId('driver_route'),
          points: routePoints,
          color: Colors.green,
          width: 4,
        ));
      }
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_deliveryData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Tracking')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Delivery #${widget.deliveryId.substring(0, 8)}'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _openGoogleNavigation(),
            icon: const Icon(Icons.navigation),
          ),
        ],
      ),
      body: Column(
        children: [
          // Delivery status timeline
          _buildStatusTimeline(),
          
          // Map with real-time tracking
          Expanded(child: _buildTrackingMap()),
          
          // Driver action buttons (if driver)
          if (_isDriver) _buildDriverActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline() {
    final status = _deliveryData!['status'] as String;
    final statuses = [
      ('assigned_to_driver', 'Assignment Received', Icons.assignment),
      ('accepted_by_driver', 'Assignment Accepted', Icons.check_circle),
      ('driver_en_route_to_vendor', 'Going to Pickup', Icons.directions),
      ('driver_at_vendor', 'At Pickup Location', Icons.store),
      ('order_picked_up', 'Order Picked Up', Icons.shopping_bag),
      ('driver_en_route_to_customer', 'Delivering', Icons.local_shipping),
      ('driver_at_customer', 'Arrived at Customer', Icons.location_on),
      ('delivered', 'Delivered', Icons.verified),
    ];

    final currentIndex = statuses.indexWhere((s) => s.$1 == status);

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getStatusDisplayText(status),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          SizedBox(
            height: 60,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: statuses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final (statusKey, label, icon) = statuses[index];
                final isCompleted = index <= currentIndex;
                final isCurrent = index == currentIndex;
                
                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isCompleted ? Colors.blue.shade600 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                        border: isCurrent ? Border.all(color: Colors.orange, width: 3) : null,
                      ),
                      child: Icon(
                        icon,
                        color: isCompleted ? Colors.white : Colors.grey.shade600,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCompleted ? Colors.blue.shade600 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingMap() {
    if (_markers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Loading map...'),
          ],
        ),
      );
    }

    try {
      if (kIsWeb) {
        return _buildFlutterMap();
      } else {
        return _buildGoogleMap();
      }
    } catch (e) {
      return Center(child: Text('Map error: $e'));
    }
  }

  Widget _buildGoogleMap() {
    final firstMarker = _markers.first;
    
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: firstMarker.position,
        zoom: 13,
      ),
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: false,
      compassEnabled: true,
      onMapCreated: (GoogleMapController controller) {
        _mapController = controller;
      },
    );
  }

  Widget _buildFlutterMap() {
    final markers = _markers.map((marker) => lm.Marker(
      point: ll.LatLng(marker.position.latitude, marker.position.longitude),
      width: 40,
      height: 40,
      child: Icon(
        marker.markerId.value == 'driver' ? Icons.delivery_dining :
        marker.markerId.value == 'vendor' ? Icons.store :
        Icons.location_on,
        color: marker.markerId.value == 'driver' ? Colors.green :
               marker.markerId.value == 'vendor' ? Colors.orange :
               Colors.blue,
        size: 30,
      ),
    )).toList();

    return lm.FlutterMap(
      options: lm.MapOptions(
        initialCenter: markers.isNotEmpty 
          ? markers.first.point 
          : ll.LatLng(6.5244, 3.3792),
        initialZoom: 13,
      ),
      children: [
        lm.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.zippup.app',
        ),
        lm.MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildDriverActionButtons() {
    final status = _deliveryData!['status'] as String;
    
    switch (status) {
      case 'assigned_to_driver':
        return _buildActionButton(
          'Accept Assignment',
          Icons.check_circle,
          Colors.green,
          () => _updateDeliveryStatus('accepted_by_driver'),
        );
        
      case 'accepted_by_driver':
        return _buildActionButton(
          'Going to Pickup',
          Icons.directions,
          Colors.orange,
          () => _updateDeliveryStatus('driver_en_route_to_vendor'),
        );
        
      case 'driver_en_route_to_vendor':
        return _buildActionButton(
          'Arrived at Pickup',
          Icons.store,
          Colors.blue,
          () => _updateDeliveryStatus('driver_at_vendor'),
        );
        
      case 'driver_at_vendor':
        return _buildActionButton(
          'Order Picked Up',
          Icons.shopping_bag,
          Colors.green,
          () => _updateDeliveryStatus('order_picked_up'),
        );
        
      case 'order_picked_up':
        return _buildActionButton(
          'Going to Customer',
          Icons.local_shipping,
          Colors.purple,
          () => _updateDeliveryStatus('driver_en_route_to_customer'),
        );
        
      case 'driver_en_route_to_customer':
        return _buildActionButton(
          'Arrived at Customer',
          Icons.location_on,
          Colors.teal,
          () => _updateDeliveryStatus('driver_at_customer'),
        );
        
      case 'driver_at_customer':
        return _buildDeliveryCodeInput();
        
      default:
        return _buildStatusDisplay();
    }
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(text),
          style: FilledButton.styleFrom(
            backgroundColor: color,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildDeliveryCodeInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter Delivery Code',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Ask customer for their delivery code to complete the delivery'),
          const SizedBox(height: 16),
          
          // 6-digit code input
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) => 
              Container(
                width: 45,
                height: 55,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                  onChanged: (value) => _onCodeDigitChanged(index, value),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _reportDeliveryIssue(),
                  icon: const Icon(Icons.report_problem),
                  label: const Text('Report Issue'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _verifyDeliveryCode,
                  icon: const Icon(Icons.verified),
                  label: const Text('Complete Delivery'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDisplay() {
    final status = _deliveryData!['status'] as String;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(_getStatusIcon(status), color: _getStatusColor(status)),
            const SizedBox(width: 12),
            Text(_getStatusDisplayText(status)),
          ],
        ),
      ),
    );
  }

  Future<void> _updateDeliveryStatus(String newStatus) async {
    try {
      await _db.collection('food_orders').doc(widget.deliveryId).update({
        'status': newStatus,
        '${newStatus.replaceAll('_', '')}At': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated: ${_getStatusDisplayText(newStatus)}'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status: $e')),
      );
    }
  }

  final List<TextEditingController> _codeControllers = List.generate(6, (_) => TextEditingController());

  void _onCodeDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      FocusScope.of(context).nextFocus();
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).previousFocus();
    }
  }

  Future<void> _verifyDeliveryCode() async {
    final enteredCode = _codeControllers.map((c) => c.text).join('');
    
    if (enteredCode.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all 6 digits')),
      );
      return;
    }

    try {
      // Verify delivery code
      final correctCode = _deliveryData!['deliveryCode'] as String;
      
      if (enteredCode.toUpperCase() == correctCode.toUpperCase()) {
        // Success - mark as delivered
        await _db.collection('food_orders').doc(widget.deliveryId).update({
          'status': 'delivered',
          'deliveredAt': FieldValue.serverTimestamp(),
          'codeVerifiedAt': FieldValue.serverTimestamp(),
          'deliveryCompletedBy': FirebaseAuth.instance.currentUser?.uid,
        });

        // Update driver availability
        await _updateDriverAvailability();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Delivery completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate back to dashboard
        Navigator.pop(context);

      } else {
        // Invalid code
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Invalid delivery code. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        
        // Clear the input for retry
        for (final controller in _codeControllers) {
          controller.clear();
        }
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification error: $e')),
      );
    }
  }

  Future<void> _updateDriverAvailability() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Update delivery driver status
      final driverQuery = await _db.collection('delivery_drivers')
          .where('userId', isEqualTo: uid)
          .limit(1)
          .get();

      if (driverQuery.docs.isNotEmpty) {
        await driverQuery.docs.first.reference.update({
          'availabilityStatus': 'available',
          'currentOrderId': null,
          'lastDeliveryCompletedAt': FieldValue.serverTimestamp(),
          'totalDeliveries': FieldValue.increment(1),
        });
      }

      // Update provider profile
      final providerQuery = await _db.collection('provider_profiles')
          .where('userId', isEqualTo: uid)
          .where('service', isEqualTo: 'delivery')
          .limit(1)
          .get();

      if (providerQuery.docs.isNotEmpty) {
        await providerQuery.docs.first.reference.update({
          'availabilityStatus': 'available',
          'currentOrderId': null,
        });
      }

    } catch (e) {
      print('❌ Error updating driver availability: $e');
    }
  }

  Future<void> _openGoogleNavigation() async {
    final driverLoc = _deliveryData!['driverLocation'] as Map<String, dynamic>?;
    final customerLoc = _deliveryData!['customerLocation'] as Map<String, dynamic>?;
    final vendorLoc = _deliveryData!['vendorLocation'] as Map<String, dynamic>?;
    final status = _deliveryData!['status'] as String;

    if (driverLoc == null) return;

    double? targetLat, targetLng;
    
    if (['driver_en_route_to_vendor', 'driver_at_vendor'].contains(status) && vendorLoc != null) {
      targetLat = vendorLoc['latitude'];
      targetLng = vendorLoc['longitude'];
    } else if (customerLoc != null) {
      targetLat = customerLoc['latitude'];
      targetLng = customerLoc['longitude'];
    }

    if (targetLat != null && targetLng != null) {
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=${driverLoc['latitude']},${driverLoc['longitude']}&destination=$targetLat,$targetLng&travelmode=driving'
      );
      
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open navigation: $e')),
        );
      }
    }
  }

  void _reportDeliveryIssue() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Delivery Issue'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person_off),
              title: Text('Customer not available'),
            ),
            ListTile(
              leading: Icon(Icons.location_off),
              title: Text('Wrong address'),
            ),
            ListTile(
              leading: Icon(Icons.code_off),
              title: Text('Customer lost delivery code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Issue reported. Support will contact you.'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  // Helper methods
  bool _isDriverActiveStatus(String status) {
    return [
      'accepted_by_driver',
      'driver_en_route_to_vendor',
      'driver_at_vendor',
      'order_picked_up',
      'driver_en_route_to_customer',
      'driver_at_customer'
    ].contains(status);
  }

  String _getDriverStatusText(String status) {
    switch (status) {
      case 'driver_en_route_to_vendor': return 'Going to pickup';
      case 'driver_at_vendor': return 'At pickup location';
      case 'order_picked_up': return 'Order picked up';
      case 'driver_en_route_to_customer': return 'Delivering to customer';
      case 'driver_at_customer': return 'Arrived at customer';
      default: return 'Assigned';
    }
  }

  String _getStatusDisplayText(String status) {
    switch (status) {
      case 'assigned_to_driver': return 'Assignment received';
      case 'accepted_by_driver': return 'Assignment accepted';
      case 'driver_en_route_to_vendor': return 'Going to pickup location';
      case 'driver_at_vendor': return 'At pickup location';
      case 'order_picked_up': return 'Order picked up';
      case 'driver_en_route_to_customer': return 'Delivering to customer';
      case 'driver_at_customer': return 'Arrived at customer';
      case 'delivered': return 'Delivery completed!';
      default: return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'assigned_to_driver': return Colors.orange;
      case 'accepted_by_driver': return Colors.blue;
      case 'driver_en_route_to_vendor': return Colors.purple;
      case 'driver_at_vendor': return Colors.teal;
      case 'order_picked_up': return Colors.indigo;
      case 'driver_en_route_to_customer': return Colors.green;
      case 'driver_at_customer': return Colors.red;
      case 'delivered': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'assigned_to_driver': return Icons.assignment;
      case 'accepted_by_driver': return Icons.check_circle;
      case 'driver_en_route_to_vendor': return Icons.directions;
      case 'driver_at_vendor': return Icons.store;
      case 'order_picked_up': return Icons.shopping_bag;
      case 'driver_en_route_to_customer': return Icons.local_shipping;
      case 'driver_at_customer': return Icons.location_on;
      case 'delivered': return Icons.verified;
      default: return Icons.info;
    }
  }
}