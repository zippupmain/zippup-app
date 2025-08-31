import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/payments/payments_service.dart';

class BillPaymentScreen extends StatefulWidget {
	const BillPaymentScreen({super.key});

	@override
	State<BillPaymentScreen> createState() => _BillPaymentScreenState();
}

class _BillPaymentScreenState extends State<BillPaymentScreen> {
	final TextEditingController _accountController = TextEditingController();
	final TextEditingController _amountController = TextEditingController();
	String _selectedBillType = 'electricity';
	String _selectedProvider = 'phcn';
	String _paymentMethod = 'wallet';
	bool _isProcessing = false;
	double _walletBalance = 0.0;

	final Map<String, Map<String, dynamic>> _billTypes = {
		'electricity': {
			'name': 'Electricity',
			'icon': Icons.electric_bolt,
			'emoji': '💡',
			'color': Colors.yellow,
			'providers': {
				'phcn': {'name': 'PHCN/NEPA', 'code': 'BIL119'},
				'eko': {'name': 'Eko Electric', 'code': 'BIL120'},
				'kano': {'name': 'Kano Electric', 'code': 'BIL121'},
			},
		},
		'cable': {
			'name': 'Cable TV',
			'icon': Icons.tv,
			'emoji': '📺',
			'color': Colors.blue,
			'providers': {
				'dstv': {'name': 'DSTV', 'code': 'BIL122'},
				'gotv': {'name': 'GOTV', 'code': 'BIL123'},
				'startimes': {'name': 'StarTimes', 'code': 'BIL124'},
			},
		},
		'internet': {
			'name': 'Internet',
			'icon': Icons.wifi,
			'emoji': '🌐',
			'color': Colors.green,
			'providers': {
				'spectranet': {'name': 'Spectranet', 'code': 'BIL125'},
				'smile': {'name': 'Smile', 'code': 'BIL126'},
				'swift': {'name': 'Swift', 'code': 'BIL127'},
			},
		},
		'water': {
			'name': 'Water',
			'icon': Icons.water_drop,
			'emoji': '💧',
			'color': Colors.cyan,
			'providers': {
				'lagos_water': {'name': 'Lagos Water Corp', 'code': 'BIL128'},
				'abuja_water': {'name': 'Abuja Water Board', 'code': 'BIL129'},
			},
		},
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

	Future<void> _payBill() async {
		final accountNumber = _accountController.text.trim();
		final amountText = _amountController.text.trim();

		if (accountNumber.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please enter account/meter number'))
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
		if (amount == null || amount < 100) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Minimum amount is ₦100'))
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
				throw Exception('Please sign in to pay bills');
			}

			if (_paymentMethod == 'wallet') {
				await _processWalletPayment(uid, amount, accountNumber);
			} else {
				await _processGatewayPayment(amount, accountNumber);
			}

		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Payment failed: $e'))
				);
			}
		} finally {
			if (mounted) setState(() => _isProcessing = false);
		}
	}

	Future<void> _processWalletPayment(String uid, double amount, String accountNumber) async {
		// Deduct from wallet
		await FirebaseFirestore.instance.collection('wallets').doc(uid).update({
			'balance': FieldValue.increment(-amount),
			'lastUpdated': DateTime.now().toIso8601String(),
		});

		// Create bill payment record
		await FirebaseFirestore.instance.collection('bill_payments').add({
			'userId': uid,
			'billType': _selectedBillType,
			'provider': _selectedProvider,
			'accountNumber': accountNumber,
			'amount': amount,
			'paymentMethod': 'wallet',
			'status': 'processing',
			'createdAt': DateTime.now().toIso8601String(),
		});

		// TODO: Integrate with Flutterwave Bills API for actual bill payment
		if (mounted) {
			final billData = _billTypes[_selectedBillType]!;
			final providerData = billData['providers'][_selectedProvider];
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text('✅ ₦${amount.toStringAsFixed(0)} ${billData['name']} bill paid for $accountNumber'),
					backgroundColor: Colors.green,
				)
			);
			_loadWalletBalance();
			_accountController.clear();
			_amountController.clear();
		}
	}

	Future<void> _processGatewayPayment(double amount, String accountNumber) async {
		try {
			final paymentsService = PaymentsService();
			final billData = _billTypes[_selectedBillType]!;
			final providerData = billData['providers'][_selectedProvider];
			
			final checkoutUrl = await paymentsService.createFlutterwaveCheckout(
				amount: amount,
				currency: 'NGN',
				items: [
					{
						'title': '${providerData['name']} ${billData['name']} Bill',
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
								Text('Complete payment for ${providerData['name']} bill:'),
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
		final billTypeData = _billTypes[_selectedBillType]!;
		final providers = billTypeData['providers'] as Map<String, dynamic>;

		return Scaffold(
			appBar: AppBar(
				title: const Text('💡 Pay Bills'),
				backgroundColor: Colors.orange.shade50,
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

							// Bill type selection
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Bill Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											Wrap(
												spacing: 8,
												runSpacing: 8,
												children: _billTypes.keys.map((billType) {
													final data = _billTypes[billType]!;
													final isSelected = billType == _selectedBillType;
													return GestureDetector(
														onTap: () {
															setState(() {
																_selectedBillType = billType;
																_selectedProvider = providers.keys.first;
															});
														},
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
																	Text(data['emoji'], style: const TextStyle(fontSize: 20)),
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

							// Provider selection
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text('${billTypeData['name']} Provider', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											DropdownButtonFormField<String>(
												value: _selectedProvider,
												decoration: InputDecoration(
													border: const OutlineInputBorder(),
													prefixIcon: Icon(billTypeData['icon'], color: billTypeData['color']),
												),
												items: providers.keys.map((provider) {
													final providerData = providers[provider];
													return DropdownMenuItem(
														value: provider,
														child: Text(providerData['name'], style: const TextStyle(color: Colors.black)),
													);
												}).toList(),
												onChanged: (value) => setState(() => _selectedProvider = value!),
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Account number input
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Text(
												_selectedBillType == 'electricity' ? 'Meter Number' : 
												_selectedBillType == 'cable' ? 'Decoder Number' :
												_selectedBillType == 'water' ? 'Account Number' : 'Account Number',
												style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)
											),
											const SizedBox(height: 12),
											TextField(
												controller: _accountController,
												keyboardType: TextInputType.number,
												style: const TextStyle(color: Colors.black),
												decoration: InputDecoration(
													labelText: _selectedBillType == 'electricity' ? 'Enter meter number' : 'Enter account number',
													labelStyle: const TextStyle(color: Colors.black),
													hintText: _selectedBillType == 'electricity' ? '12345678901' : '1234567890',
													hintStyle: const TextStyle(color: Colors.black38),
													prefixIcon: Icon(Icons.numbers, color: billTypeData['color']),
													border: const OutlineInputBorder(),
													focusedBorder: OutlineInputBorder(
														borderSide: BorderSide(color: billTypeData['color'], width: 2),
													),
												),
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Amount input
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											TextField(
												controller: _amountController,
												keyboardType: TextInputType.number,
												style: const TextStyle(color: Colors.black),
												decoration: InputDecoration(
													labelText: 'Enter amount',
													labelStyle: const TextStyle(color: Colors.black),
													hintText: 'Minimum ₦100',
													hintStyle: const TextStyle(color: Colors.black38),
													prefixIcon: Icon(Icons.attach_money, color: billTypeData['color']),
													border: const OutlineInputBorder(),
													focusedBorder: OutlineInputBorder(
														borderSide: BorderSide(color: billTypeData['color'], width: 2),
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

							// Pay button
							SizedBox(
								height: 56,
								child: FilledButton.icon(
									onPressed: _isProcessing ? null : _payBill,
									icon: _isProcessing 
										? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
										: Icon(billTypeData['icon']),
									label: Text(_isProcessing ? 'Processing Payment...' : 'Pay Bill'),
									style: FilledButton.styleFrom(
										backgroundColor: billTypeData['color'],
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
													const Text('Payment Info', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
												],
											),
											const SizedBox(height: 8),
											const Text(
												'• Payments are processed instantly\n• You will receive SMS confirmation\n• Keep your receipt for records\n• Contact support for payment issues',
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

	Future<void> _processWalletPayment(String uid, double amount, String accountNumber) async {
		// Deduct from wallet
		await FirebaseFirestore.instance.collection('wallets').doc(uid).update({
			'balance': FieldValue.increment(-amount),
			'lastUpdated': DateTime.now().toIso8601String(),
		});

		// Create bill payment record
		await FirebaseFirestore.instance.collection('bill_payments').add({
			'userId': uid,
			'billType': _selectedBillType,
			'provider': _selectedProvider,
			'accountNumber': accountNumber,
			'amount': amount,
			'paymentMethod': 'wallet',
			'status': 'processing',
			'createdAt': DateTime.now().toIso8601String(),
		});

		if (mounted) {
			final billData = _billTypes[_selectedBillType]!;
			final providerData = billData['providers'][_selectedProvider];
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(
					content: Text('✅ ₦${amount.toStringAsFixed(0)} ${billData['name']} bill paid for $accountNumber'),
					backgroundColor: Colors.green,
				)
			);
			_loadWalletBalance();
			_accountController.clear();
			_amountController.clear();
		}
	}

	Future<void> _processGatewayPayment(double amount, String accountNumber) async {
		try {
			final paymentsService = PaymentsService();
			final billData = _billTypes[_selectedBillType]!;
			final providerData = billData['providers'][_selectedProvider];
			
			final checkoutUrl = await paymentsService.createFlutterwaveCheckout(
				amount: amount,
				currency: 'NGN',
				items: [
					{
						'title': '${providerData['name']} ${billData['name']} Bill',
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
								Text('Complete payment for ${providerData['name']} bill:'),
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