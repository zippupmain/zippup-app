import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/features/marketplace/models/product.dart';

class MarketplaceScreen extends StatelessWidget {
	const MarketplaceScreen({super.key});

	Stream<List<Product>> _streamProducts() {
		return FirebaseFirestore.instance
			.collection('listings')
			.orderBy('createdAt', descending: true)
			.snapshots()
			.map((snap) => snap.docs.map((d) {
				final data = d.data();
				return Product.fromJson({
					'id': d.id,
					...data,
				});
			}).toList());
	}

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
				title: const Text('Marketplace'),
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
								hintText: 'Search items or sellers...',
								prefixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => _goSearch(context, controller.text)),
								border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
							),
						),
					),
				),
			),
			floatingActionButton: FloatingActionButton.extended(
				onPressed: () async {
					await context.pushNamed('addListing');
				},
				label: const Text('Add'),
				icon: const Icon(Icons.add),
			),
			body: StreamBuilder<List<Product>>(
				stream: _streamProducts(),
				builder: (context, snapshot) {
					if (snapshot.connectionState == ConnectionState.waiting) {
						return const Center(child: CircularProgressIndicator());
					}
					final products = snapshot.data ?? const <Product>[];
					if (products.isEmpty) {
						return ListView(children: const [SizedBox(height: 120), Center(child: Text('No products'))]);
					}
					return ListView.separated(
						itemCount: products.length,
						separatorBuilder: (_, __) => const Divider(height: 1),
						itemBuilder: (context, i) {
							final p = products[i];
							return ListTile(
								title: Text(p.title),
								subtitle: Text('${p.category} • ${p.price.toStringAsFixed(2)}'),
							);
						},
					);
				},
			),
		);
	}
}
