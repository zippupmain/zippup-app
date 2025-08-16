import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ProductDetailScreen extends StatelessWidget {
	const ProductDetailScreen({super.key, required this.productId});
	final String productId;
	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Listing')),
			body: FutureBuilder<DocumentSnapshot<Map<String, dynamic}}>(
				future: FirebaseFirestore.instance.collection('listings').doc(productId).get(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final p = snap.data!.data() ?? {};
					return Padding(
						padding: const EdgeInsets.all(16),
						child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
							Text(p['title'] ?? 'Item', style: Theme.of(context).textTheme.titleLarge),
							const SizedBox(height: 8),
							Text('Category: ${p['category'] ?? ''}'),
							Text('Price: ${p['price'] ?? ''}'),
							const Spacer(),
							FilledButton(onPressed: () {}, child: const Text('Chat with seller')),
						]),
					);
				},
			),
		);
	}
}