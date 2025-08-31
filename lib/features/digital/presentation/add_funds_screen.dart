import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/payments/payments_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AddFundsScreen extends StatefulWidget {
	const AddFundsScreen({super.key});

	@override
	State<AddFundsScreen> createState() => _AddFundsScreenState();
}

class _AddFundsScreenState extends State<AddFundsScreen> {
	final TextEditingController _amountController = TextEditingController();
	String _paymentMethod = 'card';
	bool _isProcessing = false;
	double _currentBalance = 0.0;

	final List<double> _quickAmounts = [500, 1000, 2000, 5000, 10000, 20000];

	@override
	void initState() {
		super.initState();
		_loadCurrentBalance();
	}

	Future<void> _loadCurrentBalance() async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid != null) {
				final walletDoc = await FirebaseFirestore.instance
					.collection('wallets')
					.doc(uid)
					.get();
				
				if (walletDoc.exists) {
					final data = walletDoc.data()!;
					setState(() {
						_currentBalance = (data['balance'] ?? 0.0).toDouble();
					});
				}
			}
		} catch (e) {
			print('Error loading wallet balance: $e');
		}
	}

	Future<void> _addFunds() async {
		final amountText = _amountController.text.trim();

		if (amountText.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please enter amount to add'))
			);
			return;
		}

		final amount = double.tryParse(amountText);
		if (amount == null || amount < 100) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Minimum amount is ₦100'))
			);
			return;
		}

		if (amount > 1000000) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Maximum amount is ₦1,000,000'))
			);
			return;
		}

		setState(() => _isProcessing = true);

		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) {
				throw Exception('Please sign in to add funds');
			}

			await _processPayment(uid, amount);

		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Failed to add funds: $e'))
				);
			}
		} finally {
			if (mounted) setState(() => _isProcessing = false);
		}
	}

	Future<void> _processPayment(String uid, double amount) async {
		try {
			final paymentsService = PaymentsService();
			String checkoutUrl;

			if (_paymentMethod == 'flutterwave') {
				checkoutUrl = await paymentsService.createFlutterwaveCheckout(
					amount: amount,
					currency: 'NGN',
					items: [
						{
							'title': 'ZippUp Wallet Top-up',
							'description': 'Add funds to your ZippUp wallet',
							'price': amount,
							'quantity': 1,
						}
					],
				);
			} else {
				// Use Stripe for card payments
				checkoutUrl = await paymentsService.createStripeCheckout(
					amount: amount,
					currency: 'NGN',
					items: [
						{
							'title': 'ZippUp Wallet Top-up',
							'price': amount,
							'quantity': 1,
						}
					],
				);
			}

			// Create pending transaction record
			await FirebaseFirestore.instance.collection('wallet_transactions').add({
				'userId': uid,
				'type': 'credit',
				'amount': amount,
				'description': 'Wallet top-up via ${_paymentMethod}',
				'paymentMethod': _paymentMethod,
				'status': 'pending',
				'checkoutUrl': checkoutUrl,
				'createdAt': DateTime.now().toIso8601String(),
			});

			// Open payment URL
			if (await canLaunchUrl(Uri.parse(checkoutUrl))) {
				await launchUrl(
					Uri.parse(checkoutUrl),
					mode: LaunchMode.externalApplication,
				);
				
				if (mounted) {
					ScaffoldMessenger.of(context).showSnackBar(
						const SnackBar(
							content: Text('🔄 Payment opened. Your wallet will be credited after successful payment.'),
							backgroundColor: Colors.blue,
							duration: Duration(seconds: 4),
						)
					);
					
					// Navigate back after showing message
					Future.delayed(const Duration(seconds: 2), () {
						if (mounted) context.pop();
					});
				}
			} else {
				// Fallback: Show URL in dialog
				if (mounted) {
					showDialog(
						context: context,
						builder: (_) => AlertDialog(
							title: const Text('Complete Payment'),
							content: Column(
								mainAxisSize: MainAxisSize.min,
								children: [
									Text('Add ₦${amount.toStringAsFixed(0)} to your wallet:'),
									const SizedBox(height: 16),
									Container(
										padding: const EdgeInsets.all(12),
										decoration: BoxDecoration(
											color: Colors.blue.shade50,
											borderRadius: BorderRadius.circular(8),
											border: Border.all(color: Colors.blue.shade200),
										),
										child: SelectableText(
											checkoutUrl,
											style: const TextStyle(color: Colors.blue, fontSize: 12),
										),
									),
									const SizedBox(height: 12),
									const Text(
										'Copy and paste this link in your browser to complete payment.',
										style: TextStyle(color: Colors.grey, fontSize: 12),
									),
								],
							),
							actions: [
								TextButton(
									onPressed: () {
										Navigator.pop(context);
										context.pop();
									},
									child: const Text('Close'),
								),
							],
						),
					);
				}
			}
		} catch (e) {
			throw Exception('Payment initialization failed: $e');
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text('💰 Add Funds'),
				backgroundColor: Colors.green.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
			),
			body: Container(
				color: Colors.white,
				child: SingleChildScrollView(
					padding: const EdgeInsets.all(16),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							// Current balance card
							Card(
								elevation: 4,
								child: Container(
									decoration: BoxDecoration(
										gradient: const LinearGradient(
											colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
											begin: Alignment.topLeft,
											end: Alignment.bottomRight,
										),
										borderRadius: BorderRadius.circular(12),
									),
									padding: const EdgeInsets.all(24),
									child: Column(
										children: [
											const Icon(Icons.account_balance_wallet, color: Colors.white, size: 48),
											const SizedBox(height: 12),
											const Text(
												'Current Balance',
												style: TextStyle(color: Colors.white70, fontSize: 16),
											),
											const SizedBox(height: 8),
											Text(
												'₦${_currentBalance.toStringAsFixed(2)}',
												style: const TextStyle(
													color: Colors.white,
													fontSize: 36,
													fontWeight: FontWeight.bold,
												),
											),
										],
									),
								),
							),

							const SizedBox(height: 24),

							// Quick amount selection
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Quick Amounts', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											Wrap(
												spacing: 8,
												runSpacing: 8,
												children: _quickAmounts.map((amount) => OutlinedButton(
													onPressed: () => _amountController.text = amount.toStringAsFixed(0),
													style: OutlinedButton.styleFrom(
														side: const BorderSide(color: Colors.green),
													),
													child: Text('₦${amount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green)),
												)).toList(),
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Custom amount input
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Custom Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											TextField(
												controller: _amountController,
												keyboardType: TextInputType.number,
												style: const TextStyle(color: Colors.black),
												decoration: const InputDecoration(
													labelText: 'Enter amount',
													labelStyle: TextStyle(color: Colors.black),
													hintText: 'Minimum ₦100, Maximum ₦1,000,000',
													hintStyle: TextStyle(color: Colors.black38),
													prefixIcon: Icon(Icons.attach_money, color: Colors.green),
													border: OutlineInputBorder(),
													focusedBorder: OutlineInputBorder(
														borderSide: BorderSide(color: Colors.green, width: 2),
													),
												),
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Payment method selection
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											
											RadioListTile<String>(
												title: const Row(
													children: [
														Icon(Icons.credit_card, color: Colors.blue),
														SizedBox(width: 8),
														Text('Debit/Credit Card', style: TextStyle(color: Colors.black)),
													],
												),
												subtitle: const Text('Visa, Mastercard, Verve', style: TextStyle(color: Colors.black54)),
												value: 'card',
												groupValue: _paymentMethod,
												onChanged: (value) => setState(() => _paymentMethod = value!),
												activeColor: Colors.blue,
											),
											
											RadioListTile<String>(
												title: const Row(
													children: [
														Icon(Icons.account_balance, color: Colors.green),
														SizedBox(width: 8),
														Text('Bank Transfer', style: TextStyle(color: Colors.black)),
													],
												),
												subtitle: const Text('Direct bank transfer (Flutterwave)', style: TextStyle(color: Colors.black54)),
												value: 'flutterwave',
												groupValue: _paymentMethod,
												onChanged: (value) => setState(() => _paymentMethod = value!),
												activeColor: Colors.green,
											),
											
											RadioListTile<String>(
												title: const Row(
													children: [
														Icon(Icons.phone_android, color: Colors.orange),
														SizedBox(width: 8),
														Text('USSD/Mobile Money', style: TextStyle(color: Colors.black)),
													],
												),
												subtitle: const Text('*737#, *770#, Mobile Money', style: TextStyle(color: Colors.black54)),
												value: 'ussd',
												groupValue: _paymentMethod,
												onChanged: (value) => setState(() => _paymentMethod = value!),
												activeColor: Colors.orange,
											),
										],
									),
								),
							),

							const SizedBox(height: 24),

							// Add funds button
							SizedBox(
								height: 56,
								child: FilledButton.icon(
									onPressed: _isProcessing ? null : _addFunds,
									icon: _isProcessing 
										? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
										: const Icon(Icons.add_circle),
									label: Text(_isProcessing ? 'Processing...' : 'Add Funds'),
									style: FilledButton.styleFrom(
										backgroundColor: Colors.green.shade600,
										textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
									),
								),
							),

							const SizedBox(height: 16),

							// Info card
							Card(
								color: Colors.blue.shade50,
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Row(
												children: [
													const Icon(Icons.info, color: Colors.blue),
													const SizedBox(width: 8),
													const Text('How it works', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
												],
											),
											const SizedBox(height: 8),
											const Text(
												'• Card payments are processed instantly\n• Bank transfers may take 1-5 minutes\n• USSD payments are instant\n• Funds are added automatically after payment\n• Minimum: ₦100, Maximum: ₦1,000,000',
												style: TextStyle(color: Colors.black87),
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Security info
							Card(
								color: Colors.green.shade50,
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Row(
												children: [
													const Icon(Icons.security, color: Colors.green),
													const SizedBox(width: 8),
													const Text('Secure Payments', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
												],
											),
											const SizedBox(height: 8),
											const Text(
												'🔒 All payments are secured with bank-level encryption\n🛡️ We never store your card details\n✅ Powered by Flutterwave and Stripe\n📱 PCI DSS compliant payment processing',
												style: TextStyle(color: Colors.black87),
											),
										],
									),
								),
							),
						],
					),
				),
			),
		);
	}
}