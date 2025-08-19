import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminApplicationsScreen extends StatelessWidget {
	const AdminApplicationsScreen({super.key});

	Future<void> _approve(BuildContext context, String uid, Map<String, dynamic> app) async {
		await FirebaseFirestore.instance.collection('applications').doc(uid).update({'status': 'approved', 'approvedAt': DateTime.now().toIso8601String()});
		await FirebaseFirestore.instance.collection('_onboarding').doc(uid).set({'status': 'approved'}, SetOptions(merge: true));
		await FirebaseFirestore.instance.collection('notifications').add({
			'userId': uid,
			'title': 'KYC approved',
			'body': 'Your KYC has been approved. You can now create and manage business profiles.',
			'route': '/providers',
			'createdAt': DateTime.now().toIso8601String(),
			'read': false,
		});
		await FirebaseFirestore.instance.collection('vendors').doc(uid).set({
			'name': app['name'],
			'address': app['address'],
			'category': app['category'],
			'type': app['type'],
			'title': app['title'],
			'createdAt': DateTime.now().toIso8601String(),
		}, SetOptions(merge: true));
		if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved')));
	}

	Future<void> _decline(BuildContext context, String uid) async {
		await FirebaseFirestore.instance.collection('applications').doc(uid).update({'status': 'declined', 'declinedAt': DateTime.now().toIso8601String()});
		await FirebaseFirestore.instance.collection('_onboarding').doc(uid).set({'status': 'declined', 'reason': 'Please re-upload clearer documents'}, SetOptions(merge: true));
		await FirebaseFirestore.instance.collection('notifications').add({
			'userId': uid,
			'title': 'KYC declined',
			'body': 'Your KYC was declined. Tap to update your details and resubmit.',
			'route': '/providers/kyc',
			'createdAt': DateTime.now().toIso8601String(),
			'read': false,
		});
		if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Declined')));
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Admin • Applications')),
			body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('applications').orderBy('createdAt', descending: true).snapshots(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final docs = snap.data!.docs;
					if (docs.isEmpty) return const Center(child: Text('No applications'));
					return ListView.separated(
						itemCount: docs.length,
						separatorBuilder: (_, __) => const Divider(height: 1),
						itemBuilder: (context, i) {
							final d = docs[i];
							final data = d.data();
							return ListTile(
								title: Text(data['name'] ?? d.id),
								subtitle: Text('${data['category']} • ${data['type']} • ${data['status']}'),
								trailing: Wrap(spacing: 8, children: [
									TextButton(onPressed: () => _decline(context, d.id), child: const Text('Decline')),
									FilledButton(onPressed: () => _approve(context, d.id, data), child: const Text('Approve')),
								]),
							);
						},
					);
				},
			),
		);
	}
}