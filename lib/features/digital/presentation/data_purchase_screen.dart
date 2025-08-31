import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/payments/payments_service.dart';

class DataPurchaseScreen extends StatefulWidget {
	const DataPurchaseScreen({super.key});

	@override
	State<DataPurchaseScreen> createState() => _DataPurchaseScreenState();
}

class _DataPurchaseScreenState extends State<DataPurchaseScreen> {
	final TextEditingController _phoneController = TextEditingController();
	String _selectedNetwork = 'mtn';
	String _selectedBundle = '1gb_monthly';
	String _paymentMethod = 'wallet';
	bool _isProcessing = false;
	double _walletBalance = 0.0;

	final Map<String, Map<String, dynamic>> _networks = {
		'mtn': {
			'name': 'MTN',
			'color': Colors.yellow,
			'logo': '📱',
		},
		'airtel': {
			'name': 'Airtel',
			'color': Colors.red,
			'logo': '📲',
		},
		'glo': {
			'name': 'Glo',
			'color': Colors.green,
			'logo': '📞',
		},
		'9mobile': {
			'name': '9mobile',
			'color': Colors.purple,
			'logo': '📳',
		},
	};

	final Map<String, Map<String, dynamic>> _dataBundles = {
		'500mb_daily': {'name': '500MB Daily', 'price': 200, 'validity': '1 day'},
		'1gb_daily': {'name': '1GB Daily', 'price': 350, 'validity': '1 day'},
		'1gb_weekly': {'name': '1GB Weekly', 'price': 500, 'validity': '7 days'},
		'2gb_weekly': {'name': '2GB Weekly', 'price': 800, 'validity': '7 days'},
		'1gb_monthly': {'name': '1GB Monthly', 'price': 1000, 'validity': '30 days'},
		'2gb_monthly': {'name': '2GB Monthly', 'price': 1800, 'validity': '30 days'},
		'5gb_monthly': {'name': '5GB Monthly', 'price': 4000, 'validity': '30 days'},
		'10gb_monthly': {'name': '10GB Monthly', 'price': 7500, 'validity': '30 days'},
	};

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

	Future<void> _purchaseData() async {
		final phoneNumber = _phoneController.text.trim();

		if (phoneNumber.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please enter phone number'))
			);
			return;
		}

		final bundleData = _dataBundles[_selectedBundle]!;
		final amount = bundleData['price'].toDouble();

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
				throw Exception('Please sign in to purchase data');
			}

			if (_paymentMethod == 'wallet') {
				await _processWalletPayment(uid, amount, phoneNumber, bundleData);
			} else {
				await _processGatewayPayment(amount, phoneNumber, bundleData);
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

	Future<void> _processWalletPayment(String uid, double amount, String phoneNumber, Map<String, dynamic> bundleData) async {
		// Deduct from wallet
		await FirebaseFirestore.instance.collection('wallets').doc(uid).update({
			'balance': FieldValue.increment(-amount),
			'lastUpdated': DateTime.now().toIso8601String(),
		});

		// Create data purchase record
		await FirebaseFirestore.instance.collection('data_purchases').add({
			'userId': uid,
			'phoneNumber': phoneNumber,
			'network': _selectedNetwork,
			'bundle': _selectedBundle,
			'bundleName': bundleData['name'],
			'amount': amount,
			'validity': bundleData['validity'],
			'paymentMethod': 'wallet',
			'status': 'processing',
			'createdAt': DateTime.now().toIso8601String(),
		});

		// TODO: Integrate with Flutterwave Bills API for actual data purchase
		if (mounted) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text('✅ ${bundleData['name']} sent to $phoneNumber'),
					backgroundColor: Colors.green,
				)
			);
			_loadWalletBalance();
			_phoneController.clear();
		}
	}

	Future<void> _processGatewayPayment(double amount, String phoneNumber, Map<String, dynamic> bundleData) async {
		try {
			final paymentsService = PaymentsService();
			final checkoutUrl = await paymentsService.createFlutterwaveCheckout(
				amount: amount,
				currency: 'NGN',
				items: [
					{
						'title': '${_networks[_selectedNetwork]!['name']} ${bundleData['name']}',
						'price': amount,
						'quantity': 1,
					}
				],
			);

			if (mounted) {
				showDialog(
					context: context,
					builder: (_) => AlertDialog(
						title: const Text('Complete Payment'),
						content: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								Text('Complete payment for ${bundleData['name']}:'),
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
		final bundleData = _dataBundles[_selectedBundle]!;

		return Scaffold(
			appBar: AppBar(
				title: const Text('📶 Buy Data'),
				backgroundColor: Colors.purple.shade50,
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
										],
									),
								),
							),

							const SizedBox(height: 20),

							// Network selection (same as airtime)
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

							// Data bundle selection
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Select Data Bundle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											
											// Data bundle grid
											GridView.builder(
												shrinkWrap: true,
												physics: const NeverScrollableScrollPhysics(),
												gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
													crossAxisCount: 2,
													childAspectRatio: 2.5,
													crossAxisSpacing: 8,
													mainAxisSpacing: 8,
												),
												itemCount: _dataBundles.length,
												itemBuilder: (context, index) {
													final bundleKey = _dataBundles.keys.elementAt(index);
													final bundle = _dataBundles[bundleKey]!;
													final isSelected = bundleKey == _selectedBundle;
													
													return GestureDetector(
														onTap: () => setState(() => _selectedBundle = bundleKey),
														child: Container(
															padding: const EdgeInsets.all(8),
															decoration: BoxDecoration(
																color: isSelected ? networkData['color'] : Colors.grey.shade100,
																borderRadius: BorderRadius.circular(8),
																border: Border.all(
																	color: isSelected ? networkData['color'] : Colors.grey.shade300,
																	width: 2,
																),
															),
															child: Column(
																mainAxisAlignment: MainAxisAlignment.center,
																children: [
																	Text(
																		bundle['name'],
																		style: TextStyle(
																			color: isSelected ? Colors.white : Colors.black,
																			fontWeight: FontWeight.bold,
																			fontSize: 12,
																		),
																		textAlign: TextAlign.center,
																	),
																	const SizedBox(height: 4),
																	Text(
																		'₦${bundle['price']}',
																		style: TextStyle(
																			color: isSelected ? Colors.white70 : Colors.black54,
																			fontSize: 11,
																		),
																	),
																	Text(
																		bundle['validity'],
																		style: TextStyle(
																			color: isSelected ? Colors.white70 : Colors.black54,
																			fontSize: 10,
																		),
																	),
																],
															),
														),
													);
												},
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

							// Purchase summary
							Card(
								color: Colors.blue.shade50,
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Purchase Summary', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
											const SizedBox(height: 8),
											Row(
												mainAxisAlignment: MainAxisAlignment.spaceBetween,
												children: [
													const Text('Data Bundle:', style: TextStyle(color: Colors.black)),
													Text(bundleData['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
												],
											),
											Row(
												mainAxisAlignment: MainAxisAlignment.spaceBetween,
												children: [
													const Text('Network:', style: TextStyle(color: Colors.black)),
													Text(_networks[_selectedNetwork]!['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
												],
											),
											Row(
												mainAxisAlignment: MainAxisAlignment.spaceBetween,
												children: [
													const Text('Validity:', style: TextStyle(color: Colors.black)),
													Text(bundleData['validity'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
												],
											),
											const Divider(),
											Row(
												mainAxisAlignment: MainAxisAlignment.spaceBetween,
												children: [
													const Text('Total Amount:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
													Text('₦${bundleData['price']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: networkData['color'])),
												],
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Purchase button
							SizedBox(
								height: 56,
								child: FilledButton.icon(
									onPressed: _isProcessing ? null : _purchaseData,
									icon: _isProcessing 
										? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
										: const Icon(Icons.network_cell),
									label: Text(_isProcessing ? 'Processing...' : 'Purchase Data'),
									style: FilledButton.styleFrom(
										backgroundColor: networkData['color'],
										textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
									),
								),
							),
						],
					),
				),
			),
		);
	}

	Future<void> _processWalletPayment(String uid, double amount, String phoneNumber, Map<String, dynamic> bundleData) async {
		// Deduct from wallet
		await FirebaseFirestore.instance.collection('wallets').doc(uid).update({
			'balance': FieldValue.increment(-amount),
			'lastUpdated': DateTime.now().toIso8601String(),
		});

		// Create data purchase record
		await FirebaseFirestore.instance.collection('data_purchases').add({
			'userId': uid,
			'phoneNumber': phoneNumber,
			'network': _selectedNetwork,
			'bundle': _selectedBundle,
			'bundleName': bundleData['name'],
			'amount': amount,
			'validity': bundleData['validity'],
			'paymentMethod': 'wallet',
			'status': 'processing',
			'createdAt': DateTime.now().toIso8601String(),
		});

		if (mounted) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text('✅ ${bundleData['name']} sent to $phoneNumber'),
					backgroundColor: Colors.green,
				)
			);
			_loadWalletBalance();
			_phoneController.clear();
		}
	}

	Future<void> _processGatewayPayment(double amount, String phoneNumber, Map<String, dynamic> bundleData) async {
		try {
			final paymentsService = PaymentsService();
			final checkoutUrl = await paymentsService.createFlutterwaveCheckout(
				amount: amount,
				currency: 'NGN',
				items: [
					{
						'title': '${_networks[_selectedNetwork]!['name']} ${bundleData['name']}',
						'price': amount,
						'quantity': 1,
					}
				],
			);

			if (mounted) {
				showDialog(
					context: context,
					builder: (_) => AlertDialog(
						title: const Text('Complete Payment'),
						content: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								Text('Complete payment for ${bundleData['name']}:'),
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
}