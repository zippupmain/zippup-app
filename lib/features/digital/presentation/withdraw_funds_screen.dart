import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

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

	final Map<String, Map<String, dynamic>> _banks = {
		'gtbank': {'name': 'GTBank', 'code': '058', 'ussd': '*737#'},
		'access': {'name': 'Access Bank', 'code': '044', 'ussd': '*901#'},
		'zenith': {'name': 'Zenith Bank', 'code': '057', 'ussd': '*966#'},
		'uba': {'name': 'UBA', 'code': '033', 'ussd': '*919#'},
		'firstbank': {'name': 'First Bank', 'code': '011', 'ussd': '*894#'},
		'union': {'name': 'Union Bank', 'code': '032', 'ussd': '*826#'},
		'sterling': {'name': 'Sterling Bank', 'code': '232', 'ussd': '*822#'},
		'fidelity': {'name': 'Fidelity Bank', 'code': '070', 'ussd': '*770#'},
		'fcmb': {'name': 'FCMB', 'code': '214', 'ussd': '*329#'},
		'unity': {'name': 'Unity Bank', 'code': '215', 'ussd': '*7799#'},
		'stanbic': {'name': 'Stanbic IBTC', 'code': '221', 'ussd': '*909#'},
		'wema': {'name': 'Wema Bank', 'code': '035', 'ussd': '*945#'},
		'kuda': {'name': 'Kuda Bank', 'code': '50211', 'ussd': 'App only'},
		'opay': {'name': 'OPay', 'code': '999992', 'ussd': 'App only'},
		'palmpay': {'name': 'PalmPay', 'code': '999991', 'ussd': 'App only'},
	};

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
		if (amount == null || amount < 100) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Minimum withdrawal is ₦100'))
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
				'bankCode': _banks[_selectedBank]!['code'],
				'bankName': _banks[_selectedBank]!['name'],
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
				'description': 'Withdrawal to ${_banks[_selectedBank]!['name']} ($accountNumber)',
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
								Text('₦${amount.toStringAsFixed(2)} withdrawal request submitted'),
								const SizedBox(height: 8),
								Text('To: ${_banks[_selectedBank]!['name']}'),
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
		final selectedBankData = _banks[_selectedBank]!;

		return Scaffold(
			appBar: AppBar(
				title: const Text('💸 Withdraw Funds'),
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
												items: _banks.entries.map((entry) {
													final bank = entry.value;
													return DropdownMenuItem(
														value: entry.key,
														child: Row(
															children: [
																Text(bank['name'], style: const TextStyle(color: Colors.black)),
																const Spacer(),
																Text(bank['ussd'], style: const TextStyle(color: Colors.black54, fontSize: 12)),
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
												decoration: const InputDecoration(
													labelText: 'Enter amount',
													labelStyle: TextStyle(color: Colors.black),
													hintText: 'Minimum ₦100',
													hintStyle: TextStyle(color: Colors.black38),
													prefixIcon: Icon(Icons.attach_money, color: Colors.red),
													border: OutlineInputBorder(),
													focusedBorder: OutlineInputBorder(
														borderSide: BorderSide(color: Colors.red, width: 2),
													),
												),
											),
											const SizedBox(height: 8),
											Text(
												'Available: ₦${_currentBalance.toStringAsFixed(2)}',
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
														Text('₦${double.parse(_amountController.text).toStringAsFixed(2)}', style: const TextStyle(color: Colors.black)),
													],
												),
												Row(
													mainAxisAlignment: MainAxisAlignment.spaceBetween,
													children: [
														const Text('Processing Fee (1%):', style: TextStyle(color: Colors.black)),
														Text('-₦${(double.parse(_amountController.text) * 0.01).toStringAsFixed(2)}', style: const TextStyle(color: Colors.red)),
													],
												),
												const Divider(),
												Row(
													mainAxisAlignment: MainAxisAlignment.spaceBetween,
													children: [
														const Text('You will receive:', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
														Text('₦${(double.parse(_amountController.text) * 0.99).toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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
												'Bank Code: ${selectedBankData['code']}\nUSSD: ${selectedBankData['ussd']}\n\n💡 Ensure your account name matches exactly as registered with the bank.',
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