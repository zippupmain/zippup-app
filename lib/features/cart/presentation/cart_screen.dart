import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zippup/features/cart/providers/cart_provider.dart';
import 'package:zippup/features/cart/models/cart_item.dart';
import 'package:zippup/features/cart/models/saved_cart.dart';
import 'package:zippup/services/payments/payments_service.dart';
import 'package:zippup/services/delivery/delivery_code_service.dart';

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
					? _buildEmptyCartWithSavedCarts(context, ref)
					: ListView.separated(
						padding: const EdgeInsets.all(16),
						itemCount: items.length,
						separatorBuilder: (_, __) => const Divider(height: 1),
						itemBuilder: (context, i) {
							final item = items[i];
							return ListTile(
								isThreeLine: true,
								title: Text(item.title),
								subtitle: Column(
									crossAxisAlignment: CrossAxisAlignment.start,
									children: [
										Row(children: [
											IconButton(onPressed: () => notifier.decrement(item.id), icon: const Icon(Icons.remove_circle_outline)),
											Text('x${item.quantity}'),
											IconButton(onPressed: () => notifier.increment(item.id), icon: const Icon(Icons.add_circle_outline)),
										]),
										TextButton(onPressed: () => notifier.remove(item.id), child: const Text('Remove')),
									],
								),
								trailing: Text('₦${(item.price * item.quantity).toStringAsFixed(2)}'),
							);
						},
					),
			bottomNavigationBar: SafeArea(
				child: Padding(
					padding: const EdgeInsets.all(12),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						crossAxisAlignment: CrossAxisAlignment.stretch,
						children: [
							if (vendorLocked)
								Row(children: [
									const Icon(Icons.store_mall_directory, size: 16),
									const SizedBox(width: 6),
									Expanded(child: Text('Items from a single vendor. To change vendor, clear cart.')),
								]),
							Text('Total: ₦${total.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium),
							const SizedBox(height: 8),
							FilledButton(onPressed: () => _checkout(context, items, total, 'stripe'), child: const Text('Pay with Stripe')),
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

	Widget _buildEmptyCartWithSavedCarts(BuildContext context, WidgetRef ref) {
		final userId = FirebaseAuth.instance.currentUser?.uid;
		
		if (userId == null) {
			return const Center(child: Text('Cart is empty'));
		}

		return FutureBuilder<List<SavedCart>>(
			future: ref.read(cartProvider.notifier).getSavedCarts(userId),
			builder: (context, snapshot) {
				if (snapshot.connectionState == ConnectionState.waiting) {
					return const Center(child: CircularProgressIndicator());
				}

				final savedCarts = snapshot.data ?? [];

				return Center(
					child: Column(
						mainAxisAlignment: MainAxisAlignment.center,
						children: [
							Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey.shade400),
							const SizedBox(height: 16),
							const Text('Your cart is empty', style: TextStyle(fontSize: 18)),
							
							if (savedCarts.isNotEmpty) ...[
								const SizedBox(height: 32),
								const Text('Saved Carts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
								const SizedBox(height: 16),
								
								...savedCarts.map((savedCart) => Card(
									margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
									child: ListTile(
										leading: Icon(Icons.bookmark, color: Colors.orange),
										title: Text(savedCart.vendorName),
										subtitle: Text('${savedCart.itemCount} items • ₦${savedCart.subtotal.toStringAsFixed(0)}'),
										trailing: Row(
											mainAxisSize: MainAxisSize.min,
											children: [
												IconButton(
													onPressed: () => _loadSavedCart(context, ref, savedCart),
													icon: Icon(Icons.restore),
												),
												IconButton(
													onPressed: () => _deleteSavedCart(savedCart.id),
													icon: Icon(Icons.delete, color: Colors.red),
												),
											],
										),
									),
								)),
							],
						],
					),
				);
			},
		);
	}

	void _loadSavedCart(BuildContext context, WidgetRef ref, SavedCart savedCart) {
		ref.read(cartProvider.notifier).replaceCart(savedCart.items);
		ScaffoldMessenger.of(context).showSnackBar(
			SnackBar(
				content: Text('Loaded cart from ${savedCart.vendorName}'),
				backgroundColor: Colors.green,
			),
		);
	}

	Future<void> _deleteSavedCart(String savedCartId) async {
		try {
			await FirebaseFirestore.instance.collection('saved_carts').doc(savedCartId).delete();
		} catch (e) {
			print('❌ Error deleting saved cart: $e');
		}
	}
}