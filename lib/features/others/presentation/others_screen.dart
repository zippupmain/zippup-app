import 'package:flutter/material.dart';

class OthersScreen extends StatelessWidget {
	const OthersScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final items = [
			(const Icon(Icons.event), 'Events planning'),
			(const Icon(Icons.confirmation_number), 'Live event tickets'),
			(const Icon(Icons.school), 'Tutors'),
		];
		return Scaffold(
			appBar: AppBar(title: const Text('Others')),
			body: ListView.separated(
				padding: const EdgeInsets.all(16),
				itemCount: items.length,
				separatorBuilder: (_, __) => const Divider(height: 1),
				itemBuilder: (context, i) {
					final (icon, title) = items[i];
					return ListTile(
						leading: icon,
						title: Text(title),
						onTap: () {},
					);
				},
			),
		);
	}
}