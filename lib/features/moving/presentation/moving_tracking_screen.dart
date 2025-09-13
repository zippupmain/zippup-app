import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zippup/services/requests/moving_listener_service.dart';

class MovingTrackingScreen extends StatefulWidget {
  final String requestId;

  const MovingTrackingScreen({
    super.key,
    required this.requestId,
  });

  @override
  State<MovingTrackingScreen> createState() => _MovingTrackingScreenState();
}

class _MovingTrackingScreenState extends State<MovingTrackingScreen> {
  StreamSubscription<DocumentSnapshot>? _requestSubscription;
  MovingStatus _currentStatus = MovingStatus.requesting;
  Map<String, dynamic>? _requestData;
  Map<String, dynamic>? _providerData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupMovingRequestListener();
  }

  @override
  void dispose() {
    _requestSubscription?.cancel();
    super.dispose();
  }

  void _setupMovingRequestListener() {
    _requestSubscription = MovingListenerService.listenToMovingRequest(
      requestId: widget.requestId,
      onStatusChange: _handleStatusChange,
      onError: _handleError,
    );
  }

  Future<void> _handleStatusChange(MovingStatus status, Map<String, dynamic> requestData) async {
    setState(() {
      _currentStatus = status;
      _requestData = requestData;
      _isLoading = false;
      _error = null;
    });

    // Handle specific status changes
    switch (status) {
      case MovingStatus.providerAssigned:
        await _handleProviderAssigned(requestData);
        break;
      case MovingStatus.accepted:
        await _handleProvingProviderAccepted(requestData);
        break;
      case MovingStatus.providerArrived:
        _handleProviderArrived();
        break;
      case MovingStatus.quoteProvided:
        _handleQuoteProvided();
        break;
      case MovingStatus.completed:
        _handleMovingCompleted();
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

  Future<void> _handleProviderAssigned(Map<String, dynamic> requestData) async {
    final providerId = requestData['providerId'] as String?;
    if (providerId != null) {
      _showStatusMessage(
        '📦 Moving Provider Found!',
        'We found a moving provider for you. Waiting for confirmation...',
        Colors.blue,
      );

      final providerInfo = await MovingListenerService.getMovingProviderInfo(providerId);
      if (providerInfo != null) {
        setState(() {
          _providerData = providerInfo;
        });
      }
    }
  }

  Future<void> _handleMovingProviderAccepted(Map<String, dynamic> requestData) async {
    final providerId = requestData['providerId'] as String?;
    if (providerId != null) {
      _showStatusMessage(
        '✅ Provider Accepted!',
        'Your moving provider is on the way for initial survey.',
        Colors.green,
      );

      if (_providerData == null) {
        final providerInfo = await MovingListenerService.getMovingProviderInfo(providerId);
        if (providerInfo != null) {
          setState(() {
            _providerData = providerInfo;
          });
        }
      }
    }
  }

  void _handleProviderArrived() {
    _showStatusMessage(
      '📍 Provider Arrived!',
      'Your moving provider has arrived and will survey your items.',
      Colors.green,
    );
  }

  void _handleQuoteProvided() {
    _showStatusMessage(
      '💰 Quote Ready!',
      'Your moving provider has provided a quote. Please review and accept.',
      Colors.purple,
    );
  }

  void _handleMovingCompleted() {
    _showStatusMessage(
      '🎉 Moving Completed!',
      'Your move has been completed successfully. Please rate your experience.',
      Colors.green,
    );

    Future.delayed(const Duration(seconds: 3), () {
      _navigateToRatingScreen();
    });
  }

  void _showStatusMessage(String title, String message, Color color) {
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
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToRatingScreen() {
    print('🧭 Navigating to moving rating screen');
  }

  Future<void> _cancelMovingRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Moving Request'),
        content: const Text('Are you sure you want to cancel this moving request?'),
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
        await MovingListenerService.updateMovingRequestStatus(
          requestId: widget.requestId,
          newStatus: 'cancelled_by_customer',
          additionalData: {
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancellationReason': 'cancelled_by_customer',
          },
        );

        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to cancel moving request: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _acceptQuote() async {
    try {
      await MovingListenerService.acceptMovingQuote(widget.requestId);
      _showStatusMessage(
        '✅ Quote Accepted!',
        'Your quote has been accepted. The moving will proceed as scheduled.',
        Colors.green,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept quote: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _declineQuote() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Quote'),
        content: const Text('Are you sure you want to decline this quote? This will cancel the moving request.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Decline'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await MovingListenerService.updateMovingRequestStatus(
          requestId: widget.requestId,
          newStatus: 'cancelled_by_customer',
          additionalData: {
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancellationReason': 'quote_declined',
          },
        );

        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to decline quote: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Moving Request'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          if (_currentStatus == MovingStatus.requesting || 
              _currentStatus == MovingStatus.providerAssigned)
            IconButton(
              onPressed: _cancelMovingRequest,
              icon: const Icon(Icons.close),
              tooltip: 'Cancel Moving Request',
            ),
        ],
      ),
      body: _buildBody(),
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
            Text('Loading moving request information...'),
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
                _setupMovingRequestListener();
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
          // Moving status widget
          MovingStatusWidget(
            status: _currentStatus,
            requestData: _requestData,
            providerData: _providerData,
            onCancel: (_currentStatus == MovingStatus.requesting || 
                      _currentStatus == MovingStatus.providerAssigned)
                ? _cancelMovingRequest
                : null,
            onAcceptQuote: _currentStatus == MovingStatus.quoteProvided
                ? _acceptQuote
                : null,
            onDeclineQuote: _currentStatus == MovingStatus.quoteProvided
                ? _declineQuote
                : null,
          ),

          // Progress tracker
          if (_currentStatus.isActiveStatus) ...[
            _buildProgressTracker(),
          ],

          // Additional information based on status
          if (_currentStatus == MovingStatus.surveyStarted) ...[
            _buildSurveyInfo(),
          ],

          if (_currentStatus == MovingStatus.loadingStarted ||
              _currentStatus == MovingStatus.inTransit ||
              _currentStatus == MovingStatus.unloadingStarted) ...[
            _buildMovingProgress(),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressTracker() {
    final steps = [
      {'title': 'Provider Assigned', 'status': MovingStatus.providerAssigned},
      {'title': 'Provider Accepted', 'status': MovingStatus.accepted},
      {'title': 'Provider Arrived', 'status': MovingStatus.providerArrived},
      {'title': 'Survey Complete', 'status': MovingStatus.surveyStarted},
      {'title': 'Quote Accepted', 'status': MovingStatus.quoteAccepted},
      {'title': 'Loading', 'status': MovingStatus.loadingStarted},
      {'title': 'In Transit', 'status': MovingStatus.inTransit},
      {'title': 'Unloading', 'status': MovingStatus.unloadingStarted},
      {'title': 'Completed', 'status': MovingStatus.completed},
    ];

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Moving Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...steps.map((step) {
              final stepStatus = step['status'] as MovingStatus;
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
                             isCurrent ? Colors.blue : Colors.grey,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      step['title'] as String,
                      style: TextStyle(
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        color: isCompleted ? Colors.green : 
                               isCurrent ? Colors.blue : Colors.grey,
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

  bool _isStepCompleted(MovingStatus stepStatus) {
    final statusOrder = [
      MovingStatus.requesting,
      MovingStatus.providerAssigned,
      MovingStatus.accepted,
      MovingStatus.providerArrived,
      MovingStatus.surveyStarted,
      MovingStatus.quoteProvided,
      MovingStatus.quoteAccepted,
      MovingStatus.loadingStarted,
      MovingStatus.inTransit,
      MovingStatus.unloadingStarted,
      MovingStatus.completed,
    ];

    final currentIndex = statusOrder.indexOf(_currentStatus);
    final stepIndex = statusOrder.indexOf(stepStatus);
    
    return currentIndex > stepIndex;
  }

  Widget _buildSurveyInfo() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.assignment, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Survey in Progress',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'The moving provider is surveying your items to provide an accurate quote. This usually takes 15-30 minutes.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovingProgress() {
    String progressText = '';
    Color progressColor = Colors.blue;
    IconData progressIcon = Icons.local_shipping;

    switch (_currentStatus) {
      case MovingStatus.loadingStarted:
        progressText = 'Loading your items into the moving vehicle...';
        progressColor = Colors.orange;
        progressIcon = Icons.inbox;
        break;
      case MovingStatus.inTransit:
        progressText = 'Your items are being transported to the destination...';
        progressColor = Colors.blue;
        progressIcon = Icons.local_shipping;
        break;
      case MovingStatus.unloadingStarted:
        progressText = 'Unloading your items at the destination...';
        progressColor = Colors.green;
        progressIcon = Icons.outbox;
        break;
      default:
        break;
    }

    return Card(
      margin: const EdgeInsets.all(16),
      color: progressColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(progressIcon, color: progressColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    progressText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: progressColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ],
        ),
      ),
    );
  }
}