import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EmergencyScreen extends StatelessWidget {
	const EmergencyScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final items = [
			(const Icon(Icons.medical_services), 'Ambulance', 'ambulance'),
			(const Icon(Icons.local_fire_department), 'Fire Services', 'fire_services'),
			(const Icon(Icons.shield_outlined), 'Security Services', 'security_services'),
			(const Icon(Icons.fire_truck), 'Towing Van', 'towing_van'),
			(const Icon(Icons.car_repair), 'Roadside Assistance', 'roadside'),
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
							} else {
								// Direct booking for specific emergency services
								context.push('/emergency/booking?type=$key&title=${title.replaceAll(' ', '_')}');
							}
						},
					);
				},
			),
		);
	}
}