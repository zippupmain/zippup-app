import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zippup/core/config/country_config_service.dart';

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

	Future<void> _openUrl(String url) async {
		try {
			final uri = Uri.parse(url);
			final openedInApp = await launchUrl(
				uri,
				mode: LaunchMode.inAppBrowserView,
				webOnlyWindowName: '_blank',
			);
			if (!openedInApp) {
				final openedExternal = await launchUrl(
					uri,
					mode: LaunchMode.externalApplication,
					webOnlyWindowName: '_self',
				);
				if (!openedExternal && mounted) {
					ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open payment page')));
				}
			}
		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to open link: $e')));
			}
		}
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
				await _openUrl(checkoutUrl);
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
						Padding(
							padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
							child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
								future: FirebaseFirestore.instance.collection('wallets').doc(FirebaseAuth.instance.currentUser!.uid).get(),
								builder: (context, balSnap) {
									final bal = (balSnap.data?.data()?['balance'] as num?)?.toDouble() ?? 0.0;
									return FutureBuilder<String>(
										future: CountryConfigService.instance.getCurrencySymbol(),
										builder: (context, cs) => FutureBuilder<String>(
											future: CountryConfigService.instance.getCurrencyCode(),
											builder: (context, cc) => Row(
												children: [
													const Text('Balance: ', style: TextStyle(fontWeight: FontWeight.w600)),
													Text('${(cs.data ?? '₦')}${bal.toStringAsFixed(2)} ${(cc.data ?? '').toString()}'),
												],
											),
										),
									);
								},
							),
						),
						Expanded(
							child: ListView.separated(
								itemCount: txs.length,
								separatorBuilder: (_, __) => const Divider(height: 1),
								itemBuilder: (context, i) {
									final t = txs[i].data();
									return FutureBuilder<String>(
										future: CountryConfigService.instance.getCurrencySymbol(),
										builder: (context, cs) => FutureBuilder<String>(
											future: CountryConfigService.instance.getCurrencyCode(),
											builder: (context, cc) => ListTile(
												title: Text(t['type']?.toString() ?? 'txn'),
												subtitle: Text(t['ref']?.toString() ?? ''),
												trailing: Text('${cs.data ?? '₦'}${((t['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)} ${(cc.data ?? '').toString()}'),
											),
										),
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