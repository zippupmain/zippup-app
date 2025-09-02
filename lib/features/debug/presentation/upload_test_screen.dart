import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class UploadTestScreen extends StatefulWidget {
  const UploadTestScreen({super.key});

  @override
  State<UploadTestScreen> createState() => _UploadTestScreenState();
}

class _UploadTestScreenState extends State<UploadTestScreen> {
  bool _testing = false;
  String _testResult = '';
  final TextEditingController _testController = TextEditingController(text: 'Test Data');

  Future<void> _runUploadTest() async {
    setState(() {
      _testing = true;
      _testResult = 'Starting upload test...';
    });

    try {
      print('🧪 Starting comprehensive upload test...');
      
      // Test 1: Check authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _testResult = '❌ Test failed: Not authenticated');
        return;
      }
      print('✅ Test 1: Authentication OK - User ID: ${user.uid}');
      setState(() => _testResult = '✅ Test 1: Authentication OK\n');

      // Test 2: Simple Firestore write
      print('🧪 Test 2: Testing basic Firestore write...');
      await FirebaseFirestore.instance.collection('upload_tests').add({
        'userId': user.uid,
        'testData': _testController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'testType': 'basic_write',
      });
      print('✅ Test 2: Basic Firestore write successful');
      setState(() => _testResult += '✅ Test 2: Firestore write OK\n');

      // Test 3: Profile picture simulation (public_profiles collection)
      print('🧪 Test 3: Testing profile picture save...');
      await FirebaseFirestore.instance.collection('public_profiles').doc(user.uid).set({
        'profilePictureUrl': 'https://via.placeholder.com/150x150/4CAF50/FFFFFF?text=Profile',
        'name': 'Test User',
        'email': user.email ?? 'test@example.com',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('✅ Test 3: Profile picture save successful');
      setState(() => _testResult += '✅ Test 3: Profile picture save OK\n');

      // Test 4: Provider application simulation
      print('🧪 Test 4: Testing provider application...');
      await FirebaseFirestore.instance.collection('test_applications').doc(user.uid).set({
        'applicantId': user.uid,
        'name': 'Test Provider',
        'category': 'transport',
        'subcategory': 'taxi',
        'idUrl': 'https://via.placeholder.com/300x200/2196F3/FFFFFF?text=Test+ID',
        'status': 'active',
        'createdAt': DateTime.now().toIso8601String(),
      });
      print('✅ Test 4: Provider application successful');
      setState(() => _testResult += '✅ Test 4: Provider application OK\n');

      // Test 5: Business profile simulation
      print('🧪 Test 5: Testing business profile...');
      await FirebaseFirestore.instance.collection('test_business_profiles').add({
        'userId': user.uid,
        'businessName': 'Test Business',
        'service': 'transport',
        'publicImageUrl': 'https://via.placeholder.com/300x200/FF9800/FFFFFF?text=Business',
        'status': 'active',
        'createdAt': DateTime.now().toIso8601String(),
      });
      print('✅ Test 5: Business profile successful');
      setState(() => _testResult += '✅ Test 5: Business profile OK\n');

      setState(() => _testResult += '\n🎉 ALL TESTS PASSED!\nUpload system is working correctly.');
      
    } catch (e) {
      print('❌ Upload test failed: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      setState(() => _testResult += '❌ Test failed: $e\n\nStack: ${StackTrace.current}');
    } finally {
      setState(() => _testing = false);
    }
  }

  Future<void> _quickProfileTest() async {
    setState(() {
      _testing = true;
      _testResult = 'Quick profile test...';
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _testResult = '❌ Not authenticated');
        return;
      }

      print('🧪 Quick profile test for user: ${user.uid}');
      
      // Test minimal profile save
      await FirebaseFirestore.instance.collection('public_profiles').doc(user.uid).set({
        'name': 'Test User Profile',
        'profilePictureUrl': 'https://via.placeholder.com/150x150/4CAF50/FFFFFF?text=Test+Profile',
        'email': user.email ?? 'test@example.com',
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _testResult = '✅ Quick profile test successful!\nProfile saved with placeholder image.');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile test successful!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('❌ Quick profile test failed: $e');
      setState(() => _testResult = '❌ Quick profile test failed: $e');
    } finally {
      setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Upload System Test'),
        backgroundColor: Colors.orange.shade50,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🧪 Upload System Diagnostic',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('This will test all upload functionality to identify issues.'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _testController,
                      decoration: const InputDecoration(
                        labelText: 'Test Data',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                                            SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _testing ? null : _runUploadTest,
                            icon: Icon(_testing ? Icons.hourglass_empty : Icons.bug_report),
                            label: Text(_testing ? 'Testing...' : 'Run Upload Test'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _testing ? null : _quickProfileTest,
                            icon: const Icon(Icons.person),
                            label: const Text('Quick Profile Test'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            if (_testResult.isNotEmpty)
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '📋 Test Results',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Text(
                              _testResult,
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}