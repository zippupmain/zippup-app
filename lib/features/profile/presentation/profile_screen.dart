import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends StatelessWidget {
	const ProfileScreen({super.key});

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Profile')),
			body: ListView(
				children: [
					ListTile(
						leading: const Icon(Icons.verified_user),
						title: const Text('Apply as Service Provider / Vendor'),
						subtitle: const Text('Get verified to sell and accept bookings'),
						onTap: () => context.push('/profile/apply-provider'),
					),
				],
			),
		);
	}
}