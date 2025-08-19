import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OthersScreen extends StatelessWidget {
	const OthersScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final items = [
			(const Icon(Icons.event), 'Events planning', '/others/events'),
			(const Icon(Icons.confirmation_number), 'Live event tickets', '/others/tickets'),
			(const Icon(Icons.school), 'Tutors', '/others/tutors'),
			(const Icon(Icons.drive_eta), 'Personal driver', '/personal'),
		];
		return Scaffold(
			appBar: AppBar(title: const Text('Others')),
			body: ListView.separated(
				padding: const EdgeInsets.all(16),
				itemCount: items.length,
				separatorBuilder: (_, __) => const Divider(height: 1),
				itemBuilder: (context, i) {
					final (icon, title, route) = items[i];
					return ListTile(
						leading: icon,
						title: Text(title),
						onTap: () => context.push(route),
					);
				},
			),
		);
	}
}