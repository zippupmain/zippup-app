import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RequestDebugScreen extends StatefulWidget {
  const RequestDebugScreen({super.key});

  @override
  State<RequestDebugScreen> createState() => _RequestDebugScreenState();
}

class _RequestDebugScreenState extends State<RequestDebugScreen> {
  String _debugInfo = 'Loading request data...';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRequestData();
  }

  Future<void> _loadRequestData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _debugInfo = '❌ No user authenticated';
          _loading = false;
        });
        return;
      }

      final StringBuffer info = StringBuffer();
      info.writeln('👤 User ID: $uid\n');

      // Check recent requests in all collections
      final collections = ['rides', 'hire_bookings', 'emergency_bookings', 'moving_bookings', 'personal_bookings'];
      
      for (final collection in collections) {
        info.writeln('📋 $collection:');
        try {
          final snapshot = await FirebaseFirestore.instance
              .collection(collection)
              .where('status', isEqualTo: 'requested')
              .limit(5)
              .get();
          
          if (snapshot.docs.isEmpty) {
            info.writeln('   ❌ No requested items found');
          } else {
            info.writeln('   ✅ Found ${snapshot.docs.length} requested items:');
            for (final doc in snapshot.docs) {
              final data = doc.data();
              final clientId = data['clientId'] ?? data['riderId'] ?? 'Unknown';
              final createdAt = data['createdAt'] ?? 'Unknown time';
              info.writeln('      • ID: ${doc.id}');
              info.writeln('        Client: $clientId');
              info.writeln('        Created: $createdAt');
              info.writeln('        Status: ${data['status']}');
              info.writeln('');
            }
          }
        } catch (e) {
          info.writeln('   ❌ Error querying $collection: $e');
        }
        info.writeln('');
      }

      // Check provider profiles
      info.writeln('🏢 Provider Profiles:');
      try {
        final providerSnapshot = await FirebaseFirestore.instance
            .collection('provider_profiles')
            .where('userId', isEqualTo: uid)
            .get();
        
        if (providerSnapshot.docs.isEmpty) {
          info.writeln('   ❌ No provider profiles found');
        } else {
          info.writeln('   ✅ Found ${providerSnapshot.docs.length} provider profiles:');
          for (final doc in providerSnapshot.docs) {
            final data = doc.data();
            info.writeln('      • Service: ${data['service']}');
            info.writeln('        Status: ${data['status']}');
            info.writeln('        Online: ${data['availabilityOnline']}');
            info.writeln('');
          }
        }
      } catch (e) {
        info.writeln('   ❌ Error querying provider profiles: $e');
      }

      setState(() {
        _debugInfo = info.toString();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _debugInfo = '❌ Error loading request data: $e';
        _loading = false;
      });
    }
  }

  Future<void> _createTestRideRequest() async {
    setState(() {
      _loading = true;
      _debugInfo = 'Creating test ride request...';
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw 'No user authenticated';

      await FirebaseFirestore.instance.collection('rides').add({
        'riderId': uid,
        'status': 'requested',
        'type': 'taxi',
        'pickupAddress': 'Test Pickup Location',
        'destinationAddress': 'Test Destination',
        'pickupLat': 6.5244,
        'pickupLng': 3.3792,
        'destinationLat': 6.5344,
        'destinationLng': 3.3892,
        'createdAt': DateTime.now().toIso8601String(),
        'fare': 1500,
        'currency': 'NGN',
      });

      await _loadRequestData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Test ride request created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _debugInfo = '❌ Error creating test request: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Debug'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      _debugInfo,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadRequestData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _createTestRideRequest,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Test Ride'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}