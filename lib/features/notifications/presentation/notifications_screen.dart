import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/notifications/notification_cleanup_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _showUnreadOnly = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    // Use simple query to avoid composite index requirement
    // We'll filter and sort in-memory
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .limit(100) // Get more to allow for filtering
        .snapshots();
  }

  @override
  void initState() {
    super.initState();
    // Perform cleanup when notifications screen is opened
    NotificationCleanupService.performStartupCleanup();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          // Toggle unread only
          IconButton(
            onPressed: () => setState(() => _showUnreadOnly = !_showUnreadOnly),
            icon: Icon(_showUnreadOnly ? Icons.mark_email_read : Icons.mark_email_unread),
            tooltip: _showUnreadOnly ? 'Show All' : 'Show Unread Only',
          ),
          // Mark all as read
          IconButton(
            onPressed: () async {
              await NotificationCleanupService.markAllNotificationsAsRead();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ All notifications marked as read')),
                );
              }
            },
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark All as Read',
          ),
          // Clear all notifications
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.cleaning_services),
                  title: Text('Clean Old Notifications'),
                  dense: true,
                ),
                onTap: () async {
                  await NotificationCleanupService.cleanupOldNotifications();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('🧹 Old notifications cleaned up')),
                    );
                  }
                },
              ),
              PopupMenuItem(
                child: const ListTile(
                  leading: Icon(Icons.clear_all),
                  title: Text('Clear All Notifications'),
                  dense: true,
                ),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear All Notifications'),
                      content: const Text('This will permanently delete all your notifications. Are you sure?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirmed == true) {
                    await NotificationCleanupService.clearAllNotifications();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🗑️ All notifications cleared')),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: !_showUnreadOnly,
                  onSelected: (selected) => setState(() => _showUnreadOnly = false),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Unread Only'),
                  selected: _showUnreadOnly,
                  onSelected: (selected) => setState(() => _showUnreadOnly = true),
                ),
              ],
            ),
          ),
          // Notifications list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _stream(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                
                // Filter and sort in-memory to avoid composite index requirements
                var docs = snap.data!.docs;
                
                // Filter by read status if needed
                if (_showUnreadOnly) {
                  docs = docs.where((doc) => doc.data()['read'] != true).toList();
                }
                
                // Sort by creation date (newest first)
                docs.sort((a, b) {
                  final aCreated = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                  final bCreated = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return bCreated.compareTo(aCreated);
                });
                
                // Limit to 50 most recent
                if (docs.length > 50) {
                  docs = docs.take(50).toList();
                }
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showUnreadOnly ? Icons.mark_email_read : Icons.notifications_none,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showUnreadOnly ? 'No unread notifications' : 'No notifications',
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final d = docs[i];
                    final n = d.data();
                    final unread = n['read'] != true;
                    final title = n['title']?.toString() ?? 'Notification';
                    final body = n['body']?.toString() ?? '';
                    final createdAt = n['createdAt'] as Timestamp?;
                    final timeAgo = createdAt != null 
                        ? _formatTimeAgo(createdAt.toDate()) 
                        : '';
                    
                    return Dismissible(
                      key: Key(d.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        color: Colors.red,
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) async {
                        await NotificationCleanupService.deleteNotification(d.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Deleted: $title')),
                          );
                        }
                      },
                      child: ListTile(
                        title: Text(
                          title, 
                          style: TextStyle(
                            fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                            color: unread ? Colors.black : Colors.grey[600],
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (body.isNotEmpty) Text(body),
                            if (timeAgo.isNotEmpty) 
                              Text(
                                timeAgo,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: unread ? Colors.blue.shade100 : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getNotificationIcon(title),
                            color: unread ? Colors.blue : Colors.grey,
                          ),
                        ),
                        trailing: unread 
                            ? const Icon(Icons.brightness_1, color: Colors.blue, size: 12) 
                            : null,
                        onTap: () async {
                          if (unread) {
                            await d.reference.set({'read': true, 'readAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
                          }
                          final route = n['route']?.toString();
                          if (route != null && route.isNotEmpty && context.mounted) {
                            context.push(route);
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _getNotificationIcon(String title) {
    if (title.contains('Ride') || title.contains('🚗')) return Icons.directions_car;
    if (title.contains('Order') || title.contains('🍽️')) return Icons.restaurant;
    if (title.contains('Emergency') || title.contains('🚨')) return Icons.emergency;
    if (title.contains('Payment') || title.contains('💳')) return Icons.payment;
    if (title.contains('Test') || title.contains('🧪')) return Icons.bug_report;
    return Icons.notifications;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

