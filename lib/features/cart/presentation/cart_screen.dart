import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zippup/features/cart/providers/cart_provider.dart';
import 'package:zippup/features/cart/models/cart_item.dart';

class CartScreen extends ConsumerWidget {
	const CartScreen({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final items = ref.watch(cartProvider);
		final notifier = ref.read(cartProvider.notifier);
		final total = notifier.total;
		return Scaffold(
			appBar: AppBar(title: const Text('Cart')),
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
				child: Container(
					padding: const EdgeInsets.all(12),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							Row(
								children: [
									Text('Total: ₦${total.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium),
									const Spacer(),
									FilledButton(onPressed: () => _checkout(context, total, 'stripe'), child: const Text('Pay with Stripe')),
								],
							),
							const SizedBox(height: 8),
							FilledButton.tonal(onPressed: () => _checkout(context, total, 'flutterwave'), child: const Text('Pay with Flutterwave')),
						],
					),
				),
			),
		);
	}

	Future<void> _checkout(BuildContext context, double total, String provider) async {
		final currency = 'NGN';
		// Placeholder: integrate back-end checkout URLs via PaymentsService
		final url = 'https://example.com/checkout?amount=${total.toStringAsFixed(2)}&provider=$provider&currency=$currency';
		if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open checkout')));
		}
	}
}