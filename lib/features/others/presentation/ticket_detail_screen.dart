import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippup/features/cart/models/cart_item.dart';
import 'package:zippup/features/cart/providers/cart_provider.dart';

class TicketDetailScreen extends ConsumerWidget {
  const TicketDetailScreen({super.key, required this.ticketId});
  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('others').doc(ticketId).get(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!.data() ?? {};
          final title = d['title']?.toString() ?? 'Ticket';
          final desc = d['description']?.toString() ?? '';
          final basePrice = (d['price'] as num?)?.toDouble() ?? 0;
          final variants = List<Map<String, dynamic>>.from((d['variants'] as List?) ?? [
            {'key': 'regular', 'name': 'Regular', 'price': basePrice},
            {'key': 'vip', 'name': 'VIP', 'price': basePrice * 1.5},
            {'key': 'special', 'name': 'Special request', 'price': basePrice * 2},
          ]);
          final eventAt = DateTime.tryParse(d['eventAt']?.toString() ?? '');
          final expireAt = DateTime.tryParse(d['expireAt']?.toString() ?? '');
          final organizerId = d['organizerId']?.toString() ?? '';
          final expired = expireAt != null && DateTime.now().isAfter(expireAt);

          String selectedKey = variants.first['key']?.toString() ?? 'regular';

          return StatefulBuilder(builder: (context, setStateSB) {
            final selectedVariant = variants.firstWhere((v) => v['key'] == selectedKey, orElse: () => variants.first);
            final price = ((selectedVariant['price'] as num?)?.toDouble() ?? basePrice).clamp(0, double.infinity);
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                if (eventAt != null) Text('Event: ${eventAt.toLocal()}'),
                if (expireAt != null) Text('Sales end: ${expireAt.toLocal()}'),
                const SizedBox(height: 8),
                Text(desc),
                const SizedBox(height: 12),
                const Text('Ticket type'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final v in variants)
                      ChoiceChip(
                        label: Text('${v['name']} (₦${((v['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)})'),
                        selected: selectedKey == v['key'],
                        onSelected: (_) => setStateSB(() => selectedKey = v['key']),
                      ),
                  ],
                ),
                const Spacer(),
                Row(children: [
                  if (organizerId.isNotEmpty)
                    OutlinedButton(onPressed: () => context.push('/provider?providerId=$organizerId'), child: const Text('View organizer')),
                  const Spacer(),
                ]),
                const SizedBox(height: 8),
                if (expired) const Text('Tickets ended', style: TextStyle(color: Colors.red))
                else Row(children: [
                  Expanded(child: FilledButton(onPressed: () => _addToCart(context, ref, ticketId, title, price, organizerId, selectedKey), child: Text('Buy (₦${price.toStringAsFixed(2)})'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: () => _reserve(context, ticketId, eventAt), child: const Text('Reserve (pay later)'))),
                ]),
              ]),
            );
          });
        },
      ),
    );
  }

  void _addToCart(BuildContext context, WidgetRef ref, String id, String title, double price, String vendorId, String variantKey) {
    final notifier = ref.read(cartProvider.notifier);
    final vendor = vendorId.isEmpty ? id : vendorId; // fall back to ticket doc as vendor context
    if (!notifier.canAddFromVendor(vendor)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cart has items from another vendor. Please checkout or clear cart first.')));
      return;
    }
    final itemId = '$id:$variantKey';
    notifier.add(CartItem(id: itemId, vendorId: vendor, title: '$title • ${variantKey.toUpperCase()}', price: price, quantity: 1));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart')));
    context.push('/cart');
  }

  Future<void> _reserve(BuildContext context, String id, DateTime? eventAt) async {
    await FirebaseFirestore.instance.collection('orders').add({
      'buyerId': 'self',
      'providerId': id,
      'category': 'tickets',
      'status': 'reserved',
      'eventAt': eventAt?.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    });
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reserved. You will be reminded.')));
  }
}