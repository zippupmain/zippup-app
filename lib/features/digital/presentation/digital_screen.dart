import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DigitalScreen extends StatelessWidget {
	const DigitalScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: const Text(
					'📱 Digital Services',
					style: TextStyle(
						fontWeight: FontWeight.bold,
						fontSize: 20,
					),
				),
				backgroundColor: Colors.transparent,
				flexibleSpace: Container(
					decoration: const BoxDecoration(
						gradient: LinearGradient(
							colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
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
						colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
					),
				),
				child: GridView.count(
					padding: const EdgeInsets.all(20),
					crossAxisCount: 2,
					mainAxisSpacing: 16,
					crossAxisSpacing: 16,
					childAspectRatio: 1.2,
					children: const [
						_DigitalCard(
							label: 'My Wallet',
							icon: Icons.account_balance_wallet,
							emoji: '💳',
							gradient: LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF81C784)]),
						),
						_DigitalCard(
							label: 'Buy Airtime',
							icon: Icons.phone_iphone,
							emoji: '📞',
							gradient: LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF64B5F6)]),
						),
						_DigitalCard(
							label: 'Buy Data',
							icon: Icons.network_cell,
							emoji: '📶',
							gradient: LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)]),
						),
						_DigitalCard(
							label: 'Pay Bills',
							icon: Icons.receipt_long,
							emoji: '💡',
							gradient: LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFFB74D)]),
						),
						_DigitalCard(
							label: 'Digital Products',
							icon: Icons.shopping_bag,
							emoji: '💻',
							gradient: LinearGradient(colors: [Color(0xFF607D8B), Color(0xFF90A4AE)]),
						),
						_DigitalCard(
							label: 'Select Country',
							icon: Icons.public,
							emoji: '🌍',
							gradient: LinearGradient(colors: [Color(0xFF673AB7), Color(0xFF9575CD)]),
						),
					],
				),
			),
		);
	}
}

class _DigitalCard extends StatelessWidget {
	const _DigitalCard({
		required this.label, 
		required this.icon,
		required this.emoji,
		required this.gradient,
	});
	final String label;
	final IconData icon;
	final String emoji;
	final LinearGradient gradient;
	
	@override
	Widget build(BuildContext context) {
		return InkWell(
			onTap: () {
				switch (label) {
					case 'My Wallet':
						context.push('/wallet');
						break;
					case 'Buy Airtime':
						context.push('/digital/global-airtime');
						break;
					case 'Buy Data':
						context.push('/digital/global-data');
						break;
					case 'Pay Bills':
						context.push('/digital/global-bills');
						break;
					case 'Select Country':
						context.push('/digital/country-selection');
						break;
					case 'Digital Products':
						context.push('/digital/products');
						break;
					default:
						ScaffoldMessenger.of(context).showSnackBar(
							const SnackBar(content: Text('Feature coming soon!'))
						);
				}
			},
			borderRadius: BorderRadius.circular(20),
			child: Container(
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
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						Stack(
							alignment: Alignment.center,
							children: [
								Container(
									padding: const EdgeInsets.all(20),
									decoration: BoxDecoration(
										color: Colors.white.withOpacity(0.2),
										shape: BoxShape.circle,
									),
									child: Icon(icon, color: Colors.white, size: 36),
								),
								Positioned(
									top: 8,
									right: 8,
									child: Text(
										emoji,
										style: const TextStyle(fontSize: 28),
									),
								),
							],
						),
						const SizedBox(height: 12),
						Padding(
							padding: const EdgeInsets.symmetric(horizontal: 8),
							child: Text(
								label, 
								style: const TextStyle(
									color: Colors.white,
									fontWeight: FontWeight.bold,
									fontSize: 13,
								),
								textAlign: TextAlign.center,
							),
						),
					],
				),
			),
		);
	}
}