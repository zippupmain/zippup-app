import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippup/features/cart/models/cart_item.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
	CartNotifier() : super(const []);

	bool canAddFromVendor(String vendorId) {
		return state.isEmpty || state.first.vendorId == vendorId;
	}

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

	void setQuantity(String id, int quantity) {
		if (quantity <= 0) {
			remove(id);
			return;
		}
		final i = state.indexWhere((e) => e.id == id);
		if (i < 0) return;
		final updated = [...state];
		updated[i] = updated[i].copyWith(quantity: quantity);
		state = updated;
	}

	void increment(String id) {
		final i = state.indexWhere((e) => e.id == id);
		if (i < 0) return;
		setQuantity(id, state[i].quantity + 1);
	}

	void decrement(String id) {
		final i = state.indexWhere((e) => e.id == id);
		if (i < 0) return;
		setQuantity(id, state[i].quantity - 1);
	}

	void remove(String id) => state = state.where((e) => e.id != id).toList();

	double get total => state.fold(0, (sum, item) => sum + item.price * item.quantity);

	void clear() => state = const [];
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) => CartNotifier());