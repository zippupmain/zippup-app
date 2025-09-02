import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class ServiceRolesManagerScreen extends StatefulWidget {
  final String service; // transport, hire, moving, etc.
  final String subcategory; // Taxi, Home, Courier, etc.
  
  const ServiceRolesManagerScreen({
    super.key, 
    required this.service, 
    required this.subcategory,
  });

  @override
  State<ServiceRolesManagerScreen> createState() => _ServiceRolesManagerScreenState();
}

class _ServiceRolesManagerScreenState extends State<ServiceRolesManagerScreen> {
  Map<String, bool> _enabledRoles = {};
  bool _loading = true;
  bool _saving = false;
  String _primaryRole = '';

  // Complete service role mappings for all categories
  final Map<String, Map<String, List<String>>> _serviceRoles = const {
    'transport': {
      'Taxi': ['Tricycle', 'Compact', 'Standard', 'SUV/Van'], // Driver can accept multiple passenger classes
      'Bike': ['Economy Bike', 'Luxury Bike'], // Can handle both bike types
      'Bus/Charter': ['Mini Bus (8 seater)', 'Standard Bus (12 seater)', 'Large Bus (16 seater)', 'Charter Bus (30 seater)'],
    },
    'moving': {
      'Truck': ['Small Truck', 'Medium Truck', 'Large Truck'], // Can handle multiple truck sizes
      'Pickup': ['Small Pickup', 'Large Pickup'], // Can handle both pickup sizes
      'Courier': ['Intra-City', 'Intra-State', 'Nationwide'], // Can cover multiple areas
    },
    'hire': {
      'Home': ['Plumber', 'Electrician', 'Cleaner', 'Painter', 'Carpenter', 'Pest Control', 'Gardener'], // Can offer multiple home services
      'Tech': ['Phone Repair', 'Computer', 'Network Set Up', 'CCTV Install', 'Data Recovery', 'Solar Installations', 'AC Repair', 'Fridge Repair', 'TV/Electronics Repairs'],
      'Construction': ['Builder', 'Roofer', 'Tiler', 'Welder', 'Scaffolding', 'Laborers', 'Town Planners', 'Estate Managers', 'Land Surveyors', 'Quantity Surveyors', 'Architect', 'Mason Men/Bricklayer', 'Interior Deco', 'Exterior Deco', 'POP'],
      'Auto': ['Mechanic', 'Tyre Service', 'Battery Service', 'Fuel Delivery'],
    },
    'emergency': {
      'Ambulance': ['Basic Life Support', 'Advanced Life Support', 'Critical Care', 'Patient Transport'],
      'Fire Service': ['Fire Fighting', 'Rescue Operations', 'Hazmat Response'],
      'Security': ['Armed Response', 'Patrol Service', 'Alarm Response', 'VIP Protection'],
      'Towing': ['Light Vehicle Towing', 'Heavy Vehicle Towing', 'Motorcycle Towing'],
      'Towing Van': ['Emergency Towing', 'Accident Recovery', 'Breakdown Service', 'Heavy Duty Towing'],
      'Roadside': ['Battery Jump', 'Tire Change', 'Fuel Delivery', 'Lockout Service'],
    },
    'personal': {
      'Beauty': ['Hair Cut', 'Hair Styling', 'Makeup', 'Facial', 'Eyebrow Threading', 'Waxing', 'Eye Lashes', 'Lips Treatment'],
      'Wellness': ['Massage', 'Spa Treatment', 'Reflexology', 'Aromatherapy'],
      'Fitness': ['Personal Trainer', 'Yoga Instructor', 'Physiotherapy', 'Nutrition Coaching'],
      'Cleaning': ['House Cleaning', 'Deep Cleaning', 'Laundry Services', 'Organizing', 'Pool Cleaning and Treatment'],
      'Childcare': ['Babysitter', 'Nanny', 'Child Tutor', 'Child Activities'],
    },
    'food': {
      'Fast Food': ['Burgers', 'Fried Chicken', 'Sandwiches', 'Hot Dogs', 'Tacos'],
      'Local Cuisine': ['Traditional Dishes', 'Regional Specialties', 'Local Favorites', 'Street Food'],
      'Pizza': ['Italian Pizza', 'American Pizza', 'Gourmet Pizza', 'Thin Crust', 'Deep Dish'],
      'Continental': ['African', 'American', 'Asian', 'European', 'Mediterranean', 'Middle Eastern'],
      'Desserts': ['Cakes', 'Ice Cream', 'Pastries', 'Cookies', 'Traditional Sweets'],
      'Drinks': ['Fresh Juices', 'Smoothies', 'Coffee', 'Tea', 'Soft Drinks'],
    },
    'grocery': {
      'African': ['African Vegetables', 'African Spices', 'African Grains', 'African Meat', 'African Snacks'],
      'American': ['American Brands', 'American Snacks', 'American Cereals', 'American Beverages'],
      'Asian': ['Asian Vegetables', 'Asian Spices', 'Asian Noodles', 'Asian Sauces', 'Asian Snacks'],
      'European': ['European Cheese', 'European Bread', 'European Wine', 'European Delicacies'],
      'Mediterranean': ['Mediterranean Oils', 'Mediterranean Herbs', 'Mediterranean Olives', 'Mediterranean Pasta'],
      'Middle Eastern': ['Middle Eastern Spices', 'Middle Eastern Rice', 'Middle Eastern Nuts', 'Middle Eastern Sweets'],
    },
    'others': {
      'Events Planning': ['Wedding Planning', 'Corporate Events', 'Birthday Parties', 'Conference Planning', 'Exhibition Planning'],
      'Event Ticketing': ['Concert Tickets', 'Sports Events', 'Theater Shows', 'Festival Tickets', 'Conference Tickets'],
      'Tutoring': ['Math Tutoring', 'English Tutoring', 'Science Tutoring', 'Language Learning', 'Test Prep', 'Homework Help', 'Music Lessons', 'Art Classes', 'IT Tutor', 'Business Tutor'],
      'Education': ['Online Course', 'Workshop', 'Seminar', 'Training Program', 'Certification Course', 'Skill Development'],
      'Creative Services': ['Photography', 'Videography', 'Graphics Design', 'Web Design', 'Logo Design', 'Content Creation'],
      'Business Services': ['Business Consulting', 'Legal Advice', 'Accounting', 'Marketing Strategy', 'HR Consulting', 'Financial Planning'],
      'Medical Consulting': ['Cardiologists', 'Dermatologist', 'Allergist/Immunologist', 'Endocrinologist', 'Pediatricians', 'Oncologists', 'Ophthalmologists', 'Orthopedic Surgeons', 'Gastroenterologists', 'Lab Technicians', 'Nephrologist', 'Neurologists', 'Obstetrician/Gynecologist', 'Pulmonologist', 'Rheumatologists', 'Hospice and Palliative Medicine', 'Psychiatrists', 'Radiologists', 'Surgeon', 'Anesthesiologist', 'Pharmacist/Chemist', 'Otorhinolaryngologist'],
    },
  };

  // Delivery categories for delivery providers
  final List<String> _deliveryCategories = [
    'Fast Food',
    'Grocery', 
    'Marketplace',
    'Pharmacy',
    'Electronics',
    'Documents',
    'Flowers',
    'Gifts',
  ];

  @override
  void initState() {
    super.initState();
    _loadServiceRoles();
  }

  Future<void> _loadServiceRoles() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final providerDoc = await FirebaseFirestore.instance
          .collection('provider_profiles')
          .where('userId', isEqualTo: uid)
          .where('service', isEqualTo: widget.service)
          .limit(1)
          .get();

      if (providerDoc.docs.isNotEmpty) {
        final data = providerDoc.docs.first.data();
        
        setState(() {
          _primaryRole = data['serviceType']?.toString() ?? '';
          
          // Load enabled roles
          final enabledRoles = data['enabledRoles'] as Map<String, dynamic>? ?? {};
          _enabledRoles = enabledRoles.map((key, value) => MapEntry(key, value == true));
          
          // If no roles are set, enable primary role by default
          if (_enabledRoles.isEmpty && _primaryRole.isNotEmpty) {
            _enabledRoles[_primaryRole] = true;
          }
          
          // For delivery, load delivery categories
          if (widget.service == 'delivery') {
            final enabledDeliveryCategories = data['enabledDeliveryCategories'] as Map<String, dynamic>? ?? {};
            for (final category in _deliveryCategories) {
              _enabledRoles[category] = enabledDeliveryCategories[category] == true;
            }
          }
          
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      print('Error loading service roles: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _saveServiceRoles() async {
    print('🔄 Starting to save service roles...');
    setState(() => _saving = true);
    
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        print('❌ No user ID found');
        return;
      }

      print('🔍 Looking for provider profile: service=${widget.service}, uid=$uid');

      final providerDoc = await FirebaseFirestore.instance
          .collection('provider_profiles')
          .where('userId', isEqualTo: uid)
          .where('service', isEqualTo: widget.service)
          .limit(1)
          .get();

      print('📋 Found ${providerDoc.docs.length} provider profiles');

      if (providerDoc.docs.isNotEmpty) {
        final profileId = providerDoc.docs.first.id;
        final updateData = <String, dynamic>{
          'enabledRoles': _enabledRoles,
          'enabledClasses': _enabledRoles, // Also update enabledClasses for compatibility
          'updatedAt': FieldValue.serverTimestamp(),
        };

        print('💾 Saving roles: $_enabledRoles');

        // For delivery, save delivery categories separately
        if (widget.service == 'delivery') {
          final deliveryCategories = <String, bool>{};
          for (final category in _deliveryCategories) {
            deliveryCategories[category] = _enabledRoles[category] ?? false;
          }
          updateData['enabledDeliveryCategories'] = deliveryCategories;
          print('💾 Saving delivery categories: $deliveryCategories');
        }

        print('🚀 Updating profile $profileId with data: $updateData');
        
        await providerDoc.docs.first.reference.update(updateData);

        print('✅ Profile updated successfully');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Service roles updated successfully! Changes are now active.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Optional: Navigate back to provider hub after successful save
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.of(context).pop();
          });
        }
      } else {
        print('❌ No provider profile found');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Provider profile not found. Please create a profile first.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to update roles: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
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
        appBar: AppBar(title: Text('${widget.subcategory} Service Roles')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final availableRoles = widget.service == 'delivery' 
        ? _deliveryCategories
        : _serviceRoles[widget.service]?[widget.subcategory] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.subcategory} Service Roles'),
        backgroundColor: Colors.blue.shade50,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        actions: [
          ElevatedButton.icon(
            onPressed: _saving ? null : _saveServiceRoles,
            icon: Icon(_saving ? Icons.hourglass_empty : Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _saveServiceRoles,
        icon: Icon(_saving ? Icons.hourglass_empty : Icons.save),
        label: Text(_saving ? 'Saving...' : 'Save Changes'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header info card
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎛️ ${widget.subcategory} Service Roles',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Primary Role: $_primaryRole',
                    style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.service == 'delivery'
                        ? 'Choose which delivery categories you want to handle. You can offer multiple delivery services.'
                        : 'Choose which services within your ${widget.subcategory} category you want to offer. You can expand beyond your primary role.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Service roles toggles
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.service == 'delivery' 
                        ? '📦 Delivery Categories'
                        : '⚙️ Available Service Roles',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  ...availableRoles.map((role) {
                    final isEnabled = _enabledRoles[role] ?? false;
                    final isPrimary = role == _primaryRole;
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isPrimary ? Colors.green.shade50 : null,
                        border: isPrimary ? Border.all(color: Colors.green.shade300) : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SwitchListTile(
                        title: Row(
                          children: [
                            Text(role),
                            if (isPrimary) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade600,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'PRIMARY',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          isEnabled 
                              ? '✅ Accepting ${widget.service == 'delivery' ? 'delivery' : 'service'} requests'
                              : '❌ Not accepting requests',
                          style: TextStyle(
                            color: isEnabled ? Colors.green.shade600 : Colors.red.shade600,
                            fontSize: 12,
                          ),
                        ),
                        value: isEnabled,
                        onChanged: (value) {
                          print('🔄 Toggling $role: $value');
                          setState(() => _enabledRoles[role] = value);
                          
                          // Show immediate feedback
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value == true 
                                    ? '✅ $role enabled - Remember to save!'
                                    : '❌ $role disabled - Remember to save!',
                              ),
                              backgroundColor: value == true ? Colors.green : Colors.orange,
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        activeColor: Colors.green,
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Quick actions
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚡ Quick Actions',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            print('🔄 Enabling all roles: $availableRoles');
                            setState(() {
                              for (final role in availableRoles) {
                                _enabledRoles[role] = true;
                              }
                            });
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ All roles enabled - Remember to save!'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Text('✅ Enable All'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            print('🔄 Disabling all roles except primary: $_primaryRole');
                            setState(() {
                              for (final role in availableRoles) {
                                _enabledRoles[role] = false;
                              }
                              // Keep primary role enabled
                              if (_primaryRole.isNotEmpty) {
                                _enabledRoles[_primaryRole] = true;
                              }
                            });
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('❌ All roles disabled except $_primaryRole - Remember to save!'),
                                backgroundColor: Colors.orange,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Text('❌ Disable All (Keep Primary)'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Debug info card
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🐛 Debug Info',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Service: ${widget.service}'),
                  Text('Subcategory: ${widget.subcategory}'),
                  Text('Primary Role: $_primaryRole'),
                  Text('Available Roles: ${availableRoles.length} (${availableRoles.join(", ")})'),
                  Text('Enabled Count: ${_enabledRoles.entries.where((e) => e.value).length}'),
                  Text('Currently Enabled: ${_enabledRoles.entries.where((e) => e.value).map((e) => e.key).join(", ")}'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          print('🧪 Current enabled roles: $_enabledRoles');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🧪 Enabled: ${_enabledRoles.entries.where((e) => e.value).map((e) => e.key).join(", ")}'),
                              duration: const Duration(seconds: 3),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        },
                        icon: const Icon(Icons.bug_report, size: 16),
                        label: const Text('Test State'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : () async {
                          print('🧪 Testing save function...');
                          await _saveServiceRoles();
                        },
                        icon: const Icon(Icons.save, size: 16),
                        label: const Text('Test Save'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Info card
          Card(
            color: Colors.grey.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 How Service Roles Work',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._buildInfoText(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildInfoText() {
    switch (widget.service) {
      case 'transport':
        return [
          const Text('• Your primary role is your registered vehicle capacity'),
          const Text('• Enable additional roles to accept different passenger counts'),
          const Text('• Example: 2-seater driver can enable 4-seater to get more requests'),
          const Text('• Only get requests you can actually handle'),
        ];
      case 'hire':
        return [
          const Text('• Your primary role is your main skill/service'),
          const Text('• Enable additional roles to offer multiple services'),
          const Text('• Example: Plumber can enable Electrician if qualified'),
          const Text('• Only enable services you can actually provide'),
        ];
      case 'grocery':
        return [
          const Text('• Your primary role is your main grocery category'),
          const Text('• Enable additional categories to sell more products'),
          const Text('• Example: African grocery can sell American products too'),
          const Text('• Only enable categories you actually stock'),
        ];
      case 'delivery':
        return [
          const Text('• Choose which delivery categories you want to handle'),
          const Text('• Enable multiple categories to get more delivery requests'),
          const Text('• Example: Focus only on Fast Food, or handle all categories'),
          const Text('• You can update anytime based on your capacity'),
        ];
      default:
        return [
          const Text('• Enable roles you want to offer within your category'),
          const Text('• More roles = more requests = more opportunities'),
          const Text('• Only enable services you can actually provide'),
          const Text('• Update anytime based on your skills/capacity'),
        ];
    }
  }
}