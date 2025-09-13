import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zippup/services/requests/emergency_listener_service.dart';

class EmergencyTrackingScreen extends StatefulWidget {
  final String requestId;
  final String emergencyType;

  const EmergencyTrackingScreen({
    super.key,
    required this.requestId,
    required this.emergencyType,
  });

  @override
  State<EmergencyTrackingScreen> createState() => _EmergencyTrackingScreenState();
}

class _EmergencyTrackingScreenState extends State<EmergencyTrackingScreen> {
  StreamSubscription<DocumentSnapshot>? _requestSubscription;
  EmergencyStatus _currentStatus = EmergencyStatus.requesting;
  Map<String, dynamic>? _requestData;
  Map<String, dynamic>? _responderData;
  bool _isLoading = true;
  String? _error;

  // Emergency type configurations
  final Map<String, Map<String, dynamic>> _emergencyConfigs = {
    'ambulance': {
      'title': 'Medical Emergency',
      'icon': Icons.medical_services,
      'color': Colors.red,
      'emoji': '🚑',
    },
    'fire_service': {
      'title': 'Fire Emergency',
      'icon': Icons.local_fire_department,
      'color': Colors.red.shade700,
      'emoji': '🚒',
    },
    'security_service': {
      'title': 'Security Emergency',
      'icon': Icons.security,
      'color': Colors.blue.shade700,
      'emoji': '🚔',
    },
    'towing_van': {
      'title': 'Towing Service',
      'icon': Icons.car_repair,
      'color': Colors.orange.shade700,
      'emoji': '🚛',
    },
  };

  @override
  void initState() {
    super.initState();
    _setupEmergencyRequestListener();
  }

  @override
  void dispose() {
    _requestSubscription?.cancel();
    super.dispose();
  }

  void _setupEmergencyRequestListener() {
    _requestSubscription = EmergencyListenerService.listenToEmergencyRequest(
      requestId: widget.requestId,
      onStatusChange: _handleStatusChange,
      onError: _handleError,
    );
  }

  Future<void> _handleStatusChange(EmergencyStatus status, Map<String, dynamic> requestData) async {
    setState(() {
      _currentStatus = status;
      _requestData = requestData;
      _isLoading = false;
      _error = null;
    });

    // Handle specific status changes
    switch (status) {
      case EmergencyStatus.responderAssigned:
        await _handleResponderAssigned(requestData);
        break;
      case EmergencyStatus.accepted:
        await _handleResponderAccepted(requestData);
        break;
      case EmergencyStatus.responderArrived:
        _handleResponderArrived();
        break;
      case EmergencyStatus.serviceStarted:
        _handleServiceStarted();
        break;
      case EmergencyStatus.transportRequired:
        _handleTransportRequired();
        break;
      case EmergencyStatus.completed:
        _handleEmergencyCompleted();
        break;
      default:
        break;
    }
  }

  void _handleError(String error) {
    setState(() {
      _error = error;
      _isLoading = false;
    });
  }

  Future<void> _handleResponderAssigned(Map<String, dynamic> requestData) async {
    final responderId = requestData['responderId'] as String?;
    if (responderId != null) {
      _showCriticalMessage(
        '🚨 Emergency Responder Assigned!',
        'Help is on the way. Stay calm and follow any instructions.',
        _getEmergencyColor(),
      );

      final responderInfo = await EmergencyListenerService.getEmergencyResponderInfo(responderId);
      if (responderInfo != null) {
        setState(() {
          _responderData = responderInfo;
        });
      }
    }
  }

  Future<void> _handleResponderAccepted(Map<String, dynamic> requestData) async {
    _showCriticalMessage(
      '✅ Responder Confirmed!',
      'Emergency responder has confirmed and is en route to your location.',
      Colors.green,
    );
  }

  void _handleResponderArrived() {
    _showCriticalMessage(
      '📍 Emergency Responder Arrived!',
      'The emergency responder has arrived at your location.',
      Colors.green,
    );

    // Show prominent arrival dialog
    _showArrivalDialog();
  }

  void _handleServiceStarted() {
    _showCriticalMessage(
      '🚑 Emergency Service Started',
      'Emergency service is now in progress.',
      Colors.blue,
    );
  }

  void _handleTransportRequired() {
    _showCriticalMessage(
      '🏥 Transport Required',
      'Transport to medical facility is required.',
      Colors.red,
    );
  }

  void _handleEmergencyCompleted() {
    _showCriticalMessage(
      '✅ Emergency Response Completed',
      'The emergency response has been completed.',
      Colors.green,
    );

    Future.delayed(const Duration(seconds: 3), () {
      _navigateToFeedbackScreen();
    });
  }

  void _showCriticalMessage(String title, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(message),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showArrivalDialog() {
    final config = _getEmergencyConfig();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(config['icon'], color: config['color']),
            const SizedBox(width: 8),
            const Text('Responder Arrived!'),
          ],
        ),
        content: Text(
          'The emergency responder has arrived at your location. Please proceed to meet them or follow their instructions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToFeedbackScreen() {
    print('🧭 Navigating to emergency feedback screen');
  }

  Future<void> _cancelEmergencyRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Emergency Request'),
        content: const Text(
          'Are you sure you want to cancel this emergency request? '
          'This should only be done if the emergency is no longer needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await EmergencyListenerService.updateEmergencyRequestStatus(
          requestId: widget.requestId,
          newStatus: 'cancelled_by_requester',
          additionalData: {
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancellationReason': 'cancelled_by_requester',
          },
        );

        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel emergency request: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _requestAdditionalHelp() async {
    final resources = [
      'Additional Ambulance',
      'Fire Department',
      'Police Backup',
      'Specialized Equipment',
      'Additional Personnel',
    ];

    final selectedResource = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Additional Help'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: resources.map((resource) => ListTile(
            title: Text(resource),
            onTap: () => Navigator.of(context).pop(resource),
          )).toList(),
        ),
      ),
    );

    if (selectedResource != null) {
      final reason = await showDialog<String>(
        context: context,
        builder: (context) {
          final controller = TextEditingController();
          return AlertDialog(
            title: Text('Request $selectedResource'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Reason for additional help',
                hintText: 'Please describe why additional help is needed',
              ),
              maxLines: 3,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('Request'),
              ),
            ],
          );
        },
      );

      if (reason != null && reason.isNotEmpty) {
        try {
          await EmergencyListenerService.requestAdditionalResources(
            requestId: widget.requestId,
            resourceType: selectedResource,
            reason: reason,
            urgency: 'high',
          );

          _showCriticalMessage(
            '🚨 Additional Help Requested',
            'Request for $selectedResource has been submitted.',
            Colors.orange,
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to request additional help: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Map<String, dynamic> _getEmergencyConfig() {
    return _emergencyConfigs[widget.emergencyType] ?? _emergencyConfigs['ambulance']!;
  }

  Color _getEmergencyColor() {
    return _getEmergencyConfig()['color'];
  }

  @override
  Widget build(BuildContext context) {
    final config = _getEmergencyConfig();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('${config['emoji']} ${config['title']}'),
        backgroundColor: config['color'],
        foregroundColor: Colors.white,
        actions: [
          if (_currentStatus == EmergencyStatus.requesting || 
              _currentStatus == EmergencyStatus.responderAssigned)
            IconButton(
              onPressed: _cancelEmergencyRequest,
              icon: const Icon(Icons.close),
              tooltip: 'Cancel Emergency Request',
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _currentStatus.isActiveStatus
          ? FloatingActionButton.extended(
              onPressed: _requestAdditionalHelp,
              backgroundColor: Colors.red,
              icon: const Icon(Icons.add_alert),
              label: const Text('Request Help'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading emergency request information...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $_error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _setupEmergencyRequestListener();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Emergency status widget
          EmergencyStatusWidget(
            status: _currentStatus,
            requestData: _requestData,
            responderData: _responderData,
            onCancel: (_currentStatus == EmergencyStatus.requesting || 
                      _currentStatus == EmergencyStatus.responderAssigned)
                ? _cancelEmergencyRequest
                : null,
            onRequestAdditionalHelp: _currentStatus.isActiveStatus
                ? _requestAdditionalHelp
                : null,
          ),

          // Emergency instructions
          if (_currentStatus.isCriticalStatus) ...[
            _buildEmergencyInstructions(),
          ],

          // Response timeline
          if (_currentStatus.isActiveStatus) ...[
            _buildResponseTimeline(),
          ],

          // Safety information
          _buildSafetyInformation(),
        ],
      ),
    );
  }

  Widget _buildEmergencyInstructions() {
    final config = _getEmergencyConfig();
    String instructions = '';
    List<String> steps = [];

    switch (widget.emergencyType) {
      case 'ambulance':
        instructions = 'Medical Emergency Instructions';
        steps = [
          'Stay calm and keep the patient comfortable',
          'Do not move the patient unless absolutely necessary',
          'Keep airways clear and monitor breathing',
          'Apply pressure to any bleeding wounds',
          'Be ready to provide medical history to responders',
        ];
        break;
      case 'fire_service':
        instructions = 'Fire Emergency Instructions';
        steps = [
          'Evacuate the area immediately if safe to do so',
          'Do not use elevators during evacuation',
          'Stay low to avoid smoke inhalation',
          'Do not re-enter the building',
          'Meet responders at a safe distance',
        ];
        break;
      case 'security_service':
        instructions = 'Security Emergency Instructions';
        steps = [
          'Stay in a safe location',
          'Do not confront any threats',
          'Keep doors locked if indoors',
          'Be ready to identify yourself to responders',
          'Follow all instructions from security personnel',
        ];
        break;
      case 'towing_van':
        instructions = 'Towing Service Instructions';
        steps = [
          'Move to a safe location away from traffic',
          'Turn on hazard lights',
          'Remove personal belongings from vehicle',
          'Have vehicle documents ready',
          'Stay visible to the towing operator',
        ];
        break;
    }

    return Card(
      margin: const EdgeInsets.all(16),
      color: config['color'].withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: config['color']),
                const SizedBox(width: 8),
                Text(
                  instructions,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: config['color'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...steps.map((step) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: config['color'])),
                  Expanded(child: Text(step)),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseTimeline() {
    final config = _getEmergencyConfig();
    final steps = [
      {'title': 'Request Received', 'status': EmergencyStatus.requesting},
      {'title': 'Responder Assigned', 'status': EmergencyStatus.responderAssigned},
      {'title': 'Responder Confirmed', 'status': EmergencyStatus.accepted},
      {'title': 'Responder Dispatched', 'status': EmergencyStatus.responderDispatched},
      {'title': 'Responder Arrived', 'status': EmergencyStatus.responderArrived},
      {'title': 'Service Started', 'status': EmergencyStatus.serviceStarted},
      {'title': 'Service Complete', 'status': EmergencyStatus.serviceCompleted},
    ];

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Response Timeline',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: config['color'],
              ),
            ),
            const SizedBox(height: 16),
            ...steps.map((step) {
              final stepStatus = step['status'] as EmergencyStatus;
              final isCompleted = _isStepCompleted(stepStatus);
              final isCurrent = stepStatus == _currentStatus;
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle : 
                      isCurrent ? Icons.radio_button_checked : 
                      Icons.radio_button_unchecked,
                      color: isCompleted ? Colors.green : 
                             isCurrent ? config['color'] : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      step['title'] as String,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCompleted ? Colors.green : 
                               isCurrent ? config['color'] : Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  bool _isStepCompleted(EmergencyStatus stepStatus) {
    final statusOrder = [
      EmergencyStatus.requesting,
      EmergencyStatus.responderAssigned,
      EmergencyStatus.accepted,
      EmergencyStatus.responderDispatched,
      EmergencyStatus.responderArriving,
      EmergencyStatus.responderArrived,
      EmergencyStatus.serviceStarted,
      EmergencyStatus.serviceInProgress,
      EmergencyStatus.serviceCompleted,
      EmergencyStatus.completed,
    ];

    final currentIndex = statusOrder.indexOf(_currentStatus);
    final stepIndex = statusOrder.indexOf(stepStatus);
    
    return currentIndex > stepIndex;
  }

  Widget _buildSafetyInformation() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.shield, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Safety Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('• Emergency responders are trained professionals'),
            const Text('• Follow all instructions given by responders'),
            const Text('• Stay calm and provide accurate information'),
            const Text('• Keep emergency contact numbers handy'),
            const Text('• Do not leave the scene unless instructed'),
          ],
        ),
      ),
    );
  }
}