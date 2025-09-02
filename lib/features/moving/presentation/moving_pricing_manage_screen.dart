import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MovingPricingManageScreen extends StatelessWidget {
  const MovingPricingManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('💰 Pricing & Sizes'),
        backgroundColor: Colors.green.shade50,
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
                      '💰 Pricing & Size Management',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Set your pricing based on move sizes and distances.'),
                    const SizedBox(height: 16),
                    const Text('Move Sizes:'),
                    const SizedBox(height: 8),
                    const Text('🏠 Studio/1BR - Small truck, 2-3 movers'),
                    const Text('🏡 2-3BR - Medium truck, 3-4 movers'),
                    const Text('🏘️ 4+BR - Large truck, 4-6 movers'),
                    const Text('🏢 Office - Commercial rates'),
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