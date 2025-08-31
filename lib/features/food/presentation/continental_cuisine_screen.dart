import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ContinentalCuisineScreen extends StatelessWidget {
	const ContinentalCuisineScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final cuisines = [
			{
				'name': 'African',
				'emoji': '🇳🇬',
				'description': 'Nigerian, Moroccan, Ethiopian, South African',
				'gradient': const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF81C784)]),
				'route': '/food/vendors/african',
			},
			{
				'name': 'American',
				'emoji': '🇺🇸',
				'description': 'American, Mexican, Canadian cuisine',
				'gradient': const LinearGradient(colors: [Color(0xFFFF5722), Color(0xFFFF8A65)]),
				'route': '/food/vendors/american',
			},
			{
				'name': 'Asian',
				'emoji': '🇨🇳',
				'description': 'Chinese, Japanese, Thai, Korean, Indian',
				'gradient': const LinearGradient(colors: [Color(0xFFF44336), Color(0xFFEF5350)]),
				'route': '/food/vendors/asian',
			},
			{
				'name': 'European',
				'emoji': '🇪🇺',
				'description': 'Italian, French, Spanish, German cuisine',
				'gradient': const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF64B5F6)]),
				'route': '/food/vendors/european',
			},
			{
				'name': 'Mediterranean',
				'emoji': '🇬🇷',
				'description': 'Greek, Turkish, Israeli, Moroccan',
				'gradient': const LinearGradient(colors: [Color(0xFF00BCD4), Color(0xFF4DD0E1)]),
				'route': '/food/vendors/mediterranean',
			},
			{
				'name': 'Middle Eastern',
				'emoji': '🇸🇦',
				'description': 'Arabic, Turkish, Persian, Lebanese',
				'gradient': const LinearGradient(colors: [Color(0xFF795548), Color(0xFFA1887F)]),
				'route': '/food/vendors/middle_eastern',
			},
		];

		return Scaffold(
			appBar: AppBar(
				title: const Text('🥡 Continental Cuisine'),
				backgroundColor: Colors.red.shade50,
				iconTheme: const IconThemeData(color: Colors.black),
				titleTextStyle: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
			),
			body: Container(
				decoration: BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: [Colors.red.shade50, Colors.white],
					),
				),
				child: SingleChildScrollView(
					padding: const EdgeInsets.all(16),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							// Header
							Card(
								color: Colors.white,
								elevation: 4,
								child: Padding(
									padding: const EdgeInsets.all(20),
									child: Column(
										children: [
											Icon(Icons.public, size: 48, color: Colors.red.shade600),
											const SizedBox(height: 12),
											const Text(
												'World Cuisines',
												style: TextStyle(
													fontSize: 24,
													fontWeight: FontWeight.bold,
													color: Colors.black,
												),
											),
											const SizedBox(height: 8),
											Text(
												'Explore authentic flavors from different continents and countries',
												style: TextStyle(
													color: Colors.grey.shade600,
													fontSize: 16,
												),
												textAlign: TextAlign.center,
											),
										],
									),
								),
							),

							const SizedBox(height: 20),

							// Cuisine categories
							GridView.builder(
								shrinkWrap: true,
								physics: const NeverScrollableScrollPhysics(),
								gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
									crossAxisCount: 2,
									childAspectRatio: 0.85,
									crossAxisSpacing: 12,
									mainAxisSpacing: 12,
								),
								itemCount: cuisines.length,
								itemBuilder: (context, index) {
									final cuisine = cuisines[index];
									return GestureDetector(
										onTap: () {
											context.push(cuisine['route'] as String);
										},
										child: Container(
											decoration: BoxDecoration(
												gradient: cuisine['gradient'] as LinearGradient,
												borderRadius: BorderRadius.circular(16),
												boxShadow: [
													BoxShadow(
														color: Colors.black.withOpacity(0.1),
														spreadRadius: 2,
														blurRadius: 8,
														offset: const Offset(0, 4),
													),
												],
											),
											child: Padding(
												padding: const EdgeInsets.all(16),
												child: Column(
													mainAxisAlignment: MainAxisAlignment.center,
													children: [
														Text(
															cuisine['emoji'] as String,
															style: const TextStyle(fontSize: 48),
														),
														const SizedBox(height: 12),
														Text(
															cuisine['name'] as String,
															style: const TextStyle(
																fontSize: 18,
																fontWeight: FontWeight.bold,
																color: Colors.white,
															),
															textAlign: TextAlign.center,
														),
														const SizedBox(height: 8),
														Text(
															cuisine['description'] as String,
															style: const TextStyle(
																fontSize: 12,
																color: Colors.white70,
															),
															textAlign: TextAlign.center,
															maxLines: 2,
															overflow: TextOverflow.ellipsis,
														),
													],
												),
											),
										),
									);
								},
							),
						],
					),
				),
			),
		);
	}
}