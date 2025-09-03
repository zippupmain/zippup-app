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

      // Create a realistic ride request
      final rideId = FirebaseFirestore.instance.collection('rides').doc().id;
      await FirebaseFirestore.instance.collection('rides').doc(rideId).set({
        'riderId': uid,
        'status': 'requested',
        'type': 'taxi',
        'pickupAddress': 'Victoria Island, Lagos, Nigeria',
        'destinationAddress': 'Ikeja, Lagos, Nigeria',
        'pickupLat': 6.4281,
        'pickupLng': 3.4219,
        'destinationLat': 6.5927,
        'destinationLng': 3.3547,
        'createdAt': DateTime.now().toIso8601String(),
        'fare': 2500,
        'currency': 'NGN',
        'estimatedDuration': 25,
        'distance': 18.5,
      });

      // Also create public profile for customer if it doesn't exist
      await FirebaseFirestore.instance.collection('public_profiles').doc(uid).set({
        'name': 'Test Customer',
        'photoUrl': '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _loadRequestData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Test ride request created! ID: $rideId'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
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

  Future<void> _testCompleteFlow() async {
    setState(() {
      _loading = true;
      _debugInfo = 'Testing complete flow...';
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw 'No user authenticated';

      final StringBuffer info = StringBuffer();
      info.writeln('🧪 COMPLETE FLOW TEST\n');

      // Step 1: Check if user has transport provider profile
      info.writeln('Step 1: Checking transport provider profile...');
      final providerSnap = await FirebaseFirestore.instance
          .collection('provider_profiles')
          .where('userId', isEqualTo: uid)
          .where('service', isEqualTo: 'transport')
          .get();

      if (providerSnap.docs.isEmpty) {
        info.writeln('❌ No transport provider profile found');
        info.writeln('💡 Create one at /provider-debug');
      } else {
        final providerData = providerSnap.docs.first.data();
        final isOnline = providerData['availabilityOnline'] == true;
        final status = providerData['status'];
        info.writeln('✅ Transport provider profile found');
        info.writeln('   Status: $status');
        info.writeln('   Online: $isOnline');
        
        if (status != 'active') {
          info.writeln('⚠️ Provider status is not active');
        }
        if (!isOnline) {
          info.writeln('⚠️ Provider is not online');
        }
      }
      info.writeln('');

      // Step 2: Check for existing ride requests
      info.writeln('Step 2: Checking existing ride requests...');
      final ridesSnap = await FirebaseFirestore.instance
          .collection('rides')
          .where('status', isEqualTo: 'requested')
          .limit(5)
          .get();
      
      info.writeln('✅ Found ${ridesSnap.docs.length} requested rides');
      for (final doc in ridesSnap.docs) {
        final data = doc.data();
        info.writeln('   • ${doc.id}: ${data['pickupAddress']} → ${data['destinationAddress']}');
      }
      info.writeln('');

      // Step 3: Create test ride request
      info.writeln('Step 3: Creating test ride request...');
      final rideId = FirebaseFirestore.instance.collection('rides').doc().id;
      await FirebaseFirestore.instance.collection('rides').doc(rideId).set({
        'riderId': uid,
        'status': 'requested',
        'type': 'taxi',
        'pickupAddress': 'Lagos Island, Lagos, Nigeria',
        'destinationAddress': 'Surulere, Lagos, Nigeria',
        'pickupLat': 6.4541,
        'pickupLng': 3.3947,
        'destinationLat': 6.5027,
        'destinationLng': 3.3590,
        'createdAt': DateTime.now().toIso8601String(),
        'fare': 1800,
        'currency': 'NGN',
      });
      info.writeln('✅ Test ride created with ID: $rideId');
      info.writeln('');

      // Step 4: Check notifications
      info.writeln('Step 4: Checking notification system...');
      info.writeln('🔔 If you are a transport provider and online:');
      info.writeln('   • You should receive a phone-call style notification');
      info.writeln('   • Notification should have continuous sound');
      info.writeln('   • Accept button should navigate to tracking');
      info.writeln('   • Decline button should cancel the ride');
      info.writeln('');

      info.writeln('✅ Complete flow test finished!');
      info.writeln('');
      info.writeln('📋 Next Steps:');
      info.writeln('1. Ensure you have transport provider profile (active & online)');
      info.writeln('2. Watch for phone-call notification popup');
      info.writeln('3. Test accept/decline functionality');
      info.writeln('4. Verify tracking screen navigation');

      setState(() {
        _debugInfo = info.toString();
        _loading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Complete flow test completed! Check results above.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _debugInfo = '❌ Error testing complete flow: $e';
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadRequestData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _createTestRideRequest,
                    icon: const Icon(Icons.add),
                    label: const Text('Create Test Ride'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _testCompleteFlow,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Test Complete Flow'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
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