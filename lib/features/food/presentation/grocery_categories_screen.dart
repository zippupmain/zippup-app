import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GroceryCategoriesScreen extends StatelessWidget {
	const GroceryCategoriesScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final groceryCategories = [
			{
				'name': 'African',
				'emoji': '🇳🇬',
				'description': 'African vegetables, spices, grains, traditional foods',
				'gradient': const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF81C784)]),
				'route': '/food/vendors/grocery_african',
			},
			{
				'name': 'American',
				'emoji': '🇺🇸',
				'description': 'American brands, snacks, cereals, beverages',
				'gradient': const LinearGradient(colors: [Color(0xFFFF5722), Color(0xFFFF8A65)]),
				'route': '/food/vendors/grocery_american',
			},
			{
				'name': 'Asian',
				'emoji': '🇨🇳',
				'description': 'Asian vegetables, spices, noodles, sauces',
				'gradient': const LinearGradient(colors: [Color(0xFFF44336), Color(0xFFEF5350)]),
				'route': '/food/vendors/grocery_asian',
			},
			{
				'name': 'European',
				'emoji': '🇪🇺',
				'description': 'European cheese, bread, wine, delicacies',
				'gradient': const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF64B5F6)]),
				'route': '/food/vendors/grocery_european',
			},
			{
				'name': 'Mediterranean',
				'emoji': '🇬🇷',
				'description': 'Mediterranean oils, herbs, olives, pasta',
				'gradient': const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)]),
				'route': '/food/vendors/grocery_mediterranean',
			},
			{
				'name': 'Middle Eastern',
				'emoji': '🇸🇦',
				'description': 'Middle Eastern spices, rice, nuts, sweets',
				'gradient': const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFFB74D)]),
				'route': '/food/vendors/grocery_middle_eastern',
			},
		];

		return Scaffold(
			appBar: AppBar(
				title: const Text(
					'🥬 Grocery Categories',
					style: TextStyle(
						fontWeight: FontWeight.bold,
						fontSize: 20,
					),
				),
				backgroundColor: Colors.transparent,
				flexibleSpace: Container(
					decoration: const BoxDecoration(
						gradient: LinearGradient(
							colors: [Color(0xFF8BC34A), Color(0xFFAED581)],
							begin: Alignment.topLeft,
							end: Alignment.bottomRight,
						),
					),
				),
				foregroundColor: Colors.white,
				elevation: 0,
			),
			body: Container(
				decoration: const BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: [Color(0xFFF1F8E9), Color(0xFFFFFFFF)],
					),
				),
				child: ListView(
					padding: const EdgeInsets.all(16),
					children: [
						const Card(
							child: Padding(
								padding: EdgeInsets.all(16),
								child: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Text(
											'🌍 International Grocery',
											style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
										),
										SizedBox(height: 8),
										Text(
											'Discover groceries from around the world. Each category specializes in authentic ingredients and products from their respective regions.',
											style: TextStyle(color: Colors.grey),
										),
									],
								),
							),
						),
						const SizedBox(height: 16),
						
						// Grocery categories grid
						GridView.builder(
							shrinkWrap: true,
							physics: const NeverScrollableScrollPhysics(),
							gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
								crossAxisCount: 2,
								childAspectRatio: 1.1,
								mainAxisSpacing: 12,
								crossAxisSpacing: 12,
							),
							itemCount: groceryCategories.length,
							itemBuilder: (context, index) {
								final category = groceryCategories[index];
								return _GroceryCategoryCard(
									name: category['name'] as String,
									emoji: category['emoji'] as String,
									description: category['description'] as String,
									gradient: category['gradient'] as LinearGradient,
									onTap: () => context.push(category['route'] as String),
								);
							},
						),
					],
				),
			),
		);
	}
}

class _GroceryCategoryCard extends StatelessWidget {
	final String name;
	final String emoji;
	final String description;
	final LinearGradient gradient;
	final VoidCallback onTap;

	const _GroceryCategoryCard({
		required this.name,
		required this.emoji,
		required this.description,
		required this.gradient,
		required this.onTap,
	});

	@override
	Widget build(BuildContext context) {
		return Card(
			elevation: 4,
			child: InkWell(
				onTap: onTap,
				borderRadius: BorderRadius.circular(12),
				child: Container(
					decoration: BoxDecoration(
						gradient: gradient,
						borderRadius: BorderRadius.circular(12),
					),
					padding: const EdgeInsets.all(16),
					child: Column(
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							Text(
								emoji,
								style: const TextStyle(fontSize: 32),
							),
							const SizedBox(height: 8),
							Text(
								name,
								style: const TextStyle(
									fontSize: 16,
									fontWeight: FontWeight.bold,
									color: Colors.white,
								),
								textAlign: TextAlign.center,
							),
							const SizedBox(height: 4),
							Text(
								description,
								style: const TextStyle(
									fontSize: 11,
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
	}
}