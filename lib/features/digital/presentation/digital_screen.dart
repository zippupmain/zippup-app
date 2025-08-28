import 'package:flutter/material.dart';

class DigitalScreen extends StatelessWidget {
	const DigitalScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Digital Services'), backgroundColor: Colors.white, foregroundColor: Colors.black),
			backgroundColor: Colors.white,
			body: GridView.count(
				padding: const EdgeInsets.all(16),
				crossAxisCount: 3,
				mainAxisSpacing: 12,
				crossAxisSpacing: 12,
				children: const [
					_DigitalCard(label: 'Buy Airtime', icon: Icons.phone_iphone),
					_DigitalCard(label: 'Buy Data', icon: Icons.network_cell),
					_DigitalCard(label: 'Pay Bills', icon: Icons.receipt_long),
					_DigitalCard(label: 'Digital Products', icon: Icons.shopping_bag),
				],
			),
		);
	}
}

class _DigitalCard extends StatelessWidget {
	const _DigitalCard({required this.label, required this.icon});
	final String label;
	final IconData icon;
	@override
	Widget build(BuildContext context) {
		return InkWell(
			onTap: () {
				switch (label) {
					case 'Buy Airtime':
						Navigator.of(context).pushNamed('/digital/airtime');
						break;
					case 'Buy Data':
						Navigator.of(context).pushNamed('/digital/data');
						break;
					case 'Pay Bills':
						Navigator.of(context).pushNamed('/digital/bills');
						break;
					default:
				}
			},
			child: Container(
				decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
				child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.black), const SizedBox(height: 8), Text(label, style: const TextStyle(color: Colors.black))]),
			),
		);
	}
}