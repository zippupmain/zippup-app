import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Full-screen incoming call interface for service requests
class IncomingRequestCallScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic> requestData;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingRequestCallScreen({
    super.key,
    required this.orderId,
    required this.requestData,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<IncomingRequestCallScreen> createState() => _IncomingRequestCallScreenState();
}

class _IncomingRequestCallScreenState extends State<IncomingRequestCallScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _pulseController;
  late AnimationController _slideController;
  Timer? _timeoutTimer;
  int _remainingSeconds = 60;

  @override
  void initState() {
    super.initState();
    
    // Animations for visual appeal
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    )..forward();
    
    // Start countdown timer
    _startTimeoutTimer();
    
    // Haptic feedback for urgency
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startTimeoutTimer() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _remainingSeconds--);
      
      // Urgent haptic feedback in last 10 seconds
      if (_remainingSeconds <= 10 && _remainingSeconds > 0) {
        HapticFeedback.mediumImpact();
      }
      
      if (_remainingSeconds <= 0) {
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    _timeoutTimer?.cancel();
    HapticFeedback.heavyImpact();
    widget.onDecline(); // Auto-decline on timeout
  }

  void _handleAccept() {
    _timeoutTimer?.cancel();
    HapticFeedback.lightImpact();
    widget.onAccept();
  }

  void _handleDecline() {
    _timeoutTimer?.cancel(); 
    HapticFeedback.mediumImpact();
    widget.onDecline();
  }

  @override
  Widget build(BuildContext context) {
    final customerData = widget.requestData['customer'] ?? {};
    final paymentData = widget.requestData['payment'] ?? {};
    final serviceData = widget.requestData['service'] ?? {};
    final locationData = widget.requestData['locations'] ?? {};
    final pricingData = widget.requestData['pricing'] ?? {};

    return Scaffold(
      backgroundColor: Colors.black,
      body: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic)),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.orange.shade600,
                Colors.orange.shade800,
                Colors.orange.shade900,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header with countdown and service type
                _buildHeader(serviceData),
                
                // Customer profile section
                Expanded(flex: 3, child: _buildCustomerSection(customerData)),
                
                // Request details
                Expanded(flex: 3, child: _buildRequestDetails(paymentData, locationData, pricingData)),
                
                // Action buttons
                _buildActionButtons(),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> serviceData) {
    final serviceType = serviceData['type'] ?? 'service';
    final urgencyLevel = serviceData['urgencyLevel'] ?? 'normal';
    
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Incoming ${serviceType.toUpperCase()} Request',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (urgencyLevel == 'urgent') 
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'URGENT',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          
          // Countdown timer with pulsing effect
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseController.value * 0.1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _remainingSeconds <= 10 ? Colors.red : Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text(
                    '${_remainingSeconds}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSection(Map<String, dynamic> customerData) {
    final customerName = customerData['name'] ?? 'Customer';
    final totalTrips = customerData['totalTrips'] ?? 0;
    final rating = customerData['rating'];
    final verificationStatus = customerData['verificationStatus'] ?? 'unverified';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated customer avatar with pulse effect
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Transform.scale(
              scale: 1.0 + (_pulseController.value * 0.15),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: _pulseController.value * 15,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 66,
                  backgroundColor: Colors.white,
                  backgroundImage: customerData['profilePicture'] != null 
                    ? NetworkImage(customerData['profilePicture'])
                    : null,
                  child: customerData['profilePicture'] == null 
                    ? Icon(
                        Icons.person,
                        size: 70,
                        color: Colors.orange.shade600,
                      )
                    : null,
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Customer name
        Text(
          customerName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        // Customer stats row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Trip count
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '$totalTrips trips',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Customer rating (if available)
            if (rating != null) Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Verification badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: verificationStatus == 'verified' ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    verificationStatus == 'verified' ? Icons.verified : Icons.warning,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    verificationStatus == 'verified' ? 'VERIFIED' : 'NEW',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRequestDetails(
    Map<String, dynamic> paymentData,
    Map<String, dynamic> locationData,
    Map<String, dynamic> pricingData,
  ) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Payment method (most important for provider decision)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: paymentData['method'] == 'card' ? Colors.green.shade100 : Colors.blue.shade100,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: paymentData['method'] == 'card' ? Colors.green : Colors.blue,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  paymentData['method'] == 'card' ? Icons.credit_card : Icons.money,
                  color: paymentData['method'] == 'card' ? Colors.green.shade700 : Colors.blue.shade700,
                ),
                const SizedBox(width: 12),
                Text(
                  paymentData['displayText'] ?? 'PAYMENT METHOD',
                  style: TextStyle(
                    color: paymentData['method'] == 'card' ? Colors.green.shade700 : Colors.blue.shade700,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Location details
          _buildDetailRow(
            Icons.location_on,
            'Pickup',
            locationData['pickup']?['address'] ?? 'Unknown pickup location',
            Colors.green,
          ),
          
          const SizedBox(height: 16),
          
          _buildDetailRow(
            Icons.place,
            'Destination', 
            locationData['destination']?['address'] ?? 'Unknown destination',
            Colors.red,
          ),

          const SizedBox(height: 16),

          // Service and pricing info
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Service',
                  widget.requestData['service']?['class']?.toUpperCase() ?? 'STANDARD',
                  Icons.directions_car,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Fare',
                  '₦${pricingData['estimatedFare'] ?? 0}',
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Distance and duration
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Distance',
                  '${locationData['distance'] ?? 'N/A'} km',
                  Icons.straighten,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInfoCard(
                  'Duration',
                  '${locationData['duration'] ?? 'N/A'} min',
                  Icons.timer,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: Row(
        children: [
          // Decline button
          Expanded(
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(35),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Material(
                borderRadius: BorderRadius.circular(35),
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(35),
                  onTap: _handleDecline,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(35),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close, color: Colors.white, size: 28),
                        SizedBox(width: 8),
                        Text(
                          'DECLINE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Accept button with animation
          Expanded(
            flex: 2,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.05),
                  child: Container(
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Material(
                      borderRadius: BorderRadius.circular(35),
                      color: Colors.white,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(35),
                        onTap: _handleAccept,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, color: Colors.orange.shade700, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              'ACCEPT REQUEST',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}