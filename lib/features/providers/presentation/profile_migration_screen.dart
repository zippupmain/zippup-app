import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class ProfileMigrationScreen extends StatefulWidget {
  const ProfileMigrationScreen({super.key});

  @override
  State<ProfileMigrationScreen> createState() => _ProfileMigrationScreenState();
}

class _ProfileMigrationScreenState extends State<ProfileMigrationScreen> {
  bool _migrating = false;
  String _migrationStatus = '';
  List<Map<String, dynamic>> _providerProfiles = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProviderProfiles();
  }

  Future<void> _loadProviderProfiles() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final profiles = await FirebaseFirestore.instance
          .collection('provider_profiles')
          .where('userId', isEqualTo: uid)
          .get();

      setState(() {
        _providerProfiles = profiles.docs.map((doc) => {
          'id': doc.id,
          'data': doc.data(),
        }).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _migrationStatus = 'Error loading profiles: $e';
        _loading = false;
      });
    }
  }

  Future<void> _migrateAllProfiles() async {
    setState(() {
      _migrating = true;
      _migrationStatus = 'Starting migration...';
    });

    try {
      int updated = 0;
      
      for (final profile in _providerProfiles) {
        final profileId = profile['id'] as String;
        final data = profile['data'] as Map<String, dynamic>;
        
        setState(() {
          _migrationStatus = 'Updating ${data['service']} profile...';
        });

        // Add new fields if they don't exist
        final updateData = <String, dynamic>{};
        
        // Add operational settings if missing
        if (!data.containsKey('operationalRadius')) {
          updateData['operationalRadius'] = 25.0; // Default 25km radius
        }
        if (!data.containsKey('hasRadiusLimit')) {
          updateData['hasRadiusLimit'] = false; // Default no limit
        }
        
        // Add enabled roles based on primary service type
        if (!data.containsKey('enabledRoles')) {
          final serviceType = data['serviceType']?.toString();
          if (serviceType != null && serviceType.isNotEmpty) {
            updateData['enabledRoles'] = {serviceType: true}; // Enable primary role
          } else {
            updateData['enabledRoles'] = {}; // Empty roles map
          }
        }
        
        // Add enabled classes if missing (for operational settings compatibility)
        if (!data.containsKey('enabledClasses')) {
          final serviceType = data['serviceType']?.toString();
          if (serviceType != null && serviceType.isNotEmpty) {
            updateData['enabledClasses'] = {serviceType: true}; // Enable primary class
          } else {
            updateData['enabledClasses'] = {}; // Empty classes map
          }
        }

        // Add delivery categories for delivery providers
        if (data['service'] == 'delivery' && !data.containsKey('enabledDeliveryCategories')) {
          updateData['enabledDeliveryCategories'] = {
            'Fast Food': true,
            'Grocery': true,
            'Marketplace': false,
            'Pharmacy': false,
            'Electronics': false,
            'Documents': false,
            'Flowers': false,
            'Gifts': false,
          };
        }

        // Update profile if there are changes
        if (updateData.isNotEmpty) {
          updateData['migratedAt'] = FieldValue.serverTimestamp();
          
          await FirebaseFirestore.instance
              .collection('provider_profiles')
              .doc(profileId)
              .update(updateData);
          
          updated++;
        }
      }

      setState(() {
        _migrationStatus = '✅ Migration completed! Updated $updated profiles with new features.';
        _migrating = false;
      });

      // Reload profiles to show updated data
      await _loadProviderProfiles();

    } catch (e) {
      setState(() {
        _migrationStatus = '❌ Migration failed: $e';
        _migrating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile Migration')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔄 Profile Migration'),
        backgroundColor: Colors.orange.shade50,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Migration info card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🆕 New Features Available',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Your existing provider profiles can be upgraded with new features:'),
                    const SizedBox(height: 8),
                    const Text('• Service Roles Manager (toggle multiple service types)'),
                    const Text('• Operational Settings (service radius control)'),
                    const Text('• Enhanced Class Toggles (precise targeting)'),
                    const Text('• Delivery Categories (for delivery providers)'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Current profiles
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📋 Your Provider Profiles (${_providerProfiles.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    
                    ..._providerProfiles.map((profile) {
                      final data = profile['data'] as Map<String, dynamic>;
                      final service = data['service']?.toString() ?? 'Unknown';
                      final subcategory = data['subcategory']?.toString() ?? 'Unknown';
                      final serviceType = data['serviceType']?.toString() ?? 'Not specified';
                      final hasNewFeatures = data.containsKey('enabledRoles') && data.containsKey('operationalRadius');
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: hasNewFeatures ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: hasNewFeatures ? Colors.green.shade300 : Colors.orange.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              hasNewFeatures ? Icons.check_circle : Icons.update,
                              color: hasNewFeatures ? Colors.green.shade600 : Colors.orange.shade600,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$service → $subcategory',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text('Service Type: $serviceType'),
                                  Text(
                                    hasNewFeatures ? '✅ Updated with new features' : '🔄 Needs migration',
                                    style: TextStyle(
                                      color: hasNewFeatures ? Colors.green.shade600 : Colors.orange.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Migration button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _migrating ? null : _migrateAllProfiles,
                icon: Icon(_migrating ? Icons.hourglass_empty : Icons.upgrade),
                label: Text(_migrating ? 'Migrating...' : '🚀 Upgrade All Profiles'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Migration status
            if (_migrationStatus.isNotEmpty)
              Card(
                color: _migrationStatus.contains('✅') ? Colors.green.shade50 : 
                       _migrationStatus.contains('❌') ? Colors.red.shade50 : Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _migrationStatus,
                    style: TextStyle(
                      color: _migrationStatus.contains('✅') ? Colors.green.shade700 : 
                             _migrationStatus.contains('❌') ? Colors.red.shade700 : Colors.blue.shade700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}