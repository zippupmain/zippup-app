import 'package:flutter/material.dart';
import 'package:zippup/features/cart/models/cart_item.dart';

/// Dialog shown when user tries to add items from different vendor
class VendorConflictDialog extends StatelessWidget {
  final String currentVendorName;
  final String newVendorName;
  final CartItem newItem;
  final VoidCallback onReplaceCart;
  final VoidCallback onSaveCurrentCart;
  final VoidCallback onCancel;

  const VendorConflictDialog({
    super.key,
    required this.currentVendorName,
    required this.newVendorName,
    required this.newItem,
    required this.onReplaceCart,
    required this.onSaveCurrentCart,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 12),
          Text('Different Vendor'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your cart contains items from ${currentVendorName}, but you\'re trying to add an item from ${newVendorName}.',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You can only order from one vendor at a time.',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          Text(
            'What would you like to do?',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      actions: [
        // Cancel action
        TextButton.icon(
          onPressed: onCancel,
          icon: Icon(Icons.close),
          label: Text('Cancel'),
          style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
        ),
        
        // Replace cart action
        TextButton.icon(
          onPressed: onReplaceCart,
          icon: Icon(Icons.delete_sweep),
          label: Text('Replace Cart'),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
        ),
        
        // Save and continue action
        FilledButton.icon(
          onPressed: onSaveCurrentCart,
          icon: Icon(Icons.bookmark_add),
          label: Text('Save & Continue'),
        ),
      ],
      actionsPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
    );
  }

  /// Show vendor conflict dialog
  static Future<VendorConflictAction?> show({
    required BuildContext context,
    required String currentVendorName,
    required String newVendorName,
    required CartItem newItem,
  }) async {
    return await showDialog<VendorConflictAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => VendorConflictDialog(
        currentVendorName: currentVendorName,
        newVendorName: newVendorName,
        newItem: newItem,
        onReplaceCart: () => Navigator.pop(context, VendorConflictAction.replaceCart),
        onSaveCurrentCart: () => Navigator.pop(context, VendorConflictAction.saveCurrentCart),
        onCancel: () => Navigator.pop(context, VendorConflictAction.cancel),
      ),
    );
  }
}

enum VendorConflictAction {
  replaceCart,
  saveCurrentCart, 
  cancel,
}

/// Helper widget for cart action buttons
class CartActionHelper {
  /// Handle adding item with vendor conflict resolution
  static Future<void> addItemWithConflictResolution({
    required BuildContext context,
    required CartItem newItem,
    required Function(CartItem) onAddItem,
    required Function(List<CartItem>) onReplaceCart,
    required Function(CartItem, String) onSaveAndContinue,
    required String customerId,
    required List<CartItem> currentCart,
  }) async {
    try {
      // Try to add item normally
      onAddItem(newItem);
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${newItem.title} added to cart'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      
    } on VendorConflictException catch (e) {
      // Get vendor names for dialog
      final currentVendorName = await _getVendorName(e.currentVendorId);
      final newVendorName = await _getVendorName(e.newVendorId);
      
      // Show conflict resolution dialog
      final action = await VendorConflictDialog.show(
        context: context,
        currentVendorName: currentVendorName,
        newVendorName: newVendorName,
        newItem: newItem,
      );

      switch (action) {
        case VendorConflictAction.replaceCart:
          onReplaceCart([newItem]);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Cart replaced with ${newItem.title}'),
              backgroundColor: Colors.orange,
            ),
          );
          break;
          
        case VendorConflictAction.saveCurrentCart:
          await onSaveAndContinue(newItem, customerId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Previous cart saved. ${newItem.title} added to new cart.'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 3),
            ),
          );
          break;
          
        case VendorConflictAction.cancel:
        case null:
          // Do nothing - user cancelled
          break;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding item: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<String> _getVendorName(String vendorId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('vendors').doc(vendorId).get();
      return doc.data()?['businessName'] ?? 'Unknown Vendor';
    } catch (e) {
      return 'Unknown Vendor';
    }
  }
}