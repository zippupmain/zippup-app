import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
		return Scaffold(
			appBar: AppBar(title: const Text('Business profiles')),
			body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('_onboarding').doc(uid).snapshots(),
				builder: (context, kycSnap) {
					if (kycSnap.hasError) {
						return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Error: ${kycSnap.error}')));
					}
					if (!kycSnap.hasData) {
						return const _KycGate(
							message: 'Checking KYC status... If this takes long, you can proceed to complete KYC.',
							ctaText: 'Complete KYC',
							onTapRoute: '/providers/kyc',
						);
					}
					final kyc = kycSnap.data!;
					final exists = kyc.exists;
					final status = (kyc.data()?['status'] ?? '').toString().toLowerCase();
					final reason = kyc.data()?['reason']?.toString();
					if (!exists || status.isEmpty) {
						return const _KycGate(
							message: 'Go to Apply as Service Provider / Vendor to complete KYC before you can create a business profile.',
							ctaText: 'Complete KYC',
							onTapRoute: '/providers/kyc',
						);
					}
					if (status == 'pending') {
						return const _KycGate(
							message: 'Your KYC is submitted and awaiting approval. You will be notified once reviewed.',
							ctaText: 'View notifications',
							onTapRoute: '/notifications',
						);
					}
					if (status == 'declined') {
						return _KycGate(
							message: 'Your KYC was declined.${reason != null && reason.isNotEmpty ? '\nReason: $reason' : ''}',
							ctaText: 'Update KYC',
							onTapRoute: '/providers/kyc',
						);
					}
					// Approved => show hub
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
										return ListTile(
											title: Text(p['title']?.toString() ?? 'Untitled'),
											subtitle: Text('${p['category'] ?? ''} • ${p['subcategory'] ?? ''} • ${p['type'] ?? 'individual'} • ${p['status'] ?? 'draft'}'),
											trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => context.push('/providers/create?profileId=${d.id}')),
										);
									}),
								],
							);
						},
					);
				},
			),
		);
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

