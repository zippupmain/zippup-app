import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MovingTeamManageScreen extends StatefulWidget {
  const MovingTeamManageScreen({super.key});

  @override
  State<MovingTeamManageScreen> createState() => _MovingTeamManageScreenState();
}

class _MovingTeamManageScreenState extends State<MovingTeamManageScreen> {
  final Map<String, bool> _teamRoles = {
    'Team Leader': true,
    'Movers': true,
    'Driver': true,
    'Coordinator': false,
    'Equipment Specialist': false,
  };
  bool _saving = false;

  String _getTeamRoleDescription(String role) {
    switch (role) {
      case 'Team Leader':
        return '👨‍💼 Supervises the move and coordinates team';
      case 'Movers':
        return '💪 Handle loading, carrying, and unloading';
      case 'Driver':
        return '🚛 Operates the vehicle safely';
      case 'Coordinator':
        return '📋 Manages logistics and scheduling';
      case 'Equipment Specialist':
        return '🔧 Handles special equipment and tools';
      default:
        return 'Team member role';
    }
  }

  Future<void> _saveTeamRoles() async {
    setState(() => _saving = true);
    
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Update provider profile with team configuration
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
          'teamConfiguration': _teamRoles,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Team configuration saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error saving team config: $e')),
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
                    const Text('Select team roles you provide:'),
                    const SizedBox(height: 16),
                    
                    // Team role toggles
                    Column(
                      children: _teamRoles.entries.map((entry) {
                        final role = entry.key;
                        final isEnabled = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: CheckboxListTile(
                            value: isEnabled,
                            onChanged: (value) {
                              setState(() {
                                _teamRoles[role] = value ?? false;
                              });
                            },
                            title: Text(role, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(_getTeamRoleDescription(role)),
                            activeColor: Colors.blue,
                            checkColor: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveTeamRoles,
                        icon: Icon(_saving ? Icons.hourglass_empty : Icons.save),
                        label: Text(_saving ? 'Saving...' : 'Save Team Configuration'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
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