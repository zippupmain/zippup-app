import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MovingTeamManageScreen extends StatelessWidget {
  const MovingTeamManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👥 Moving Team'),
        backgroundColor: Colors.blue.shade50,
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
                      '👥 Team Management',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Manage your moving team members and their roles.'),
                    const SizedBox(height: 16),
                    const Text('Team Roles:'),
                    const SizedBox(height: 8),
                    const Text('👨‍💼 Team Leader - Supervises the move'),
                    const Text('💪 Movers - Handle loading and unloading'),
                    const Text('🚛 Driver - Operates the vehicle'),
                    const Text('📋 Coordinator - Manages logistics'),
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
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}