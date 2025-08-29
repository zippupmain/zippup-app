import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CallService {
	final FirebaseFirestore _db = FirebaseFirestore.instance;
	final FirebaseAuth _auth = FirebaseAuth.instance;

	Future<String> startCall({required String calleeId, required String threadId}) async {
		final uid = _auth.currentUser?.uid ?? 'anon';
		final ref = await _db.collection('calls').add({
			'callerId': uid,
			'calleeId': calleeId,
			'threadId': threadId,
			'status': 'ringing', // ringing | accepted | busy | declined | ended
			'createdAt': DateTime.now().toIso8601String(),
		});
		return ref.id;
	}

	Future<void> accept({required String callId}) async {
		await _db.collection('calls').doc(callId).set({'status': 'accepted', 'acceptedAt': DateTime.now().toIso8601String()}, SetOptions(merge: true));
	}

	Future<void> decline({required String callId}) async {
		await _db.collection('calls').doc(callId).set({'status': 'declined', 'endedAt': DateTime.now().toIso8601String()}, SetOptions(merge: true));
	}

	Future<void> busy({required String callId}) async {
		await _db.collection('calls').doc(callId).set({'status': 'busy', 'endedAt': DateTime.now().toIso8601String()}, SetOptions(merge: true));
	}

	Future<void> end({required String callId}) async {
		await _db.collection('calls').doc(callId).set({'status': 'ended', 'endedAt': DateTime.now().toIso8601String()}, SetOptions(merge: true));
	}
}

