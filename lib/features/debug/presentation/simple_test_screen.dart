import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class SimpleTestScreen extends StatefulWidget {
  const SimpleTestScreen({super.key});

  @override
  State<SimpleTestScreen> createState() => _SimpleTestScreenState();
}

class _SimpleTestScreenState extends State<SimpleTestScreen> {
  String _result = 'Ready to test';
  bool _testing = false;

  void _simpleTest() {
    setState(() {
      _testing = true;
      _result = 'Testing basic functionality...';
    });

    // Test without async/await to see if that's the issue
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _result = '❌ No user found - please sign in first';
          _testing = false;
        });
        return;
      }

      setState(() => _result = '✅ User found: ${user.uid}\nTesting Firestore with timeout...');

      // Add timeout to catch hanging operations
      Future.any([
        FirebaseFirestore.instance.collection('simple_test').add({
          'userId': user.uid,
          'message': 'Simple test',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        }),
        Future.delayed(const Duration(seconds: 10), () => throw TimeoutException('Firestore operation timed out after 10 seconds')),
      ]).then((result) {
        if (result is DocumentReference) {
          print('✅ Firestore write successful: ${result.id}');
          setState(() {
            _result = '✅ SUCCESS!\nUser: ${user.uid}\nFirestore: Working\nDoc ID: ${result.id}';
            _testing = false;
          });
        }
      }).catchError((error) {
        print('❌ Firestore write failed: $error');
        setState(() {
          _result = '❌ Firestore failed: $error\n\nThis indicates:\n- Network connectivity issues\n- Firebase configuration problems\n- Firestore rules blocking writes';
          _testing = false;
        });
      });

    } catch (e) {
      print('❌ Simple test failed: $e');
      setState(() {
        _result = '❌ Test failed: $e';
        _testing = false;
      });
    }
  }

  void _testTimeout() {
    setState(() {
      _testing = true;
      _result = 'Testing timeout...';
    });

    // Test if the issue is with timeouts
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _result = '✅ Timeout test completed - setState works';
          _testing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔧 Simple Test'),
        backgroundColor: Colors.red.shade50,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔧 Basic Functionality Test',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text('Test basic operations without complex async logic.'),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _testing ? null : _simpleTest,
                            icon: Icon(_testing ? Icons.hourglass_empty : Icons.play_arrow),
                            label: Text(_testing ? 'Testing...' : 'Simple Test'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _testing ? null : _testTimeout,
                            icon: const Icon(Icons.timer),
                            label: const Text('Timeout Test'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
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
                            _result,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
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