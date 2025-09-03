import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart' as lm;
import 'package:latlong2/latlong.dart' as ll;

/// Real-time food order tracking screen for customers
/// Features live driver tracking, status updates, and delivery code display
class FoodOrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const FoodOrderTrackingScreen({super.key, required this.orderId});

  @override
  State<FoodOrderTrackingScreen> createState() => _FoodOrderTrackingScreenState();
}

class _FoodOrderTrackingScreenState extends State<FoodOrderTrackingScreen> {
  StreamSubscription<DocumentSnapshot>? _orderSubscription;
  Map<String, dynamic>? _orderData;
  GoogleMapController? _mapController;
  
  // Map markers and polylines
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _startOrderTracking();
  }

  @override
  void dispose() {
    _orderSubscription?.cancel();
    super.dispose();
  }

  void _startOrderTracking() {
    _orderSubscription = FirebaseFirestore.instance
        .collection('food_orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        setState(() {
          _orderData = snapshot.data();
        });
        _updateMap();
        _handleStatusUpdates();
      }
    });
  }

  void _updateMap() {
    if (_orderData == null) return;

    final markers = <Marker>{};
    final polylines = <Polyline>{};

    // Customer location marker
    final customerLoc = _orderData!['customerLocation'] as Map<String, dynamic>?;
    if (customerLoc != null) {
      markers.add(Marker(
        markerId: const MarkerId('customer'),
        position: LatLng(customerLoc['latitude'], customerLoc['longitude']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Delivery Address'),
      ));
    }

    // Vendor location marker  
    final vendorLoc = _orderData!['vendorLocation'] as Map<String, dynamic>?;
    if (vendorLoc != null) {
      markers.add(Marker(
        markerId: const MarkerId('vendor'),
        position: LatLng(vendorLoc['latitude'], vendorLoc['longitude']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(title: _orderData!['vendorName'] ?? 'Restaurant'),
      ));
    }

    // Driver location marker (if active)
    final driverLoc = _orderData!['driverLocation'] as Map<String, dynamic>?;
    final status = _orderData!['status'] as String;
    
    if (driverLoc != null && 
        driverLoc['latitude'] != null && 
        driverLoc['longitude'] != null &&
        _isDriverActiveStatus(status)) {
      
      markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: LatLng(driverLoc['latitude'], driverLoc['longitude']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: _orderData!['driverName'] ?? 'Your Driver',
          snippet: _getDriverStatusText(status),
        ),
      ));

      // Add route polyline
      if (customerLoc != null && vendorLoc != null) {
        List<LatLng> routePoints = [];

        // Route based on driver status
        if (['driver_en_route_to_vendor', 'driver_at_vendor'].contains(status)) {
          // Driver going to vendor
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

    // Auto-fit map to show all markers
    _fitMapToMarkers();
  }

  void _handleStatusUpdates() {
    final status = _orderData!['status'] as String;
    
    // Show notifications for key status changes
    switch (status) {
      case 'accepted_by_vendor':
        _showStatusNotification('Order Accepted!', 'Your order is being prepared', Colors.green);
        break;
      case 'ready_for_pickup':
        _showStatusNotification('Order Ready!', 'Looking for a delivery driver', Colors.blue);
        break;
      case 'assigned_to_driver':
        final driverName = _orderData!['driverName'] ?? 'Driver';
        _showStatusNotification('Driver Assigned!', '$driverName will deliver your order', Colors.purple);
        break;
      case 'order_picked_up':
        _showStatusNotification('Order Picked Up!', 'Your order is on the way', Colors.orange);
        break;
      case 'driver_at_customer':
        _showStatusNotification('Driver Arrived!', 'Your delivery code is needed', Colors.red);
        _showDeliveryCodeBottomSheet();
        break;
      case 'delivered':
        _showStatusNotification('Order Delivered!', 'Enjoy your meal!', Colors.green);
        _showRatingDialog();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_orderData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Tracking')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${widget.orderId.substring(0, 8)}'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _showOrderDetails(),
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          // Status timeline
          _buildStatusTimeline(),
          
          // Live map
          Expanded(child: _buildTrackingMap()),
          
          // Order info and delivery code
          _buildOrderInfoSection(),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline() {
    final status = _orderData!['status'] as String;
    final statuses = [
      ('pending_vendor_acceptance', 'Order Placed', Icons.restaurant_menu),
      ('preparing', 'Preparing', Icons.restaurant),
      ('ready_for_pickup', 'Ready', Icons.check_circle),
      ('assigned_to_driver', 'Driver Assigned', Icons.delivery_dining),
      ('order_picked_up', 'Picked Up', Icons.shopping_bag),
      ('driver_en_route_to_customer', 'On the Way', Icons.directions),
      ('driver_at_customer', 'Arrived', Icons.location_on),
      ('delivered', 'Delivered', Icons.verified),
    ];

    final currentIndex = statuses.indexWhere((s) => s.$1 == status);

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _getStatusDisplayText(status),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          // Timeline
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
                        color: isCompleted ? Colors.green : Colors.grey.shade300,
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
                        color: isCompleted ? Colors.green : Colors.grey.shade600,
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
        // Use flutter_map for web
        return _buildFlutterMap();
      } else {
        // Use Google Maps for mobile
        return _buildGoogleMap();
      }
    } catch (e) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text('Map failed to load'),
            Text('Error: $e'),
          ],
        ),
      );
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
        _fitMapToMarkers();
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
        marker.markerId.value == 'vendor' ? Icons.restaurant :
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

  Widget _buildOrderInfoSection() {
    final status = _orderData!['status'] as String;
    final deliveryCode = _orderData!['deliveryCode'] as String?;
    final prepTime = _orderData!['prepTimeEstimate'] as int?;
    final driverName = _orderData!['driverName'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preparation time (if available)
          if (prepTime != null && ['preparing', 'ready_for_pickup'].contains(status)) ...[
            _buildInfoCard(
              'Preparation Time',
              '${prepTime} minutes',
              Icons.timer,
              Colors.blue,
              _buildPrepTimeProgress(),
            ),
            const SizedBox(height: 12),
          ],

          // Driver info (if assigned)
          if (driverName != null) ...[
            _buildDriverInfoCard(),
            const SizedBox(height: 12),
          ],

          // Delivery code (when driver arrives)
          if (deliveryCode != null && ['driver_at_customer', 'delivery_code_verification'].contains(status)) ...[
            _buildDeliveryCodeCard(deliveryCode),
            const SizedBox(height: 12),
          ],

          // Order actions
          _buildOrderActions(),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String subtitle, IconData icon, Color color, [Widget? trailing]) {
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: trailing,
      ),
    );
  }

  Widget _buildPrepTimeProgress() {
    final prepStarted = _orderData!['prepStartedAt'] as Timestamp?;
    final prepTime = _orderData!['prepTimeEstimate'] as int?;
    
    if (prepStarted == null || prepTime == null) {
      return const SizedBox.shrink();
    }

    final elapsed = DateTime.now().difference(prepStarted.toDate()).inMinutes;
    final progress = (elapsed / prepTime).clamp(0.0, 1.0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${elapsed}/${prepTime}m'),
        const SizedBox(height: 4),
        SizedBox(
          width: 60,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0 ? Colors.green : Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDriverInfoCard() {
    final driverName = _orderData!['driverName'] as String;
    final driverVehicle = _orderData!['driverVehicle'] as Map<String, dynamic>?;
    final status = _orderData!['status'] as String;

    return Card(
      color: Colors.green.shade50,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.delivery_dining, color: Colors.green.shade700),
        ),
        title: Text(driverName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (driverVehicle != null) 
              Text('${driverVehicle['type']} • ${driverVehicle['plateNumber']}'),
            Text(_getDriverStatusText(status)),
          ],
        ),
        trailing: IconButton(
          onPressed: () => _callDriver(),
          icon: Icon(Icons.phone, color: Colors.green.shade700),
        ),
        isThreeLine: driverVehicle != null,
      ),
    );
  }

  Widget _buildDeliveryCodeCard(String deliveryCode) {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.key, color: Colors.amber.shade700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Delivery Code',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Give this code to the driver',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Large delivery code display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: deliveryCode.split('').map((char) => 
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      char,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderActions() {
    final status = _orderData!['status'] as String;
    
    if (['pending_vendor_acceptance', 'accepted_by_vendor', 'preparing'].contains(status)) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _showCancelOrderDialog(),
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Cancel Order'),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
        ),
      );
    }

    if (status == 'delivered') {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => _showRatingDialog(),
          icon: const Icon(Icons.star),
          label: const Text('Rate Your Experience'),
          style: FilledButton.styleFrom(backgroundColor: Colors.green),
        ),
      );
    }

    return const SizedBox.shrink();
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
      case 'driver_en_route_to_vendor': return 'Going to restaurant';
      case 'driver_at_vendor': return 'At restaurant';
      case 'order_picked_up': return 'Order picked up';
      case 'driver_en_route_to_customer': return 'On the way to you';
      case 'driver_at_customer': return 'Arrived at your location';
      default: return 'Assigned';
    }
  }

  String _getStatusDisplayText(String status) {
    switch (status) {
      case 'pending_vendor_acceptance': return 'Waiting for restaurant confirmation';
      case 'accepted_by_vendor': return 'Order confirmed by restaurant';
      case 'preparing': return 'Your order is being prepared';
      case 'ready_for_pickup': return 'Order ready, finding driver';
      case 'assigned_to_driver': return 'Driver assigned to your order';
      case 'accepted_by_driver': return 'Driver confirmed pickup';
      case 'driver_en_route_to_vendor': return 'Driver going to restaurant';
      case 'driver_at_vendor': return 'Driver at restaurant';
      case 'order_picked_up': return 'Order picked up by driver';
      case 'driver_en_route_to_customer': return 'Driver on the way to you';
      case 'driver_at_customer': return 'Driver has arrived!';
      case 'delivered': return 'Order delivered successfully!';
      default: return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  void _fitMapToMarkers() {
    if (_mapController == null || _markers.isEmpty) return;

    final bounds = _calculateBounds(_markers.map((m) => m.position).toList());
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      maxLat = math.max(maxLat, point.latitude);
      minLng = math.min(minLng, point.longitude);
      maxLng = math.max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  void _showStatusNotification(String title, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(message),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showDeliveryCodeBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delivery_dining, size: 48, color: Colors.green),
            const SizedBox(height: 16),
            const Text(
              'Driver Arrived!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your delivery code is:',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            
            // Large code display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade300, width: 2),
              ),
              child: Text(
                deliveryCode ?? 'N/A',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: Colors.amber.shade700,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Give this code to the driver to complete your delivery',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 24),
            
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it!'),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetails() {
    // Implementation for showing full order details
  }

  void _showCancelOrderDialog() {
    // Implementation for order cancellation
  }

  void _showRatingDialog() {
    // Implementation for rating and feedback
  }

  void _callDriver() {
    // Implementation for calling driver (if phone number available)
  }
}