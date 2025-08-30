import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RentalsHubScreen extends StatelessWidget {
	const RentalsHubScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text(
					'🏠 Rentals Hub',
					style: TextStyle(
						fontWeight: FontWeight.bold,
						fontSize: 20,
					),
				),
				backgroundColor: Colors.transparent,
				flexibleSpace: Container(
					decoration: const BoxDecoration(
						gradient: LinearGradient(
							colors: [Color(0xFFFF5722), Color(0xFFFF8A65)],
							begin: Alignment.topLeft,
							end: Alignment.bottomRight,
						),
					),
				),
				foregroundColor: Colors.white,
			),
			body: Container(
				decoration: const BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: [Color(0xFFFBE9E7), Color(0xFFFFCCBC)],
					),
				),
				child: ListView(
					padding: const EdgeInsets.all(20),
					children: [
						_RentalCategoryCard(
							title: 'Vehicles',
							subtitle: 'Luxury cars, normal cars, bus, truck, tractor',
							emoji: '🚗',
							gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF64B5F6)]),
							onTap: () => context.pushNamed('rentalVehicles'),
						),
						const SizedBox(height: 16),
						_RentalCategoryCard(
							title: 'Houses & Properties',
							subtitle: 'Apartments, shortlets, halls, offices, warehouses',
							emoji: '🏠',
							gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF81C784)]),
							onTap: () => context.pushNamed('rentalHouses'),
						),
						const SizedBox(height: 16),
						_RentalCategoryCard(
							title: 'Equipment & Tools',
							subtitle: 'Equipment, instruments, party items, tools',
							emoji: '🔧',
							gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)]),
							onTap: () => context.pushNamed('rentalOthers'),
						),
					],
				),
			),
		);
	}
}

class _RentalCategoryCard extends StatelessWidget {
	const _RentalCategoryCard({
		required this.title,
		required this.subtitle,
		required this.emoji,
		required this.gradient,
		required this.onTap,
	});
	
	final String title;
	final String subtitle;
	final String emoji;
	final LinearGradient gradient;
	final VoidCallback onTap;
	
	@override
	Widget build(BuildContext context) {
		return InkWell(
			onTap: onTap,
			borderRadius: BorderRadius.circular(20),
			child: Container(
				padding: const EdgeInsets.all(20),
				decoration: BoxDecoration(
					gradient: gradient,
					borderRadius: BorderRadius.circular(20),
					boxShadow: [
						BoxShadow(
							color: gradient.colors.first.withOpacity(0.3),
							blurRadius: 12,
							offset: const Offset(0, 6),
							spreadRadius: 2,
						),
					],
				),
				child: Row(
					children: [
						Container(
							padding: const EdgeInsets.all(16),
							decoration: BoxDecoration(
								color: Colors.white.withOpacity(0.2),
								shape: BoxShape.circle,
							),
							child: Text(emoji, style: const TextStyle(fontSize: 32)),
						),
						const SizedBox(width: 16),
						Expanded(
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(
										title,
										style: const TextStyle(
											color: Colors.white,
											fontWeight: FontWeight.bold,
											fontSize: 18,
										),
									),
									const SizedBox(height: 4),
									Text(
										subtitle,
										style: const TextStyle(
											color: Colors.white,
											fontSize: 14,
										),
									),
								],
							),
						),
						const Icon(
							Icons.arrow_forward_ios,
							color: Colors.white,
							size: 20,
						),
					],
				),
			),
		);
	}
}
}

