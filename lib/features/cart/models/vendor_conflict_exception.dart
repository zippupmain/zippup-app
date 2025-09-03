import 'package:zippup/features/cart/models/cart_item.dart';

/// Exception thrown when trying to add items from different vendors to cart
class VendorConflictException implements Exception {
  final String currentVendorId;
  final String newVendorId;
  final CartItem newItem;
  final String message;

  const VendorConflictException({
    required this.currentVendorId,
    required this.newVendorId,
    required this.newItem,
    this.message = 'Cannot add items from different vendors to the same cart',
  });

  @override
  String toString() {
    return 'VendorConflictException: $message (current: $currentVendorId, new: $newVendorId)';
  }
}