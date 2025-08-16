import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippup/features/cart/models/cart_item.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
	CartNotifier() : super(const []);

	void add(CartItem item) {
		// Enforce single-vendor checkout
		if (state.isNotEmpty && state.first.vendorId != item.vendorId) {
			return; // ignore add; require checkout/clear first
		}
		final existingIndex = state.indexWhere((e) => e.id == item.id);
		if (existingIndex >= 0) {
			final updated = [...state];
			updated[existingIndex] = updated[existingIndex].copyWith(quantity: updated[existingIndex].quantity + item.quantity);
			state = updated;
			return;
		}
		state = [...state, item];
	}

	void remove(String id) => state = state.where((e) => e.id != id).toList();

	double get total => state.fold(0, (sum, item) => sum + item.price * item.quantity);

	void clear() => state = const [];
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());