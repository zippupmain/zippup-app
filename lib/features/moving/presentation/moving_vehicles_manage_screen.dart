import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MovingVehiclesManageScreen extends StatelessWidget {
  const MovingVehiclesManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚚 Manage Vehicles'),
        backgroundColor: Colors.orange.shade50,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
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
                      '🚚 Vehicle Management',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Manage your moving vehicles, truck sizes, and equipment.'),
                    const SizedBox(height: 16),
                    const Text('Add and manage your vehicles:'),
                    const SizedBox(height: 16),
                    
                    // Vehicle type cards
                    Column(
                      children: [
                        _VehicleCard(
                          icon: '🚛',
                          title: 'Small Truck',
                          subtitle: 'Apartments, small moves',
                          isActive: true,
                        ),
                        _VehicleCard(
                          icon: '🚛',
                          title: 'Medium Truck', 
                          subtitle: '2-3 bedroom houses',
                          isActive: false,
                        ),
                        _VehicleCard(
                          icon: '🚛',
                          title: 'Large Truck',
                          subtitle: 'Large houses, offices',
                          isActive: false,
                        ),
                        _VehicleCard(
                          icon: '🛻',
                          title: 'Small Pickup',
                          subtitle: 'Small items, furniture',
                          isActive: true,
                        ),
                      ],
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
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatefulWidget {
  final String icon;
  final String title;
  final String subtitle;
  final bool isActive;

  const _VehicleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isActive,
  });

  @override
  State<_VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends State<_VehicleCard> {
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _isActive = widget.isActive;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: _isActive 
              ? LinearGradient(
                  colors: [Colors.green.shade100, Colors.green.shade50],
                )
              : null,
        ),
        child: CheckboxListTile(
          value: _isActive,
          onChanged: (value) {
            setState(() => _isActive = value ?? false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isActive ? '✅ ${widget.title} enabled' : '❌ ${widget.title} disabled'),
                backgroundColor: _isActive ? Colors.green : Colors.orange,
                duration: const Duration(seconds: 1),
              ),
            );
          },
          title: Row(
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          subtitle: Text(widget.subtitle),
          activeColor: Colors.green,
          checkColor: Colors.white,
        ),
      ),
    );
  }
}