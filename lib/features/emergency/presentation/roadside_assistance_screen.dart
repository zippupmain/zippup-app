import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Roadside Assistance Screen with specific sub-class selection
/// Allows users to select the exact type of roadside help they need
class RoadsideAssistanceScreen extends StatelessWidget {
  const RoadsideAssistanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final roadsideServices = [
      RoadsideService(
        icon: const Icon(Icons.tire_repair, color: Colors.orange),
        title: 'Tyre Fix/Replacement',
        subtitle: 'Flat tyre repair, tyre replacement, puncture fix',
        serviceClass: 'roadside_tyre_fix',
        color: Colors.orange.shade50,
      ),
      RoadsideService(
        icon: const Icon(Icons.battery_charging_full, color: Colors.green),
        title: 'Battery Issues',
        subtitle: 'Dead battery, battery replacement, charging issues',
        serviceClass: 'roadside_battery',
        color: Colors.green.shade50,
      ),
      RoadsideService(
        icon: const Icon(Icons.local_gas_station, color: Colors.blue),
        title: 'Fuel Delivery',
        subtitle: 'Out of fuel, emergency fuel delivery',
        serviceClass: 'roadside_fuel',
        color: Colors.blue.shade50,
      ),
      RoadsideService(
        icon: const Icon(Icons.build, color: Colors.purple),
        title: 'Mechanical Repair',
        subtitle: 'Engine problems, mechanical breakdowns, on-site repair',
        serviceClass: 'roadside_mechanic',
        color: Colors.purple.shade50,
      ),
      RoadsideService(
        icon: const Icon(Icons.key, color: Colors.red),
        title: 'Vehicle Lockout',
        subtitle: 'Locked out of vehicle, key replacement',
        serviceClass: 'roadside_lockout',
        color: Colors.red.shade50,
      ),
      RoadsideService(
        icon: const Icon(Icons.electric_bolt, color: Colors.amber),
        title: 'Jumpstart Service',
        subtitle: 'Battery jumpstart, electrical issues',
        serviceClass: 'roadside_jumpstart',
        color: Colors.amber.shade50,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roadside Assistance'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Header section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade600, Colors.orange.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.car_repair,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                const Text(
                  'What do you need help with?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select the specific roadside assistance you need',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          
          // Services list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: roadsideServices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final service = roadsideServices[index];
                return _buildServiceCard(context, service);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, RoadsideService service) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate to emergency booking with specific roadside class
          context.push('/emergency/booking?type=${service.serviceClass}&title=${service.title}');
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: service.color,
          ),
          child: Row(
            children: [
              // Service icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: service.icon,
              ),
              
              const SizedBox(width: 16),
              
              // Service details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow indicator
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data model for roadside services
class RoadsideService {
  final Icon icon;
  final String title;
  final String subtitle;
  final String serviceClass;
  final Color color;

  const RoadsideService({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.serviceClass,
    required this.color,
  });
}