import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippup/features/cart/models/cart_item.dart';
import 'package:zippup/features/cart/models/saved_cart.dart';
import 'package:zippup/features/cart/models/vendor_conflict_exception.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
	CartNotifier() : super(const []);

	bool canAddFromVendor(String vendorId) {
		return state.isEmpty || state.first.vendorId == vendorId;
	}

	void add(CartItem item) {
		// Enforce single-vendor checkout
		if (state.isNotEmpty && state.first.vendorId != item.vendorId) {
			// Don't automatically replace - this should trigger a dialog in the UI
			throw VendorConflictException(
				currentVendorId: state.first.vendorId,
				newVendorId: item.vendorId,
				newItem: item,
			);
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

	// Replace entire cart with new vendor's items
	void replaceCart(List<CartItem> newItems) {
		state = newItems;
	}

	// Save current cart and start new one
	Future<void> saveCurrentCartAndStartNew(CartItem newItem, String customerId) async {
		if (state.isNotEmpty) {
			await _saveCartToFirestore(customerId);
		}
		state = [newItem];
	}

	// Save cart to Firestore for later
	Future<void> _saveCartToFirestore(String customerId) async {
		if (state.isEmpty) return;

		try {
			final vendorId = state.first.vendorId;
			final vendorName = await _getVendorName(vendorId);
			
			await FirebaseFirestore.instance.collection('saved_carts').add({
				'customerId': customerId,
				'vendorId': vendorId,
				'vendorName': vendorName,
				'items': state.map((item) => item.toMap()).toList(),
				'subtotal': _calculateSubtotal(),
				'savedAt': FieldValue.serverTimestamp(),
				'expiresAt': Timestamp.fromDate(DateTime.now().add(Duration(days: 7))),
			});

			print('✅ Cart saved for vendor: $vendorName');
		} catch (e) {
			print('❌ Error saving cart: $e');
		}
	}

	// Load saved carts for customer
	Future<List<SavedCart>> getSavedCarts(String customerId) async {
		try {
			final snapshot = await FirebaseFirestore.instance
				.collection('saved_carts')
				.where('customerId', isEqualTo: customerId)
				.where('expiresAt', isGreaterThan: Timestamp.now())
				.orderBy('savedAt', descending: true)
				.get();

			return snapshot.docs.map((doc) => SavedCart.fromFirestore(doc)).toList();
		} catch (e) {
			print('❌ Error loading saved carts: $e');
			return [];
		}
	}

	double _calculateSubtotal() {
		return state.fold<double>(0, (sum, item) => sum + (item.price * item.quantity));
	}

	Future<String> _getVendorName(String vendorId) async {
		try {
			final doc = await FirebaseFirestore.instance.collection('vendors').doc(vendorId).get();
			return doc.data()?['businessName'] ?? 'Unknown Vendor';
		} catch (e) {
			return 'Unknown Vendor';
		}
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