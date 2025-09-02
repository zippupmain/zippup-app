import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class DeliveryBusinessSelectionScreen extends StatefulWidget {
  const DeliveryBusinessSelectionScreen({super.key});

  @override
  State<DeliveryBusinessSelectionScreen> createState() => _DeliveryBusinessSelectionScreenState();
}

class _DeliveryBusinessSelectionScreenState extends State<DeliveryBusinessSelectionScreen> {
  final Map<String, bool> _selectedBusinesses = {};
  List<Map<String, dynamic>> _availableBusinesses = [];
  bool _loading = true;
  bool _saving = false;
  String _userCity = '';

  @override
  void initState() {
    super.initState();
    _loadBusinessesAndSelections();
  }

  Future<void> _loadBusinessesAndSelections() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Get user's city from profile
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      
      _userCity = userDoc.data()?['city']?.toString() ?? '';

      // Load all food and grocery businesses in the same city
      final businessesQuery = await FirebaseFirestore.instance
          .collection('provider_profiles')
          .where('service', whereIn: ['food', 'grocery'])
          .where('city', isEqualTo: _userCity)
          .where('status', isEqualTo: 'active')
          .get();

      _availableBusinesses = businessesQuery.docs.map((doc) => {
        'id': doc.id,
        'data': doc.data(),
        'userId': doc.data()['userId'],
        'businessName': doc.data()['businessName'] ?? 'Unnamed Business',
        'service': doc.data()['service'],
        'subcategory': doc.data()['subcategory'],
        'address': doc.data()['address'] ?? 'No address',
      }).toList();

      // Load current delivery provider's selected businesses
      final deliveryProviderDoc = await FirebaseFirestore.instance
          .collection('provider_profiles')
          .where('userId', isEqualTo: uid)
          .where('service', isEqualTo: 'delivery')
          .limit(1)
          .get();

      if (deliveryProviderDoc.docs.isNotEmpty) {
        final data = deliveryProviderDoc.docs.first.data();
        final selectedBusinessIds = data['selectedBusinesses'] as Map<String, dynamic>? ?? {};
        
        setState(() {
          _selectedBusinesses.clear();
          selectedBusinessIds.forEach((businessId, selected) {
            _selectedBusinesses[businessId] = selected as bool;
          });
        });
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading businesses: $e')),
        );
      }
    }
  }

  Future<void> _saveBusinessSelections() async {
    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Update delivery provider profile with selected businesses
      final deliveryProviderQuery = await FirebaseFirestore.instance
          .collection('provider_profiles')
          .where('userId', isEqualTo: uid)
          .where('service', isEqualTo: 'delivery')
          .limit(1)
          .get();

      if (deliveryProviderQuery.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('provider_profiles')
            .doc(deliveryProviderQuery.docs.first.id)
            .update({
          'selectedBusinesses': _selectedBusinesses,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Business partnerships updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error saving selections: $e')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Business Partnerships')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🤝 Business Partnerships'),
        backgroundColor: Colors.orange.shade50,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: Column(
        children: [
          // Header info
          Container(
            color: Colors.orange.shade50,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  '🎯 Select Businesses to Partner With',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose food and grocery businesses in $_userCity that you want to deliver for. They can assign orders to you.',
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '📍 Found ${_availableBusinesses.length} businesses in your city',
                  style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),

          // Businesses list
          Expanded(
            child: _availableBusinesses.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.business_center, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No businesses found in $_userCity',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Businesses need to be approved and active to appear here.',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _availableBusinesses.length,
                    itemBuilder: (context, index) {
                      final business = _availableBusinesses[index];
                      final businessId = business['id'] as String;
                      final data = business['data'] as Map<String, dynamic>;
                      final isSelected = _selectedBusinesses[businessId] ?? false;
                      final service = business['service'] as String;
                      final subcategory = business['subcategory'] as String;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: isSelected 
                                ? LinearGradient(
                                    colors: [
                                      Colors.orange.withOpacity(0.1),
                                      Colors.orange.withOpacity(0.05),
                                    ],
                                  )
                                : null,
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                _selectedBusinesses[businessId] = value ?? false;
                              });
                            },
                            title: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: service == 'food' ? Colors.red.shade100 : Colors.green.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    service == 'food' ? '🍕' : '🛒',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        business['businessName'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        '$service → $subcategory',
                                        style: TextStyle(
                                          color: service == 'food' ? Colors.red.shade600 : Colors.green.shade600,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '📍 ${business['address']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.green.shade100 : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isSelected ? '✅ Partnership Active' : '⏸️ Not Partnered',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            activeColor: Colors.orange,
                            checkColor: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Quick actions and save
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _availableBusinesses.forEach((business) {
                              _selectedBusinesses[business['id'] as String] = true;
                            });
                          });
                        },
                        icon: const Icon(Icons.select_all),
                        label: const Text('Partner with All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _availableBusinesses.forEach((business) {
                              _selectedBusinesses[business['id'] as String] = false;
                            });
                          });
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear All'),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveBusinessSelections,
                    icon: Icon(_saving ? Icons.hourglass_empty : Icons.handshake),
                    label: Text(_saving ? 'Saving...' : '🤝 Save Partnerships'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}