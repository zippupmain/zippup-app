class CartItem {
	final String id;
	final String vendorId;
	final String title;
	final double price;
	final int quantity;

	const CartItem({required this.id, required this.vendorId, required this.title, required this.price, required this.quantity});

	CartItem copyWith({int? quantity}) => CartItem(id: id, vendorId: vendorId, title: title, price: price, quantity: quantity ?? this.quantity);

	Map<String, dynamic> toMap() => {'id': id, 'vendorId': vendorId, 'title': title, 'price': price, 'quantity': quantity};
}