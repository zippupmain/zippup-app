import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/core/config/flags_service.dart';

class BusinessProfilesScreen extends StatelessWidget {
	const BusinessProfilesScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
		if (uid.isEmpty) {
			return Scaffold(
				appBar: AppBar(title: const Text('Business profiles')),
				body: const _KycGate(
					message: 'Please sign in and complete KYC to manage business profiles.',
					ctaText: 'Complete KYC',
					onTapRoute: '/providers/kyc',
				),
			);
		}
		// BYPASS KYC for testing: always show approved hub
		return Scaffold(appBar: AppBar(title: const Text('Business profiles'), actions: [
			IconButton(icon: const Icon(Icons.home_outlined), onPressed: () => context.go('/')),
			IconButton(icon: const Icon(Icons.close), onPressed: () { if (Navigator.of(context).canPop()) { Navigator.pop(context); } else { context.go('/'); } }),
		]), body: _ApprovedHub(uid: uid));
	}
}

class _KycGate extends StatelessWidget {
	final String message;
	final String ctaText;
	final String onTapRoute;
	const _KycGate({required this.message, required this.ctaText, required this.onTapRoute});
	@override
	Widget build(BuildContext context) {
		return Center(
			child: Padding(
				padding: const EdgeInsets.all(24),
				child: Column(mainAxisSize: MainAxisSize.min, children: [
					Text(message, textAlign: TextAlign.center),
					const SizedBox(height: 12),
					FilledButton(onPressed: () => context.push(onTapRoute), child: Text(ctaText)),
				]),
			),
		);
	}
}

class _ApprovedHub extends StatelessWidget {
	final String uid;
	const _ApprovedHub({required this.uid});
	@override
	Widget build(BuildContext context) {
		return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
			stream: FirebaseFirestore.instance.collection('business_profiles').doc(uid).collection('profiles').snapshots(),
			builder: (context, snap) {
				if (!snap.hasData) return const Center(child: CircularProgressIndicator());
				final docs = snap.data!.docs;
				if (docs.isEmpty) {
					return Center(
						child: Padding(
							padding: const EdgeInsets.all(24),
							child: Column(mainAxisSize: MainAxisSize.min, children: [
								const Text('No business profiles yet'),
								const SizedBox(height: 12),
								FilledButton.icon(onPressed: () => context.push('/providers/create'), icon: const Icon(Icons.add_business), label: const Text('Create business profile')),
							]),
						),
					);
				}
				return ListView(
					children: [
						Padding(
							padding: const EdgeInsets.all(16),
							child: FilledButton.icon(onPressed: () => context.push('/providers/create'), icon: const Icon(Icons.add_business), label: const Text('Create business profile')),
						),
						...docs.map((d) {
							final p = d.data();
							return Dismissible(
								key: ValueKey(d.id),
								background: Container(color: Colors.redAccent),
								direction: DismissDirection.endToStart,
								onDismissed: (_) async {
									await d.reference.delete();
									ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile deleted')));
								},
								child: ListTile(
									onTap: () async {
										await FirebaseFirestore.instance.collection('users').doc(uid).set({'activeProfileId': d.id}, SetOptions(merge: true));
										final category = (p['category']?.toString() ?? '').toLowerCase();
										if (category == 'food' || category == 'restaurant' || category == 'fast food' || category == 'local' || category == 'bakery') {
											if (context.mounted) context.push('/hub/food');
											return;
										}
										if (category == 'transport' || category == 'taxi' || category == 'bike' || category == 'tricycle' || category == 'bus' || category == 'courier' || category == 'driver') {
											if (context.mounted) context.push('/hub/transport');
											return;
										}
										// Default to generic orders for now
										if (context.mounted) context.push('/hub/orders');
									},
									title: Text(p['title']?.toString() ?? 'Untitled'),
									subtitle: Text('${p['category'] ?? ''} • ${p['subcategory'] ?? ''} • ${p['type'] ?? 'individual'} • ${p['status'] ?? 'draft'}'),
									trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => context.push('/providers/create?profileId=${d.id}')),
								),
							);
						}),
					],
				);
			},
		);
	}
}

