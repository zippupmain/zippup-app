import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/payments/payments_service.dart';
import 'package:zippup/services/location/country_detection_service.dart';

class GlobalBillsScreen extends StatefulWidget {
	const GlobalBillsScreen({super.key});

	@override
	State<GlobalBillsScreen> createState() => _GlobalBillsScreenState();
}

class _GlobalBillsScreenState extends State<GlobalBillsScreen> {
	final TextEditingController _accountController = TextEditingController();
	final TextEditingController _amountController = TextEditingController();
	String _detectedCountry = 'NG';
	String _currencySymbol = '₦';
	String _currencyCode = 'NGN';
	String _selectedBillType = 'electricity';
	String _selectedProvider = 'phcn';
	String _paymentMethod = 'wallet';
	bool _isProcessing = false;
	double _walletBalance = 0.0;

	// Global bill types by country
	final Map<String, Map<String, Map<String, dynamic>>> _globalBillTypes = {
		'NG': { // Nigeria
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
		},
		'KE': { // Kenya
			'electricity': {
				'name': 'Electricity',
				'icon': Icons.electric_bolt,
				'emoji': '💡',
				'color': Colors.yellow,
				'providers': {
					'kplc': {'name': 'KPLC', 'code': 'KE_KPLC'},
				},
			},
			'water': {
				'name': 'Water',
				'icon': Icons.water_drop,
				'emoji': '💧',
				'color': Colors.cyan,
				'providers': {
					'nairobi_water': {'name': 'Nairobi Water', 'code': 'KE_WATER'},
				},
			},
		},
		'US': { // United States
			'utilities': {
				'name': 'Utilities',
				'icon': Icons.electric_bolt,
				'emoji': '💡',
				'color': Colors.blue,
				'providers': {
					'pge': {'name': 'PG&E', 'code': 'US_PGE'},
					'con_edison': {'name': 'Con Edison', 'code': 'US_CONED'},
				},
			},
		},
		'GB': { // United Kingdom
			'utilities': {
				'name': 'Utilities',
				'icon': Icons.electric_bolt,
				'emoji': '💡',
				'color': Colors.blue,
				'providers': {
					'british_gas': {'name': 'British Gas', 'code': 'UK_BG'},
					'edf': {'name': 'EDF Energy', 'code': 'UK_EDF'},
				},
			},
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
				
				// Set default bill type and provider for detected country
				final countryBills = _globalBillTypes[detectedCountry];
				if (countryBills != null && countryBills.isNotEmpty) {
					_selectedBillType = countryBills.keys.first;
					final providers = countryBills[_selectedBillType]!['providers'] as Map<String, dynamic>;
					_selectedProvider = providers.keys.first;
				}
			});
			
			await _loadWalletBalance();
		} catch (e) {
			print('Error detecting country: $e');
			await _loadWalletBalance();
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

	@override
	Widget build(BuildContext context) {
		final countryBills = _globalBillTypes[_detectedCountry];
		
		if (countryBills == null || countryBills.isEmpty) {
			return Scaffold(
				appBar: AppBar(
					title: Text('💡 Bills - $_detectedCountry'),
					backgroundColor: Colors.orange.shade50,
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
									'Bill payments not yet available in ${CountryDetectionService.getCountryName(_detectedCountry)}',
									style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
									textAlign: TextAlign.center,
								),
								const SizedBox(height: 8),
								const Text(
									'Coming soon! We\'re working to add bill payment services for your country.',
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

		final billTypeData = countryBills[_selectedBillType]!;
		final providers = billTypeData['providers'] as Map<String, dynamic>;

		return Scaffold(
			appBar: AppBar(
				title: Text('💡 Bills - ${CountryDetectionService.getCountryName(_detectedCountry)}'),
				backgroundColor: Colors.orange.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
				actions: [
					IconButton(
						onPressed: () => context.push('/digital/country-selection'),
						icon: const Icon(Icons.public, color: Colors.black),
						tooltip: 'Change Country',
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
															'${countryBills.length} bill types available',
															style: const TextStyle(color: Colors.black54),
														),
													],
												),
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
												children: countryBills.keys.map((billType) {
													final data = countryBills[billType]!;
													final isSelected = billType == _selectedBillType;
													return GestureDetector(
														onTap: () {
															setState(() {
																_selectedBillType = billType;
																final newProviders = data['providers'] as Map<String, dynamic>;
																_selectedProvider = newProviders.keys.first;
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

							// Info card for unsupported countries
							if (_detectedCountry != 'NG')
								Card(
									color: Colors.amber.shade50,
									child: Padding(
										padding: const EdgeInsets.all(16),
										child: Column(
											children: [
												Row(
													children: [
														const Icon(Icons.info, color: Colors.amber),
														const SizedBox(width: 8),
														const Text('Limited Availability', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
													],
												),
												const SizedBox(height: 8),
												Text(
													'Bill payment services are currently limited in ${CountryDetectionService.getCountryName(_detectedCountry)}. We\'re working to add more providers for your country.',
													style: const TextStyle(color: Colors.black87),
												),
											],
										),
									),
								),

							const SizedBox(height: 24),

							// Coming soon message for non-Nigerian users
							if (_detectedCountry != 'NG')
								Container(
									padding: const EdgeInsets.all(24),
									decoration: BoxDecoration(
										color: Colors.blue.shade50,
										borderRadius: BorderRadius.circular(12),
										border: Border.all(color: Colors.blue.shade200),
									),
									child: Column(
										children: [
											Icon(Icons.construction, size: 48, color: Colors.blue.shade600),
											const SizedBox(height: 16),
											Text(
												'Bill Payments Coming Soon!',
												style: TextStyle(
													fontSize: 20,
													fontWeight: FontWeight.bold,
													color: Colors.blue.shade700,
												),
											),
											const SizedBox(height: 8),
											Text(
												'We\'re working to add bill payment services for ${CountryDetectionService.getCountryName(_detectedCountry)}. Meanwhile, you can use our other digital services:',
												style: const TextStyle(color: Colors.black87),
												textAlign: TextAlign.center,
											),
											const SizedBox(height: 16),
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
												],
											),
										],
									),
								),
						],
					),
				),
			),
		);
	}
}