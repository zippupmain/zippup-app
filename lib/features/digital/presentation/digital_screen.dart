import 'package:flutter/material.dart';

class DigitalScreen extends StatelessWidget {
	const DigitalScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Digital Services')),
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
		return Container(
			decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
			child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon), const SizedBox(height: 8), Text(label)]),
		);
	}
}