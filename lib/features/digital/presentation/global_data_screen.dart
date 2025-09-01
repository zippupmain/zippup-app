import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/digital/reloadly_service.dart';
import 'package:zippup/services/payments/payments_service.dart';
import 'package:zippup/services/location/country_detection_service.dart';

class GlobalDataScreen extends StatefulWidget {
	const GlobalDataScreen({super.key});

	@override
	State<GlobalDataScreen> createState() => _GlobalDataScreenState();
}

class _GlobalDataScreenState extends State<GlobalDataScreen> {
	final TextEditingController _phoneController = TextEditingController();
	
	String _detectedCountry = 'NG';
	String _currencySymbol = '₦';
	String _currencyCode = 'NGN';
	List<Map<String, dynamic>> _operators = [];
	List<Map<String, dynamic>> _dataBundles = [];
	Map<String, dynamic>? _selectedOperator;
	Map<String, dynamic>? _selectedBundle;
	String _paymentMethod = 'wallet';
	bool _isProcessing = false;
	bool _isLoadingOperators = false;
	bool _isLoadingBundles = false;
	bool _isLoading = false;
	double _walletBalance = 0.0;

	@override
	void initState() {
		super.initState();
		_detectCountryAndLoadData();
		_phoneController.addListener(_onPhoneNumberChanged);
	}

	@override
	void dispose() {
		_phoneController.removeListener(_onPhoneNumberChanged);
		super.dispose();
	}

	Future<void> _detectCountryAndLoadData() async {
		setState(() => _isLoading = true);
		
		try {
			final detectedCountry = await CountryDetectionService.detectUserCountry();
			final currencyInfo = CountryDetectionService.getCurrencyInfo(detectedCountry);
			
			setState(() {
				_detectedCountry = detectedCountry;
				_currencySymbol = currencyInfo['symbol']!;
				_currencyCode = currencyInfo['code']!;
			});
			
			await _loadWalletBalance();
			await _loadOperators();
		} catch (e) {
			print('Error detecting country: $e');
			await _loadWalletBalance();
		} finally {
			setState(() => _isLoading = false);
		}
	}

	void _onPhoneNumberChanged() {
		final phoneNumber = _phoneController.text.trim();
		if (phoneNumber.length >= 3) {
			final detectedCountry = ReloadlyService.getCountryCodeFromPhone(phoneNumber);
			if (detectedCountry != _detectedCountry) {
				setState(() {
					_detectedCountry = detectedCountry;
					final currencyInfo = CountryDetectionService.getCurrencyInfo(detectedCountry);
					_currencySymbol = currencyInfo['symbol']!;
					_currencyCode = currencyInfo['code']!;
					_operators = [];
					_selectedOperator = null;
					_dataBundles = [];
					_selectedBundle = null;
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
					_loadDataBundles();
				}
			});
		} catch (e) {
			print('Error loading operators: $e');
		} finally {
			setState(() => _isLoadingOperators = false);
		}
	}

	Future<void> _loadDataBundles() async {
		if (_selectedOperator == null) return;
		
		setState(() => _isLoadingBundles = true);
		
		try {
			final bundles = await ReloadlyService.getDataBundles(_selectedOperator!['id']);
			setState(() {
				_dataBundles = bundles;
				if (bundles.isNotEmpty) {
					_selectedBundle = bundles.first;
				}
			});
		} catch (e) {
			print('Error loading data bundles: $e');
		} finally {
			setState(() => _isLoadingBundles = false);
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

		if (_selectedOperator == null || _selectedBundle == null) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Please select operator and data bundle'))
			);
			return;
		}

		final amount = (_selectedBundle!['price'] ?? 0.0).toDouble();

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

			// Purchase data via Reloadly
			final result = await ReloadlyService.purchaseDataBundle(
				phoneNumber: phoneNumber,
				bundleId: _selectedBundle!['id'],
				operatorId: _selectedOperator!['id'],
				countryCode: _detectedCountry,
			);

			// Record transaction
			await FirebaseFirestore.instance.collection('data_purchases').add({
				'userId': uid,
				'phoneNumber': phoneNumber,
				'operatorId': _selectedOperator!['id'],
				'operatorName': _selectedOperator!['name'],
				'bundleId': _selectedBundle!['id'],
				'bundleName': _selectedBundle!['name'],
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
						content: Text('✅ ${_selectedBundle!['name']} sent to $phoneNumber'),
						backgroundColor: Colors.green,
					)
				);
				_loadWalletBalance();
				_phoneController.clear();
			}
		} catch (e) {
			// Refund wallet if data purchase failed
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
						'title': '${_selectedOperator!['name']} ${_selectedBundle!['name']}',
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
								Text('Complete payment for ${_selectedBundle!['name']}:'),
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
		if (_isLoading) {
			return const Scaffold(
				body: Center(child: CircularProgressIndicator()),
			);
		}

		return Scaffold(
			appBar: AppBar(
				title: Text('💳 My Wallet - $_detectedCountry'),
				backgroundColor: Colors.green.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
				actions: [
					IconButton(
						onPressed: () => context.push('/digital/country-selection'),
						icon: const Icon(Icons.public, color: Colors.black),
						tooltip: 'Change Country',
					),
					IconButton(
						onPressed: _detectCountryAndLoadData,
						icon: const Icon(Icons.refresh, color: Colors.black),
						tooltip: 'Refresh',
					),
				],
			),
			body: Container(
				color: Colors.white,
				child: SingleChildScrollView(
					padding: const EdgeInsets.all(16),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							// Country info card
							Card(
								color: Colors.blue.shade50,
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Row(
										children: [
											Text(
												CountryDetectionService.getCountryFlag(_detectedCountry),
												style: const TextStyle(fontSize: 32),
											),
											const SizedBox(width: 12),
											Expanded(
												child: Column(
													crossAxisAlignment: CrossAxisAlignment.start,
													children: [
														Text(
															CountryDetectionService.getCountryName(_detectedCountry),
															style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
														),
														Text(
															'Currency: $_currencyCode ($_currencySymbol)',
															style: const TextStyle(color: Colors.black54),
														),
													],
												),
											),
											OutlinedButton(
												onPressed: () => context.push('/digital/country-selection'),
												child: const Text('Change'),
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Wallet balance card (existing)
							Card(
								elevation: 8,
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
												'Wallet Balance',
												style: TextStyle(color: Colors.white70, fontSize: 16),
											),
											const SizedBox(height: 8),
											Text(
												'$_currencySymbol${_walletBalance.toStringAsFixed(2)}',
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

							const SizedBox(height: 20),

							// Quick actions (existing but updated routes)
							Row(
								children: [
									Expanded(
										child: Card(
											child: InkWell(
												onTap: () => context.push('/wallet/add-funds'),
												borderRadius: BorderRadius.circular(12),
												child: const Padding(
													padding: EdgeInsets.all(16),
													child: Column(
														children: [
															Icon(Icons.add_circle, color: Colors.green, size: 32),
															SizedBox(height: 8),
															Text('Add Funds', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
														],
													),
												),
											),
										),
									),
									const SizedBox(width: 12),
									Expanded(
										child: Card(
											child: InkWell(
												onTap: () => context.push('/wallet/withdraw'),
												borderRadius: BorderRadius.circular(12),
												child: const Padding(
													padding: EdgeInsets.all(16),
													child: Column(
														children: [
															Icon(Icons.remove_circle, color: Colors.blue, size: 32),
															SizedBox(height: 8),
															Text('Withdraw', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
														],
													),
												),
											),
										),
									),
								],
							),

							const SizedBox(height: 20),

							// Global digital services quick access
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Row(
												children: [
													const Icon(Icons.public, color: Colors.blue),
													const SizedBox(width: 8),
													Text('Global Services - $_detectedCountry', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
												],
											),
											const SizedBox(height: 12),
											Row(
												children: [
													Expanded(
														child: OutlinedButton.icon(
															onPressed: () => context.push('/digital/global-airtime'),
															icon: const Icon(Icons.phone, color: Colors.blue),
															label: const Text('Airtime', style: TextStyle(color: Colors.blue)),
														),
													),
													const SizedBox(width: 8),
													Expanded(
														child: OutlinedButton.icon(
															onPressed: () => context.push('/digital/global-data'),
															icon: const Icon(Icons.network_cell, color: Colors.purple),
															label: const Text('Data', style: TextStyle(color: Colors.purple)),
														),
													),
													const SizedBox(width: 8),
													Expanded(
														child: OutlinedButton.icon(
															onPressed: () => context.push('/digital/global-bills'),
															icon: const Icon(Icons.receipt_long, color: Colors.orange),
															label: const Text('Bills', style: TextStyle(color: Colors.orange)),
														),
													),
												],
											),
										],
									),
								),
							),

							const SizedBox(height: 20),

							// Info card for global data
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
													const Text('Global Data Bundles', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
												],
											),
											const SizedBox(height: 8),
											const Text(
												'🌍 Works in 150+ countries worldwide\n📶 Real data bundles from local operators\n💰 Local currency and pricing\n⚡ Instant delivery via Reloadly network',
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