import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/common/models/order.dart' as models;

class EnhancedDeliveryDashboardScreen extends StatefulWidget {
  const EnhancedDeliveryDashboardScreen({super.key});

  @override
  State<EnhancedDeliveryDashboardScreen> createState() => _EnhancedDeliveryDashboardScreenState();
}

class _EnhancedDeliveryDashboardScreenState extends State<EnhancedDeliveryDashboardScreen> {
  bool _online = true; // Default to online
  bool _loading = true;
  String _deliveryProviderId = '';
  String _userCity = '';
  final Map<String, bool> _businessPartnerships = {};
  List<Map<String, dynamic>> _availableBusinesses = [];
  models.OrderStatus? _filterStatus;

  @override
  void initState() {
    super.initState();
    _initializeDeliveryDashboard();
  }

  Future<void> _autoMigrateProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final providerDoc = await FirebaseFirestore.instance
          .collection('provider_profiles')
          .where('userId', isEqualTo: uid)
          .where('service', isEqualTo: 'delivery')
          .limit(1)
          .get();

      if (providerDoc.docs.isNotEmpty) {
        final data = providerDoc.docs.first.data();
        final updateData = <String, dynamic>{};

        // Add missing fields for new features
        if (!data.containsKey('enabledRoles')) {
          updateData['enabledRoles'] = {'delivery': true};
        }
        if (!data.containsKey('enabledClasses')) {
          updateData['enabledClasses'] = {'delivery': true};
        }
        if (!data.containsKey('operationalRadius')) {
          updateData['operationalRadius'] = 25.0;
        }
        if (!data.containsKey('hasRadiusLimit')) {
          updateData['hasRadiusLimit'] = false;
        }
        if (!data.containsKey('enabledDeliveryCategories')) {
          updateData['enabledDeliveryCategories'] = {
            'Food': true,
            'Grocery': true,
            'Marketplace': false,
            'Pharmacy': false,
          };
        }

        // Update profile if needed
        if (updateData.isNotEmpty) {
          updateData['autoMigratedAt'] = FieldValue.serverTimestamp();
          await providerDoc.docs.first.reference.update(updateData);
          print('✅ Auto-migrated delivery profile with new features');
          
          // Show user that profile was updated
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Profile updated with new features! Service Roles and Settings now available.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error during delivery auto-migration: $e');
    }
  }

  Future<void> _initializeDeliveryDashboard() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Auto-migrate profile first
      await _autoMigrateProfile();

      // Get user's city
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      _userCity = userDoc.data()?['city']?.toString() ?? '';

      // Get delivery provider profile
      final deliveryProviderDoc = await FirebaseFirestore.instance
          .collection('provider_profiles')
          .where('userId', isEqualTo: uid)
          .where('service', isEqualTo: 'delivery')
          .limit(1)
          .get();

      if (deliveryProviderDoc.docs.isNotEmpty) {
        final data = deliveryProviderDoc.docs.first.data();
        _deliveryProviderId = deliveryProviderDoc.docs.first.id;
        
        // Always default to online, update profile
        _online = true;
        
        // Update profile to be online (fire and forget)
        FirebaseFirestore.instance
            .collection('provider_profiles')
            .doc(_deliveryProviderId)
            .update({'availabilityOnline': true})
            .catchError((e) => print('Error updating online status: $e'));
        
        // Load business partnerships
        final selectedBusinesses = data['selectedBusinesses'] as Map<String, dynamic>? ?? {};
        selectedBusinesses.forEach((businessId, selected) {
          _businessPartnerships[businessId] = selected as bool;
        });
      }

      // Load all available businesses in city
      await _loadAvailableBusinesses();

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing dashboard: $e')),
        );
      }
    }
  }

  Future<void> _loadAvailableBusinesses() async {
    final businessesQuery = await FirebaseFirestore.instance
        .collection('provider_profiles')
        .where('service', whereIn: ['food', 'grocery'])
        .where('city', isEqualTo: _userCity)
        .where('status', isEqualTo: 'active')
        .get();

    _availableBusinesses = businessesQuery.docs.map((doc) => {
      'id': doc.id,
      'data': doc.data(),
      'businessName': doc.data()['businessName'] ?? 'Unnamed Business',
      'service': doc.data()['service'],
      'subcategory': doc.data()['subcategory'],
      'address': doc.data()['address'] ?? 'No address',
    }).toList();
  }

  Future<void> _toggleOnline(bool value) async {
    setState(() => _online = value);
    
    try {
      await FirebaseFirestore.instance
          .collection('provider_profiles')
          .doc(_deliveryProviderId)
          .update({
        'availabilityOnline': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  Future<void> _toggleBusinessPartnership(String businessId, bool value) async {
    setState(() => _businessPartnerships[businessId] = value);
    
    try {
      await FirebaseFirestore.instance
          .collection('provider_profiles')
          .doc(_deliveryProviderId)
          .update({
        'selectedBusinesses.$businessId': value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? '✅ Partnership activated' : '❌ Partnership removed'),
            backgroundColor: value ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating partnership: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Delivery Dashboard')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🚚 Delivery Dashboard'),
        backgroundColor: Colors.orange.shade50,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/operational-settings/delivery'),
            tooltip: 'Operational Settings',
          ),
          IconButton(
            icon: const Icon(Icons.business_center),
            onPressed: () => context.push('/delivery/business-partnerships'),
            tooltip: 'Manage Business Partnerships',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'roles':
                  context.push('/delivery/service-roles');
                  break;
                case 'settings':
                  context.push('/operational-settings/delivery');
                  break;
                case 'partnerships':
                  context.push('/delivery/business-partnerships');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'roles',
                child: ListTile(
                  leading: Icon(Icons.tune),
                  title: Text('Service Roles'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Operational Settings'),
                  dense: true,
                ),
              ),
              const PopupMenuItem(
                value: 'partnerships',
                child: ListTile(
                  leading: Icon(Icons.business_center),
                  title: Text('Business Partnerships'),
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Online status toggle
          Container(
            color: Colors.orange.shade50,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _online ? Icons.delivery_dining : Icons.delivery_dining_outlined,
                  color: _online ? Colors.green : Colors.grey,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _online ? '🟢 Online - Accepting Deliveries' : '🔴 Offline - Not Accepting',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _online ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                      Text(
                        'Partnered with ${_businessPartnerships.values.where((v) => v).length} businesses',
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _online,
                  onChanged: _toggleOnline,
                  activeColor: Colors.green,
                ),
              ],
            ),
          ),

          // Quick access features
          Container(
            color: Colors.orange.shade50,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  '⚙️ Delivery Provider Features',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/delivery/service-roles'),
                        icon: const Icon(Icons.tune),
                        label: const Text('Service Roles'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => context.push('/operational-settings/delivery'),
                        icon: const Icon(Icons.settings),
                        label: const Text('Settings'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Manual migration button for testing
                OutlinedButton.icon(
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🔄 Updating profile...')),
                    );
                    await _autoMigrateProfile();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Profile migration completed! Try Service Roles and Settings now.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.update),
                  label: const Text('🔄 Update Profile (if features not working)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          // Business partnerships section
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '🤝 Partnership Invitations',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => context.push('/delivery/business-partnerships'),
                      icon: const Icon(Icons.mail, size: 16),
                      label: const Text('View Invites'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Quick partnership toggles
                SizedBox(
                  height: 120,
                  child: _availableBusinesses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.business_center, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                                              'No partnership invitations yet',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Businesses will invite you to deliver for them.',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _availableBusinesses.length,
                          itemBuilder: (context, index) {
                            final business = _availableBusinesses[index];
                            final businessId = business['id'] as String;
                            final isPartnered = _businessPartnerships[businessId] ?? false;
                            final service = business['service'] as String;

                            return Container(
                              width: 200,
                              margin: const EdgeInsets.only(right: 12),
                              child: Card(
                                elevation: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    gradient: isPartnered 
                                        ? LinearGradient(
                                            colors: [
                                              Colors.green.withOpacity(0.1),
                                              Colors.green.withOpacity(0.05),
                                            ],
                                          )
                                        : null,
                                  ),
                                  child: CheckboxListTile(
                                    value: isPartnered,
                                    onChanged: (value) => _toggleBusinessPartnership(businessId, value ?? false),
                                    title: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          service == 'food' ? '🍕' : '🛒',
                                          style: const TextStyle(fontSize: 20),
                                        ),
                                        Text(
                                          business['businessName'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      business['subcategory'] as String,
                                      style: const TextStyle(fontSize: 10),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    activeColor: Colors.green,
                                    checkColor: Colors.white,
                                    dense: true,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Active delivery orders
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Filter tabs
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('📋 All History'),
                            selected: _filterStatus == null,
                            onSelected: (_) => setState(() => _filterStatus = null),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Assigned'),
                            selected: _filterStatus == models.OrderStatus.assigned,
                            onSelected: (_) => setState(() => _filterStatus = models.OrderStatus.assigned),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('En Route'),
                            selected: _filterStatus == models.OrderStatus.enroute,
                            onSelected: (_) => setState(() => _filterStatus = models.OrderStatus.enroute),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: const Text('Delivered'),
                            selected: _filterStatus == models.OrderStatus.delivered,
                            onSelected: (_) => setState(() => _filterStatus = models.OrderStatus.delivered),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Orders stream
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('orders')
                          .where('assignedCourierId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final orders = snapshot.data!.docs.map((doc) => 
                          models.Order.fromJson(doc.id, doc.data())
                        ).toList();

                        final filteredOrders = _filterStatus == null 
                            ? orders 
                            : orders.where((order) => order.status == _filterStatus).toList();

                        if (filteredOrders.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delivery_dining, size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  _filterStatus == null ? 'No delivery orders yet' : 'No ${_filterStatus?.name} orders',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Partner with businesses to start receiving delivery requests.',
                                  style: TextStyle(color: Colors.grey, fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final order = filteredOrders[index];
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(order.status),
                                  child: Text(
                                    order.status == models.OrderStatus.assigned ? '📦' :
                                    order.status == models.OrderStatus.enroute ? '🚚' :
                                    order.status == models.OrderStatus.delivered ? '✅' : '📋',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                                title: Text(
                                  'Order ${order.id.substring(0, 8)} • ${order.category.name}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Status: ${order.status.name.toUpperCase()}'),
                                    Text('📍 Order ID: ${order.id.substring(0, 8)}'),
                                  ],
                                ),
                                trailing: _buildOrderActions(order),
                                onTap: () => context.push('/track/order?orderId=${order.id}'),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(models.OrderStatus status) {
    switch (status) {
      case models.OrderStatus.assigned:
        return Colors.blue.shade100;
      case models.OrderStatus.enroute:
        return Colors.orange.shade100;
      case models.OrderStatus.delivered:
        return Colors.green.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Widget _buildOrderActions(models.Order order) {
    switch (order.status) {
      case models.OrderStatus.assigned:
        return ElevatedButton(
          onPressed: () => _updateOrderStatus(order.id, models.OrderStatus.enroute),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            minimumSize: const Size(80, 32),
          ),
          child: const Text('Start'),
        );
      case models.OrderStatus.enroute:
        return ElevatedButton(
          onPressed: () => _updateOrderStatus(order.id, models.OrderStatus.delivered),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            minimumSize: const Size(80, 32),
          ),
          child: const Text('Deliver'),
        );
      case models.OrderStatus.delivered:
        return const Icon(Icons.check_circle, color: Colors.green);
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _updateOrderStatus(String orderId, models.OrderStatus newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': newStatus.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Order status updated to ${newStatus.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating order: $e')),
        );
      }
    }
  }
}