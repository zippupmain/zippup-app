import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zippup/common/models/ride.dart';

class RideService {
	final FirebaseFirestore _db = FirebaseFirestore.instance;
	final FirebaseAuth _auth = FirebaseAuth.instance;

	Future<void> assignAndAccept(String rideId) async {
		final uid = _auth.currentUser?.uid;
		await _db.collection('rides').doc(rideId).set({'driverId': uid, 'status': RideStatus.accepted.name}, SetOptions(merge: true));
	}

	Future<void> updateStatus(String rideId, RideStatus status) async {
		await _db.collection('rides').doc(rideId).update({'status': status.name});
	}

	Future<void> updateDriverLocation(String rideId, {required double lat, required double lng}) async {
		await _db.collection('rides').doc(rideId).set({'driverLat': lat, 'driverLng': lng}, SetOptions(merge: true));
	}
}