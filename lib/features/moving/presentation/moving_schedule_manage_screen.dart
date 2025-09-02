import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MovingScheduleManageScreen extends StatefulWidget {
  const MovingScheduleManageScreen({super.key});

  @override
  State<MovingScheduleManageScreen> createState() => _MovingScheduleManageScreenState();
}

class _MovingScheduleManageScreenState extends State<MovingScheduleManageScreen> {
  final Map<String, bool> _availableDays = {
    'Monday': true,
    'Tuesday': true,
    'Wednesday': true,
    'Thursday': true,
    'Friday': true,
    'Saturday': true,
    'Sunday': false,
  };
  
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  bool _saving = false;

  Future<void> _saveSchedule() async {
    setState(() => _saving = true);
    
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Update provider profile with schedule configuration
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
          'scheduleConfiguration': {
            'availableDays': _availableDays,
            'startTime': '${_startTime.hour}:${_startTime.minute.toString().padLeft(2, '0')}',
            'endTime': '${_endTime.hour}:${_endTime.minute.toString().padLeft(2, '0')}',
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Schedule saved successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error saving schedule: $e')),
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
        title: const Text('📅 Schedule Management'),
        backgroundColor: Colors.purple.shade50,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
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
                    const Text('Configure your availability:'),
                    const SizedBox(height: 16),
                    
                    // Available days
                    const Text('📅 Available Days:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Column(
                      children: _availableDays.entries.map((entry) {
                        final day = entry.key;
                        final isAvailable = entry.value;
                        return CheckboxListTile(
                          value: isAvailable,
                          onChanged: (value) {
                            setState(() {
                              _availableDays[day] = value ?? false;
                            });
                          },
                          title: Text(day),
                          subtitle: Text(isAvailable ? 'Available for moves' : 'Not available'),
                          activeColor: Colors.purple,
                        );
                      }).toList(),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Working hours
                    const Text('⏰ Working Hours:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Card(
                            child: ListTile(
                              title: const Text('Start Time'),
                              subtitle: Text(_startTime.format(context)),
                              trailing: const Icon(Icons.access_time),
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: _startTime,
                                );
                                if (time != null) {
                                  setState(() => _startTime = time);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Card(
                            child: ListTile(
                              title: const Text('End Time'),
                              subtitle: Text(_endTime.format(context)),
                              trailing: const Icon(Icons.access_time),
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: _endTime,
                                );
                                if (time != null) {
                                  setState(() => _endTime = time);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveSchedule,
                        icon: Icon(_saving ? Icons.hourglass_empty : Icons.save),
                        label: Text(_saving ? 'Saving...' : 'Save Schedule'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
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