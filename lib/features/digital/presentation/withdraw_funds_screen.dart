import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/location/country_detection_service.dart';

class WithdrawFundsScreen extends StatefulWidget {
	const WithdrawFundsScreen({super.key});

	@override
	State<WithdrawFundsScreen> createState() => _WithdrawFundsScreenState();
}

class _WithdrawFundsScreenState extends State<WithdrawFundsScreen> {
	final TextEditingController _amountController = TextEditingController();
	final TextEditingController _accountNumberController = TextEditingController();
	final TextEditingController _accountNameController = TextEditingController();
	String _selectedBank = 'gtbank';
	bool _isProcessing = false;
	double _currentBalance = 0.0;
	String _detectedCountry = 'NG';
	String _currencySymbol = '₦';
	String _currencyCode = 'NGN';
	Map<String, Map<String, dynamic>> _availableBanks = {};

	final Map<String, Map<String, Map<String, dynamic>>> _globalBanks = {
		'NG': { // Nigeria
			'gtbank': {'name': 'GTBank', 'code': '058', 'ussd': '*737#'},
			'access': {'name': 'Access Bank', 'code': '044', 'ussd': '*901#'},
			'zenith': {'name': 'Zenith Bank', 'code': '057', 'ussd': '*966#'},
			'uba': {'name': 'UBA', 'code': '033', 'ussd': '*919#'},
			'firstbank': {'name': 'First Bank', 'code': '011', 'ussd': '*894#'},
			'union': {'name': 'Union Bank', 'code': '032', 'ussd': '*826#'},
			'sterling': {'name': 'Sterling Bank', 'code': '232', 'ussd': '*822#'},
			'fidelity': {'name': 'Fidelity Bank', 'code': '070', 'ussd': '*770#'},
			'fcmb': {'name': 'FCMB', 'code': '214', 'ussd': '*329#'},
			'kuda': {'name': 'Kuda Bank', 'code': '50211', 'ussd': 'App only'},
			'opay': {'name': 'OPay', 'code': '999992', 'ussd': 'App only'},
			'palmpay': {'name': 'PalmPay', 'code': '999991', 'ussd': 'App only'},
		},
		'KE': { // Kenya
			'equity': {'name': 'Equity Bank', 'code': '68000', 'ussd': '*247#'},
			'kcb': {'name': 'KCB Bank', 'code': '01000', 'ussd': '*522#'},
			'coop': {'name': 'Co-operative Bank', 'code': '11000', 'ussd': '*667#'},
			'absa': {'name': 'Absa Bank Kenya', 'code': '03000', 'ussd': '*329#'},
			'standard': {'name': 'Standard Chartered', 'code': '02000', 'ussd': '*329#'},
			'dtb': {'name': 'Diamond Trust Bank', 'code': '63000', 'ussd': '*444#'},
		},
		'GH': { // Ghana
			'gcb': {'name': 'GCB Bank', 'code': 'GH001', 'ussd': '*422#'},
			'ecobank': {'name': 'Ecobank Ghana', 'code': 'GH002', 'ussd': '*326#'},
			'absa_gh': {'name': 'Absa Bank Ghana', 'code': 'GH003', 'ussd': '*329#'},
			'cal_bank': {'name': 'CAL Bank', 'code': 'GH004', 'ussd': '*588#'},
			'fidelity_gh': {'name': 'Fidelity Bank Ghana', 'code': 'GH005', 'ussd': '*770#'},
		},
		'ZA': { // South Africa
			'fnb': {'name': 'FNB', 'code': '250655', 'ussd': '*120*321#'},
			'absa_za': {'name': 'Absa', 'code': '632005', 'ussd': '*120*2272#'},
			'standard_za': {'name': 'Standard Bank', 'code': '051001', 'ussd': '*120*3279#'},
			'nedbank': {'name': 'Nedbank', 'code': '198765', 'ussd': '*120*321#'},
			'capitec': {'name': 'Capitec Bank', 'code': '470010', 'ussd': '*120*3279#'},
		},
		'US': { // United States
			'chase': {'name': 'Chase Bank', 'code': 'US_CHASE', 'routing': '021000021'},
			'bofa': {'name': 'Bank of America', 'code': 'US_BOFA', 'routing': '026009593'},
			'wells': {'name': 'Wells Fargo', 'code': 'US_WELLS', 'routing': '121000248'},
			'citi': {'name': 'Citibank', 'code': 'US_CITI', 'routing': '021000089'},
			'pnc': {'name': 'PNC Bank', 'code': 'US_PNC', 'routing': '043000096'},
		},
		'GB': { // United Kingdom
			'hsbc': {'name': 'HSBC UK', 'code': 'GB_HSBC', 'sort': '40-02-50'},
			'barclays': {'name': 'Barclays', 'code': 'GB_BARC', 'sort': '20-00-00'},
			'lloyds': {'name': 'Lloyds Bank', 'code': 'GB_LLOY', 'sort': '30-00-00'},
			'natwest': {'name': 'NatWest', 'code': 'GB_NATW', 'sort': '60-00-00'},
			'santander': {'name': 'Santander UK', 'code': 'GB_SANT', 'sort': '09-01-26'},
		},
		'CA': { // Canada
			'rbc': {'name': 'RBC', 'code': 'CA_RBC', 'transit': '00003'},
			'td': {'name': 'TD Canada Trust', 'code': 'CA_TD', 'transit': '00004'},
			'scotia': {'name': 'Scotiabank', 'code': 'CA_SCOT', 'transit': '00002'},
			'bmo': {'name': 'BMO', 'code': 'CA_BMO', 'transit': '00001'},
		},
	};

	@override
	void initState() {
		super.initState();
		_detectCountryAndLoadData();
	}

	Future<void> _detectCountryAndLoadData() async {
		try {
			final detectedCountry = await CountryDetectionService.detectUserCountry();
			final currencyInfo = CountryDetectionService.getCurrencyInfo(detectedCountry);
			
			setState(() {
				_detectedCountry = detectedCountry;
				_currencySymbol = currencyInfo['symbol']!;
				_currencyCode = currencyInfo['code']!;
				
				// Load banks for detected country
				_availableBanks = _globalBanks[detectedCountry] ?? _globalBanks['NG']!;
				
				// Set default bank
				if (_availableBanks.isNotEmpty) {
					_selectedBank = _availableBanks.keys.first;
				}
			});
			
			await _loadCurrentBalance();
		} catch (e) {
			print('Error detecting country: $e');
			// Fallback to Nigeria
			_availableBanks = _globalBanks['NG']!;
			await _loadCurrentBalance();
		}
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

	Future<void> _withdrawFunds() async {
		final amountText = _amountController.text.trim();
		final accountNumber = _accountNumberController.text.trim();
		final accountName = _accountNameController.text.trim();

		if (amountText.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please enter amount to withdraw'))
			);
			return;
		}

		if (accountNumber.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please enter account number'))
			);
			return;
		}

		if (accountName.isEmpty) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please enter account name'))
			);
			return;
		}

		final amount = double.tryParse(amountText);
		final minAmount = _currencyCode == 'USD' ? 5 : _currencyCode == 'GBP' ? 5 : _currencyCode == 'EUR' ? 5 : 100;
		if (amount == null || amount < minAmount) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Minimum withdrawal is $_currencySymbol$minAmount'))
			);
			return;
		}

		if (amount > _currentBalance) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Insufficient wallet balance'))
			);
			return;
		}

		if (amount > 500000) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Maximum withdrawal is ₦500,000 per transaction'))
			);
			return;
		}

		setState(() => _isProcessing = true);

		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) {
				throw Exception('Please sign in to withdraw funds');
			}

			await _processWithdrawal(uid, amount, accountNumber, accountName);

		} catch (e) {
			if (mounted) {
				ScaffoldMessenger.of(context).showSnackBar(
					SnackBar(content: Text('Withdrawal failed: $e'))
				);
			}
		} finally {
			if (mounted) setState(() => _isProcessing = false);
		}
	}

	Future<void> _processWithdrawal(String uid, double amount, String accountNumber, String accountName) async {
		try {
			// Deduct from wallet first
			await FirebaseFirestore.instance.collection('wallets').doc(uid).update({
				'balance': FieldValue.increment(-amount),
				'lastUpdated': DateTime.now().toIso8601String(),
			});

			// Create withdrawal request
			await FirebaseFirestore.instance.collection('withdrawal_requests').add({
				'userId': uid,
				'amount': amount,
				'currency': _currencyCode,
				'countryCode': _detectedCountry,
				'bankCode': _availableBanks[_selectedBank]!['code'],
				'bankName': _availableBanks[_selectedBank]!['name'],
				'accountNumber': accountNumber,
				'accountName': accountName,
				'status': 'processing',
				'createdAt': DateTime.now().toIso8601String(),
				'processingFee': amount * 0.01, // 1% withdrawal fee
				'netAmount': amount * 0.99, // Amount after fee
			});

			// Record transaction
			await FirebaseFirestore.instance.collection('wallet_transactions').add({
				'userId': uid,
				'type': 'debit',
				'amount': amount,
				'description': 'Withdrawal to ${_availableBanks[_selectedBank]!['name']} ($accountNumber)',
				'status': 'processing',
				'createdAt': DateTime.now().toIso8601String(),
			});

			// TODO: Integrate with Flutterwave Transfer API for actual bank transfer
			// For now, simulate processing
			if (mounted) {
				showDialog(
					context: context,
					barrierDismissible: false,
					builder: (_) => AlertDialog(
						title: const Text('✅ Withdrawal Initiated'),
						content: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								const Icon(Icons.check_circle, color: Colors.green, size: 64),
								const SizedBox(height: 16),
								Text('$_currencySymbol${amount.toStringAsFixed(2)} withdrawal request submitted'),
								const SizedBox(height: 8),
								Text('To: ${_availableBanks[_selectedBank]!['name']}'),
								Text('Account: $accountNumber'),
								Text('Name: $accountName'),
								const SizedBox(height: 12),
								Container(
									padding: const EdgeInsets.all(12),
									decoration: BoxDecoration(
										color: Colors.blue.shade50,
										borderRadius: BorderRadius.circular(8),
									),
									child: const Text(
										'⏱️ Processing time: 1-24 hours\n💰 Processing fee: 1%\n📱 You will receive SMS confirmation',
										style: TextStyle(color: Colors.black87, fontSize: 12),
									),
								),
							],
						),
						actions: [
							FilledButton(
								onPressed: () {
									Navigator.pop(context);
									context.pop();
								},
								child: const Text('Done'),
							),
						],
					),
				);
			}

			// Refresh balance
			_loadCurrentBalance();
			
			// Clear form
			_amountController.clear();
			_accountNumberController.clear();
			_accountNameController.clear();

		} catch (e) {
			// Refund wallet if withdrawal creation failed
			await FirebaseFirestore.instance.collection('wallets').doc(uid).update({
				'balance': FieldValue.increment(amount),
			});
			throw e;
		}
	}

	@override
	Widget build(BuildContext context) {
		if (_availableBanks.isEmpty) {
			return Scaffold(
				appBar: AppBar(
					title: Text('💸 Withdraw - ${CountryDetectionService.getCountryName(_detectedCountry)}'),
					backgroundColor: Colors.blue.shade50,
					iconTheme: const IconThemeData(color: Colors.black),
				),
				body: Container(
					color: Colors.white,
					child: Center(
						child: Column(
							mainAxisAlignment: MainAxisAlignment.center,
							children: [
								Icon(Icons.construction, size: 64, color: Colors.grey.shade400),
								const SizedBox(height: 16),
								Text(
									'Bank withdrawals not yet available in ${CountryDetectionService.getCountryName(_detectedCountry)}',
									style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
									textAlign: TextAlign.center,
								),
								const SizedBox(height: 8),
								const Text(
									'Coming soon! We\'re working to add bank transfer services for your country.',
									style: TextStyle(color: Colors.grey),
									textAlign: TextAlign.center,
								),
								const SizedBox(height: 24),
								OutlinedButton.icon(
									onPressed: () => context.push('/digital/country-selection'),
									icon: const Icon(Icons.public),
									label: const Text('Change Country'),
								),
							],
						),
					),
				),
			);
		}

		final selectedBankData = _availableBanks[_selectedBank]!;

		return Scaffold(
			appBar: AppBar(
				title: Text('💸 Withdraw - ${CountryDetectionService.getCountryName(_detectedCountry)}'),
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
							// Current balance card
							Card(
								elevation: 4,
								child: Container(
									decoration: BoxDecoration(
										gradient: const LinearGradient(
											colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
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
												'Available Balance',
												style: TextStyle(color: Colors.white70, fontSize: 16),
											),
											const SizedBox(height: 8),
											Text(
												'$_currencySymbol${_currentBalance.toStringAsFixed(2)}',
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

							// Bank selection
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Select Bank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											DropdownButtonFormField<String>(
												value: _selectedBank,
												decoration: const InputDecoration(
													border: OutlineInputBorder(),
													prefixIcon: Icon(Icons.account_balance, color: Colors.blue),
												),
												items: _availableBanks.entries.map((entry) {
													final bank = entry.value;
													return DropdownMenuItem(
														value: entry.key,
														child: Row(
															children: [
																Text(bank['name'], style: const TextStyle(color: Colors.black)),
																const Spacer(),
																Text(bank['ussd'] ?? bank['routing'] ?? bank['sort'] ?? '', style: const TextStyle(color: Colors.black54, fontSize: 12)),
															],
														),
													);
												}).toList(),
												onChanged: (value) => setState(() => _selectedBank = value!),
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Account details
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Account Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											
											TextField(
												controller: _accountNumberController,
												keyboardType: TextInputType.number,
												style: const TextStyle(color: Colors.black),
												decoration: const InputDecoration(
													labelText: 'Account Number',
													labelStyle: TextStyle(color: Colors.black),
													hintText: '1234567890',
													hintStyle: TextStyle(color: Colors.black38),
													prefixIcon: Icon(Icons.numbers, color: Colors.blue),
													border: OutlineInputBorder(),
												),
											),
											
											const SizedBox(height: 12),
											
											TextField(
												controller: _accountNameController,
												style: const TextStyle(color: Colors.black),
												decoration: const InputDecoration(
													labelText: 'Account Name',
													labelStyle: TextStyle(color: Colors.black),
													hintText: 'John Doe',
													hintStyle: TextStyle(color: Colors.black38),
													prefixIcon: Icon(Icons.person, color: Colors.blue),
													border: OutlineInputBorder(),
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
											const Text('Withdrawal Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											TextField(
												controller: _amountController,
												keyboardType: TextInputType.number,
												style: const TextStyle(color: Colors.black),
												decoration: InputDecoration(
													labelText: 'Enter amount',
													labelStyle: const TextStyle(color: Colors.black),
													hintText: 'Minimum $_currencySymbol${_currencyCode == 'USD' ? '5' : _currencyCode == 'GBP' ? '5' : _currencyCode == 'EUR' ? '5' : '100'}',
													hintStyle: const TextStyle(color: Colors.black38),
													prefixIcon: const Icon(Icons.attach_money, color: Colors.red),
													border: const OutlineInputBorder(),
													focusedBorder: const OutlineInputBorder(
														borderSide: BorderSide(color: Colors.red, width: 2),
													),
												),
											),
											const SizedBox(height: 8),
											Text(
												'Available: $_currencySymbol${_currentBalance.toStringAsFixed(2)}',
												style: const TextStyle(color: Colors.black54, fontSize: 12),
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Fee information
							Card(
								color: Colors.orange.shade50,
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Row(
												children: [
													const Icon(Icons.info, color: Colors.orange),
													const SizedBox(width: 8),
													const Text('Withdrawal Fees', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
												],
											),
											const SizedBox(height: 8),
											if (_amountController.text.isNotEmpty && double.tryParse(_amountController.text) != null) ...[
												const Text('Fee Breakdown:', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
												const SizedBox(height: 4),
																									Row(
														mainAxisAlignment: MainAxisAlignment.spaceBetween,
														children: [
															const Text('Withdrawal Amount:', style: TextStyle(color: Colors.black)),
															Text('$_currencySymbol${double.parse(_amountController.text).toStringAsFixed(2)}', style: const TextStyle(color: Colors.black)),
														],
													),
													Row(
														mainAxisAlignment: MainAxisAlignment.spaceBetween,
														children: [
															const Text('Processing Fee (1%):', style: TextStyle(color: Colors.black)),
															Text('-$_currencySymbol${(double.parse(_amountController.text) * 0.01).toStringAsFixed(2)}', style: const TextStyle(color: Colors.red)),
														],
													),
													const Divider(),
													Row(
														mainAxisAlignment: MainAxisAlignment.spaceBetween,
														children: [
															const Text('You will receive:', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
															Text('$_currencySymbol${(double.parse(_amountController.text) * 0.99).toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
														],
													),
											] else
												const Text(
													'• Processing fee: 1% of withdrawal amount\n• Minimum withdrawal: ₦100\n• Maximum withdrawal: ₦500,000 per transaction\n• Processing time: 1-24 hours',
													style: TextStyle(color: Colors.black87),
												),
										],
									),
								),
							),

							const SizedBox(height: 24),

							// Withdraw button
							SizedBox(
								height: 56,
								child: FilledButton.icon(
									onPressed: _isProcessing ? null : _withdrawFunds,
									icon: _isProcessing 
										? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
										: const Icon(Icons.send),
									label: Text(_isProcessing ? 'Processing...' : 'Withdraw Funds'),
									style: FilledButton.styleFrom(
										backgroundColor: Colors.red.shade600,
										textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
													const Text('Secure Withdrawals', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
												],
											),
											const SizedBox(height: 8),
											Text(
												'🔒 Bank transfers are secured and encrypted\n⏱️ Processing time: 1-24 hours\n📱 SMS confirmation when funds are sent\n🆔 Account name verification for security\n💰 Powered by Flutterwave transfer API',
												style: const TextStyle(color: Colors.black87),
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Bank info
							Card(
								color: Colors.blue.shade50,
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Row(
												children: [
													const Icon(Icons.account_balance, color: Colors.blue),
													const SizedBox(width: 8),
													Text('${selectedBankData['name']} Info', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
												],
											),
											const SizedBox(height: 8),
											Text(
												'Bank Code: ${selectedBankData['code']}\n${selectedBankData['ussd'] != null ? 'USSD: ${selectedBankData['ussd']}' : selectedBankData['routing'] != null ? 'Routing: ${selectedBankData['routing']}' : selectedBankData['sort'] != null ? 'Sort Code: ${selectedBankData['sort']}' : ''}\n\n💡 Ensure your account name matches exactly as registered with the bank.',
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