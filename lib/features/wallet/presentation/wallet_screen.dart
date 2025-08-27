import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

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

	Future<void> _addFunds() async {
		final amountController = TextEditingController();
		final ok = await showDialog<bool>(
			context: context,
			builder: (c) => AlertDialog(
				title: const Text('Add funds'),
				content: TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
				actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Continue'))],
			),
		);
		if (ok != true) return;
		final amount = double.tryParse(amountController.text.trim()) ?? 0;
		if (amount <= 0) return;
		try {
			final res = await FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('walletCreateTopup').call({'amount': amount});
			final data = Map<String, dynamic>.from(res.data as Map);
			final checkoutUrl = data['checkoutUrl']?.toString();
			if (checkoutUrl != null && context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Redirecting to payment...')));
				// Platform-specific navigation handled elsewhere (e.g., web: launchUrl)
			}
		} catch (e) {
			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start top-up: $e')));
			}
		}
	}

	Future<void> _send() async {
		final toController = TextEditingController();
		final amountController = TextEditingController();
		final ok = await showDialog<bool>(
			context: context,
			builder: (c) => AlertDialog(
				title: const Text('Send to wallet'),
				content: Column(mainAxisSize: MainAxisSize.min, children: [
					TextField(controller: toController, decoration: const InputDecoration(labelText: 'Recipient phone or UID')),
					TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
				]),
				actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Send'))],
			),
		);
		if (ok != true) return;
		final amount = double.tryParse(amountController.text.trim()) ?? 0;
		final to = toController.text.trim();
		if (amount <= 0 || to.isEmpty) return;
		try {
			await FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('walletSend').call({'to': to, 'amount': amount});
			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent')));
			}
		} catch (e) {
			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
			}
		}
	}

	Future<void> _withdraw() async {
		final amountController = TextEditingController();
		final ok = await showDialog<bool>(
			context: context,
			builder: (c) => AlertDialog(
				title: const Text('Withdraw'),
				content: TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount')),
				actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Withdraw'))],
			),
		);
		if (ok != true) return;
		final amount = double.tryParse(amountController.text.trim()) ?? 0;
		if (amount <= 0) return;
		try {
			await FirebaseFunctions.instanceFor(region: 'us-central1').httpsCallable('walletWithdraw').call({'amount': amount});
			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request submitted')));
			}
		} catch (e) {
			if (context.mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
			}
		}
	}

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