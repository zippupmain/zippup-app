import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to manage notification cleanup and prevent old notifications from accumulating
class NotificationCleanupService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  /// Clean up old read notifications for the current user
  static Future<void> cleanupOldNotifications() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      
      // Use simpler query to avoid composite index requirement
      // Get all user notifications and filter in-memory
      final userNotifications = await _db.collection('notifications')
          .where('userId', isEqualTo: uid)
          .get();
      
      // Filter for old read notifications in-memory
      final cutoffDate = DateTime.now().subtract(const Duration(days: 7));
      final toDelete = <DocumentSnapshot>[];
      
      for (final doc in userNotifications.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final isRead = data['read'] == true;
        final createdAt = data['createdAt'] as Timestamp?;
        
        if (isRead && createdAt != null && createdAt.toDate().isBefore(cutoffDate)) {
          toDelete.add(doc);
        }
      }
      
      // Delete in batches to avoid hitting Firestore limits
      final batch = _db.batch();
      int count = 0;
      
      for (final doc in toDelete) {
        batch.delete(doc.reference);
        count++;
        
        // Execute batch every 500 operations (Firestore limit)
        if (count % 500 == 0) {
          await batch.commit();
        }
      }
      
      // Commit any remaining operations
      if (count % 500 != 0) {
        await batch.commit();
      }
      
      print('✅ Cleaned up $count old read notifications for user: $uid');
    } catch (e) {
      print('❌ Error cleaning up old notifications: $e');
    }
  }
  
  /// Clean up old read notifications and limit total notifications per user
  static Future<void> cleanupAndLimitNotifications() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      
      // First, clean up old read notifications
      await cleanupOldNotifications();
      
      // Then, limit total notifications to 50 per user (keep most recent)
      // Use simpler query and sort in-memory to avoid composite index
      final userNotifications = await _db.collection('notifications')
          .where('userId', isEqualTo: uid)
          .get();
      
      if (userNotifications.docs.length > 50) {
        // Sort by creation date in-memory (newest first)
        final sortedDocs = userNotifications.docs.toList();
        sortedDocs.sort((a, b) {
          final aCreated = (a.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bCreated = (b.data()['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bCreated.compareTo(aCreated); // Descending (newest first)
        });
        
        // Delete notifications beyond the 50 most recent
        final toDelete = sortedDocs.skip(50);
        final batch = _db.batch();
        int count = 0;
        
        for (final doc in toDelete) {
          batch.delete(doc.reference);
          count++;
          
          // Execute batch every 500 operations
          if (count % 500 == 0) {
            await batch.commit();
          }
        }
        
        // Commit any remaining operations
        if (count % 500 != 0) {
          await batch.commit();
        }
        
        print('✅ Limited notifications to 50 most recent (deleted $count old notifications)');
      }
    } catch (e) {
      print('❌ Error limiting notifications: $e');
    }
  }
  
  /// Mark all notifications as read for the current user
  static Future<void> markAllNotificationsAsRead() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      
      // Use simpler query and filter in-memory to avoid composite index
      final userNotifications = await _db.collection('notifications')
          .where('userId', isEqualTo: uid)
          .get();
      
      final batch = _db.batch();
      int count = 0;
      
      for (final doc in userNotifications.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final isUnread = data['read'] != true;
        
        if (isUnread) {
          batch.update(doc.reference, {
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          });
          count++;
          
          // Execute batch every 500 operations
          if (count % 500 == 0) {
            await batch.commit();
          }
        }
      }
      
      // Commit any remaining operations
      if (count % 500 != 0) {
        await batch.commit();
      }
      
      print('✅ Marked $count notifications as read for user: $uid');
    } catch (e) {
      print('❌ Error marking notifications as read: $e');
    }
  }
  
  /// Auto-cleanup that runs on app startup
  static Future<void> performStartupCleanup() async {
    try {
      print('🧹 Performing notification startup cleanup...');
      
      // Clean up old notifications and limit total count
      await cleanupAndLimitNotifications();
      
      print('✅ Notification startup cleanup completed');
    } catch (e) {
      print('❌ Error during notification startup cleanup: $e');
    }
  }
  
  /// Delete a specific notification
  static Future<void> deleteNotification(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).delete();
      print('✅ Deleted notification: $notificationId');
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }
  
  /// Clear all notifications for the current user (use with caution)
  static Future<void> clearAllNotifications() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      
      // This query only uses userId which has a simple index
      final userNotifications = await _db.collection('notifications')
          .where('userId', isEqualTo: uid)
          .get();
      
      final batch = _db.batch();
      int count = 0;
      
      for (final doc in userNotifications.docs) {
        batch.delete(doc.reference);
        count++;
        
        // Execute batch every 500 operations
        if (count % 500 == 0) {
          await batch.commit();
        }
      }
      
      // Commit any remaining operations
      if (count % 500 != 0) {
        await batch.commit();
      }
      
      print('✅ Cleared all $count notifications for user: $uid');
    } catch (e) {
      print('❌ Error clearing all notifications: $e');
    }
  }
}