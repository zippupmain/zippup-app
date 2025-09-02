import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zippup/features/marketplace/models/product.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
		final stt.SpeechToText speech = stt.SpeechToText();
		Future<void> _mic() async {
			final ok = await speech.initialize(onError: (_) {});
			if (!ok) return;
			speech.listen(onResult: (r) {
				// Only update on final result to avoid duplicates
				if (r.finalResult) {
					final newText = r.recognizedWords.trim();
					if (newText.isNotEmpty) {
						controller.text = newText;
						controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
						_goSearch(context, newText);
					}
				}
			});
		}
		return Scaffold(
			appBar: AppBar(
				title: const Text(
					'🛒 Marketplace',
					style: TextStyle(
						fontWeight: FontWeight.bold,
						fontSize: 20,
					),
				),
				backgroundColor: Colors.transparent,
				flexibleSpace: Container(
					decoration: const BoxDecoration(
						gradient: LinearGradient(
							colors: [Color(0xFFE91E63), Color(0xFFF06292)],
							begin: Alignment.topLeft,
							end: Alignment.bottomRight,
						),
					),
				),
				foregroundColor: Colors.white,
				bottom: PreferredSize(
					preferredSize: const Size.fromHeight(110),
					child: Column(
						children: [
							Padding(
								padding: const EdgeInsets.fromLTRB(8,8,8,4),
								child: TextField(
									controller: controller,
									textInputAction: TextInputAction.search,
									onSubmitted: (v) => _goSearch(context, v),
									decoration: InputDecoration(
										filled: true,
										hintText: 'Search items or sellers...',
										prefixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => _goSearch(context, controller.text)),
										suffixIcon: IconButton(icon: const Icon(Icons.mic_none), onPressed: _mic),
										border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
									),
								),
							),
							Padding(
								padding: const EdgeInsets.fromLTRB(8,0,8,8),
								child: Align(
									alignment: Alignment.centerRight,
									child: FilledButton.icon(
										icon: const Icon(Icons.add),
										label: const Text('Manage products'),
										onPressed: () => context.pushNamed('addListing'),
									),
								),
							),
						],
					),
				),
			),
			body: Container(
				decoration: const BoxDecoration(
					gradient: LinearGradient(
						begin: Alignment.topCenter,
						end: Alignment.bottomCenter,
						colors: [Color(0xFFFCE4EC), Color(0xFFF8BBD9)],
					),
				),
				child: StreamBuilder<List<Product>>(
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
							final firstImage = (p.toJson()['imageUrls'] as List?)?.cast<String>().firstOrNull;
							return ListTile(
								leading: firstImage != null ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(firstImage, width: 56, height: 56, fit: BoxFit.cover)) : const Icon(Icons.image_not_supported),
								title: Text(p.title),
								subtitle: Text('${p.category} • ${p.price.toStringAsFixed(2)}'),
								trailing: PopupMenuButton<String>(
									onSelected: (val) async {
										if (val == 'edit') {
											context.push('/marketplace/add?listingId=${Uri.encodeComponent(p.id)}');
										} else if (val == 'sold') {
											await FirebaseFirestore.instance.collection('listings').doc(p.id).update({'status': 'sold'});
										} else if (val == 'delete') {
											await FirebaseFirestore.instance.collection('listings').doc(p.id).delete();
										}
									},
									itemBuilder: (context) => const [
										PopupMenuItem(value: 'edit', child: Text('Edit')),
										PopupMenuItem(value: 'sold', child: Text('Mark as sold')),
										PopupMenuItem(value: 'delete', child: Text('Delete')),
									],
								),
							);
					},
					);
				},
				),
			),
		);
	}
}