import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProviderDebugScreen extends StatefulWidget {
  const ProviderDebugScreen({super.key});

  @override
  State<ProviderDebugScreen> createState() => _ProviderDebugScreenState();
}

class _ProviderDebugScreenState extends State<ProviderDebugScreen> {
  String _debugInfo = 'Loading provider profiles...';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProviderProfiles();
  }

  Future<void> _loadProviderProfiles() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        setState(() {
          _debugInfo = '❌ No user authenticated';
          _loading = false;
        });
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('provider_profiles')
          .where('userId', isEqualTo: uid)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _debugInfo = '❌ No provider profiles found for user: $uid';
          _loading = false;
        });
        return;
      }

      final StringBuffer info = StringBuffer();
      info.writeln('👤 User ID: $uid');
      info.writeln('📋 Found ${snapshot.docs.length} provider profiles:\n');

      for (final doc in snapshot.docs) {
        final data = doc.data();
        info.writeln('🏢 Profile ID: ${doc.id}');
        info.writeln('   Service: ${data['service'] ?? 'Unknown'}');
        info.writeln('   Status: ${data['status'] ?? 'Unknown'}');
        info.writeln('   Online: ${data['availabilityOnline'] ?? false}');
        info.writeln('   Subcategory: ${data['subcategory'] ?? 'None'}');
        info.writeln('   Service Type: ${data['serviceType'] ?? 'None'}');
        info.writeln('   Enabled Classes: ${data['enabledClasses'] ?? 'None'}');
        info.writeln('   Has Radius Limit: ${data['hasRadiusLimit'] ?? false}');
        if (data['hasRadiusLimit'] == true) {
          info.writeln('   Operational Radius: ${data['operationalRadius'] ?? 'Unknown'} km');
        }
        info.writeln('   Location: ${data['lat']}, ${data['lng']}');
        info.writeln('');
      }

      setState(() {
        _debugInfo = info.toString();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _debugInfo = '❌ Error loading provider profiles: $e';
        _loading = false;
      });
    }
  }

  Future<void> _createTestProfiles() async {
    setState(() {
      _loading = true;
      _debugInfo = 'Creating test provider profiles...';
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw 'No user authenticated';

      final services = ['hire', 'emergency', 'moving', 'personal'];
      
      for (final service in services) {
        // Check if profile already exists
        final existingSnap = await FirebaseFirestore.instance
            .collection('provider_profiles')
            .where('userId', isEqualTo: uid)
            .where('service', isEqualTo: service)
            .get();

        if (existingSnap.docs.isEmpty) {
          // Create new profile
          await FirebaseFirestore.instance.collection('provider_profiles').add({
            'userId': uid,
            'service': service,
            'status': 'active',
            'availabilityOnline': true,
            'subcategory': service,
            'serviceType': service,
            'enabledClasses': {service: true},
            'hasRadiusLimit': false,
            'operationalRadius': 50.0,
            'lat': 6.5244, // Lagos coordinates
            'lng': 3.3792,
            'createdAt': FieldValue.serverTimestamp(),
            'businessName': 'Test $service Provider',
            'businessDescription': 'Test provider for $service services',
          });
        }
      }

      await _loadProviderProfiles();
    } catch (e) {
      setState(() {
        _debugInfo = '❌ Error creating test profiles: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Debug'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                _debugInfo,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _loadProviderProfiles,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _createTestProfiles,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Test Profiles'),
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
    );
  }
}