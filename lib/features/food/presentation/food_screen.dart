import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class FoodScreen extends StatelessWidget {
	const FoodScreen({super.key});

	void _goSearch(BuildContext context, String q) {
		final query = q.trim();
		if (query.isEmpty) return;
		context.push('/search?q=${Uri.encodeComponent(query)}');
	}

	Future<void> _voiceSearch(BuildContext context, TextEditingController controller) async {
		final speech = stt.SpeechToText();
		final available = await speech.initialize(options: [stt.SpeechToText.androidIntentLookup]);
		if (!available) return;
		speech.listen(onResult: (res) {
			if (res.finalResult) {
				controller.text = res.recognizedWords;
				_goSearch(context, controller.text);
				speech.stop();
			}
		});
	}

	@override
	Widget build(BuildContext context) {
		final controller = TextEditingController();
		return Scaffold(
			appBar: AppBar(
				title: const Text(
					'🍽️ Food & Dining',
					style: TextStyle(
						fontWeight: FontWeight.bold,
						fontSize: 20,
					),
				),
				backgroundColor: Colors.transparent,
				flexibleSpace: Container(
					decoration: const BoxDecoration(
						gradient: LinearGradient(
							colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
							begin: Alignment.topLeft,
							end: Alignment.bottomRight,
						),
					),
				),
				foregroundColor: Colors.white,
				bottom: PreferredSize(
					preferredSize: const Size.fromHeight(70),
					child: Padding(
						padding: const EdgeInsets.all(16.0),
						child: Container(
							decoration: BoxDecoration(
								gradient: const LinearGradient(
									colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)],
								),
								borderRadius: BorderRadius.circular(16),
								boxShadow: [
									BoxShadow(
										color: Colors.orange.shade200,
										blurRadius: 8,
										offset: const Offset(0, 2),
									),
								],
							),
							child: TextField(
								controller: controller,
								textInputAction: TextInputAction.search,
								onSubmitted: (v) => _goSearch(context, v),
								style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w500),
								decoration: InputDecoration(
									filled: false,
									hintText: '🔍 Search delicious food, restaurants...',
									hintStyle: const TextStyle(color: Colors.orange),
									prefixIcon: Container(
										margin: const EdgeInsets.all(8),
										decoration: BoxDecoration(
											color: Colors.white.withOpacity(0.9),
											shape: BoxShape.circle,
										),
										child: const Icon(Icons.search, color: Colors.orange, size: 20),
									),
									suffixIcon: Container(
										margin: const EdgeInsets.all(8),
										decoration: BoxDecoration(
											gradient: const LinearGradient(
												colors: [Color(0xFFFF9800), Color(0xFFFF5722)],
											),
											shape: BoxShape.circle,
										),
										child: IconButton(
											icon: const Icon(Icons.mic, color: Colors.white, size: 20),
											onPressed: () => _voiceSearch(context, controller),
										),
									),
									border: InputBorder.none,
									contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
								),
							),
						),
					),
				),
			),
			body: Container(
				decoration: const BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: [Color(0xFFFFF8E1), Color(0xFFFFF3E0)],
					),
				),
				child: GridView.count(
					padding: const EdgeInsets.all(20),
					crossAxisCount: 2,
					mainAxisSpacing: 16,
					crossAxisSpacing: 16,
					childAspectRatio: 1.1,
					children: [
						_CategoryCard(
							label: 'Fast Food',
							icon: Icons.fastfood,
							emoji: '🍔',
							gradient: const LinearGradient(colors: [Color(0xFFFF5722), Color(0xFFFF8A65)]),
							onTap: () => context.push('/food/vendors/fast_food'),
						),
						_CategoryCard(
							label: 'Local Cuisine',
							icon: Icons.restaurant,
							emoji: '🍲',
							gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF81C784)]),
							onTap: () => context.push('/food/vendors/local'),
						),
						_CategoryCard(
							label: 'Pizza',
							icon: Icons.local_pizza,
							emoji: '🍕',
							gradient: const LinearGradient(colors: [Color(0xFFE91E63), Color(0xFFF06292)]),
							onTap: () => context.push('/food/vendors/pizza'),
						),
						_CategoryCard(
							label: 'Continental',
							icon: Icons.ramen_dining,
							emoji: '🥡',
							gradient: const LinearGradient(colors: [Color(0xFFF44336), Color(0xFFEF5350)]),
							onTap: () => context.push('/food/vendors/continental'),
						),
						_CategoryCard(
							label: 'Desserts',
							icon: Icons.cake,
							emoji: '🍰',
							gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)]),
							onTap: () => context.push('/food/vendors/desserts'),
						),
						_CategoryCard(
							label: 'Drinks',
							icon: Icons.local_drink,
							emoji: '🥤',
							gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF64B5F6)]),
							onTap: () => context.push('/food/vendors/drinks'),
						),
					],
				),
			),
		);
	}
}

class _CategoryCard extends StatelessWidget {
	const _CategoryCard({
		required this.label, 
		required this.icon, 
		required this.onTap,
		required this.emoji,
		required this.gradient,
	});
	final String label;
	final IconData icon;
	final VoidCallback onTap;
	final String emoji;
	final LinearGradient gradient;
	
	@override
	Widget build(BuildContext context) {
		return InkWell(
			onTap: onTap,
			borderRadius: BorderRadius.circular(20),
			child: Container(
				decoration: BoxDecoration(
					gradient: gradient,
					borderRadius: BorderRadius.circular(20),
					boxShadow: [
						BoxShadow(
							color: gradient.colors.first.withOpacity(0.3),
							blurRadius: 12,
							offset: const Offset(0, 6),
							spreadRadius: 2,
						),
					],
				),
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [
						Stack(
							alignment: Alignment.center,
							children: [
								Container(
									padding: const EdgeInsets.all(16),
									decoration: BoxDecoration(
										color: Colors.white.withOpacity(0.2),
										shape: BoxShape.circle,
									),
									child: Icon(icon, color: Colors.white, size: 32),
								),
								Positioned(
									top: 8,
									right: 8,
									child: Text(
										emoji,
										style: const TextStyle(fontSize: 24),
									),
								),
							],
						),
						const SizedBox(height: 12),
						Text(
							label, 
							style: const TextStyle(
								color: Colors.white,
								fontWeight: FontWeight.bold,
								fontSize: 14,
							),
							textAlign: TextAlign.center,
						),
					],
				),
			),
		);
	}
}