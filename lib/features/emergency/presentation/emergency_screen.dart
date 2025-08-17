import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EmergencyScreen extends StatelessWidget {
	const EmergencyScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final items = [
			(const Icon(Icons.medical_services), 'Ambulance'),
			(const Icon(Icons.local_fire_department), 'Fire Service'),
			(const Icon(Icons.shield_outlined), 'Security'),
			(const Icon(Icons.local_shipping), 'Towing'),
			(const Icon(Icons.build_circle), 'Roadside'),
		];
		return Scaffold(
			appBar: AppBar(title: const Text('Emergency')),
			body: ListView.separated(
				padding: const EdgeInsets.all(16),
				itemCount: items.length,
				separatorBuilder: (_, __) => const Divider(height: 1),
				itemBuilder: (context, i) {
					final (icon, title) = items[i];
					return ListTile(
						leading: icon,
						title: Text(title),
						onTap: () {
							if (title == 'Roadside') {
								context.push('/emergency/roadside');
							} else {
								context.push('/transport');
							}
						},
					);
				},
			),
		);
	}
}