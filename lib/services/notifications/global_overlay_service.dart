import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

/// Service to show global overlay notifications that appear on any screen
class GlobalOverlayService {
  static OverlayEntry? _currentOverlay;
  static Timer? _soundTimer;

  /// Show a global ride request overlay that appears on any screen
  static void showRideRequestOverlay({
    required BuildContext context,
    required String rideId,
    required String customerName,
    required String pickupAddress,
    required String rideType,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
  }) {
    print('🚨 SHOWING GLOBAL OVERLAY for ride: $rideId on ANY screen');
    
    // Remove any existing overlay
    removeCurrentOverlay();

    // Play continuous sound immediately
    _playUrgentSoundLoop();

    _currentOverlay = OverlayEntry(
      builder: (context) => _GlobalRideRequestOverlay(
        rideId: rideId,
        customerName: customerName,
        pickupAddress: pickupAddress,
        rideType: rideType,
        onAccept: () {
          removeCurrentOverlay();
          onAccept();
        },
        onDecline: () {
          removeCurrentOverlay();
          onDecline();
        },
        onTimeout: () {
          removeCurrentOverlay();
          onDecline();
        },
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  /// Remove current overlay
  static void removeCurrentOverlay() {
    _currentOverlay?.remove();
    _currentOverlay = null;
    _soundTimer?.cancel();
    _soundTimer = null;
  }

  /// Play urgent sound in a loop
  static void _playUrgentSoundLoop() {
    _soundTimer?.cancel();
    
    // Play sound immediately
    _playUrgentSound();
    
    // Continue playing every 3 seconds
    _soundTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _playUrgentSound();
    });

    // Stop after 30 seconds max
    Timer(const Duration(seconds: 30), () {
      _soundTimer?.cancel();
      _soundTimer = null;
    });
  }

  /// Play urgent sound
  static void _playUrgentSound() {
    try {
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    } catch (e) {
      print('❌ Error playing urgent sound: $e');
    }
  }
}

/// Global ride request overlay widget
class _GlobalRideRequestOverlay extends StatefulWidget {
  final String rideId;
  final String customerName;
  final String pickupAddress;
  final String rideType;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onTimeout;

  const _GlobalRideRequestOverlay({
    required this.rideId,
    required this.customerName,
    required this.pickupAddress,
    required this.rideType,
    required this.onAccept,
    required this.onDecline,
    required this.onTimeout,
  });

  @override
  State<_GlobalRideRequestOverlay> createState() => _GlobalRideRequestOverlayState();
}

class _GlobalRideRequestOverlayState extends State<_GlobalRideRequestOverlay>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  Timer? _timeoutTimer;
  int _countdown = 30;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();

    // Start countdown
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _countdown--);
      
      if (_countdown <= 0) {
        widget.onTimeout();
      }
      
      // Urgent haptic in last 10 seconds
      if (_countdown <= 10) {
        HapticFeedback.mediumImpact();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.8),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _slideController,
          curve: Curves.easeOutCubic,
        )),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_car, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '🚗 ${widget.rideType} REQUEST',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'New ride request from ${widget.customerName}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Countdown
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseController.value * 0.1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: _countdown <= 10 ? Colors.red : Colors.white.withOpacity(0.2),
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
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Pickup address
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pickup Location',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              widget.pickupAddress,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.onDecline,
                        icon: const Icon(Icons.close),
                        label: const Text('DECLINE'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseController.value * 0.05),
                            child: ElevatedButton.icon(
                              onPressed: widget.onAccept,
                              icon: const Icon(Icons.check),
                              label: const Text('ACCEPT RIDE'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                elevation: 8,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}