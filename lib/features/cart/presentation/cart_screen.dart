import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zippup/features/cart/providers/cart_provider.dart';
import 'package:zippup/features/cart/models/cart_item.dart';
import 'package:zippup/services/payments/payments_service.dart';

class CartScreen extends ConsumerWidget {
	const CartScreen({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final items = ref.watch(cartProvider);
		final notifier = ref.read(cartProvider.notifier);
		final total = notifier.total;
		final vendorLocked = items.map((e) => e.vendorId).toSet().length == 1 && items.isNotEmpty;
		return Scaffold(
			appBar: AppBar(title: const Text('Cart'), actions: [
				if (items.isNotEmpty)
					TextButton(onPressed: notifier.clear, child: const Text('Clear', style: TextStyle(color: Colors.white)))
			]),
			body: items.isEmpty
					? const Center(child: Text('Cart is empty'))
					: ListView.separated(
						padding: const EdgeInsets.all(16),
						itemCount: items.length,
						separatorBuilder: (_, __) => const Divider(height: 1),
						itemBuilder: (context, i) {
							final item = items[i];
							return ListTile(
								title: Text(item.title),
								subtitle: Row(children: [
									IconButton(onPressed: () => notifier.decrement(item.id), icon: const Icon(Icons.remove_circle_outline)),
									Text('x${item.quantity}'),
									IconButton(onPressed: () => notifier.increment(item.id), icon: const Icon(Icons.add_circle_outline)),
								]),
								trailing: Column(
									mainAxisAlignment: MainAxisAlignment.center,
									children: [
										Text('₦${(item.price * item.quantity).toStringAsFixed(2)}'),
										TextButton(onPressed: () => notifier.remove(item.id), child: const Text('Remove')),
									],
								),
							);
						},
					),
			bottomNavigationBar: SafeArea(
				child: SingleChildScrollView(
					padding: const EdgeInsets.all(12),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							if (vendorLocked)
								Row(children: [
									const Icon(Icons.store_mall_directory, size: 16),
									const SizedBox(width: 6),
									Expanded(child: Text('Items from a single vendor. To change vendor, clear cart.')),
								]),
							Row(
								children: [
									Text('Total: ₦${total.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium),
									const Spacer(),
									FilledButton(onPressed: () => _checkout(context, items, total, 'stripe'), child: const Text('Pay with Stripe')),
								],
							),
							const SizedBox(height: 8),
							FilledButton.tonal(onPressed: () => _checkout(context, items, total, 'flutterwave'), child: const Text('Pay with Flutterwave')),
						],
					),
				),
			),
		);
	}

	Future<void> _checkout(BuildContext context, List<CartItem> items, double total, String provider) async {
		final service = PaymentsService();
		final currency = 'NGN';
		late String url;
		final payloadItems = items.map((e) => {'id': e.id, 'vendorId': e.vendorId, 'title': e.title, 'price': e.price, 'quantity': e.quantity}).toList();
		try {
			if (provider == 'stripe') {
				url = await service.createStripeCheckout(amount: total, currency: currency, items: payloadItems);
			} else {
				url = await service.createFlutterwaveCheckout(amount: total, currency: currency, items: payloadItems);
			}
			if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
				ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open checkout')));
			}
		} catch (e) {
			ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checkout failed: $e')));
		}
	}
}