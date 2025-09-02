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
                    const Text('Available Vehicle Types:'),
                    const SizedBox(height: 8),
                    const Text('🚛 Small Truck - For apartments and small moves'),
                    const Text('🚛 Medium Truck - For 2-3 bedroom houses'),
                    const Text('🚛 Large Truck - For large houses and offices'),
                    const Text('🛻 Small Pickup - For small items and furniture'),
                    const Text('🛻 Large Pickup - For medium-sized moves'),
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