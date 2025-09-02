import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OthersScreen extends StatelessWidget {
	const OthersScreen({super.key});

	@override
	Widget build(BuildContext context) {
		final items = [
			('🎉', 'Events Planning', 'Plan weddings, parties, conferences', const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFF06292)]), '/others/events'),
			('🎫', 'Event Tickets', 'Live concerts, shows, sports events', const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)]), '/others/tickets'),
			('👨‍🏫', 'Tutoring', 'Private lessons, academic support', const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF64B5F6)]), '/others/tutors'),
			('📚', 'Education', 'Courses, training, workshops', const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF81C784)]), '/others/education'),
			('🎨', 'Creative Services', 'Design, photography, art', const LinearGradient(colors: [Color(0xFFFF9800), Color(0xFFFFB74D)]), '/others/creative'),
			('💼', 'Business Services', 'Consulting, legal, accounting', const LinearGradient(colors: [Color(0xFF607D8B), Color(0xFF90A4AE)]), '/others/business'),
			('🩺', 'Medical Consulting', 'Doctors, specialists, healthcare', const LinearGradient(colors: [Color(0xFF00BCD4), Color(0xFF4DD0E1)]), '/others/medical'),
		];
		
		return Scaffold(
			appBar: AppBar(
				title: const Text(
					'📋 Other Services',
					style: TextStyle(
						fontWeight: FontWeight.bold,
						fontSize: 20,
					),
				),
				backgroundColor: Colors.transparent,
				flexibleSpace: Container(
					decoration: const BoxDecoration(
						gradient: LinearGradient(
							colors: [Color(0xFF607D8B), Color(0xFF90A4AE)],
							begin: Alignment.topLeft,
							end: Alignment.bottomRight,
						),
					),
				),
				foregroundColor: Colors.white,
			),
			body: Container(
				decoration: const BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: [Color(0xFFECEFF1), Color(0xFFCFD8DC)],
					),
				),
				child: ListView.builder(
					padding: const EdgeInsets.all(20),
					itemCount: items.length,
					itemBuilder: (context, i) {
						final (emoji, title, subtitle, gradient, route) = items[i];
						return Padding(
							padding: const EdgeInsets.only(bottom: 16),
							child: _OtherServiceCard(
								emoji: emoji,
								title: title,
								subtitle: subtitle,
								gradient: gradient,
								onTap: () => context.push(route),
							),
						);
					},
				),
			),
		);
	}
}

class _OtherServiceCard extends StatelessWidget {
	const _OtherServiceCard({
		required this.emoji,
		required this.title,
		required this.subtitle,
		required this.gradient,
		required this.onTap,
	});
	
	final String emoji;
	final String title;
	final String subtitle;
	final LinearGradient gradient;
	final VoidCallback onTap;
	
	@override
	Widget build(BuildContext context) {
		return InkWell(
			onTap: onTap,
			borderRadius: BorderRadius.circular(16),
			child: Container(
				padding: const EdgeInsets.all(16),
				decoration: BoxDecoration(
					gradient: gradient,
					borderRadius: BorderRadius.circular(16),
					boxShadow: [
						BoxShadow(
							color: gradient.colors.first.withOpacity(0.3),
							blurRadius: 8,
							offset: const Offset(0, 4),
						),
					],
				),
				child: Row(
					children: [
						Container(
							padding: const EdgeInsets.all(12),
							decoration: BoxDecoration(
								color: Colors.white.withOpacity(0.2),
								shape: BoxShape.circle,
							),
							child: Text(emoji, style: const TextStyle(fontSize: 24)),
						),
						const SizedBox(width: 16),
						Expanded(
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text(
										title,
										style: const TextStyle(
											color: Colors.white,
											fontWeight: FontWeight.bold,
											fontSize: 16,
										),
									),
									const SizedBox(height: 4),
									Text(
										subtitle,
										style: const TextStyle(
											color: Colors.white,
											fontSize: 13,
										),
									),
								],
							),
						),
						const Icon(
							Icons.arrow_forward_ios,
							color: Colors.white,
							size: 18,
						),
					],
				),
			),
		);
	}
}