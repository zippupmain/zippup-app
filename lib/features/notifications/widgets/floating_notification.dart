import 'package:flutter/material.dart';
import 'package:zippup/services/notifications/audible_notification_service.dart';

class FloatingNotification extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final Color? backgroundColor;
  final IconData? icon;

  const FloatingNotification({
    super.key,
    required this.title,
    required this.message,
    this.onTap,
    this.onDismiss,
    this.backgroundColor,
    this.icon,
  });

  @override
  State<FloatingNotification> createState() => _FloatingNotificationState();
}

class _FloatingNotificationState extends State<FloatingNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    ));

    // Play notification sound and animate in
    _playNotificationAndShow();
    
    // Auto-dismiss after 8 seconds
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) _dismiss();
    });
  }

  Future<void> _playNotificationAndShow() async {
    try {
      // Play sound first
      final success = await AudibleNotificationService.instance.playDriverNotification();
      print(success ? '✅ Floating notification sound SUCCESS' : '❌ Floating notification sound FAILED');
    } catch (e) {
      print('❌ Floating notification sound failed: $e');
    }
    
    // Then animate in
    _controller.forward();
  }

  void _dismiss() {
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismiss?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.all(16),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                _dismiss();
                widget.onTap?.call();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: widget.backgroundColor ?? Colors.blue.shade600,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.icon ?? Icons.notifications,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.message,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _dismiss,
                      icon: const Icon(Icons.close, color: Colors.white),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Overlay manager for floating notifications
class NotificationOverlay {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onTap,
    Color? backgroundColor,
    IconData? icon,
  }) {
    // Remove existing notification
    hide();

    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 10,
        left: 0,
        right: 0,
        child: FloatingNotification(
          title: title,
          message: message,
          onTap: onTap,
          onDismiss: hide,
          backgroundColor: backgroundColor,
          icon: icon,
        ),
      ),
    );

    Overlay.of(context).insert(_currentEntry!);
  }

  static void hide() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}