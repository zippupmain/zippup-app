import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class VendorListScreen extends StatefulWidget {
	const VendorListScreen({super.key, required this.category});
	final String category;
	@override
	State<VendorListScreen> createState() => _VendorListScreenState();
}

class _VendorListScreenState extends State<VendorListScreen> {
	final _search = TextEditingController();
	String _q = '';
	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(
				title: Text('Vendors • ${widget.category.replaceAll('_', ' ')}'),
				bottom: PreferredSize(
					preferredSize: const Size.fromHeight(56),
					child: Padding(
						padding: const EdgeInsets.all(8.0),
						child: TextField(
							controller: _search,
							textInputAction: TextInputAction.search,
							onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
							decoration: InputDecoration(
								filled: true,
								hintText: 'Search vendors...',
								prefixIcon: const Icon(Icons.search),
								border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
							),
						),
					),
				),
			),
			body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
				stream: FirebaseFirestore.instance.collection('vendors').where('category', isEqualTo: widget.category).snapshots(),
				builder: (context, snapshot) {
					if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
					final docs = snapshot.data!.docs.where((d) {
						if (_q.isEmpty) return true;
						final name = (d.data()['name'] ?? '').toString().toLowerCase();
						return name.contains(_q);
					}).toList();
					if (docs.isEmpty) return const Center(child: Text('No vendors nearby'));
					return ListView.separated(
						itemCount: docs.length,
						separatorBuilder: (_, __) => const Divider(height: 1),
						itemBuilder: (context, i) {
							final v = docs[i].data();
							final vid = docs[i].id;
							return ListTile(
								title: Text(v['name'] ?? 'Vendor'),
								subtitle: Text((v['rating'] ?? 0).toString()),
								trailing: Wrap(spacing: 8, children: [
									IconButton(onPressed: () => context.pushNamed('chat', pathParameters: {'threadId': 'vendor_$vid'}, queryParameters: {'title': v['name'] ?? 'Chat'}), icon: const Icon(Icons.chat_bubble_outline)),
									TextButton(onPressed: () => context.push('/vendor?vendorId=$vid'), child: const Text('View')),
								]),
							);
						},
					);
				},
			),
			bottomNavigationBar: SafeArea(
				child: Padding(
					padding: const EdgeInsets.all(12.0),
					child: FilledButton.icon(onPressed: () {}, icon: const Icon(Icons.shopping_cart_checkout), label: const Text('Checkout')),
				),
			),
		);
	}
}