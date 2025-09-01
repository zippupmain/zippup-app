import 'package:flutter/material.dart';
import 'package:zippup/services/notifications/sound_service.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  String _testResult = '';
  bool _isLoading = false;

  Future<void> _testCustomerSound() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing customer notification...';
    });

    try {
      await SoundService.instance.playChirp();
      setState(() {
        _testResult = '✅ Customer notification test completed! Check console for details.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Customer notification test failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testDriverSound() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing driver notification...';
    });

    try {
      await SoundService.instance.playCall();
      setState(() {
        _testResult = '✅ Driver notification test completed! Check console for details.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Driver notification test failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testCompletionSound() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing completion notification...';
    });

    try {
      await SoundService.instance.playTrill();
      setState(() {
        _testResult = '✅ Completion notification test completed! Check console for details.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Completion notification test failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testAllSounds() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing all notification sounds...';
    });

    try {
      final result = await SoundService.instance.testSounds();
      setState(() {
        _testResult = result 
          ? '✅ All notification sounds test completed! Check console for details.'
          : '❌ Some notification sounds failed. Check console for details.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Full notification test failed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔔 Notification Test'),
        backgroundColor: Colors.orange.shade400,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🧪 Notification Sound Test',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Use this screen to test if notification sounds are working properly. '
                      'Each test will attempt multiple sound methods and show results in the console.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testCustomerSound,
              icon: const Icon(Icons.person),
              label: const Text('Test Customer Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testDriverSound,
              icon: const Icon(Icons.drive_eta),
              label: const Text('Test Driver Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testCompletionSound,
              icon: const Icon(Icons.check_circle),
              label: const Text('Test Completion Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _testAllSounds,
              icon: const Icon(Icons.volume_up),
              label: const Text('Test All Notification Sounds'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 24),
            
            if (_isLoading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Testing sounds...'),
                  ],
                ),
              ),
            
            if (_testResult.isNotEmpty && !_isLoading)
              Card(
                color: _testResult.contains('✅') ? Colors.green.shade50 : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Test Result:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _testResult.contains('✅') ? Colors.green.shade800 : Colors.red.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _testResult,
                        style: TextStyle(
                          color: _testResult.contains('✅') ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            const Spacer(),
            
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '💡 Troubleshooting Tips:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• Make sure device volume is up'),
                    Text('• Check device notification permissions'),
                    Text('• Try different notification types'),
                    Text('• Check console logs for detailed error messages'),
                    Text('• On web, some browsers block auto-play sounds'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}