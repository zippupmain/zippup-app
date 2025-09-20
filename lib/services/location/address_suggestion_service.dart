import 'package:zippup/services/location/location_config_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to provide location-biased address suggestions and place search
class AddressSuggestionService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  /// Search for addresses with location bias
  static Future<List<Map<String, dynamic>>> searchAddresses(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      // Use location config service for biased search
      final results = await LocationConfigService.searchAddresses(query);
      
      // Also search in saved addresses for quick access
      final savedAddresses = await _getSavedAddresses(query);
      
      // Combine results, prioritizing saved addresses
      final combined = <Map<String, dynamic>>[];
      combined.addAll(savedAddresses);
      
      // Add location-based results that aren't already in saved
      for (final result in results) {
        final isDuplicate = combined.any((saved) => 
          saved['address']?.toString().toLowerCase() == result['address']?.toString().toLowerCase()
        );
        if (!isDuplicate) {
          combined.add(result);
        }
      }
      
      return combined.take(10).toList(); // Limit to 10 results
    } catch (e) {
      print('❌ Error searching addresses: $e');
      return [];
    }
  }

  /// Search for places by name (landmarks, businesses, etc.)
  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      // Use location config service for place search
      final results = await LocationConfigService.searchPlacesByName(query);
      
      // Also search in popular places database
      final popularPlaces = await _getPopularPlaces(query);
      
      // Combine results
      final combined = <Map<String, dynamic>>[];
      combined.addAll(popularPlaces);
      
      for (final result in results) {
        final isDuplicate = combined.any((place) => 
          place['name']?.toString().toLowerCase() == result['name']?.toString().toLowerCase()
        );
        if (!isDuplicate) {
          combined.add(result);
        }
      }
      
      return combined.take(8).toList(); // Limit to 8 results
    } catch (e) {
      print('❌ Error searching places: $e');
      return [];
    }
  }

  /// Get saved addresses for current user
  static Future<List<Map<String, dynamic>>> _getSavedAddresses(String query) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return [];
      
      final userDoc = await _db.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      final savedAddresses = userData['savedAddresses'] as List<dynamic>? ?? [];
      
      // Filter saved addresses by query
      final filtered = savedAddresses
          .where((addr) => addr is Map && 
                         addr['address']?.toString().toLowerCase().contains(query.toLowerCase()) == true)
          .map((addr) => Map<String, dynamic>.from(addr as Map))
          .toList();
      
      return filtered;
    } catch (e) {
      print('❌ Error getting saved addresses: $e');
      return [];
    }
  }

  /// Get popular places for current country
  static Future<List<Map<String, dynamic>>> _getPopularPlaces(String query) async {
    try {
      final config = await LocationConfigService.getCurrentConfig();
      final countryCode = config['countryCode'] ?? 'NG';
      
      final placesQuery = await _db.collection('popular_places')
          .where('countryCode', isEqualTo: countryCode)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: query + '\uf8ff')
          .limit(5)
          .get();
      
      return placesQuery.docs.map((doc) => {
        'name': doc.data()['name'],
        'address': doc.data()['address'],
        'latitude': doc.data()['latitude'],
        'longitude': doc.data()['longitude'],
        'type': 'popular_place',
      }).toList();
    } catch (e) {
      print('❌ Error getting popular places: $e');
      return [];
    }
  }

  /// Save an address for future quick access
  static Future<void> saveAddress(Map<String, dynamic> addressData) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      
      final userRef = _db.collection('users').doc(uid);
      
      await userRef.update({
        'savedAddresses': FieldValue.arrayUnion([{
          'address': addressData['address'],
          'latitude': addressData['latitude'],
          'longitude': addressData['longitude'],
          'savedAt': DateTime.now().toIso8601String(),
        }])
      });
      
      print('✅ Saved address: ${addressData['address']}');
    } catch (e) {
      print('❌ Error saving address: $e');
    }
  }

  /// Combined search for both addresses and places
  static Future<List<Map<String, dynamic>>> universalSearch(String query) async {
    if (query.trim().isEmpty) return [];
    
    try {
      // Search both addresses and places simultaneously
      final results = await Future.wait([
        searchAddresses(query),
        searchPlaces(query),
      ]);
      
      final addresses = results[0];
      final places = results[1];
      
      // Combine and deduplicate
      final combined = <Map<String, dynamic>>[];
      
      // Add places first (they're usually more specific)
      combined.addAll(places);
      
      // Add addresses that aren't duplicates
      for (final address in addresses) {
        final isDuplicate = combined.any((item) => 
          item['address']?.toString().toLowerCase() == address['address']?.toString().toLowerCase()
        );
        if (!isDuplicate) {
          combined.add(address);
        }
      }
      
      return combined.take(12).toList(); // Limit total results
    } catch (e) {
      print('❌ Error in universal search: $e');
      return [];
    }
  }
}