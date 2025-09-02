import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class OperationalSettingsScreen extends StatefulWidget {
  final String service; // transport, hire, moving, etc.
  const OperationalSettingsScreen({super.key, required this.service});

  @override
  State<OperationalSettingsScreen> createState() => _OperationalSettingsScreenState();
}

class _OperationalSettingsScreenState extends State<OperationalSettingsScreen> {
  double _operationalRadius = 10.0; // Default 10km radius
  bool _hasRadiusLimit = false;
  Map<String, bool> _enabledClasses = {};
  bool _loading = true;
  bool _saving = false;

  // Service class mappings
  final Map<String, Map<String, List<String>>> _serviceClasses = const {
    'transport': {
      'Taxi': ['Tricycle', 'Compact', 'Standard', 'SUV/Van'],
      'Bike': ['Economy Bike', 'Luxury Bike'],
      'Bus/Charter': ['Mini Bus (8 seater)', 'Standard Bus (12 seater)', 'Large Bus (16 seater)', 'Charter Bus (30 seater)'],
    },
    'moving': {
      'Truck': ['Small Truck', 'Medium Truck', 'Large Truck'],
      'Pickup': ['Small Pickup', 'Large Pickup'],
      'Courier': ['Intra-City', 'Intra-State', 'Nationwide'],
    },
    'hire': {
      'Home': ['Plumber', 'Electrician', 'Cleaner', 'Painter', 'Carpenter', 'Pest Control', 'Gardener'],
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
  };

  @override
  void initState() {
    super.initState();
    _loadOperationalSettings();
  }

  Future<void> _loadOperationalSettings() async {
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
          _operationalRadius = (data['operationalRadius'] as num?)?.toDouble() ?? 10.0;
          _hasRadiusLimit = data['hasRadiusLimit'] == true;
          
          // Load enabled classes
          final enabledClasses = data['enabledClasses'] as Map<String, dynamic>? ?? {};
          _enabledClasses = enabledClasses.map((key, value) => MapEntry(key, value == true));
          
          // If no classes are set, enable all by default
          if (_enabledClasses.isEmpty) {
            _initializeDefaultClasses(data['subcategory']?.toString(), data['serviceType']?.toString());
          }
          
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      print('Error loading operational settings: $e');
      setState(() => _loading = false);
    }
  }

  void _initializeDefaultClasses(String? subcategory, String? serviceType) {
    if (subcategory != null) {
      final availableClasses = _serviceClasses[widget.service]?[subcategory] ?? [];
      for (final className in availableClasses) {
        _enabledClasses[className] = className == serviceType; // Enable only provider's specific type by default
      }
    }
  }

  Future<void> _saveOperationalSettings() async {
    setState(() => _saving = true);
    
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
        await providerDoc.docs.first.reference.update({
          'operationalRadius': _operationalRadius,
          'hasRadiusLimit': _hasRadiusLimit,
          'enabledClasses': _enabledClasses,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Operational settings saved successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Failed to save settings: $e')),
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
        appBar: AppBar(title: Text('${widget.service.toUpperCase()} Operational Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.service.toUpperCase()} Operational Settings'),
        backgroundColor: Colors.blue.shade50,
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveOperationalSettings,
            child: Text(_saving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Operational Radius Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📍 Operational Area Radius',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Set your service area radius. Requests outside this area won\'t be sent to you.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  
                  SwitchListTile(
                    title: const Text('Enable Radius Limit'),
                    subtitle: Text(_hasRadiusLimit 
                      ? 'Only receive requests within ${_operationalRadius.toInt()}km' 
                      : 'Receive requests from anywhere'),
                    value: _hasRadiusLimit,
                    onChanged: (value) => setState(() => _hasRadiusLimit = value),
                  ),
                  
                  if (_hasRadiusLimit) ...[
                    const SizedBox(height: 16),
                    Text('Radius: ${_operationalRadius.toInt()} km'),
                    Slider(
                      value: _operationalRadius,
                      min: 1.0,
                      max: 100.0,
                      divisions: 99,
                      label: '${_operationalRadius.toInt()} km',
                      onChanged: (value) => setState(() => _operationalRadius = value),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Class Toggle Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🎛️ Service Class Toggles',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose which service classes you want to receive requests for. You can toggle these anytime.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  
                  ..._buildClassToggles(),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Info Card
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '💡 How Request Routing Works',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
                  ),
                  const SizedBox(height: 8),
                  const Text('• Requests are sent to nearest provider in the specific class'),
                  const Text('• If not accepted within 60 seconds, routed to next provider'),
                  const Text('• Continues until a provider accepts or user cancels'),
                  const Text('• Only enabled classes receive requests'),
                  const Text('• Radius limit filters requests by distance'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildClassToggles() {
    final widgets = <Widget>[];
    
    _serviceClasses[widget.service]?.forEach((subcategory, classes) {
      widgets.add(
        ExpansionTile(
          title: Text(subcategory, style: const TextStyle(fontWeight: FontWeight.bold)),
          children: classes.map((className) {
            final isEnabled = _enabledClasses[className] ?? false;
            return SwitchListTile(
              title: Text(className),
              subtitle: Text(isEnabled ? 'Receiving requests' : 'Not receiving requests'),
              value: isEnabled,
              onChanged: (value) {
                setState(() => _enabledClasses[className] = value);
              },
              activeColor: Colors.green,
            );
          }).toList(),
        ),
      );
    });
    
    return widgets;
  }
}