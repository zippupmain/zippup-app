import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MovingScheduleManageScreen extends StatelessWidget {
  const MovingScheduleManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📅 Schedule Management'),
        backgroundColor: Colors.purple.shade50,
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
                      '📅 Schedule Management',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Manage your availability and booking schedule.'),
                    const SizedBox(height: 16),
                    const Text('Schedule Features:'),
                    const SizedBox(height: 8),
                    const Text('📅 Set available days and hours'),
                    const Text('⏰ Manage time slots for bookings'),
                    const Text('🚫 Block unavailable dates'),
                    const Text('📋 View upcoming scheduled moves'),
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
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}