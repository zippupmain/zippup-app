import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zippup/features/cart/providers/cart_provider.dart';
import 'package:zippup/services/payments/payments_service.dart';

class CartScreen extends ConsumerWidget {
	const CartScreen({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		final items = ref.watch(cartProvider);
		final total = ref.read(cartProvider.notifier).total;
		return Scaffold(
			appBar: AppBar(title: const Text('Cart')),
			body: items.isEmpty
					? const Center(child: Text('Cart is empty'))
					: ListView.separated(
						padding: const EdgeInsets.all(16),
						itemCount: items.length,
						separatorBuilder: (_, __) => const Divider(height: 1),
						itemBuilder: (context, i) => ListTile(
							title: Text(items[i].title),
							subtitle: Text('x${items[i].quantity}'),
							trailing: Text('₦${(items[i].price * items[i].quantity).toStringAsFixed(2)}'),
						),
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
		final service = PaymentsService();
		final currency = 'NGN';
		late String url;
		if (provider == 'stripe') {
			url = await service.createStripeCheckout(amount: total, currency: currency);
		} else {
			url = await service.createFlutterwaveCheckout(amount: total, currency: currency);
		}
		if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
			ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open checkout')));
		}
	}
}