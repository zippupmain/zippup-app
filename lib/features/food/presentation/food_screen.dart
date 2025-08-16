import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FoodScreen extends StatelessWidget {
	const FoodScreen({super.key});

	void _goSearch(BuildContext context, String q) {
		final query = q.trim();
		if (query.isEmpty) return;
		context.push('/search?q=${Uri.encodeComponent(query)}');
	}

	@override
	Widget build(BuildContext context) {
		final controller = TextEditingController();
		return Scaffold(
			appBar: AppBar(
				title: const Text('Food'),
				actions: [
					IconButton(onPressed: () => _goSearch(context, controller.text), icon: const Icon(Icons.mic_none)),
				],
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
								hintText: 'Search food, vendors...',
								prefixIcon: const Icon(Icons.search),
								border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
				decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
				child: Column(
					mainAxisAlignment: MainAxisAlignment.center,
					children: [Icon(icon), const SizedBox(height: 8), Text(label)],
				),
			),
		);
	}
}