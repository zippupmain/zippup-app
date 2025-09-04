import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Delivery Provider Dashboard Screen
class DeliveryProviderDashboardScreen extends StatefulWidget {
  const DeliveryProviderDashboardScreen({super.key});

  @override
  State<DeliveryProviderDashboardScreen> createState() => _DeliveryProviderDashboardScreenState();
}

class _DeliveryProviderDashboardScreenState extends State<DeliveryProviderDashboardScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _online = false;
  bool _loading = true;
  String? _currentDeliveryId;
  
  // Dashboard metrics
  int _todayDeliveries = 0;
  double _todayEarnings = 0.0;
  double _averageRating = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeDeliveryProvider();
  }

  Future<void> _initializeDeliveryProvider() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final providerQuery = await _db.collection('provider_profiles')
          .where('userId', isEqualTo: uid)
          .where('service', isEqualTo: 'delivery')
          .limit(1)
          .get();

      if (providerQuery.docs.isNotEmpty) {
        final providerData = providerQuery.docs.first.data();
        setState(() {
          _online = providerData['availabilityOnline'] ?? false;
        });
        await _loadDashboardMetrics(uid);
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadDashboardMetrics(String uid) async {
    // Load metrics implementation
    setState(() {
      _todayDeliveries = 5; // Mock data
      _todayEarnings = 2500.0;
      _averageRating = 4.8;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Dashboard'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildStatusSection(),
            const SizedBox(height: 16),
            _buildMetricsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _online 
              ? [Colors.green.shade400, Colors.green.shade600]
              : [Colors.grey.shade400, Colors.grey.shade600],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              _online ? Icons.delivery_dining : Icons.delivery_dining_outlined,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 12),
            Text(
              _online ? 'You\'re Online' : 'You\'re Offline',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _toggleOnlineStatus(),
                icon: Icon(_online ? Icons.pause : Icons.play_arrow),
                label: Text(_online ? 'Go Offline' : 'Go Online'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _online ? Colors.green.shade600 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsSection() {
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.local_shipping, color: Colors.blue, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    '$_todayDeliveries',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                  const Text('Today\'s Deliveries', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.attach_money, color: Colors.green, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    '₦${_todayEarnings.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const Text('Today\'s Earnings', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _toggleOnlineStatus() async {
    // Toggle online status implementation
    setState(() => _online = !_online);
  }
}