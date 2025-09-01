import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/location/country_detection_service.dart';

class DigitalProviderDashboardScreen extends StatefulWidget {
	const DigitalProviderDashboardScreen({super.key});

	@override
	State<DigitalProviderDashboardScreen> createState() => _DigitalProviderDashboardScreenState();
}

class _DigitalProviderDashboardScreenState extends State<DigitalProviderDashboardScreen> {
	String _detectedCountry = 'NG';
	String _currencySymbol = '₦';
	String _currencyCode = 'NGN';
	double _totalEarnings = 0.0;
	double _todayEarnings = 0.0;
	int _totalTransactions = 0;
	int _todayTransactions = 0;
	bool _isOnline = true;

	@override
	void initState() {
		super.initState();
		_loadDashboardData();
	}

	Future<void> _loadDashboardData() async {
		try {
			final detectedCountry = await CountryDetectionService.detectUserCountry();
			final currencyInfo = CountryDetectionService.getCurrencyInfo(detectedCountry);
			
			setState(() {
				_detectedCountry = detectedCountry;
				_currencySymbol = currencyInfo['symbol']!;
				_currencyCode = currencyInfo['code']!;
			});

			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid != null) {
				// Load earnings and transaction stats
				await _loadEarningsData(uid);
			}
		} catch (e) {
			print('Error loading dashboard data: $e');
		}
	}

	Future<void> _loadEarningsData(String uid) async {
		try {
			// Load total earnings from digital services
			final earningsQuery = await FirebaseFirestore.instance
				.collection('digital_earnings')
				.where('providerId', isEqualTo: uid)
				.get();

			double totalEarnings = 0.0;
			int totalTransactions = earningsQuery.docs.length;

			for (final doc in earningsQuery.docs) {
				final data = doc.data();
				totalEarnings += (data['amount'] ?? 0.0).toDouble();
			}

			// Load today's earnings
			final today = DateTime.now();
			final todayStart = DateTime(today.year, today.month, today.day).toIso8601String();
			final todayQuery = await FirebaseFirestore.instance
				.collection('digital_earnings')
				.where('providerId', isEqualTo: uid)
				.where('createdAt', isGreaterThanOrEqualTo: todayStart)
				.get();

			double todayEarnings = 0.0;
			int todayTransactions = todayQuery.docs.length;

			for (final doc in todayQuery.docs) {
				final data = doc.data();
				todayEarnings += (data['amount'] ?? 0.0).toDouble();
			}

			setState(() {
				_totalEarnings = totalEarnings;
				_todayEarnings = todayEarnings;
				_totalTransactions = totalTransactions;
				_todayTransactions = todayTransactions;
			});
		} catch (e) {
			print('Error loading earnings data: $e');
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: Text('📱 Digital Services - ${CountryDetectionService.getCountryName(_detectedCountry)}'),
				backgroundColor: Colors.green.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
				actions: [
					Switch(
						value: _isOnline,
						onChanged: (value) {
							setState(() => _isOnline = value);
							// TODO: Update provider status in Firestore
						},
					),
					const SizedBox(width: 8),
				],
			),
			body: Container(
				color: Colors.white,
				child: SingleChildScrollView(
					padding: const EdgeInsets.all(16),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							// Status card
							Card(
								color: _isOnline ? Colors.green.shade50 : Colors.red.shade50,
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Row(
										children: [
											Icon(
												_isOnline ? Icons.online_prediction : Icons.offline_bolt,
												color: _isOnline ? Colors.green : Colors.red,
												size: 32,
											),
											const SizedBox(width: 12),
											Expanded(
												child: Column(
													crossAxisAlignment: CrossAxisAlignment.start,
													children: [
														Text(
															_isOnline ? 'Digital Services Online' : 'Digital Services Offline',
															style: TextStyle(
																fontWeight: FontWeight.bold,
																fontSize: 16,
																color: _isOnline ? Colors.green.shade700 : Colors.red.shade700,
															),
														),
														Text(
															_isOnline 
																? 'Ready to process airtime, data, and bill payments'
																: 'Not receiving digital service requests',
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

							// Earnings overview
							Row(
								children: [
									Expanded(
										child: Card(
											child: Padding(
												padding: const EdgeInsets.all(16),
												child: Column(
													children: [
														Icon(Icons.today, color: Colors.blue.shade600, size: 32),
														const SizedBox(height: 8),
														Text(
															'$_currencySymbol${_todayEarnings.toStringAsFixed(2)}',
															style: TextStyle(
																fontSize: 24,
																fontWeight: FontWeight.bold,
																color: Colors.blue.shade700,
															),
														),
														const Text('Today\'s Earnings', style: TextStyle(color: Colors.black54)),
														Text('$_todayTransactions transactions', style: const TextStyle(color: Colors.black38, fontSize: 12)),
													],
												),
											),
										),
									),
									const SizedBox(width: 12),
									Expanded(
										child: Card(
											child: Padding(
												padding: const EdgeInsets.all(16),
												child: Column(
													children: [
														Icon(Icons.account_balance_wallet, color: Colors.green.shade600, size: 32),
														const SizedBox(height: 8),
														Text(
															'$_currencySymbol${_totalEarnings.toStringAsFixed(2)}',
															style: TextStyle(
																fontSize: 24,
																fontWeight: FontWeight.bold,
																color: Colors.green.shade700,
															),
														),
														const Text('Total Earnings', style: TextStyle(color: Colors.black54)),
														Text('$_totalTransactions transactions', style: const TextStyle(color: Colors.black38, fontSize: 12)),
													],
												),
											),
										),
									),
								],
							),

							const SizedBox(height: 16),

							// Digital services management
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											const Text('Digital Services Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
											const SizedBox(height: 16),
											
											ListTile(
												leading: const Icon(Icons.phone, color: Colors.blue),
												title: const Text('Airtime Sales'),
												subtitle: const Text('Manage airtime commissions and rates'),
												trailing: const Icon(Icons.arrow_forward_ios),
												onTap: () {
													ScaffoldMessenger.of(context).showSnackBar(
														const SnackBar(content: Text('Airtime management coming soon!'))
													);
												},
											),
											
											const Divider(),
											
											ListTile(
												leading: const Icon(Icons.network_cell, color: Colors.purple),
												title: const Text('Data Bundle Sales'),
												subtitle: const Text('Manage data bundle commissions'),
												trailing: const Icon(Icons.arrow_forward_ios),
												onTap: () {
													ScaffoldMessenger.of(context).showSnackBar(
														const SnackBar(content: Text('Data management coming soon!'))
													);
												},
											),
											
											const Divider(),
											
											ListTile(
												leading: const Icon(Icons.receipt_long, color: Colors.orange),
												title: const Text('Bill Payment Services'),
												subtitle: const Text('Manage utility bill commissions'),
												trailing: const Icon(Icons.arrow_forward_ios),
												onTap: () {
													ScaffoldMessenger.of(context).showSnackBar(
														const SnackBar(content: Text('Bill management coming soon!'))
													);
												},
											),
											
											const Divider(),
											
											ListTile(
												leading: const Icon(Icons.shopping_bag, color: Colors.indigo),
												title: const Text('Digital Products'),
												subtitle: const Text('Manage software and subscription sales'),
												trailing: const Icon(Icons.arrow_forward_ios),
												onTap: () {
													ScaffoldMessenger.of(context).showSnackBar(
														const SnackBar(content: Text('Digital products management coming soon!'))
													);
												},
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Recent transactions
							Card(
								child: Padding(
									padding: const EdgeInsets.all(16),
									child: Column(
										crossAxisAlignment: CrossAxisAlignment.start,
										children: [
											Row(
												children: [
													const Icon(Icons.history, color: Colors.grey),
													const SizedBox(width: 8),
													const Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
													const Spacer(),
													TextButton(
														onPressed: () {
															ScaffoldMessenger.of(context).showSnackBar(
																const SnackBar(content: Text('Full transaction history coming soon!'))
															);
														},
														child: const Text('View All'),
													),
												],
											),
											const SizedBox(height: 12),
											
											// Sample transaction (in production, load from Firestore)
											const ListTile(
												leading: CircleAvatar(
													backgroundColor: Colors.green,
													child: Icon(Icons.phone, color: Colors.white),
												),
												title: Text('Airtime Sale'),
												subtitle: Text('MTN ₦1,000 • Commission: ₦50'),
												trailing: Text('₦50', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
											),
											
											const Divider(),
											
											const Center(
												child: Padding(
													padding: EdgeInsets.all(16),
													child: Text(
														'Digital services transactions will appear here when you start processing payments.',
														style: TextStyle(color: Colors.grey),
														textAlign: TextAlign.center,
													),
												),
											),
										],
									),
								),
							),

							const SizedBox(height: 16),

							// Commission info
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
													const Text('Commission Structure', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
												],
											),
											const SizedBox(height: 8),
											const Text(
												'📞 Airtime Sales: 2-5% commission\n📶 Data Bundles: 3-7% commission\n💡 Bill Payments: 1-3% commission\n💻 Digital Products: 10-20% commission\n\n💰 Payments processed instantly\n📊 Real-time earnings tracking',
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