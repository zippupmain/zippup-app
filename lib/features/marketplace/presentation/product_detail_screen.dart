import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zippup/features/food/providers/order_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippup/features/cart/providers/cart_provider.dart';
import 'package:zippup/features/cart/models/cart_item.dart';
import 'package:zippup/services/location/location_service.dart';
import 'package:zippup/common/models/order.dart';

class ProductDetailScreen extends ConsumerWidget {
	const ProductDetailScreen({super.key, required this.productId});
	final String productId;
	@override
	Widget build(BuildContext context, WidgetRef ref) {
		return Scaffold(
			appBar: AppBar(title: const Text('Listing')),
			body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
				future: FirebaseFirestore.instance.collection('listings').doc(productId).get(),
				builder: (context, snap) {
					if (!snap.hasData) return const Center(child: CircularProgressIndicator());
					final p = snap.data!.data() ?? {};
					return Padding(
						padding: const EdgeInsets.all(16),
						child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
							Text(p['title'] ?? 'Item', style: Theme.of(context).textTheme.titleLarge),
							const SizedBox(height: 8),
							Text('Category: ${p['category'] ?? ''}'),
							Text('Price: ${p['price'] ?? ''}'),
							const Spacer(),
							Row(children: [
								OutlinedButton(onPressed: () => _checkout(context, p), child: const Text('Buy now')),
								const SizedBox(width: 8),
								FilledButton(onPressed: () { _addToCart(ref, p); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart'))); }, child: const Text('Add to cart')),
							]),
						]),
					);
				},
			),
		);
	}

	void _addToCart(WidgetRef ref, Map<String, dynamic> p) {
		final price = (p['price'] is num) ? (p['price'] as num).toDouble() : 0;
		final vendorId = (p['sellerId'] ?? '').toString();
		ref.read(cartProvider.notifier).add(CartItem(id: productId, vendorId: vendorId, title: (p['title'] ?? 'Item').toString(), price: price.toDouble(), quantity: 1));
	}

	Future<void> _checkout(BuildContext context, Map<String, dynamic> p) async {
		final sellerId = (p['sellerId'] ?? '').toString();
		if (sellerId.isEmpty) return;
		bool delivery = (p['deliveryEnabled'] == true);
		final destController = TextEditingController();
		double deliveryFee = 0;
		final base = (p['deliveryBaseFee'] is num) ? (p['deliveryBaseFee'] as num).toDouble() : 0;
		final perKm = (p['deliveryPerKm'] is num) ? (p['deliveryPerKm'] as num).toDouble() : 0;
		await showModalBottomSheet(context: context, isScrollControlled: true, builder: (ctx) {
			return Padding(
				padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
				child: StatefulBuilder(builder: (ctx, setState) => Column(mainAxisSize: MainAxisSize.min, children: [
					if (p['deliveryEnabled'] == true)
						SwitchListTile(title: const Text('Delivery'), subtitle: const Text('Toggle off for Pickup'), value: delivery, onChanged: (v) => setState(()=> delivery=v)),
					if (delivery)
						TextField(controller: destController, decoration: const InputDecoration(labelText: 'Delivery address (optional)')),
					const SizedBox(height: 12),
					FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
				]))
			);
		});
		// compute delivery fee if delivery
		if (delivery && (base > 0 || perKm > 0)) {
			try {
				final me = await LocationService.getCurrentPosition();
				final destLat = p['pickupLat'] is num ? (p['pickupLat'] as num).toDouble() : null;
				final destLng = p['pickupLng'] is num ? (p['pickupLng'] as num).toDouble() : null;
				if (me != null && destLat != null && destLng != null) {
					final dx = (me.latitude - destLat); final dy = (me.longitude - destLng);
					final km = (dx.abs() + dy.abs()) * 111; // rough estimate; refine later
					deliveryFee = (base + perKm * km).toDouble();
				}
			} catch (_) {}
		}
		// create order
		final price = (p['price'] is num) ? (p['price'] as num).toDouble() : 0;
		final orderId = await OrderService().createOrder(category: OrderCategory.marketplace, providerId: sellerId, extra: {
			'price': price,
			'platformFee': null,
			'deliveryFee': delivery ? deliveryFee : 0,
		});
		if (context.mounted) {
			ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order ${orderId.substring(0,6)} created')));
		}
	}
}