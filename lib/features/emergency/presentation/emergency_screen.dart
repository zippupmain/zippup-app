import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EmergencyScreen extends StatelessWidget {
	const EmergencyScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final items = [
			(const Icon(Icons.medical_services), 'Ambulance', 'ambulance'),
			(const Icon(Icons.local_fire_department), 'Fire Service', 'fire'),
			(const Icon(Icons.shield_outlined), 'Security', 'security'),
			(const Icon(Icons.local_shipping), 'Towing', 'towing'),
			(const Icon(Icons.build_circle), 'Roadside', 'roadside'),
		];
		return Scaffold(
			appBar: AppBar(title: const Text('Emergency')),
			body: ListView.separated(
				padding: const EdgeInsets.all(16),
				itemCount: items.length,
				separatorBuilder: (_, __) => const Divider(height: 1),
				itemBuilder: (context, i) {
					final (icon, title, key) = items[i];
					return ListTile(
						leading: icon,
						title: Text(title),
						onTap: () {
							if (key == 'roadside') {
								context.push('/emergency/roadside');
							} else if (key == 'towing' || key == 'ambulance' || key == 'fire' || key == 'security') {
								context.push('/emergency/providers/$key');
							}
						},
					);
				},
			),
		);
	}
}