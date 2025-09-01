import 'package:flutter/material.dart';
import 'package:zippup/services/notifications/reliable_sound_service.dart';
import 'package:zippup/services/notifications/audible_notification_service.dart';
import 'package:zippup/services/notifications/working_sound_service.dart';
import 'package:zippup/services/notifications/simple_beep_service.dart';
import 'package:zippup/services/notifications/voice_hijack_service.dart';
import 'package:zippup/services/notifications/flutter_feedback_service.dart';
import 'package:zippup/services/notifications/sound_detective_service.dart';
import 'package:zippup/services/notifications/system_only_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({super.key});

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  String _testResult = '';
  bool _isLoading = false;
  
  // Voice search testing
  stt.SpeechToText? _speech;
  bool _isListening = false;
  String _voiceResult = '';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> _testCustomerSound() async {
    setState(() {
      _isLoading = true;
      _testResult = 'Testing customer notification...';
    });

    try {
      final success = await ReliableSoundService.instance.playCustomerNotification();
      setState(() {
        _testResult = success 
          ? '✅ Customer notification SUCCESS! Check console for details.'
          : '❌ Customer notification FAILED. Check console for details.';
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
      final success = await ReliableSoundService.instance.playDriverNotification();
      setState(() {
        _testResult = success 
          ? '✅ Driver notification SUCCESS! Check console for details.'
          : '❌ Driver notification FAILED. Check console for details.';
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
      final success = await ReliableSoundService.instance.playCompletionNotification();
      setState(() {
        _testResult = success 
          ? '✅ Completion notification SUCCESS! Check console for details.'
          : '❌ Completion notification FAILED. Check console for details.';
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
      final results = await ReliableSoundService.instance.testAllNotifications();
      final successCount = results.values.where((success) => success).length;
      setState(() {
        _testResult = '📊 Test Results: $successCount/3 notifications working\n'
          'Customer: ${results['customer'] == true ? '✅' : '❌'}\n'
          'Driver: ${results['driver'] == true ? '✅' : '❌'}\n'
          'Completion: ${results['completion'] == true ? '✅' : '❌'}\n'
          'Check console for detailed logs.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _testResult = '❌ Full notification test failed: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _testVoiceSearch() async {
    print('🎤 Testing voice search functionality...');
    
    if (_speech == null) {
      setState(() {
        _voiceResult = '❌ Speech service not initialized';
      });
      return;
    }

    if (_isListening) {
      await _speech!.stop();
      setState(() {
        _isListening = false;
        _voiceResult = '🛑 Voice search stopped';
      });
      return;
    }

    try {
      setState(() {
        _voiceResult = '🔄 Initializing voice recognition...';
      });

      final available = await _speech!.initialize(
        onStatus: (status) {
          print('🎤 Voice test status: $status');
          setState(() {
            _voiceResult = '🎤 Status: $status';
          });
        },
        onError: (error) {
          print('❌ Voice test error: $error');
          setState(() {
            _voiceResult = '❌ Error: ${error.errorMsg}';
            _isListening = false;
          });
        },
      );

      if (!available) {
        setState(() {
          _voiceResult = '❌ Voice recognition not available on this device';
        });
        return;
      }

      setState(() {
        _isListening = true;
        _voiceResult = '🎤 Listening... Say something!';
      });

      _speech!.listen(
        onResult: (result) {
          print('🎤 Voice test result: ${result.recognizedWords}');
          setState(() {
            _voiceResult = result.finalResult 
              ? '✅ Final result: "${result.recognizedWords}"'
              : '🔄 Partial: "${result.recognizedWords}"';
          });
          
          if (result.finalResult) {
            setState(() => _isListening = false);
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 2),
      );
    } catch (e) {
      print('❌ Voice test failed: $e');
      setState(() {
        _voiceResult = '❌ Voice test failed: $e';
        _isListening = false;
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
            
            // PRIORITY TEST: SystemSound only (most likely to work)
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () async {
                setState(() {
                  _isLoading = true;
                  _testResult = 'Testing SYSTEM-ONLY sounds (no external URLs)...';
                });
                try {
                  final results = await SystemOnlyService.instance.testSystemSoundTypes();
                  final workingCount = results.values.where((s) => s).length;
                  setState(() {
                    _testResult = '🔊 SYSTEM-ONLY Test: $workingCount/2 SystemSound types work\n'
                      'Alert Sound: ${results['alert'] == true ? '✅ WORKS' : '❌ SILENT'}\n'
                      'Click Sound: ${results['click'] == true ? '✅ WORKS' : '❌ SILENT'}\n'
                      '\n💡 This test uses ONLY SystemSound (no CORS issues)\n'
                      'If you don\'t hear anything, check device system sound settings';
                    _isLoading = false;
                  });
                } catch (e) {
                  setState(() {
                    _testResult = '❌ System-only test failed: $e';
                    _isLoading = false;
                  });
                }
              },
              icon: const Icon(Icons.volume_up),
              label: const Text('🔊 SYSTEM-ONLY Test (Priority)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 12),
            
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
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: (_isLoading || _isListening) ? null : _testVoiceSearch,
              icon: Icon(_isListening ? Icons.stop : Icons.mic),
              label: Text(_isListening ? 'Stop Voice Test' : 'Test Voice Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isListening ? Colors.red : Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () async {
                setState(() {
                  _isLoading = true;
                  _testResult = 'Testing emergency sound fallback...';
                });
                try {
                  final success = await ReliableSoundService.instance.playNotification(isUrgent: true);
                  setState(() {
                    _testResult = success 
                      ? '✅ EMERGENCY sound test SUCCESS! At least one method worked.'
                      : '❌ EMERGENCY sound test FAILED! All methods failed.';
                    _isLoading = false;
                  });
                } catch (e) {
                  setState(() {
                    _testResult = '❌ Emergency sound test failed: $e';
                    _isLoading = false;
                  });
                }
              },
              icon: const Icon(Icons.emergency),
              label: const Text('Emergency Sound Test'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 24),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () async {
                setState(() {
                  _isLoading = true;
                  _testResult = 'Testing AUDIBLE notifications...';
                });
                try {
                  final results = await AudibleNotificationService.instance.testAllSounds();
                  final successCount = results.values.where((s) => s).length;
                  setState(() {
                    _testResult = '🔊 AUDIBLE Test Results: $successCount/4 sounds played\n'
                      'Customer: ${results['customer'] == true ? '✅' : '❌'}\n'
                      'Driver: ${results['driver'] == true ? '✅' : '❌'}\n'
                      'Completion: ${results['completion'] == true ? '✅' : '❌'}\n'
                      'Emergency: ${results['emergency'] == true ? '✅' : '❌'}\n'
                      'Check console for detailed logs.';
                    _isLoading = false;
                  });
                } catch (e) {
                  setState(() {
                    _testResult = '❌ Audible notification test failed: $e';
                    _isLoading = false;
                  });
                }
              },
              icon: const Icon(Icons.volume_up),
              label: const Text('Test AUDIBLE Notifications'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () async {
                setState(() {
                  _isLoading = true;
                  _testResult = 'Playing LOUDEST possible notification...';
                });
                try {
                  final success = await AudibleNotificationService.instance.playLoudestNotification();
                  setState(() {
                    _testResult = success 
                      ? '📢 LOUDEST notification SUCCESS! You should have heard it!'
                      : '❌ Even LOUDEST notification failed. Check device volume.';
                    _isLoading = false;
                  });
                } catch (e) {
                  setState(() {
                    _testResult = '❌ Loudest notification test failed: $e';
                    _isLoading = false;
                  });
                }
              },
              icon: const Icon(Icons.campaign),
              label: const Text('Play LOUDEST Notification'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () async {
                setState(() {
                  _isLoading = true;
                  _testResult = 'Testing WORKING notification methods...';
                });
                try {
                  final results = await WorkingSoundService.instance.testWorkingNotifications();
                  final successCount = results.values.where((s) => s).length;
                  setState(() {
                    _testResult = '🔧 WORKING Methods Test: $successCount/4 types successful\n'
                      'Customer: ${results['customer'] == true ? '✅' : '❌'}\n'
                      'Driver: ${results['driver'] == true ? '✅' : '❌'}\n'
                      'Completion: ${results['completion'] == true ? '✅' : '❌'}\n'
                      'Emergency: ${results['emergency'] == true ? '✅' : '❌'}\n'
                      'Uses: SystemSound + HapticFeedback only';
                    _isLoading = false;
                  });
                } catch (e) {
                  setState(() {
                    _testResult = '❌ Working methods test failed: $e';
                    _isLoading = false;
                  });
                }
              },
              icon: const Icon(Icons.build),
              label: const Text('Test WORKING Methods Only'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () async {
                setState(() {
                  _isLoading = true;
                  _testResult = 'Testing SIMPLE beep methods (like voice search)...';
                });
                try {
                  final results = await SimpleBeepService.instance.testIndividualMethods();
                  final successCount = results.values.where((s) => s).length;
                  setState(() {
                    _testResult = '🔊 SIMPLE Beep Test: $successCount/5 methods worked\n'
                      'System Alert: ${results['system_alert'] == true ? '✅' : '❌'}\n'
                      'Urgent Alert: ${results['urgent_alert'] == true ? '✅' : '❌'}\n'
                      'Haptic Only: ${results['haptic_only'] == true ? '✅' : '❌'}\n'
                      'Customer: ${results['customer'] == true ? '✅' : '❌'}\n'
                      'Driver: ${results['driver'] == true ? '✅' : '❌'}\n'
                      'Uses same methods as voice search!';
                    _isLoading = false;
                  });
                } catch (e) {
                  setState(() {
                    _testResult = '❌ Simple beep test failed: $e';
                    _isLoading = false;
                  });
                }
              },
              icon: const Icon(Icons.volume_down),
              label: const Text('Test SIMPLE Beeps (Like Voice)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () async {
                setState(() {
                  _isLoading = true;
                  _testResult = 'Testing VOICE HIJACK method (uses voice search audio)...';
                });
                try {
                  final success = await VoiceHijackService.instance.testVoiceHijack();
                  setState(() {
                    _testResult = success 
                      ? '🎤 VOICE HIJACK SUCCESS! Uses same audio system as voice search'
                      : '❌ VOICE HIJACK FAILED. Even voice audio system not working';
                    _isLoading = false;
                  });
                } catch (e) {
                  setState(() {
                    _testResult = '❌ Voice hijack test failed: $e';
                    _isLoading = false;
                  });
                }
              },
              icon: const Icon(Icons.record_voice_over),
              label: const Text('Test VOICE HIJACK Method'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () async {
                setState(() {
                  _isLoading = true;
                  _testResult = 'Trying EVERY possible sound method...';
                });
                try {
                  final success = await VoiceHijackService.instance.playAnySoundPossible();
                  setState(() {
                    _testResult = success 
                      ? '🚨 EMERGENCY SUCCESS! At least one sound method worked'
                      : '💥 TOTAL FAILURE! No sound methods work on this device';
                    _isLoading = false;
                  });
                } catch (e) {
                  setState(() {
                    _testResult = '❌ Emergency sound test failed: $e';
                    _isLoading = false;
                  });
                }
              },
              icon: const Icon(Icons.warning),
              label: const Text('EMERGENCY: Try ANY Sound'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () async {
                setState(() {
                  _isLoading = true;
                  _testResult = 'Testing Flutter built-in feedback system...';
                });
                try {
                  final results = await FlutterFeedbackService.instance.testAllFlutterFeedback(context);
                  final successCount = results.values.where((s) => s).length;
                  setState(() {
                    _testResult = '🎯 FLUTTER FEEDBACK: $successCount/5 methods worked\n'
                      'Light Impact: ${results['light_impact'] == true ? '✅' : '❌'}\n'
                      'Medium Impact: ${results['medium_impact'] == true ? '✅' : '❌'}\n'
                      'Heavy Impact: ${results['heavy_impact'] == true ? '✅' : '❌'}\n'
                      'Selection Click: ${results['selection_click'] == true ? '✅' : '❌'}\n'
                      'Vibrate: ${results['vibrate'] == true ? '✅' : '❌'}\n'
                      'This explains the "shaking" you feel!';
                    _isLoading = false;
                  });
                } catch (e) {
                  setState(() {
                    _testResult = '❌ Flutter feedback test failed: $e';
                    _isLoading = false;
                  });
                }
              },
              icon: const Icon(Icons.touch_app),
              label: const Text('Test Flutter Feedback (Shaking)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () async {
                setState(() {
                  _isLoading = true;
                  _testResult = 'Running FULL SOUND INVESTIGATION...';
                });
                try {
                  final results = await SoundDetectiveService.instance.fullSoundInvestigation();
                  final systemSounds = results['system_sounds'] as Map<String, bool>;
                  final workingSounds = systemSounds.values.where((s) => s).length;
                  
                  setState(() {
                    _testResult = '🕵️ SOUND DETECTIVE REPORT:\n'
                      'Working SystemSounds: $workingSounds/2\n'
                      'Alert Sound: ${systemSounds['alert'] == true ? '✅' : '❌'}\n'
                      'Click Sound: ${systemSounds['click'] == true ? '✅' : '❌'}\n'
                      'Timing Test: ${results['timing_test'] == true ? '✅' : '❌'}\n'
                      'Context Test: ${results['context_test'] == true ? '✅' : '❌'}\n'
                      '\nThis will help identify why sounds don\'t work!';
                    _isLoading = false;
                  });
                } catch (e) {
                  setState(() {
                    _testResult = '❌ Sound investigation failed: $e';
                    _isLoading = false;
                  });
                }
              },
              icon: const Icon(Icons.search),
              label: const Text('🕵️ SOUND DETECTIVE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown,
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
            
            if (_voiceResult.isNotEmpty)
              Card(
                color: _voiceResult.contains('✅') ? Colors.green.shade50 : 
                       _voiceResult.contains('🎤') ? Colors.blue.shade50 : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Voice Search Result:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _voiceResult.contains('✅') ? Colors.green.shade800 : Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _voiceResult,
                        style: TextStyle(
                          color: _voiceResult.contains('✅') ? Colors.green.shade700 : Colors.blue.shade700,
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
                    Text('• Check microphone permissions for voice search'),
                    Text('• Try different notification types'),
                    Text('• Check console logs for detailed error messages'),
                    Text('• On web, some browsers block auto-play sounds'),
                    Text('• For voice search: speak clearly and wait for result'),
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