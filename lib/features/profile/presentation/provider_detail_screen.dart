import 'package:flutter/material.dart';
import 'package:zippup/features/profile/presentation/provider_profile_screen.dart';

class ProviderDetailScreen extends StatelessWidget {
	const ProviderDetailScreen({super.key, required this.providerId});
	final String providerId;
	@override
	Widget build(BuildContext context) {
		return ProviderProfileScreen(providerId: providerId);
	}
}