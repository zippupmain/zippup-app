import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/services/location/country_detection_service.dart';

class DigitalProductsScreen extends StatefulWidget {
	const DigitalProductsScreen({super.key});

	@override
	State<DigitalProductsScreen> createState() => _DigitalProductsScreenState();
}

class _DigitalProductsScreenState extends State<DigitalProductsScreen> {
	String _detectedCountry = 'NG';
	String _currencySymbol = '₦';
	String _currencyCode = 'NGN';
	String _selectedCategory = 'software';

	final Map<String, List<Map<String, dynamic>>> _digitalProducts = {
		'software': [
			{
				'name': 'Microsoft Office 365',
				'description': '1-year subscription for Word, Excel, PowerPoint',
				'price': 45000,
				'duration': '12 months',
				'icon': Icons.work,
				'color': Colors.blue,
			},
			{
				'name': 'Adobe Creative Cloud',
				'description': 'Photoshop, Illustrator, Premiere Pro suite',
				'price': 85000,
				'duration': '12 months',
				'icon': Icons.design_services,
				'color': Colors.red,
			},
			{
				'name': 'Antivirus Premium',
				'description': 'Norton, McAfee, or Kaspersky protection',
				'price': 15000,
				'duration': '12 months',
				'icon': Icons.security,
				'color': Colors.green,
			},
		],
		'entertainment': [
			{
				'name': 'Netflix Premium',
				'description': '4K streaming, 4 screens, downloads',
				'price': 8000,
				'duration': '1 month',
				'icon': Icons.movie,
				'color': Colors.red,
			},
			{
				'name': 'Spotify Premium',
				'description': 'Ad-free music, offline downloads',
				'price': 3500,
				'duration': '1 month',
				'icon': Icons.music_note,
				'color': Colors.green,
			},
			{
				'name': 'YouTube Premium',
				'description': 'Ad-free videos, background play, downloads',
				'price': 4500,
				'duration': '1 month',
				'icon': Icons.play_circle,
				'color': Colors.red,
			},
		],
		'gaming': [
			{
				'name': 'PlayStation Plus',
				'description': 'Free games, online multiplayer, discounts',
				'price': 12000,
				'duration': '3 months',
				'icon': Icons.sports_esports,
				'color': Colors.blue,
			},
			{
				'name': 'Xbox Game Pass',
				'description': '100+ games, cloud gaming, new releases',
				'price': 15000,
				'duration': '3 months',
				'icon': Icons.gamepad,
				'color': Colors.green,
			},
			{
				'name': 'Steam Wallet',
				'description': 'Add funds to Steam for game purchases',
				'price': 25000,
				'duration': 'No expiry',
				'icon': Icons.computer,
				'color': Colors.indigo,
			},
		],
		'education': [
			{
				'name': 'Coursera Plus',
				'description': 'Unlimited access to 7,000+ courses',
				'price': 35000,
				'duration': '12 months',
				'icon': Icons.school,
				'color': Colors.blue,
			},
			{
				'name': 'Udemy Business',
				'description': 'Professional development courses',
				'price': 25000,
				'duration': '6 months',
				'icon': Icons.business_center,
				'color': Colors.purple,
			},
			{
				'name': 'Duolingo Plus',
				'description': 'Ad-free language learning, offline lessons',
				'price': 8500,
				'duration': '6 months',
				'icon': Icons.translate,
				'color': Colors.green,
			},
		],
	};

	@override
	void initState() {
		super.initState();
		_detectCountry();
	}

	Future<void> _detectCountry() async {
		try {
			final detectedCountry = await CountryDetectionService.detectUserCountry();
			final currencyInfo = CountryDetectionService.getCurrencyInfo(detectedCountry);
			
			setState(() {
				_detectedCountry = detectedCountry;
				_currencySymbol = currencyInfo['symbol']!;
				_currencyCode = currencyInfo['code']!;
			});
		} catch (e) {
			print('Error detecting country: $e');
		}
	}

	Future<void> _purchaseProduct(Map<String, dynamic> product) async {
		try {
			final uid = FirebaseAuth.instance.currentUser?.uid;
			if (uid == null) {
				ScaffoldMessenger.of(context).showSnackBar(
					const SnackBar(content: Text('Please sign in to purchase digital products'))
				);
				return;
			}

			// Create purchase record
			await FirebaseFirestore.instance.collection('digital_purchases').add({
				'userId': uid,
				'productName': product['name'],
				'description': product['description'],
				'price': product['price'],
				'duration': product['duration'],
				'category': _selectedCategory,
				'currency': _currencyCode,
				'countryCode': _detectedCountry,
				'status': 'pending',
				'createdAt': DateTime.now().toIso8601String(),
			});

			if (mounted) {
				showDialog(
					context: context,
					builder: (_) => AlertDialog(
						title: const Text('🛒 Purchase Digital Product'),
						content: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								Icon(product['icon'], size: 48, color: product['color']),
								const SizedBox(height: 16),
								Text(
									product['name'],
									style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
									textAlign: TextAlign.center,
								),
								const SizedBox(height: 8),
								Text(
									product['description'],
									style: const TextStyle(color: Colors.grey),
									textAlign: TextAlign.center,
								),
								const SizedBox(height: 16),
								Container(
									padding: const EdgeInsets.all(12),
									decoration: BoxDecoration(
										color: Colors.green.shade50,
										borderRadius: BorderRadius.circular(8),
									),
									child: Column(
										children: [
											Row(
												mainAxisAlignment: MainAxisAlignment.spaceBetween,
												children: [
													const Text('Price:'),
													Text('$_currencySymbol${product['price']}', style: const TextStyle(fontWeight: FontWeight.bold)),
												],
											),
											Row(
												mainAxisAlignment: MainAxisAlignment.spaceBetween,
												children: [
													const Text('Duration:'),
													Text(product['duration'], style: const TextStyle(fontWeight: FontWeight.bold)),
												],
											),
										],
									),
								),
								const SizedBox(height: 12),
								const Text(
									'🔄 This will redirect to secure payment gateway',
									style: TextStyle(color: Colors.blue, fontSize: 12),
								),
							],
						),
						actions: [
							TextButton(
								onPressed: () => Navigator.pop(context),
								child: const Text('Cancel'),
							),
							FilledButton(
								onPressed: () {
									Navigator.pop(context);
									ScaffoldMessenger.of(context).showSnackBar(
										const SnackBar(
											content: Text('🔄 Digital product purchase integration coming soon! Purchase request saved.'),
											backgroundColor: Colors.blue,
										)
									);
								},
								child: const Text('Purchase'),
							),
						],
					),
				);
			}
		} catch (e) {
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text('Purchase failed: $e'))
			);
		}
	}

	@override
	Widget build(BuildContext context) {
		final products = _digitalProducts[_selectedCategory] ?? [];

		return Scaffold(
			appBar: AppBar(
				title: Text('💻 Digital Products - ${CountryDetectionService.getCountryName(_detectedCountry)}'),
				backgroundColor: Colors.indigo.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
			),
			body: Container(
				color: Colors.white,
				child: Column(
					children: [
						// Category selection
						Container(
							color: Colors.white,
							padding: const EdgeInsets.all(16),
							child: SingleChildScrollView(
								scrollDirection: Axis.horizontal,
								child: Row(
									children: _digitalProducts.keys.map((category) {
										final isSelected = category == _selectedCategory;
										return Padding(
											padding: const EdgeInsets.only(right: 8),
											child: FilterChip(
												label: Text(category.toUpperCase(), style: const TextStyle(color: Colors.black)),
												selected: isSelected,
												onSelected: (_) => setState(() => _selectedCategory = category),
												selectedColor: Colors.indigo.shade100,
												backgroundColor: Colors.white,
											),
										);
									}).toList(),
								),
							),
						),

						// Products list
						Expanded(
							child: ListView.separated(
								padding: const EdgeInsets.all(16),
								itemCount: products.length,
								separatorBuilder: (context, index) => const SizedBox(height: 12),
								itemBuilder: (context, index) {
									final product = products[index];
									return Card(
										elevation: 4,
										child: Padding(
											padding: const EdgeInsets.all(16),
											child: Row(
												children: [
													Container(
														padding: const EdgeInsets.all(12),
														decoration: BoxDecoration(
															color: (product['color'] as Color).withOpacity(0.1),
															borderRadius: BorderRadius.circular(8),
														),
														child: Icon(
															product['icon'],
															color: product['color'],
															size: 32,
														),
													),
													const SizedBox(width: 16),
													Expanded(
														child: Column(
															crossAxisAlignment: CrossAxisAlignment.start,
															children: [
																Text(
																	product['name'],
																	style: const TextStyle(
																		fontWeight: FontWeight.bold,
																		fontSize: 16,
																		color: Colors.black,
																	),
																),
																const SizedBox(height: 4),
																Text(
																	product['description'],
																	style: const TextStyle(color: Colors.black54, fontSize: 12),
																),
																const SizedBox(height: 8),
																Row(
																	children: [
																		Text(
																			'$_currencySymbol${product['price']}',
																			style: TextStyle(
																				fontWeight: FontWeight.bold,
																				fontSize: 16,
																				color: product['color'],
																			),
																		),
																		const SizedBox(width: 8),
																		Text(
																			'• ${product['duration']}',
																			style: const TextStyle(color: Colors.black54, fontSize: 12),
																		),
																	],
																),
															],
														),
													),
													FilledButton(
														onPressed: () => _purchaseProduct(product),
														style: FilledButton.styleFrom(
															backgroundColor: product['color'],
														),
														child: const Text('Buy'),
													),
												],
											),
										),
									);
								},
							),
						),
					],
				),
			),
		);
	}
}