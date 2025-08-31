import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/payments/payments_service.dart';
import 'package:zippup/services/location/country_detection_service.dart';

class WalletScreen extends StatefulWidget {
	const WalletScreen({super.key});

	@override
	State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
	double _walletBalance = 0.0;
	bool _isLoading = true;
	List<Map<String, dynamic>> _recentTransactions = [];
	String _currentCountry = 'NG';
	String _currencySymbol = '₦';
	String _currencyCode = 'NGN';

	@override
	void initState() {
		super.initState();
		_detectCountryAndLoadWallet();
	}

	Future<void> _detectCountryAndLoadWallet() async {
		try {
			final detectedCountry = await CountryDetectionService.detectUserCountry();
			final currencyInfo = CountryDetectionService.getCurrencyInfo(detectedCountry);
			
			setState(() {
				_currentCountry = detectedCountry;
				_currencySymbol = currencyInfo['symbol']!;
				_currencyCode = currencyInfo['code']!;
			});
			
			await _loadWalletData();
		} catch (e) {
			print('Error detecting country: $e');
			await _loadWalletData();
		}
	}

	Future<void> _loadWalletData() async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid != null) {
				// Load wallet balance
				final walletDoc = await FirebaseFirestore.instance
					.collection('wallets')
					.doc(uid)
					.get();
				
				if (walletDoc.exists) {
					final data = walletDoc.data()!;
					setState(() {
						_walletBalance = (data['balance'] ?? 0.0).toDouble();
					});
				} else {
					// Create wallet if doesn't exist
					await FirebaseFirestore.instance.collection('wallets').doc(uid).set({
						'balance': 0.0,
						'createdAt': DateTime.now().toIso8601String(),
						'lastUpdated': DateTime.now().toIso8601String(),
					});
				}

				// Load recent transactions
				final transactionsQuery = await FirebaseFirestore.instance
					.collection('wallet_transactions')
					.where('userId', isEqualTo: uid)
					.orderBy('createdAt', descending: true)
					.limit(10)
					.get();

				setState(() {
					_recentTransactions = transactionsQuery.docs.map((doc) => {
						'id': doc.id,
						...doc.data(),
					}).toList();
				});
			}
		} catch (e) {
			print('Error loading wallet data: $e');
		} finally {
			setState(() => _isLoading = false);
		}
	}

	Future<void> _addFunds(double amount) async {
		try {
			final paymentsService = PaymentsService();
			final checkoutUrl = await paymentsService.createFlutterwaveCheckout(
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

			// TODO: Open checkout URL in webview
			// For now, show URL
			if (mounted) {
				showDialog(
					context: context,
					builder: (_) => AlertDialog(
						title: const Text('Add Funds to Wallet'),
						content: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								Text('Add ₦${amount.toStringAsFixed(0)} to your wallet:'),
								const SizedBox(height: 12),
								SelectableText(
									checkoutUrl,
									style: const TextStyle(color: Colors.blue),
								),
								const SizedBox(height: 12),
								const Text(
									'After payment, your wallet will be credited automatically.',
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
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Failed to initiate payment: $e'))
			);
		}
	}

	void _showAddFundsDialog() {
		final amounts = [500.0, 1000.0, 2000.0, 5000.0, 10000.0];
		
		showDialog(
			context: context,
			builder: (_) => AlertDialog(
				title: const Text('Add Funds'),
				content: Column(
					mainAxisSize: MainAxisSize.min,
					children: [
						const Text('Select amount to add to your wallet:'),
						const SizedBox(height: 16),
						Wrap(
							spacing: 8,
							runSpacing: 8,
							children: amounts.map((amount) => OutlinedButton(
								onPressed: () {
									Navigator.pop(context);
									_addFunds(amount);
								},
								child: Text('₦${amount.toStringAsFixed(0)}'),
							)).toList(),
						),
					],
				),
				actions: [
					TextButton(
						onPressed: () => Navigator.pop(context),
						child: const Text('Cancel'),
					),
				],
			),
		);
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
				title: Text('💳 My Wallet - $_currentCountry'),
				backgroundColor: Colors.green.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
				actions: [
					IconButton(
						onPressed: _loadWalletData,
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
							// Wallet balance card
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

							// Quick actions
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

							// Digital services quick access
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Quick Services', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											Row(
												children: [
													Expanded(
														child: OutlinedButton.icon(
															onPressed: () => context.push('/digital/airtime'),
															icon: const Icon(Icons.phone, color: Colors.blue),
															label: const Text('Airtime', style: TextStyle(color: Colors.blue)),
														),
													),
													const SizedBox(width: 8),
													Expanded(
														child: OutlinedButton.icon(
															onPressed: () => context.push('/digital/data'),
															icon: const Icon(Icons.network_cell, color: Colors.purple),
															label: const Text('Data', style: TextStyle(color: Colors.purple)),
														),
													),
													const SizedBox(width: 8),
													Expanded(
														child: OutlinedButton.icon(
															onPressed: () => context.push('/digital/bills'),
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

							// Recent transactions
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 12),
											
											if (_recentTransactions.isEmpty) 
												const Center(
													child: Padding(
														padding: EdgeInsets.all(32),
														child: Column(
															children: [
																Icon(Icons.history, size: 48, color: Colors.grey),
																SizedBox(height: 8),
																Text('No transactions yet', style: TextStyle(color: Colors.grey)),
															],
														),
													),
												)
											else
												ListView.separated(
													shrinkWrap: true,
													physics: const NeverScrollableScrollPhysics(),
													itemCount: _recentTransactions.length,
													separatorBuilder: (context, index) => const Divider(height: 1),
													itemBuilder: (context, index) {
														final transaction = _recentTransactions[index];
														final isCredit = transaction['type'] == 'credit';
														final amount = (transaction['amount'] ?? 0.0).toDouble();
														
														return ListTile(
															leading: CircleAvatar(
																backgroundColor: isCredit ? Colors.green.shade100 : Colors.red.shade100,
																child: Icon(
																	isCredit ? Icons.add : Icons.remove,
																	color: isCredit ? Colors.green : Colors.red,
																),
															),
															title: Text(
																transaction['description'] ?? 'Transaction',
																style: const TextStyle(color: Colors.black),
															),
															subtitle: Text(
																transaction['createdAt'] ?? '',
																style: const TextStyle(color: Colors.black54),
															),
															trailing: Text(
																'${isCredit ? '+' : '-'}₦${amount.toStringAsFixed(2)}',
																style: TextStyle(
																	color: isCredit ? Colors.green : Colors.red,
																	fontWeight: FontWeight.bold,
																),
															),
														);
													},
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