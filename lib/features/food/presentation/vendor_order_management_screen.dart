import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Vendor Order Management Dashboard
/// Handles order acceptance, preparation time setting, and driver assignment
class VendorOrderManagementScreen extends StatefulWidget {
  const VendorOrderManagementScreen({super.key});

  @override
  State<VendorOrderManagementScreen> createState() => _VendorOrderManagementScreenState();
}

class _VendorOrderManagementScreenState extends State<VendorOrderManagementScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _currentVendorId;
  String _statusFilter = 'all';
  
  // Real-time metrics
  int _pendingOrders = 0;
  int _activeOrders = 0;
  double _todayRevenue = 0.0;
  double _avgPrepTime = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeVendor();
  }

  Future<void> _initializeVendor() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      // Find vendor profile for current user
      final vendorQuery = await _db.collection('vendors')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (vendorQuery.docs.isNotEmpty) {
        setState(() {
          _currentVendorId = vendorQuery.docs.first.id;
        });
        _loadMetrics();
      }
    } catch (e) {
      print('❌ Error initializing vendor: $e');
    }
  }

  Future<void> _loadMetrics() async {
    if (_currentVendorId == null) return;

    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Load today's metrics
      final todayOrders = await _db.collection('food_orders')
          .where('vendorId', isEqualTo: _currentVendorId)
          .where('createdAt', isGreaterThan: Timestamp.fromDate(startOfDay))
          .get();

      double revenue = 0.0;
      int completed = 0;
      double totalPrepTime = 0.0;

      for (final doc in todayOrders.docs) {
        final data = doc.data();
        if (data['status'] == 'delivered') {
          revenue += (data['total'] as num?)?.toDouble() ?? 0.0;
          completed++;
          
          final prepTime = data['actualPrepTime'] as int?;
          if (prepTime != null) {
            totalPrepTime += prepTime;
          }
        }
      }

      setState(() {
        _todayRevenue = revenue;
        _avgPrepTime = completed > 0 ? totalPrepTime / completed : 0.0;
      });

    } catch (e) {
      print('❌ Error loading metrics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentVendorId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Management')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => context.push('/vendor/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          // Metrics dashboard
          _buildMetricsDashboard(),
          
          // Order filters
          _buildOrderFilters(),
          
          // Orders list
          Expanded(child: _buildOrdersList()),
        ],
      ),
    );
  }

  Widget _buildMetricsDashboard() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          Expanded(child: _buildMetricCard('Pending', '$_pendingOrders', Icons.pending, Colors.orange)),
          Expanded(child: _buildMetricCard('Active', '$_activeOrders', Icons.local_dining, Colors.blue)),
          Expanded(child: _buildMetricCard('Revenue', '₦${_todayRevenue.toStringAsFixed(0)}', Icons.attach_money, Colors.green)),
          Expanded(child: _buildMetricCard('Avg Prep', '${_avgPrepTime.toStringAsFixed(0)}m', Icons.timer, Colors.purple)),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('Filter: ', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          ...['all', 'pending', 'preparing', 'ready'].map((filter) =>
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(filter.toUpperCase()),
                selected: _statusFilter == filter,
                onSelected: (selected) => setState(() => _statusFilter = filter),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _getOrdersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final orders = snapshot.data!.docs;
        
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text('No orders found', style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 8),
                Text('Orders will appear here when customers place them'),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final orderData = orders[index].data();
            return VendorOrderCard(
              orderId: orders[index].id,
              orderData: orderData,
              onAccept: _acceptOrder,
              onDecline: _declineOrder,
              onMarkReady: _markOrderReady,
              onAssignDriver: _assignDriver,
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getOrdersStream() {
    Query<Map<String, dynamic>> query = _db.collection('food_orders')
        .where('vendorId', isEqualTo: _currentVendorId);

    // Apply status filter
    if (_statusFilter != 'all') {
      final statusMap = {
        'pending': 'pending_vendor_acceptance',
        'preparing': 'preparing',
        'ready': 'ready_for_pickup',
      };
      query = query.where('status', isEqualTo: statusMap[_statusFilter]);
    } else {
      // Show active orders only
      query = query.where('status', whereIn: [
        'pending_vendor_acceptance',
        'accepted_by_vendor', 
        'preparing',
        'ready_for_pickup',
        'assigned_to_driver',
      ]);
    }

    return query.orderBy('createdAt', descending: true).snapshots();
  }

  /// Accept order with preparation time
  Future<void> _acceptOrder(String orderId, int prepTimeMinutes) async {
    try {
      final prepDeadline = DateTime.now().add(Duration(minutes: prepTimeMinutes));
      
      await _db.collection('food_orders').doc(orderId).update({
        'status': 'accepted_by_vendor',
        'acceptedByVendorAt': FieldValue.serverTimestamp(),
        'prepTimeEstimate': prepTimeMinutes,
        'prepTimeDeadline': Timestamp.fromDate(prepDeadline),
        'estimatedReadyTime': Timestamp.fromDate(prepDeadline),
      });

      // Automatically transition to preparing
      Timer(const Duration(seconds: 2), () async {
        await _db.collection('food_orders').doc(orderId).update({
          'status': 'preparing',
          'prepStartedAt': FieldValue.serverTimestamp(),
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order accepted! Preparation time: ${prepTimeMinutes} minutes'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting order: $e')),
      );
    }
  }

  /// Decline order with reason
  Future<void> _declineOrder(String orderId, String reason) async {
    try {
      await _db.collection('food_orders').doc(orderId).update({
        'status': 'declined_by_vendor',
        'declinedAt': FieldValue.serverTimestamp(),
        'declineReason': reason,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order declined'),
          backgroundColor: Colors.orange,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error declining order: $e')),
      );
    }
  }

  /// Mark order as ready for pickup
  Future<void> _markOrderReady(String orderId) async {
    try {
      await _db.collection('food_orders').doc(orderId).update({
        'status': 'ready_for_pickup',
        'readyForPickupAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order marked as ready!'),
          backgroundColor: Colors.blue,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking order ready: $e')),
      );
    }
  }

  /// Assign driver to order
  Future<void> _assignDriver(String orderId, String driverId) async {
    try {
      await _db.collection('food_orders').doc(orderId).update({
        'driverId': driverId,
        'status': 'assigned_to_driver',
        'assignedToDriverAt': FieldValue.serverTimestamp(),
      });

      // Update driver status
      final driverQuery = await _db.collection('delivery_drivers')
          .where('userId', isEqualTo: driverId)
          .limit(1)
          .get();

      if (driverQuery.docs.isNotEmpty) {
        await driverQuery.docs.first.reference.update({
          'availabilityStatus': 'assigned',
          'currentOrderId': orderId,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Driver assigned successfully!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning driver: $e')),
      );
    }
  }
}

/// Individual order card widget
class VendorOrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> orderData;
  final Function(String, int) onAccept;
  final Function(String, String) onDecline;
  final Function(String) onMarkReady;
  final Function(String, String) onAssignDriver;

  const VendorOrderCard({
    super.key,
    required this.orderId,
    required this.orderData,
    required this.onAccept,
    required this.onDecline,
    required this.onMarkReady,
    required this.onAssignDriver,
  });

  @override
  Widget build(BuildContext context) {
    final status = orderData['status'] as String;
    final items = List<Map<String, dynamic>>.from(orderData['items'] ?? []);
    final total = (orderData['total'] as num?)?.toDouble() ?? 0.0;
    final customerLocation = orderData['customerLocation'] as Map<String, dynamic>?;
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order header with status and timing
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(_getStatusIcon(status), color: _getStatusColor(status)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${orderId.substring(0, 8)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        _getStatusDisplayName(status),
                        style: TextStyle(color: _getStatusColor(status), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₦${total.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(_getTimeDisplay(), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),

          // Order items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${item['quantity']}x', style: const TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item['name'] ?? 'Unknown Item')),
                      Text('₦${((item['price'] as num? ?? 0) * (item['quantity'] as num? ?? 1)).toStringAsFixed(0)}'),
                    ],
                  ),
                )),
              ],
            ),
          ),

          // Customer info
          if (customerLocation != null) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customerLocation['address'] ?? 'Unknown address',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildActionButtons(status),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String status) {
    switch (status) {
      case 'pending_vendor_acceptance':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showDeclineDialog(),
                icon: const Icon(Icons.close),
                label: const Text('Decline'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: () => _showAcceptDialog(),
                icon: const Icon(Icons.check),
                label: const Text('Accept Order'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
          ],
        );

      case 'preparing':
        return Column(
          children: [
            LinearProgressIndicator(
              value: _getPrepProgress(),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => onMarkReady(orderId),
                icon: const Icon(Icons.restaurant_menu),
                label: const Text('Mark as Ready'),
                style: FilledButton.styleFrom(backgroundColor: Colors.blue),
              ),
            ),
          ],
        );

      case 'ready_for_pickup':
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _showDriverAssignmentDialog(),
            icon: const Icon(Icons.delivery_dining),
            label: const Text('Assign Driver'),
            style: FilledButton.styleFrom(backgroundColor: Colors.purple),
          ),
        );

      default:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(_getStatusIcon(status), color: _getStatusColor(status)),
              const SizedBox(width: 12),
              Text(_getStatusDisplayName(status)),
            ],
          ),
        );
    }
  }

  void _showAcceptDialog() {
    final prepTimeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accept Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('How long will this order take to prepare?'),
            const SizedBox(height: 16),
            
            // Quick time buttons
            Wrap(
              spacing: 8,
              children: [15, 20, 25, 30, 35, 40, 45].map((minutes) =>
                ActionChip(
                  label: Text('${minutes}m'),
                  onPressed: () {
                    Navigator.pop(context);
                    onAccept(orderId, minutes);
                  },
                ),
              ).toList(),
            ),
            
            const SizedBox(height: 16),
            
            // Custom time input
            TextField(
              controller: prepTimeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Custom time (minutes)',
                border: OutlineInputBorder(),
                suffixText: 'min',
              ),
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
              final customTime = int.tryParse(prepTimeController.text);
              if (customTime != null && customTime > 0) {
                Navigator.pop(context);
                onAccept(orderId, customTime);
              }
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showDeclineDialog() {
    String reason = 'too_busy';
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Why are you declining this order?'),
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: reason,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'too_busy', child: Text('Too busy')),
                DropdownMenuItem(value: 'out_of_ingredients', child: Text('Out of ingredients')),
                DropdownMenuItem(value: 'closed', child: Text('Currently closed')),
                DropdownMenuItem(value: 'other', child: Text('Other reason')),
              ],
              onChanged: (value) => reason = value!,
            ),
            
            const SizedBox(height: 16),
            
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message to customer (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
              onDecline(orderId, reason);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Decline Order'),
          ),
        ],
      ),
    );
  }

  void _showDriverAssignmentDialog() {
    showDialog(
      context: context,
      builder: (context) => DriverAssignmentDialog(
        orderId: orderId,
        vendorLocation: orderData['vendorLocation'] as Map<String, dynamic>? ?? {},
        onAssignDriver: onAssignDriver,
      ),
    );
  }

  // Helper methods
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending_vendor_acceptance': return Colors.orange;
      case 'preparing': return Colors.blue;
      case 'ready_for_pickup': return Colors.green;
      case 'assigned_to_driver': return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending_vendor_acceptance': return Icons.pending;
      case 'preparing': return Icons.restaurant;
      case 'ready_for_pickup': return Icons.restaurant_menu;
      case 'assigned_to_driver': return Icons.delivery_dining;
      default: return Icons.info;
    }
  }

  String _getStatusDisplayName(String status) {
    switch (status) {
      case 'pending_vendor_acceptance': return 'Waiting for acceptance';
      case 'preparing': return 'Preparing order';
      case 'ready_for_pickup': return 'Ready for pickup';
      case 'assigned_to_driver': return 'Driver assigned';
      default: return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  double _getPrepProgress() {
    final prepStarted = orderData['prepStartedAt'] as Timestamp?;
    final prepTime = orderData['prepTimeEstimate'] as int?;
    
    if (prepStarted == null || prepTime == null) return 0.0;
    
    final elapsed = DateTime.now().difference(prepStarted.toDate()).inMinutes;
    return (elapsed / prepTime).clamp(0.0, 1.0);
  }

  String _getTimeDisplay() {
    final createdAt = orderData['createdAt'] as Timestamp?;
    if (createdAt == null) return '';
    
    final elapsed = DateTime.now().difference(createdAt.toDate());
    if (elapsed.inMinutes < 60) {
      return '${elapsed.inMinutes}m ago';
    } else {
      return '${elapsed.inHours}h ${elapsed.inMinutes % 60}m ago';
    }
  }
}

/// Driver assignment dialog
class DriverAssignmentDialog extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> vendorLocation;
  final Function(String, String) onAssignDriver;

  const DriverAssignmentDialog({
    super.key,
    required this.orderId,
    required this.vendorLocation,
    required this.onAssignDriver,
  });

  @override
  State<DriverAssignmentDialog> createState() => _DriverAssignmentDialogState();
}

class _DriverAssignmentDialogState extends State<DriverAssignmentDialog> {
  List<Map<String, dynamic>> _availableDrivers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNearbyDrivers();
  }

  Future<void> _loadNearbyDrivers() async {
    try {
      final vendorLat = widget.vendorLocation['latitude'] as double?;
      final vendorLng = widget.vendorLocation['longitude'] as double?;

      if (vendorLat == null || vendorLng == null) {
        setState(() => _loading = false);
        return;
      }

      // Get available drivers
      final driversQuery = await FirebaseFirestore.instance
          .collection('delivery_drivers')
          .where('isOnline', isEqualTo: true)
          .where('availabilityStatus', isEqualTo: 'available')
          .get();

      final drivers = <Map<String, dynamic>>[];

      for (final doc in driversQuery.docs) {
        final data = doc.data();
        final driverLat = data['currentLocation']?['latitude'] as double?;
        final driverLng = data['currentLocation']?['longitude'] as double?;

        if (driverLat != null && driverLng != null) {
          final distance = _calculateDistance(vendorLat, vendorLng, driverLat, driverLng);
          
          if (distance <= 10.0) { // Within 10km
            drivers.add({
              ...data,
              'id': data['userId'],
              'distance': distance,
              'estimatedArrival': (distance * 2).ceil(), // 2 min per km
            });
          }
        }
      }

      // Sort by distance
      drivers.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

      setState(() {
        _availableDrivers = drivers;
        _loading = false;
      });

    } catch (e) {
      print('❌ Error loading drivers: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.purple.shade600,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.delivery_dining, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text('Assign Driver', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Drivers list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _availableDrivers.isEmpty
                      ? _buildNoDriversView()
                      : _buildDriversList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDriversView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.no_accounts, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No drivers available nearby'),
          const SizedBox(height: 8),
          Text('Try again in a few minutes', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _loadNearbyDrivers,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _availableDrivers.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final driver = _availableDrivers[index];
        return _buildDriverCard(driver);
      },
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    final distance = driver['distance'] as double;
    final eta = driver['estimatedArrival'] as int;
    final rating = (driver['rating'] as num?)?.toDouble() ?? 4.0;
    final vehicle = driver['vehicle'] as Map<String, dynamic>? ?? {};

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(Icons.person, color: Colors.blue.shade700),
        ),
        title: Text(driver['name'] ?? 'Unknown Driver', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${vehicle['type'] ?? 'Vehicle'} • ${vehicle['plateNumber'] ?? 'No plate'}'),
            Text('${distance.toStringAsFixed(1)}km away • ETA: ${eta}min'),
            Row(
              children: [
                Icon(Icons.star, size: 16, color: Colors.amber),
                Text('${rating.toStringAsFixed(1)}'),
                const SizedBox(width: 8),
                Text('${driver['totalDeliveries'] ?? 0} deliveries'),
              ],
            ),
          ],
        ),
        trailing: FilledButton(
          onPressed: () {
            Navigator.pop(context);
            widget.onAssignDriver(widget.orderId, driver['id']);
          },
          child: const Text('Assign'),
        ),
        isThreeLine: true,
      ),
    );
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // km
    
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);
    
    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLng / 2) * math.sin(dLng / 2);
    
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180);
}