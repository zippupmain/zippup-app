import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class GrocerySellerCategoriesScreen extends StatefulWidget {
  const GrocerySellerCategoriesScreen({super.key});

  @override
  State<GrocerySellerCategoriesScreen> createState() => _GrocerySellerCategoriesScreenState();
}

class _GrocerySellerCategoriesScreenState extends State<GrocerySellerCategoriesScreen> {
  final Map<String, bool> _selectedCategories = {};
  bool _loading = true;
  bool _saving = false;

  final Map<String, Map<String, dynamic>> _groceryCategories = {
    'African': {
      'icon': '🌍',
      'color': Colors.green,
      'items': ['Vegetables', 'Spices', 'Grains', 'Meat', 'Snacks', 'Beverages']
    },
    'American': {
      'icon': '🇺🇸',
      'color': Colors.blue,
      'items': ['Breakfast', 'Snacks', 'Beverages', 'Frozen Foods', 'Dairy', 'Bakery']
    },
    'Asian': {
      'icon': '🍜',
      'color': Colors.red,
      'items': ['Rice & Noodles', 'Sauces', 'Spices', 'Vegetables', 'Seafood', 'Tea']
    },
    'European': {
      'icon': '🇪🇺',
      'color': Colors.purple,
      'items': ['Cheese', 'Wine', 'Bread', 'Pasta', 'Meat', 'Vegetables']
    },
    'Mediterranean': {
      'icon': '🫒',
      'color': Colors.orange,
      'items': ['Olive Oil', 'Herbs', 'Nuts', 'Seafood', 'Vegetables', 'Grains']
    },
    'Middle Eastern': {
      'icon': '🕌',
      'color': Colors.amber,
      'items': ['Spices', 'Grains', 'Meat', 'Nuts', 'Dates', 'Tea']
    },
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentCategories();
  }

  Future<void> _loadCurrentCategories() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Load current grocery categories from provider profile
      final profile = await FirebaseFirestore.instance
          .collection('provider_profiles')
          .where('userId', isEqualTo: uid)
          .where('service', isEqualTo: 'grocery')
          .limit(1)
          .get();

      if (profile.docs.isNotEmpty) {
        final data = profile.docs.first.data();
        final enabledCategories = data['enabledGroceryCategories'] as Map<String, dynamic>?;
        
        if (enabledCategories != null) {
          setState(() {
            _selectedCategories.clear();
            enabledCategories.forEach((category, enabled) {
              _selectedCategories[category] = enabled as bool;
            });
          });
        } else {
          // Initialize with default selections
          setState(() {
            _selectedCategories.clear();
            _groceryCategories.keys.forEach((category) {
              _selectedCategories[category] = false;
            });
          });
        }
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading categories: $e')),
        );
      }
    }
  }

  Future<void> _saveCategories() async {
    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Update provider profile with selected categories
      final profileQuery = await FirebaseFirestore.instance
          .collection('provider_profiles')
          .where('userId', isEqualTo: uid)
          .where('service', isEqualTo: 'grocery')
          .limit(1)
          .get();

      if (profileQuery.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('provider_profiles')
            .doc(profileQuery.docs.first.id)
            .update({
          'enabledGroceryCategories': _selectedCategories,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Grocery categories updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error saving categories: $e')),
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
        appBar: AppBar(title: const Text('Grocery Categories')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🛒 Grocery Categories'),
        backgroundColor: Colors.green.shade50,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: Column(
        children: [
          // Header info
          Container(
            color: Colors.green.shade50,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  '🎯 Select Grocery Categories You Stock',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose which types of groceries you have available. Customers will only see you for selected categories.',
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Categories list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _groceryCategories.keys.length,
              itemBuilder: (context, index) {
                final categoryName = _groceryCategories.keys.elementAt(index);
                final categoryData = _groceryCategories[categoryName]!;
                final isSelected = _selectedCategories[categoryName] ?? false;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: isSelected 
                          ? LinearGradient(
                              colors: [
                                (categoryData['color'] as Color).withOpacity(0.1),
                                (categoryData['color'] as Color).withOpacity(0.05),
                              ],
                            )
                          : null,
                    ),
                    child: CheckboxListTile(
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          _selectedCategories[categoryName] = value ?? false;
                        });
                      },
                      title: Row(
                        children: [
                          Text(
                            categoryData['icon'] as String,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '$categoryName Grocery',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: (categoryData['items'] as List<String>).map((item) => 
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (categoryData['color'] as Color).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: categoryData['color'] as Color,
                                ),
                              ),
                            )
                          ).toList(),
                        ),
                      ),
                      activeColor: categoryData['color'] as Color,
                      checkColor: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ),

          // Quick actions
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
                            _groceryCategories.keys.forEach((category) {
                              _selectedCategories[category] = true;
                            });
                          });
                        },
                        icon: const Icon(Icons.select_all),
                        label: const Text('Select All'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _groceryCategories.keys.forEach((category) {
                              _selectedCategories[category] = false;
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
                    onPressed: _saving ? null : _saveCategories,
                    icon: Icon(_saving ? Icons.hourglass_empty : Icons.save),
                    label: Text(_saving ? 'Saving...' : '💾 Save Categories'),
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
        ],
      ),
    );
  }
}