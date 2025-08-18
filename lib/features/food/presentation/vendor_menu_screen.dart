import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippup/features/cart/models/cart_item.dart';
import 'package:zippup/features/cart/providers/cart_provider.dart';

class VendorMenuScreen extends ConsumerWidget {
  const VendorMenuScreen({super.key, required this.vendorId});
  final String vendorId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('vendors').doc(vendorId).collection('menu').orderBy('title').snapshots(),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty) return const Center(child: Text('No menu items'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final id = docs[i].id;
              final m = docs[i].data();
              final title = (m['title'] ?? 'Item').toString();
              final price = (m['price'] as num?)?.toDouble() ?? 0;
              return ListTile(
                title: Text(title),
                subtitle: Text('₦${price.toStringAsFixed(2)}'),
                trailing: FilledButton(onPressed: () => _addToCart(context, ref, id, title, price), child: const Text('Add')),
              );
            },
          );
        },
      ),
    );
  }

  void _addToCart(BuildContext context, WidgetRef ref, String id, String title, double price) {
    final notifier = ref.read(cartProvider.notifier);
    if (!notifier.canAddFromVendor(vendorId)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart has items from another vendor. Please checkout or clear cart first.')));
      return;
    }
    notifier.add(CartItem(id: id, vendorId: vendorId, title: title, price: price, quantity: 1));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart')));
  }
}