import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zippup/services/notifications/reliable_sound_service.dart';
import 'dart:async';

class IncomingCallNotification extends StatefulWidget {
  final String requestId;
  final String requestType;
  final String title;
  final String subtitle;
  final String customerName;
  final String pickupAddress;
  final String? destinationAddress;
  final String? fare;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallNotification({
    super.key,
    required this.requestId,
    required this.requestType,
    required this.title,
    required this.subtitle,
    required this.customerName,
    required this.pickupAddress,
    this.destinationAddress,
    this.fare,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  State<IncomingCallNotification> createState() => _IncomingCallNotificationState();
}

class _IncomingCallNotificationState extends State<IncomingCallNotification>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _timeoutTimer;
  Timer? _soundTimer;
  int _countdown = 30; // 30 second timeout

  @override
  void initState() {
    super.initState();
    
    // Pulse animation for accept button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);

    // Slide animation for entry
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));
    _slideController.forward();

    // Start timeout countdown
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 0) {
        timer.cancel();
        _autoDecline();
      } else {
        setState(() => _countdown--);
      }
    });

    // Play continuous notification sound
    _startNotificationLoop();
  }

  void _startNotificationLoop() {
    _playNotificationSound();
    _soundTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _playNotificationSound();
    });
  }

  void _playNotificationSound() {
    ReliableSoundService.instance.playNotification(isUrgent: true);
  }

  void _autoDecline() {
    _stopSounds();
    widget.onDecline();
  }

  void _stopSounds() {
    _timeoutTimer?.cancel();
    _soundTimer?.cancel();
  }

  @override
  void dispose() {
    _stopSounds();
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black87,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue.shade900,
                Colors.blue.shade700,
                Colors.blue.shade500,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header with countdown
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.requestType.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _countdown <= 10 ? Colors.red : Colors.orange,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_countdown}s',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Customer avatar
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                    border: Border.all(color: Colors.white54, width: 3),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Customer name
                Text(
                  widget.customerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Request title
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Location details
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      _buildLocationRow(
                        Icons.my_location,
                        'Pickup',
                        widget.pickupAddress,
                        Colors.green,
                      ),
                      if (widget.destinationAddress != null) ...[
                        const SizedBox(height: 15),
                        _buildLocationRow(
                          Icons.location_on,
                          'Destination',
                          widget.destinationAddress!,
                          Colors.red,
                        ),
                      ],
                      if (widget.fare != null) ...[
                        const SizedBox(height: 15),
                        _buildLocationRow(
                          Icons.attach_money,
                          'Fare',
                          widget.fare!,
                          Colors.amber,
                        ),
                      ],
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Decline button
                      GestureDetector(
                        onTap: () {
                          _stopSounds();
                          widget.onDecline();
                        },
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red,
                          ),
                          child: const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 35,
                          ),
                        ),
                      ),
                      
                      // Accept button with pulse animation
                      GestureDetector(
                        onTap: () {
                          _stopSounds();
                          widget.onAccept();
                        },
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.green,
                                ),
                                child: const Icon(
                                  Icons.call,
                                  color: Colors.white,
                                  size: 35,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}