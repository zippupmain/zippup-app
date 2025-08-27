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
				title: const Text('Food'),
				actions: [
					IconButton(onPressed: () => _voiceSearch(context, controller), icon: const Icon(Icons.mic_none, color: Colors.black)),
				],
				backgroundColor: Colors.white,
				foregroundColor: Colors.black,
				bottom: PreferredSize(
					preferredSize: const Size.fromHeight(56),
					child: Padding(
						padding: const EdgeInsets.all(8.0),
						child: TextField(
							controller: controller,
							textInputAction: TextInputAction.search,
							onSubmitted: (v) => _goSearch(context, v),
							decoration: InputDecoration(
								filled: true,
								fillColor: Colors.white,
								hintText: 'Search food, vendors...',
								prefixIcon: const Icon(Icons.search, color: Colors.black),
								suffixIcon: IconButton(icon: const Icon(Icons.mic_none), onPressed: () => _voiceSearch(context, controller)),
								border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black12)),
							),
						),
					),
				),
			),
			body: GridView.count(
				padding: const EdgeInsets.all(16),
				crossAxisCount: 3,
				mainAxisSpacing: 12,
				crossAxisSpacing: 12,
				children: [
					_CategoryCard(label: 'Fast Food', icon: Icons.fastfood, onTap: () => context.push('/food/vendors/fast_food')),
					_CategoryCard(label: 'Grocery', icon: Icons.local_grocery_store, onTap: () => context.push('/food/vendors/grocery')),
					_CategoryCard(label: 'Local', icon: Icons.restaurant, onTap: () => context.push('/food/vendors/local')),
				],
			),
		);
	}
}

class _CategoryCard extends StatelessWidget {
	const _CategoryCard({required this.label, required this.icon, required this.onTap});
	final String label;
	final IconData icon;
	final VoidCallback onTap;
	@override
	Widget build(BuildContext context) {
		return InkWell(
			onTap: onTap,
			child: Container(
				decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [Icon(icon, color: Colors.black), const SizedBox(height: 8), Text(label, style: const TextStyle(color: Colors.black))],
				),
			),
		);
	}
}