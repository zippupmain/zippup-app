import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VendorDetailScreen extends StatelessWidget {
	const VendorDetailScreen({super.key, required this.vendorId});
	final String vendorId;
	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: const Text('Vendor')), 
			body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
				future: FirebaseFirestore.instance.collection('vendors').doc(vendorId).get(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final v = snap.data!.data() ?? {};
					return Padding(
						padding: const EdgeInsets.all(16),
						child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
							Text(v['name'] ?? 'Vendor', style: Theme.of(context).textTheme.titleLarge),
							const SizedBox(height: 8),
							Text('Category: ${v['category'] ?? ''}'),
							Text('Rating: ${(v['rating'] ?? 0).toString()}'),
							const Spacer(),
							FilledButton(onPressed: () => context.push('/food/vendor/menu?vendorId=$vendorId'), child: const Text('View menu')),
						]),
					);
				},
			),
		);
	}
}