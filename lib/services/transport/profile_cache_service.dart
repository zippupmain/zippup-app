import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to manage transport profile caching and refresh
class ProfileCacheService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  /// Force refresh of transport provider profile cache
  static Future<void> refreshTransportProfile(String userId) async {
    try {
      // Update the profile with a refresh timestamp to invalidate any caches
      final profileQuery = await _db.collection('provider_profiles')
          .where('userId', isEqualTo: userId)
          .where('service', isEqualTo: 'transport')
          .limit(1)
          .get();
      
      if (profileQuery.docs.isNotEmpty) {
        await profileQuery.docs.first.reference.update({
          'cacheRefreshedAt': FieldValue.serverTimestamp(),
          'lastModified': FieldValue.serverTimestamp(),
        });
        
        print('✅ Transport profile cache refreshed for user: $userId');
      }
    } catch (e) {
      print('❌ Error refreshing transport profile cache: $e');
    }
  }
  
  /// Clear deleted profile references
  static Future<void> clearDeletedProfile(String userId) async {
    try {
      // Mark profile as deleted instead of actually deleting
      final profileQuery = await _db.collection('provider_profiles')
          .where('userId', isEqualTo: userId)
          .where('service', isEqualTo: 'transport')
          .get();
      
      for (final doc in profileQuery.docs) {
        await doc.reference.update({
          'status': 'deleted',
          'deletedAt': FieldValue.serverTimestamp(),
          'cacheRefreshedAt': FieldValue.serverTimestamp(),
        });
      }
      
      print('✅ Marked transport profile as deleted for user: $userId');
    } catch (e) {
      print('❌ Error clearing deleted profile: $e');
    }
  }
  
  /// Create new profile with cache refresh
  static Future<void> createTransportProfile(Map<String, dynamic> profileData) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;
      
      // First clear any existing profiles
      await clearDeletedProfile(userId);
      
      // Create new profile
      await _db.collection('provider_profiles').add({
        ...profileData,
        'userId': userId,
        'service': 'transport',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'cacheRefreshedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Created new transport profile with cache refresh for user: $userId');
    } catch (e) {
      print('❌ Error creating transport profile: $e');
    }
  }
}