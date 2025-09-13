import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPermissionsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Admin permission levels
  static const Map<String, List<String>> rolePermissions = {
    'super_admin': [
      'all', // Super admin has all permissions
    ],
    'admin': [
      'user_management',
      'provider_management',
      'financial_management',
      'system_config',
      'analytics',
      'support_tickets',
      'content_moderation',
    ],
    'moderator': [
      'user_management',
      'provider_management',
      'support_tickets',
      'content_moderation',
    ],
    'support': [
      'support_tickets',
      'user_management', // Limited user management
    ],
    'analyst': [
      'analytics',
      'provider_management', // View only
    ],
  };

  // Worker permission levels
  static const Map<String, List<String>> workerPermissions = {
    'driver': [
      'accept_rides',
      'update_location',
      'complete_trips',
      'view_earnings',
      'update_availability',
    ],
    'delivery_agent': [
      'accept_deliveries',
      'update_status',
      'collect_payment',
      'view_earnings',
      'update_availability',
    ],
    'service_provider': [
      'accept_bookings',
      'provide_service',
      'collect_payment',
      'view_earnings',
      'update_availability',
    ],
    'emergency_responder': [
      'accept_emergencies',
      'update_status',
      'provide_emergency_care',
      'view_earnings',
      'update_availability',
    ],
    'customer_support': [
      'handle_tickets',
      'chat_with_users',
      'escalate_issues',
      'view_user_profiles',
      'create_reports',
    ],
    'dispatcher': [
      'assign_jobs',
      'monitor_operations',
      'coordinate_teams',
      'view_analytics',
      'manage_schedules',
    ],
    'quality_controller': [
      'review_services',
      'audit_providers',
      'generate_reports',
      'approve_content',
      'investigate_complaints',
    ],
    'finance_officer': [
      'process_payments',
      'handle_refunds',
      'generate_financial_reports',
      'audit_transactions',
      'manage_payouts',
    ],
  };

  /// Check if current user is admin
  static Future<bool> isAdmin() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      final adminDoc = await _firestore
          .collection('_config')
          .doc('admins')
          .collection('users')
          .doc(uid)
          .get();

      return adminDoc.exists && adminDoc.data()?['status'] == 'active';
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }

  /// Check if current user has specific permission
  static Future<bool> hasPermission(String permission) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      final adminDoc = await _firestore
          .collection('_config')
          .doc('admins')
          .collection('users')
          .doc(uid)
          .get();

      if (!adminDoc.exists) return false;

      final data = adminDoc.data()!;
      final role = data['role'] as String?;
      final customPermissions = data['permissions'] as List<dynamic>? ?? [];

      if (role == null) return false;

      // Super admin has all permissions
      if (role == 'super_admin') return true;

      // Check role-based permissions
      final rolePerms = rolePermissions[role] ?? [];
      if (rolePerms.contains(permission)) return true;

      // Check custom permissions
      if (customPermissions.contains(permission)) return true;

      return false;
    } catch (e) {
      print('Error checking permission: $e');
      return false;
    }
  }

  /// Get current user's admin role
  static Future<String?> getCurrentAdminRole() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;

      final adminDoc = await _firestore
          .collection('_config')
          .doc('admins')
          .collection('users')
          .doc(uid)
          .get();

      if (!adminDoc.exists) return null;

      return adminDoc.data()?['role'] as String?;
    } catch (e) {
      print('Error getting admin role: $e');
      return null;
    }
  }

  /// Check if current user is worker
  static Future<bool> isWorker() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      final workerDoc = await _firestore
          .collection('worker_profiles')
          .doc(uid)
          .get();

      return workerDoc.exists && workerDoc.data()?['status'] == 'active';
    } catch (e) {
      print('Error checking worker status: $e');
      return false;
    }
  }

  /// Check if worker has specific permission
  static Future<bool> hasWorkerPermission(String permission) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return false;

      final workerDoc = await _firestore
          .collection('worker_profiles')
          .doc(uid)
          .get();

      if (!workerDoc.exists) return false;

      final data = workerDoc.data()!;
      final role = data['role'] as String?;
      final customPermissions = data['permissions'] as List<dynamic>? ?? [];

      if (role == null) return false;

      // Check role-based permissions
      final rolePerms = workerPermissions[role] ?? [];
      if (rolePerms.contains(permission)) return true;

      // Check custom permissions
      if (customPermissions.contains(permission)) return true;

      return false;
    } catch (e) {
      print('Error checking worker permission: $e');
      return false;
    }
  }

  /// Get current user's worker role
  static Future<String?> getCurrentWorkerRole() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;

      final workerDoc = await _firestore
          .collection('worker_profiles')
          .doc(uid)
          .get();

      if (!workerDoc.exists) return null;

      return workerDoc.data()?['role'] as String?;
    } catch (e) {
      print('Error getting worker role: $e');
      return null;
    }
  }

  /// Assign admin role to user
  static Future<bool> assignAdminRole({
    required String userId,
    required String role,
    required List<String> permissions,
  }) async {
    try {
      // Check if current user has permission to assign admin roles
      if (!await hasPermission('user_management')) {
        throw Exception('Insufficient permissions');
      }

      await _firestore
          .collection('_config')
          .doc('admins')
          .collection('users')
          .doc(userId)
          .set({
        'role': role,
        'permissions': permissions,
        'status': 'active',
        'assignedAt': FieldValue.serverTimestamp(),
        'assignedBy': _auth.currentUser?.uid,
      });

      return true;
    } catch (e) {
      print('Error assigning admin role: $e');
      return false;
    }
  }

  /// Assign worker role to user
  static Future<bool> assignWorkerRole({
    required String userId,
    required String role,
    required String department,
    required double salary,
    List<String>? customPermissions,
  }) async {
    try {
      // Check if current user has permission to assign worker roles
      if (!await hasPermission('user_management')) {
        throw Exception('Insufficient permissions');
      }

      final defaultPerms = workerPermissions[role] ?? [];
      final finalPermissions = customPermissions ?? defaultPerms;

      await _firestore.collection('worker_profiles').doc(userId).set({
        'userId': userId,
        'role': role,
        'department': department,
        'salary': salary,
        'permissions': finalPermissions,
        'status': 'active',
        'assignedAt': FieldValue.serverTimestamp(),
        'assignedBy': _auth.currentUser?.uid,
      });

      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'workerRole': role,
        'isWorker': true,
      });

      return true;
    } catch (e) {
      print('Error assigning worker role: $e');
      return false;
    }
  }

  /// Remove admin role from user
  static Future<bool> removeAdminRole(String userId) async {
    try {
      if (!await hasPermission('user_management')) {
        throw Exception('Insufficient permissions');
      }

      await _firestore
          .collection('_config')
          .doc('admins')
          .collection('users')
          .doc(userId)
          .delete();

      return true;
    } catch (e) {
      print('Error removing admin role: $e');
      return false;
    }
  }

  /// Remove worker role from user
  static Future<bool> removeWorkerRole(String userId) async {
    try {
      if (!await hasPermission('user_management')) {
        throw Exception('Insufficient permissions');
      }

      await _firestore.collection('worker_profiles').doc(userId).delete();

      // Update user document
      await _firestore.collection('users').doc(userId).update({
        'workerRole': FieldValue.delete(),
        'isWorker': false,
      });

      return true;
    } catch (e) {
      print('Error removing worker role: $e');
      return false;
    }
  }

  /// Get all available admin roles
  static List<String> getAvailableAdminRoles() {
    return rolePermissions.keys.toList();
  }

  /// Get all available worker roles
  static List<String> getAvailableWorkerRoles() {
    return workerPermissions.keys.toList();
  }

  /// Get permissions for a specific role
  static List<String> getPermissionsForRole(String role, {bool isWorker = false}) {
    if (isWorker) {
      return workerPermissions[role] ?? [];
    } else {
      return rolePermissions[role] ?? [];
    }
  }

  /// Log admin action for audit trail
  static Future<void> logAdminAction({
    required String action,
    required String targetUserId,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _firestore.collection('admin_audit_log').add({
        'adminId': _auth.currentUser?.uid,
        'action': action,
        'targetUserId': targetUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'additionalData': additionalData,
      });
    } catch (e) {
      print('Error logging admin action: $e');
    }
  }
}