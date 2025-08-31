import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/digital/reloadly_service.dart';
import 'package:zippup/services/payments/payments_service.dart';

class GlobalAirtimeScreen extends StatefulWidget {
	const GlobalAirtimeScreen({super.key});

	@override
	State<GlobalAirtimeScreen> createState() => _GlobalAirtimeScreenState();
}

class _GlobalAirtimeScreenState extends State<GlobalAirtimeScreen> {
	final TextEditingController _phoneController = TextEditingController();
	final TextEditingController _amountController = TextEditingController();
	
	String _detectedCountry = 'NG';
	String _currencySymbol = '₦';
	String _currencyCode = 'NGN';
	List<Map<String, dynamic>> _operators = [];
	Map<String, dynamic>? _selectedOperator;
	String _paymentMethod = 'wallet';
	bool _isProcessing = false;
	bool _isLoadingOperators = false;
	double _walletBalance = 0.0;

	@override
	void initState() {
		super.initState();
		_loadWalletBalance();
		_phoneController.addListener(_onPhoneNumberChanged);
	}

	@override
	void dispose() {
		_phoneController.removeListener(_onPhoneNumberChanged);
		super.dispose();
	}

	void _onPhoneNumberChanged() {
		final phoneNumber = _phoneController.text.trim();
		if (phoneNumber.length >= 3) {
			final detectedCountry = ReloadlyService.getCountryCodeFromPhone(phoneNumber);
			if (detectedCountry != _detectedCountry) {
				setState(() {
					_detectedCountry = detectedCountry;
					final currencyInfo = ReloadlyService.getCurrencyInfo(detectedCountry);
					_currencySymbol = currencyInfo['symbol']!;
					_currencyCode = currencyInfo['code']!;
					_operators = [];
					_selectedOperator = null;
				});
				_loadOperators();
			}
		}
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

	Future<void> _loadOperators() async {
		setState(() => _isLoadingOperators = true);
		
		try {
			final operators = await ReloadlyService.getOperatorsByCountry(_detectedCountry);
			setState(() {
				_operators = operators;
				if (operators.isNotEmpty) {
					_selectedOperator = operators.first;
				}
			});
		} catch (e) {
			print('Error loading operators: $e');
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Failed to load operators: $e'))
			);
		} finally {
			setState(() => _isLoadingOperators = false);
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

		if (_selectedOperator == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please select a network operator'))
			);
			return;
		}

		final amount = double.tryParse(amountText);
		if (amount == null || amount < 1) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please enter a valid amount'))
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
				await _processWalletPayment(uid, amount, phoneNumber);
			} else {
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
		try {
			// Deduct from wallet first
			await FirebaseFirestore.instance.collection('wallets').doc(uid).update({
				'balance': FieldValue.increment(-amount),
				'lastUpdated': DateTime.now().toIso8601String(),
			});

			// Purchase airtime via Reloadly
			final result = await ReloadlyService.purchaseAirtime(
				phoneNumber: phoneNumber,
				amount: amount,
				operatorId: _selectedOperator!['id'],
				countryCode: _detectedCountry,
			);

			// Record transaction
			await FirebaseFirestore.instance.collection('airtime_purchases').add({
				'userId': uid,
				'phoneNumber': phoneNumber,
				'operatorId': _selectedOperator!['id'],
				'operatorName': _selectedOperator!['name'],
				'amount': amount,
				'currency': _currencyCode,
				'countryCode': _detectedCountry,
				'paymentMethod': 'wallet',
				'reloadlyTransactionId': result['transactionId'],
				'status': 'completed',
				'createdAt': DateTime.now().toIso8601String(),
			});

			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(
						content: Text('✅ $_currencySymbol${amount.toStringAsFixed(2)} airtime sent to $phoneNumber'),
						backgroundColor: Colors.green,
					)
				);
				_loadWalletBalance();
				_phoneController.clear();
				_amountController.clear();
			}
		} catch (e) {
			// Refund wallet if airtime purchase failed
			await FirebaseFirestore.instance.collection('wallets').doc(uid).update({
				'balance': FieldValue.increment(amount),
			});
			throw e;
		}
	}

	Future<void> _processGatewayPayment(double amount, String phoneNumber) async {
		try {
			final paymentsService = PaymentsService();
			final checkoutUrl = await paymentsService.createFlutterwaveCheckout(
				amount: amount,
				currency: _currencyCode,
				items: [
					{
						'title': '${_selectedOperator!['name']} Airtime',
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
								Text('Complete payment for ${_selectedOperator!['name']} airtime:'),
								const SizedBox(height: 12),
								SelectableText(
									checkoutUrl,
									style: const TextStyle(color: Colors.blue),
								),
								const SizedBox(height: 12),
								const Text(
									'After payment, airtime will be delivered automatically.',
									style: TextStyle(color: Colors.grey),
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
		return Scaffold(
			appBar: AppBar(
				title: Text('📞 Global Airtime - $_detectedCountry'),
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
							// Country detection info
							Card(
								color: Colors.blue.shade50,
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Row(
										children: [
											const Icon(Icons.public, color: Colors.blue, size: 32),
											const SizedBox(width: 12),
											Expanded(
												child: Column(
													crossAxisAlignment: CrossAxisAlignment.start,
													children: [
														Text(
															'Detected Country: $_detectedCountry',
															style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
														),
														Text(
															'Currency: $_currencyCode ($_currencySymbol)',
															style: const TextStyle(color: Colors.black54),
														),
														Text(
															'Operators: ${_operators.length} available',
															style: const TextStyle(color: Colors.black54),
														),
													],
												),
											),
											OutlinedButton(
												onPressed: () {
													// TODO: Manual country selection
													ScaffoldMessenger.of(context).showSnackBar(
														const SnackBar(content: Text('Manual country selection coming soon!'))
													);
												},
												child: const Text('Change'),
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

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
														'$_currencySymbol${_walletBalance.toStringAsFixed(2)}',
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
												onPressed: () => context.push('/wallet'),
												child: const Text('Add Funds'),
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
												decoration: const InputDecoration(
													labelText: 'Enter phone number with country code',
													labelStyle: TextStyle(color: Colors.black),
													hintText: '+234812345678 or +1234567890',
													hintStyle: TextStyle(color: Colors.black38),
													prefixIcon: Icon(Icons.phone, color: Colors.blue),
													border: OutlineInputBorder(),
													helperText: 'Country auto-detected from phone number',
													helperStyle: TextStyle(color: Colors.black54),
												),
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Network operator selection
							if (_isLoadingOperators)
								const Card(
									child: Padding(
										padding: EdgeInsets.all(32),
										child: Center(
											child: Column(
												children: [
													CircularProgressIndicator(),
													SizedBox(height: 8),
													Text('Loading operators...', style: TextStyle(color: Colors.black)),
												],
											),
										),
									),
								)
							else if (_operators.isNotEmpty)
								Card(
									child: Padding(
										padding: const EdgeInsets.all(16),
										child: Column(
											crossAxisAlignment: CrossAxisAlignment.start,
											children: [
												const Text('Select Network Operator', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
												const SizedBox(height: 12),
												Wrap(
													spacing: 8,
													runSpacing: 8,
													children: _operators.map((operator) {
														final isSelected = _selectedOperator?['id'] == operator['id'];
														return GestureDetector(
															onTap: () => setState(() => _selectedOperator = operator),
															child: Container(
																padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
																decoration: BoxDecoration(
																	color: isSelected ? Colors.blue : Colors.grey.shade100,
																	borderRadius: BorderRadius.circular(8),
																	border: Border.all(
																		color: isSelected ? Colors.blue : Colors.grey.shade300,
																		width: 2,
																	),
																),
																child: Column(
																	children: [
																		Text(
																			operator['name'] ?? 'Unknown',
																			style: TextStyle(
																				color: isSelected ? Colors.white : Colors.black,
																				fontWeight: FontWeight.bold,
																			),
																		),
																		if (operator['denominationType'] != null)
																			Text(
																				operator['denominationType'],
																				style: TextStyle(
																					color: isSelected ? Colors.white70 : Colors.black54,
																					fontSize: 11,
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
													hintText: 'Minimum $_currencySymbol 1',
													hintStyle: const TextStyle(color: Colors.black38),
													prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
													border: const OutlineInputBorder(),
													focusedBorder: const OutlineInputBorder(
														borderSide: BorderSide(color: Colors.green, width: 2),
													),
												),
											),
											if (_selectedOperator != null) ...[
												const SizedBox(height: 8),
												Text(
													'Min: $_currencySymbol${_selectedOperator!['minAmount'] ?? 1} • Max: $_currencySymbol${_selectedOperator!['maxAmount'] ?? 1000}',
													style: const TextStyle(color: Colors.black54, fontSize: 12),
												),
											],
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
														Text('Wallet ($_currencySymbol${_walletBalance.toStringAsFixed(2)})', style: const TextStyle(color: Colors.black)),
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
									onPressed: (_isProcessing || _selectedOperator == null) ? null : _purchaseAirtime,
									icon: _isProcessing 
										? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
										: const Icon(Icons.phone),
									label: Text(_isProcessing ? 'Processing...' : 'Purchase Airtime'),
									style: FilledButton.styleFrom(
										backgroundColor: Colors.blue.shade600,
										textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
									),
								),
							),

							const SizedBox(height: 16),

							// Global coverage info
							Card(
								color: Colors.green.shade50,
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										children: [
											Row(
												children: [
													const Icon(Icons.public, color: Colors.green),
													const SizedBox(width: 8),
													const Text('Global Coverage', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
												],
											),
											const SizedBox(height: 8),
											const Text(
												'🌍 Works in 150+ countries worldwide\n📞 Auto-detects your country from phone number\n💰 Local currency and operators\n⚡ Instant delivery via Reloadly network',
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