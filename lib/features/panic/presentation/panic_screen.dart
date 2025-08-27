import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:zippup/services/location/location_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PanicScreen extends StatelessWidget {
  const PanicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panic Mode')),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Send Alert'),
          onPressed: () async {
            final shouldSend = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Confirm Emergency Alert'),
                content: const Text(
                  'Send your live location to your emergency contacts?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Send'),
                  ),
                ],
              ),
            );
            if (shouldSend == true) {
              double? lat;
              double? lng;
              final pos = await LocationService.getCurrentPosition();
              if (pos != null) {
                lat = pos.latitude;
                lng = pos.longitude;
              }

              // Load user emergency contacts
              List<String> userContacts = const [];
              String? defaultContact;
              try {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                  final data = userDoc.data() ?? const {};
                  final contacts = (data['emergencyContacts'] as List?)?.map((e) => e.toString()).toList() ?? const [];
                  userContacts = contacts.cast<String>();
                }
              } catch (_) {}

              try {
                // Admin default per country
                final defDoc = await FirebaseFirestore.instance.collection('_config').doc('emergency').get();
                if (defDoc.exists) {
                  final map = defDoc.data() ?? const {};
                  // Try countryCode from user profile first, else fallback to NG
                  String countryCode = 'NG';
                  try {
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      final uDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                      countryCode = (uDoc.data()?['countryCode']?.toString() ?? 'NG').toUpperCase();
                    }
                  } catch (_) {}
                  defaultContact = map[countryCode]?.toString();
                }
              } catch (_) {}

              final noUserContacts = userContacts.isEmpty;
              try {
                await FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('sendPanicAlert').call({
                  'lat': lat,
                  'lng': lng,
                  'userContacts': userContacts,
                  'defaultContact': defaultContact,
                });
                if (context.mounted) {
                  if (noUserContacts) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sent to default emergency line. Add your contacts in Profile > Emergency contacts.')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Emergency alert sent to your contacts')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to send alert: $e')),
                  );
                }
              }
            }
          },
        ),
      ),
    );
  }
}
