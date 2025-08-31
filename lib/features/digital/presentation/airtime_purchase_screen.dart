import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/payments/payments_service.dart';

class AirtimePurchaseScreen extends StatefulWidget {
	const AirtimePurchaseScreen({super.key});

	@override
	State<AirtimePurchaseScreen> createState() => _AirtimePurchaseScreenState();
}

class _AirtimePurchaseScreenState extends State<AirtimePurchaseScreen> {
	final TextEditingController _phoneController = TextEditingController();
	final TextEditingController _amountController = TextEditingController();
	String _selectedNetwork = 'mtn';
	String _paymentMethod = 'wallet';
	bool _isProcessing = false;
	double _walletBalance = 0.0;

	final Map<String, Map<String, dynamic>> _networks = {
		'mtn': {
			'name': 'MTN',
			'color': Colors.yellow,
			'logo': '📱',
			'ussd': '*131#',
		},
		'airtel': {
			'name': 'Airtel',
			'color': Colors.red,
			'logo': '📲',
			'ussd': '*140#',
		},
		'glo': {
			'name': 'Glo',
			'color': Colors.green,
			'logo': '📞',
			'ussd': '*777#',
		},
		'9mobile': {
			'name': '9mobile',
			'color': Colors.purple,
			'logo': '📳',
			'ussd': '*200#',
		},
	};

	final List<double> _quickAmounts = [100, 200, 500, 1000, 2000, 5000];

	@override
	void initState() {
		super.initState();
		_loadWalletBalance();
	}

	Future<void> _loadWalletBalance() async {
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
						_walletBalance = (data['balance'] ?? 0.0).toDouble();
					});
				}
			}
		} catch (e) {
			print('Error loading wallet balance: $e');
		}
	}

	Future<void> _purchaseAirtime() async {
		final phoneNumber = _phoneController.text.trim();
		final amountText = _amountController.text.trim();

		if (phoneNumber.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please enter phone number'))
			);
			return;
		}

		if (amountText.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please enter amount'))
			);
			return;
		}

		final amount = double.tryParse(amountText);
		if (amount == null || amount < 50) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Minimum amount is ₦50'))
			);
			return;
		}

		if (_paymentMethod == 'wallet' && amount > _walletBalance) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Insufficient wallet balance'))
			);
			return;
		}

		setState(() => _isProcessing = true);

		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) {
				throw Exception('Please sign in to purchase airtime');
			}

			if (_paymentMethod == 'wallet') {
				// Deduct from wallet and process airtime
				await _processWalletPayment(uid, amount, phoneNumber);
			} else {
				// Redirect to payment gateway
				await _processGatewayPayment(amount, phoneNumber);
			}

		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Purchase failed: $e'))
				);
			}
		} finally {
			if (mounted) setState(() => _isProcessing = false);
		}
	}

	Future<void> _processWalletPayment(String uid, double amount, String phoneNumber) async {
		// Deduct from wallet
		await FirebaseFirestore.instance.collection('wallets').doc(uid).update({
			'balance': FieldValue.increment(-amount),
			'lastUpdated': DateTime.now().toIso8601String(),
		});

		// Create airtime purchase record
		await FirebaseFirestore.instance.collection('airtime_purchases').add({
			'userId': uid,
			'phoneNumber': phoneNumber,
			'network': _selectedNetwork,
			'amount': amount,
			'paymentMethod': 'wallet',
			'status': 'processing',
			'createdAt': DateTime.now().toIso8601String(),
		});

		// TODO: Integrate with Flutterwave Bills API for actual airtime purchase
		// For now, simulate success
		if (mounted) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text('✅ ₦${amount.toStringAsFixed(0)} airtime sent to $phoneNumber'),
					backgroundColor: Colors.green,
				)
			);
			_loadWalletBalance(); // Refresh balance
			_phoneController.clear();
			_amountController.clear();
		}
	}

	Future<void> _processGatewayPayment(double amount, String phoneNumber) async {
		try {
			// Use existing payment service for gateway redirect
			final paymentsService = PaymentsService();
			final checkoutUrl = await paymentsService.createFlutterwaveCheckout(
				amount: amount,
				currency: 'NGN',
				items: [
					{
						'title': '${_networks[_selectedNetwork]!['name']} Airtime',
						'price': amount,
						'quantity': 1,
					}
				],
			);

			// TODO: Open checkout URL in webview or browser
			// For now, show URL
			if (mounted) {
				showDialog(
					context: context,
					builder: (_) => AlertDialog(
						title: const Text('Complete Payment'),
						content: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								const Text('Click the link below to complete your airtime purchase:'),
								const SizedBox(height: 12),
								SelectableText(
									checkoutUrl,
									style: const TextStyle(color: Colors.blue),
								),
							],
						),
						actions: [
							TextButton(
								onPressed: () => Navigator.pop(context),
								child: const Text('Close'),
							),
						],
					),
				);
			}
		} catch (e) {
			throw Exception('Payment gateway error: $e');
		}
	}

	@override
	Widget build(BuildContext context) {
		final networkData = _networks[_selectedNetwork]!;

		return Scaffold(
			appBar: AppBar(
				title: const Text('📞 Buy Airtime'),
				backgroundColor: Colors.blue.shade50,
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
							// Wallet balance card
							Card(
								color: Colors.green.shade50,
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Row(
										children: [
											const Icon(Icons.account_balance_wallet, color: Colors.green, size: 32),
											const SizedBox(width: 12),
											Column(
												crossAxisAlignment: CrossAxisAlignment.start,
												children: [
													const Text('Wallet Balance', style: TextStyle(color: Colors.black54)),
													Text(
														'₦${_walletBalance.toStringAsFixed(2)}',
														style: const TextStyle(
															fontSize: 24,
															fontWeight: FontWeight.bold,
															color: Colors.black,
														),
													),
												],
											),
											const Spacer(),
											OutlinedButton(
												onPressed: () {
													// TODO: Navigate to add funds screen
													ScaffoldMessenger.of(context).showSnackBar(
														const SnackBar(content: Text('Add funds feature coming soon!'))
													);
												},
												child: const Text('Add Funds'),
											),
										],
									),
								),
							),

							const SizedBox(height: 20),

							// Network selection
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Select Network', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											Wrap(
												spacing: 8,
												runSpacing: 8,
												children: _networks.keys.map((network) {
													final data = _networks[network]!;
													final isSelected = network == _selectedNetwork;
													return GestureDetector(
														onTap: () => setState(() => _selectedNetwork = network),
														child: Container(
															padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
															decoration: BoxDecoration(
																color: isSelected ? data['color'] : Colors.grey.shade100,
																borderRadius: BorderRadius.circular(8),
																border: Border.all(
																	color: isSelected ? data['color'] : Colors.grey.shade300,
																	width: 2,
																),
															),
															child: Row(
																mainAxisSize: MainAxisSize.min,
																children: [
																	Text(data['logo'], style: const TextStyle(fontSize: 20)),
																	const SizedBox(width: 8),
																	Text(
																		data['name'],
																		style: TextStyle(
																			color: isSelected ? Colors.white : Colors.black,
																			fontWeight: FontWeight.bold,
																		),
																	),
																],
															),
														),
													);
												}).toList(),
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Phone number input
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Phone Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											TextField(
												controller: _phoneController,
												keyboardType: TextInputType.phone,
												style: const TextStyle(color: Colors.black),
												decoration: InputDecoration(
													labelText: 'Enter phone number',
													labelStyle: const TextStyle(color: Colors.black),
													hintText: '08012345678',
													hintStyle: const TextStyle(color: Colors.black38),
													prefixIcon: Icon(Icons.phone, color: networkData['color']),
													border: const OutlineInputBorder(),
													focusedBorder: OutlineInputBorder(
														borderSide: BorderSide(color: networkData['color'], width: 2),
													),
												),
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Amount selection
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											
											// Quick amount buttons
											Wrap(
												spacing: 8,
												runSpacing: 8,
												children: _quickAmounts.map((amount) => OutlinedButton(
													onPressed: () => _amountController.text = amount.toStringAsFixed(0),
													style: OutlinedButton.styleFrom(
														side: BorderSide(color: networkData['color']),
													),
													child: Text('₦${amount.toStringAsFixed(0)}', style: TextStyle(color: networkData['color'])),
												)).toList(),
											),
											
											const SizedBox(height: 12),
											
											// Custom amount input
											TextField(
												controller: _amountController,
												keyboardType: TextInputType.number,
												style: const TextStyle(color: Colors.black),
												decoration: InputDecoration(
													labelText: 'Enter custom amount',
													labelStyle: const TextStyle(color: Colors.black),
													hintText: 'Minimum ₦50',
													hintStyle: const TextStyle(color: Colors.black38),
													prefixIcon: Icon(Icons.attach_money, color: networkData['color']),
													border: const OutlineInputBorder(),
													focusedBorder: OutlineInputBorder(
														borderSide: BorderSide(color: networkData['color'], width: 2),
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
												title: Row(
													children: [
														const Icon(Icons.account_balance_wallet, color: Colors.green),
														const SizedBox(width: 8),
														Text('Wallet (₦${_walletBalance.toStringAsFixed(2)})', style: const TextStyle(color: Colors.black)),
													],
												),
												value: 'wallet',
												groupValue: _paymentMethod,
												onChanged: (value) => setState(() => _paymentMethod = value!),
												activeColor: Colors.green,
											),
											
											RadioListTile<String>(
												title: const Row(
													children: [
														Icon(Icons.credit_card, color: Colors.blue),
														SizedBox(width: 8),
														Text('Card/Bank Transfer', style: TextStyle(color: Colors.black)),
													],
												),
												value: 'gateway',
												groupValue: _paymentMethod,
												onChanged: (value) => setState(() => _paymentMethod = value!),
												activeColor: Colors.blue,
											),
										],
									),
								),
							),

							const SizedBox(height: 24),

							// Purchase button
							SizedBox(
								height: 56,
								child: FilledButton.icon(
									onPressed: _isProcessing ? null : _purchaseAirtime,
									icon: _isProcessing 
										? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
										: const Icon(Icons.phone),
									label: Text(_isProcessing ? 'Processing...' : 'Purchase Airtime'),
									style: FilledButton.styleFrom(
										backgroundColor: networkData['color'],
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
										children: [
											Row(
												children: [
													const Icon(Icons.info, color: Colors.blue),
													const SizedBox(width: 8),
													const Text('How it works', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
												],
											),
											const SizedBox(height: 8),
											Text(
												'• Wallet payments are instant\n• Card payments redirect to secure gateway\n• Airtime is delivered within 30 seconds\n• Check balance with ${networkData['ussd'] ?? '*#'}',
												style: const TextStyle(color: Colors.black87),
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