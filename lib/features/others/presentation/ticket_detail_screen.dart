import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TicketDetailScreen extends StatelessWidget {
  const TicketDetailScreen({super.key, required this.ticketId});
  final String ticketId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ticket')),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance.collection('others').doc(ticketId).get(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!.data() ?? {};
          final title = d['title']?.toString() ?? 'Ticket';
          final desc = d['description']?.toString() ?? '';
          final price = (d['price'] as num?)?.toDouble() ?? 0;
          final eventAt = DateTime.tryParse(d['eventAt']?.toString() ?? '');
          final expireAt = DateTime.tryParse(d['expireAt']?.toString() ?? '');
          final expired = expireAt != null && DateTime.now().isAfter(expireAt);
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (eventAt != null) Text('Event: ${eventAt.toLocal()}'),
              if (expireAt != null) Text('Sales end: ${expireAt.toLocal()}'),
              const SizedBox(height: 8),
              Text(desc),
              const Spacer(),
              if (expired) const Text('Tickets ended', style: TextStyle(color: Colors.red)),
              if (!expired) Row(children: [
                Expanded(child: FilledButton(onPressed: () => _buyNow(context, ticketId, price), child: Text('Buy now ₦${price.toStringAsFixed(2)}'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => _reserve(context, ticketId, eventAt), child: const Text('Reserve (pay later)'))),
              ]),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _buyNow(BuildContext context, String id, double price) async {
    // TODO: add to cart and go to cart
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