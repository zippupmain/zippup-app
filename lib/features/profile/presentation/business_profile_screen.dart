import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BusinessProfileScreen extends StatelessWidget {
	const BusinessProfileScreen({super.key});
	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Business profile')),
			body: Center(
				child: Padding(
					padding: const EdgeInsets.all(24),
					child: Column(mainAxisSize: MainAxisSize.min, children: [
						const Text('Manage your business profiles in the new hub'),
						const SizedBox(height: 12),
						FilledButton.icon(onPressed: () => context.push('/providers'), icon: const Icon(Icons.business_center), label: const Text('Open Business Profiles')),
					]),
				),
			),
		);
	}
}