import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VendorMenuScreen extends StatelessWidget {
  const VendorMenuScreen({super.key, required this.vendorId});
  final String vendorId;
  @override
  Widget build(BuildContext context) {
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
              final m = docs[i].data();
              final price = (m['price'] as num?)?.toDouble() ?? 0;
              return ListTile(
                title: Text(m['title']?.toString() ?? 'Item'),
                subtitle: Text('₦${price.toStringAsFixed(2)}'),
                trailing: FilledButton(onPressed: () => _addToCart(context, m), child: const Text('Add')),
              );
            },
          );
        },
      ),
    );
  }

  void _addToCart(BuildContext context, Map<String, dynamic> item) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart')));
  }
}