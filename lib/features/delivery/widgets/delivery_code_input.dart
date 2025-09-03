import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zippup/services/delivery/delivery_code_service.dart';

/// Secure delivery code input widget for drivers
class DeliveryCodeInput extends StatefulWidget {
  final String orderId;
  final String driverId;
  final Function(bool) onVerificationComplete;

  const DeliveryCodeInput({
    super.key,
    required this.orderId,
    required this.driverId,
    required this.onVerificationComplete,
  });

  @override
  State<DeliveryCodeInput> createState() => _DeliveryCodeInputState();
}

class _DeliveryCodeInputState extends State<DeliveryCodeInput> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isVerifying = false;
  String? _errorMessage;
  int? _remainingAttempts;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.verified, color: Colors.green.shade700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter Delivery Code',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Ask customer for their 6-digit delivery code',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Code input fields
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) => _buildCodeInput(index)),
          ),

          const SizedBox(height: 16),

          // Error message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Remaining attempts indicator
          if (_remainingAttempts != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '$_remainingAttempts attempts remaining',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isVerifying ? null : () => _reportDeliveryIssue(),
                  icon: const Icon(Icons.report_problem),
                  label: const Text('Report Issue'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _isVerifying || !_isCodeComplete() ? null : _verifyCode,
                  icon: _isVerifying 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.verified),
                  label: Text(_isVerifying ? 'Verifying...' : 'Complete Delivery'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Help text
          Text(
            'The customer received this code when they placed the order',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeInput(int index) {
    return Container(
      width: 45,
      height: 55,
      decoration: BoxDecoration(
        border: Border.all(
          color: _errorMessage != null ? Colors.red : Colors.grey.shade300,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
        ],
        onChanged: (value) => _onCodeChanged(index, value),
      ),
    );
  }

  void _onCodeChanged(int index, String value) {
    // Clear error when user types
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
        _remainingAttempts = null;
      });
    }

    if (value.isNotEmpty) {
      // Move to next field
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        // Last field - unfocus
        _focusNodes[index].unfocus();
      }
    } else {
      // Move to previous field on backspace
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  bool _isCodeComplete() {
    return _controllers.every((controller) => controller.text.isNotEmpty);
  }

  String _getEnteredCode() {
    return _controllers.map((controller) => controller.text.toUpperCase()).join('');
  }

  Future<void> _verifyCode() async {
    if (!_isCodeComplete()) {
      setState(() => _errorMessage = 'Please enter all 6 digits');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      // Get current location
      final position = await _getCurrentLocation();
      
      // Verify code
      final result = await DeliveryCodeService.verifyCode(
        orderId: widget.orderId,
        enteredCode: _getEnteredCode(),
        driverId: widget.driverId,
        driverLat: position.latitude,
        driverLng: position.longitude,
      );

      if (result.isValid) {
        // Success
        widget.onVerificationComplete(true);
        _showSuccessDialog();
      } else {
        // Failed verification
        setState(() {
          _errorMessage = result.message;
          _remainingAttempts = result.remainingAttempts;
        });

        if (result.isBlocked) {
          widget.onVerificationComplete(false);
          _showBlockedDialog();
        } else {
          // Clear the input for retry
          _clearCode();
          _focusNodes[0].requestFocus();
        }
      }

    } catch (e) {
      setState(() => _errorMessage = 'Verification failed: $e');
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  void _clearCode() {
    for (final controller in _controllers) {
      controller.clear();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.check_circle, color: Colors.green, size: 64),
        title: const Text('Delivery Completed!'),
        content: const Text('Order has been successfully delivered to the customer.'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close code input
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showBlockedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.block, color: Colors.red, size: 64),
        title: const Text('Verification Blocked'),
        content: const Text(
          'Too many failed attempts. This order has been flagged for manual review. Please contact support.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close code input
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  void _reportDeliveryIssue() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Delivery Issue'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person_off),
              title: Text('Customer not available'),
              onTap: () => _handleDeliveryIssue('customer_not_available'),
            ),
            ListTile(
              leading: Icon(Icons.location_off),
              title: Text('Wrong address'),
              onTap: () => _handleDeliveryIssue('wrong_address'),
            ),
            ListTile(
              leading: Icon(Icons.code_off),
              title: Text('Customer lost delivery code'),
              onTap: () => _handleDeliveryIssue('lost_code'),
            ),
            ListTile(
              leading: Icon(Icons.report),
              title: Text('Other issue'),
              onTap: () => _handleDeliveryIssue('other'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleDeliveryIssue(String issueType) {
    Navigator.pop(context); // Close issue dialog
    
    // Create support ticket and handle appropriately
    // Implementation would depend on specific business rules
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Issue reported. Support will contact you shortly.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Future<Position> _getCurrentLocation() async {
    // Implementation would use geolocator package
    // For now, return mock location
    return Position(
      latitude: 6.5244,
      longitude: 3.3792,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }
}

// Mock Position class for compilation
class Position {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double accuracy;
  final double altitude;
  final double heading;
  final double speed;
  final double speedAccuracy;
  final double altitudeAccuracy;
  final double headingAccuracy;

  const Position({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.accuracy,
    required this.altitude,
    required this.heading,
    required this.speed,
    required this.speedAccuracy,
    required this.altitudeAccuracy,
    required this.headingAccuracy,
  });
}