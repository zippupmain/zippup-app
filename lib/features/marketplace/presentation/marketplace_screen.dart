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

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Marketplace')),
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
