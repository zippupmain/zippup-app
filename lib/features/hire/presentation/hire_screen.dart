import 'package:flutter/material.dart';

class HireScreen extends StatelessWidget {
	const HireScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Hire')),
			body: const Center(child: Text('Find tradesmen (coming soon)')),
		);
	}
}