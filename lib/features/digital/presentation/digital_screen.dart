import 'package:flutter/material.dart';

class DigitalScreen extends StatelessWidget {
	const DigitalScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Digital Services')),
			body: const Center(child: Text('Airtime, data, and bills (coming soon)')),
		);
	}
}