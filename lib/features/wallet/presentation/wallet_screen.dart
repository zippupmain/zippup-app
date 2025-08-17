import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WalletScreen extends StatefulWidget {
	const WalletScreen({super.key});
	@override
	State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
	Future<QuerySnapshot<Map<String, dynamic>>> _history() {
		final uid = FirebaseAuth.instance.currentUser!.uid;
		return FirebaseFirestore.instance.collection('wallets').doc(uid).collection('tx').orderBy('createdAt', descending: true).limit(50).get();
	}

	void _addFunds() {}
	void _send() {}
	void _withdraw() {}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Wallet')),
			body: FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
				future: _history(),
				builder: (context, snap) {
					final txs = snap.data?.docs ?? [];
					return Column(children: [
						Padding(
							padding: const EdgeInsets.all(16),
							child: Row(children: [
								Expanded(child: FilledButton(onPressed: _addFunds, child: const Text('Add fund'))),
								const SizedBox(width: 8),
								Expanded(child: OutlinedButton(onPressed: _send, child: const Text('Send'))),
								const SizedBox(width: 8),
								Expanded(child: OutlinedButton(onPressed: _withdraw, child: const Text('Withdraw'))),
							]),
						),
						const Divider(),
						Expanded(
							child: ListView.separated(
								itemCount: txs.length,
								separatorBuilder: (_, __) => const Divider(height: 1),
								itemBuilder: (context, i) {
									final t = txs[i].data();
									return ListTile(
										title: Text(t['type']?.toString() ?? 'txn'),
										subtitle: Text(t['ref']?.toString() ?? ''),
										trailing: Text(t['amount']?.toString() ?? ''),
									);
								},
							),
						),
					]);
				},
			),
		);
	}
}