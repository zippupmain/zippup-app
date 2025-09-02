import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MovingPricingManageScreen extends StatefulWidget {
  const MovingPricingManageScreen({super.key});

  @override
  State<MovingPricingManageScreen> createState() => _MovingPricingManageScreenState();
}

class _MovingPricingManageScreenState extends State<MovingPricingManageScreen> {
  final Map<String, TextEditingController> _priceControllers = {
    'Studio/1BR': TextEditingController(text: '15000'),
    '2-3BR': TextEditingController(text: '25000'),
    '4+BR': TextEditingController(text: '40000'),
    'Office': TextEditingController(text: '50000'),
  };
  bool _saving = false;

  String _getMoveSizeIcon(String moveSize) {
    switch (moveSize) {
      case 'Studio/1BR':
        return '🏠';
      case '2-3BR':
        return '🏡';
      case '4+BR':
        return '🏘️';
      case 'Office':
        return '🏢';
      default:
        return '📦';
    }
  }

  String _getMoveSizeDescription(String moveSize) {
    switch (moveSize) {
      case 'Studio/1BR':
        return 'Small truck, 2-3 movers, 3-5 hours';
      case '2-3BR':
        return 'Medium truck, 3-4 movers, 5-7 hours';
      case '4+BR':
        return 'Large truck, 4-6 movers, 7-10 hours';
      case 'Office':
        return 'Commercial rates, specialized equipment';
      default:
        return 'Custom move size';
    }
  }

  Future<void> _savePricing() async {
    setState(() => _saving = true);
    
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Convert prices to map
      final pricing = <String, double>{};
      _priceControllers.forEach((moveSize, controller) {
        final price = double.tryParse(controller.text) ?? 0.0;
        pricing[moveSize] = price;
      });

      // Update provider profile with pricing
      final providerQuery = await FirebaseFirestore.instance
          .collection('provider_profiles')
          .where('userId', isEqualTo: uid)
          .where('service', isEqualTo: 'moving')
          .limit(1)
          .get();

      if (providerQuery.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('provider_profiles')
            .doc(providerQuery.docs.first.id)
            .update({
          'pricingConfiguration': pricing,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Pricing saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error saving pricing: $e')),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Pricing & Sizes'),
        backgroundColor: Colors.green.shade50,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '💰 Pricing & Size Management',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Set your pricing based on move sizes and distances.'),
                    const SizedBox(height: 16),
                    const Text('Set your pricing for different move sizes:'),
                    const SizedBox(height: 16),
                    
                    // Pricing inputs
                    Column(
                      children: _priceControllers.entries.map((entry) {
                        final moveSize = entry.key;
                        final controller = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getMoveSizeIcon(moveSize) + ' ' + moveSize,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                Text(_getMoveSizeDescription(moveSize)),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: controller,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Price (₦)',
                                    prefixText: '₦ ',
                                    border: const OutlineInputBorder(),
                                    hintText: 'Enter base price',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _savePricing,
                        icon: Icon(_saving ? Icons.hourglass_empty : Icons.save),
                        label: Text(_saving ? 'Saving...' : 'Save Pricing'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}