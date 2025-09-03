import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zippup/features/cart/models/cart_item.dart';

/// Represents a saved cart for later checkout
class SavedCart {
  final String id;
  final String customerId;
  final String vendorId;
  final String vendorName;
  final List<CartItem> items;
  final double subtotal;
  final DateTime savedAt;
  final DateTime expiresAt;

  const SavedCart({
    required this.id,
    required this.customerId,
    required this.vendorId,
    required this.vendorName,
    required this.items,
    required this.subtotal,
    required this.savedAt,
    required this.expiresAt,
  });

  factory SavedCart.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final itemsData = List<Map<String, dynamic>>.from(data['items'] ?? []);
    
    return SavedCart(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      vendorId: data['vendorId'] ?? '',
      vendorName: data['vendorName'] ?? 'Unknown Vendor',
      items: itemsData.map((itemData) => CartItem(
        id: itemData['id'] ?? '',
        vendorId: itemData['vendorId'] ?? '',
        title: itemData['title'] ?? '',
        price: (itemData['price'] as num?)?.toDouble() ?? 0.0,
        quantity: (itemData['quantity'] as num?)?.toInt() ?? 1,
      )).toList(),
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      savedAt: (data['savedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(Duration(days: 7)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'savedAt': Timestamp.fromDate(savedAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
}