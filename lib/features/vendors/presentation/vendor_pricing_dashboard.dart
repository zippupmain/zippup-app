import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Vendor Pricing Management Dashboard
/// Allows vendors to set and manage their own pricing (when authorized)
class VendorPricingDashboard extends StatefulWidget {
  const VendorPricingDashboard({super.key});

  @override
  State<VendorPricingDashboard> createState() => _VendorPricingDashboardState();
}

class _VendorPricingDashboardState extends State<VendorPricingDashboard> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _vendorId;
  bool _pricingEnabled = false;
  bool _loading = true;
  
  // Pricing metrics
  int _totalItems = 0;
  double _avgPrice = 0.0;
  int _changesThisWeek = 0;
  double _priceRating = 0.0;
  int _healthScore = 0;

  // UI state
  String _itemFilter = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeVendor();
  }

  Future<void> _initializeVendor() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Find vendor profile for current user
      final vendorQuery = await _db.collection('vendors')
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (vendorQuery.docs.isNotEmpty) {
        final vendorData = vendorQuery.docs.first.data();
        final pricingConfig = Map<String, dynamic>.from(vendorData['pricingConfiguration'] ?? {});

        setState(() {
          _vendorId = vendorQuery.docs.first.id;
          _pricingEnabled = pricingConfig['isPricingEnabled'] as bool? ?? false;
          _loading = false;
        });

        await _loadMetrics();
      } else {
        setState(() => _loading = false);
      }

    } catch (e) {
      print('❌ Error initializing vendor: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadMetrics() async {
    if (_vendorId == null) return;

    try {
      // Load pricing metrics
      final metrics = await _getVendorMetrics(_vendorId!);
      
      setState(() {
        _totalItems = metrics['totalItems'] ?? 0;
        _avgPrice = (metrics['avgPrice'] as num?)?.toDouble() ?? 0.0;
        _changesThisWeek = metrics['changesThisWeek'] ?? 0;
        _priceRating = (metrics['priceRating'] as num?)?.toDouble() ?? 0.0;
        _healthScore = metrics['healthScore'] ?? 0;
      });

    } catch (e) {
      print('❌ Error loading metrics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_vendorId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pricing Management')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Vendor profile not found'),
              Text('Please contact support'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pricing Management'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showPricingHelp(),
            icon: const Icon(Icons.help_outline),
          ),
          IconButton(
            onPressed: () => _showPricingSettings(),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Column(
        children: [
          // Pricing status and metrics
          _buildPricingStatusSection(),
          
          // Search and filters
          _buildSearchAndFilters(),
          
          // Items list
          Expanded(child: _buildItemsList()),
        ],
      ),
      floatingActionButton: _pricingEnabled ? FloatingActionButton.extended(
        onPressed: () => _showBulkPricingTools(),
        icon: const Icon(Icons.tune),
        label: const Text('Bulk Tools'),
        backgroundColor: Colors.orange.shade600,
      ) : null,
    );
  }

  Widget _buildPricingStatusSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade600, Colors.orange.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pricing status header
          Row(
            children: [
              Icon(
                _pricingEnabled ? Icons.check_circle : Icons.block,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pricingEnabled ? 'Pricing Control Active' : 'Pricing Control Suspended',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _pricingEnabled 
                        ? 'You have full control over your pricing'
                        : 'Contact admin to restore pricing rights',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Health score badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.health_and_safety, color: Colors.white, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Health: $_healthScore%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Metrics row
          Row(
            children: [
              Expanded(child: _buildMetricItem('Items', '$_totalItems', Icons.inventory)),
              Expanded(child: _buildMetricItem('Avg Price', '₦${_avgPrice.toStringAsFixed(0)}', Icons.attach_money)),
              Expanded(child: _buildMetricItem('Changes', '$_changesThisWeek/week', Icons.trending_up)),
              Expanded(child: _buildMetricItem('Rating', '${_priceRating.toStringAsFixed(1)}/5', Icons.star)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade50,
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search items...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (query) => setState(() => _searchQuery = query),
          ),
          
          const SizedBox(height: 12),
          
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Items'),
                  selected: _itemFilter == 'all',
                  onSelected: (selected) => setState(() => _itemFilter = 'all'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Custom Pricing'),
                  selected: _itemFilter == 'custom',
                  onSelected: (selected) => setState(() => _itemFilter = 'custom'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Pending Review'),
                  selected: _itemFilter == 'pending',
                  onSelected: (selected) => setState(() => _itemFilter = 'pending'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Best Sellers'),
                  selected: _itemFilter == 'bestsellers',
                  onSelected: (selected) => setState(() => _itemFilter = 'bestsellers'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Low Stock'),
                  selected: _itemFilter == 'lowstock',
                  onSelected: (selected) => setState(() => _itemFilter = 'lowstock'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _getItemsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!.docs;

        if (items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('No items found'),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty 
                    ? 'Try adjusting your search'
                    : 'Add items to start managing pricing',
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final itemData = items[index].data();
            return VendorItemPricingCard(
              itemId: items[index].id,
              itemData: itemData,
              pricingEnabled: _pricingEnabled,
              onPriceUpdate: _updateItemPrice,
              onViewAnalytics: _viewItemAnalytics,
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getItemsStream() {
    Query<Map<String, dynamic>> query = _db.collection('items')
        .where('vendorId', isEqualTo: _vendorId)
        .where('isActive', isEqualTo: true);

    // Apply filters
    switch (_itemFilter) {
      case 'custom':
        query = query.where('pricing.isUsingCustomPrice', isEqualTo: true);
        break;
      case 'pending':
        query = query.where('pricing.adminReview.status', isEqualTo: 'pending');
        break;
      case 'bestsellers':
        query = query.orderBy('salesMetrics.totalSold', descending: true);
        break;
      case 'lowstock':
        query = query.where('inventory.currentStock', isLessThan: 10);
        break;
      default:
        query = query.orderBy('name');
    }

    return query.snapshots();
  }

  Future<void> _updateItemPrice(String itemId, double newPrice, String reason) async {
    if (!_pricingEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pricing control is currently suspended'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Call pricing update API (would be implemented as Firebase Function)
      await _db.collection('items').doc(itemId).update({
        'pricing.currentPrice': newPrice,
        'pricing.lastPriceUpdate': FieldValue.serverTimestamp(),
        'pricing.priceUpdatedBy': FirebaseAuth.instance.currentUser?.uid,
        'pricing.isUsingCustomPrice': true,
        'pricing.priceSource': 'vendor',
        'pricing.priceHistory': FieldValue.arrayUnion({
          'price': newPrice,
          'timestamp': FieldValue.serverTimestamp(),
          'reason': reason,
          'updatedBy': FirebaseAuth.instance.currentUser?.uid,
        }),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Price updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Reload metrics
      await _loadMetrics();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating price: $e')),
      );
    }
  }

  void _viewItemAnalytics(String itemId) {
    showDialog(
      context: context,
      builder: (context) => ItemAnalyticsDialog(itemId: itemId),
    );
  }

  void _showBulkPricingTools() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BulkPricingToolsSheet(
        vendorId: _vendorId!,
        onBulkUpdate: _handleBulkPriceUpdate,
      ),
    );
  }

  Future<void> _handleBulkPriceUpdate(List<Map<String, dynamic>> updates, String reason) async {
    try {
      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Updating ${updates.length} items...'),
            ],
          ),
        ),
      );

      // Process bulk update (would call Firebase Function)
      for (final update in updates) {
        await _updateItemPrice(update['itemId'], update['newPrice'], reason);
      }

      Navigator.pop(context); // Close progress dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully updated ${updates.length} items'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      Navigator.pop(context); // Close progress dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bulk update failed: $e')),
      );
    }
  }

  void _showPricingHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pricing Guidelines'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💰 Pricing Best Practices:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Keep prices competitive with market rates'),
              Text('• Avoid frequent price changes (max 3-5 per week)'),
              Text('• Price increases above 20% may require admin approval'),
              Text('• Consider customer feedback when adjusting prices'),
              
              SizedBox(height: 16),
              Text('📊 Use Analytics:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Monitor demand trends for optimal pricing'),
              Text('• Check competitor pricing regularly'),
              Text('• Track profit margins and revenue impact'),
              
              SizedBox(height: 16),
              Text('⚠️ Pricing Violations:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Excessive price increases (>200%) may be flagged'),
              Text('• Predatory pricing below cost is prohibited'),
              Text('• Rapid price changes may trigger review'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showPricingSettings() {
    // Show pricing preferences and settings
  }

  // Helper methods
  Future<Map<String, dynamic>> _getVendorMetrics(String vendorId) async {
    // This would typically call a Firebase Function for complex metrics
    // For now, return mock data
    return {
      'totalItems': 25,
      'avgPrice': 1850.0,
      'changesThisWeek': 3,
      'priceRating': 4.2,
      'healthScore': 85,
    };
  }
}

/// Individual item pricing card for vendors
class VendorItemPricingCard extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> itemData;
  final bool pricingEnabled;
  final Function(String, double, String) onPriceUpdate;
  final Function(String) onViewAnalytics;

  const VendorItemPricingCard({
    super.key,
    required this.itemId,
    required this.itemData,
    required this.pricingEnabled,
    required this.onPriceUpdate,
    required this.onViewAnalytics,
  });

  @override
  State<VendorItemPricingCard> createState() => _VendorItemPricingCardState();
}

class _VendorItemPricingCardState extends State<VendorItemPricingCard> {
  late TextEditingController _priceController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    final currentPrice = (widget.itemData['pricing']?['currentPrice'] as num?)?.toDouble() ?? 0.0;
    _priceController = TextEditingController(text: currentPrice.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itemName = widget.itemData['name'] as String? ?? 'Unknown Item';
    final category = widget.itemData['category'] as String? ?? 'Uncategorized';
    final pricing = Map<String, dynamic>.from(widget.itemData['pricing'] ?? {});
    final currentPrice = (pricing['currentPrice'] as num?)?.toDouble() ?? 0.0;
    final salesMetrics = Map<String, dynamic>.from(widget.itemData['salesMetrics'] ?? {});
    final inventory = Map<String, dynamic>.from(widget.itemData['inventory'] ?? {});
    final adminReview = Map<String, dynamic>.from(pricing['adminReview'] ?? {});

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item header
            Row(
              children: [
                // Item image placeholder
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.fastfood, color: Colors.grey.shade400),
                ),
                
                const SizedBox(width: 12),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        itemName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        category,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      
                      // Item metrics
                      Row(
                        children: [
                          Icon(Icons.trending_up, size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          Text('${salesMetrics['totalSold'] ?? 0} sold'),
                          const SizedBox(width: 12),
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text('${(salesMetrics['averageRating'] ?? 0.0).toStringAsFixed(1)}'),
                          const SizedBox(width: 12),
                          if ((inventory['currentStock'] as int? ?? 0) < 10)
                            Row(
                              children: [
                                Icon(Icons.warning, size: 16, color: Colors.red),
                                const SizedBox(width: 4),
                                Text('Low stock', style: TextStyle(color: Colors.red, fontSize: 12)),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Price section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (_isEditing) ...[
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            prefixText: '₦',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        '₦${currentPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                    
                    // Admin review status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getReviewStatusColor(adminReview['status']),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _getReviewStatusText(adminReview['status']),
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Pricing controls
            if (widget.pricingEnabled) Row(
              children: [
                // Quick adjustment buttons
                IconButton(
                  onPressed: () => _quickAdjustPrice(-100),
                  icon: Icon(Icons.remove_circle, color: Colors.red),
                  tooltip: 'Decrease ₦100',
                ),
                
                Expanded(
                  child: Slider(
                    value: currentPrice,
                    min: 100,
                    max: 10000,
                    divisions: 99,
                    label: '₦${currentPrice.toStringAsFixed(0)}',
                    onChanged: (value) => _onPriceSliderChanged(value),
                    onChangeEnd: (value) => _onPriceChangeEnd(value),
                  ),
                ),
                
                IconButton(
                  onPressed: () => _quickAdjustPrice(100),
                  icon: Icon(Icons.add_circle, color: Colors.green),
                  tooltip: 'Increase ₦100',
                ),
                
                // Edit button
                IconButton(
                  onPressed: () => _toggleEditMode(),
                  icon: Icon(_isEditing ? Icons.check : Icons.edit),
                  color: _isEditing ? Colors.green : Colors.blue,
                ),
              ],
            ) else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Text(
                      'Pricing controlled by admin',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Analytics preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildAnalyticChip('Revenue', '₦${salesMetrics['revenue'] ?? 0}')),
                  Expanded(child: _buildAnalyticChip('Margin', '${((salesMetrics['profitMargin'] ?? 0) * 100).toStringAsFixed(0)}%')),
                  Expanded(child: _buildAnalyticChip('Demand', _getDemandTrend(salesMetrics))),
                  IconButton(
                    onPressed: () => widget.onViewAnalytics(widget.itemId),
                    icon: Icon(Icons.analytics, color: Colors.blue.shade700),
                    tooltip: 'View detailed analytics',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticChip(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue.shade600,
          ),
        ),
      ],
    );
  }

  void _quickAdjustPrice(double adjustment) {
    final currentPrice = (widget.itemData['pricing']?['currentPrice'] as num?)?.toDouble() ?? 0.0;
    final newPrice = math.max(100, currentPrice + adjustment); // Minimum ₦100
    
    _showPriceUpdateDialog(newPrice, 'Quick price adjustment');
  }

  void _onPriceSliderChanged(double value) {
    setState(() {
      _priceController.text = value.toStringAsFixed(0);
    });
  }

  void _onPriceChangeEnd(double value) {
    _showPriceUpdateDialog(value, 'Price slider adjustment');
  }

  void _toggleEditMode() {
    if (_isEditing) {
      // Save price
      final newPrice = double.tryParse(_priceController.text);
      if (newPrice != null && newPrice > 0) {
        _showPriceUpdateDialog(newPrice, 'Manual price edit');
      }
    }
    
    setState(() => _isEditing = !_isEditing);
  }

  void _showPriceUpdateDialog(double newPrice, String defaultReason) {
    final reasonController = TextEditingController(text: defaultReason);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Price'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Update price to ₦${newPrice.toStringAsFixed(0)}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for change',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onPriceUpdate(widget.itemId, newPrice, reasonController.text.trim());
            },
            child: const Text('Update Price'),
          ),
        ],
      ),
    );
  }

  // Helper methods
  Color _getReviewStatusColor(String? status) {
    switch (status) {
      case 'approved': return Colors.green;
      case 'pending': return Colors.orange;
      case 'flagged': return Colors.red;
      case 'auto_approved': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _getReviewStatusText(String? status) {
    switch (status) {
      case 'approved': return 'APPROVED';
      case 'pending': return 'PENDING';
      case 'flagged': return 'FLAGGED';
      case 'auto_approved': return 'AUTO-OK';
      default: return 'UNKNOWN';
    }
  }

  String _getDemandTrend(Map<String, dynamic> salesMetrics) {
    final orderFrequency = (salesMetrics['orderFrequency'] as num?)?.toDouble() ?? 0.0;
    
    if (orderFrequency > 5) return '📈 High';
    if (orderFrequency > 2) return '📊 Medium';
    if (orderFrequency > 0.5) return '📉 Low';
    return '❌ None';
  }
}

/// Bulk pricing tools bottom sheet
class BulkPricingToolsSheet extends StatefulWidget {
  final String vendorId;
  final Function(List<Map<String, dynamic>>, String) onBulkUpdate;

  const BulkPricingToolsSheet({
    super.key,
    required this.vendorId,
    required this.onBulkUpdate,
  });

  @override
  State<BulkPricingToolsSheet> createState() => _BulkPricingToolsSheetState();
}

class _BulkPricingToolsSheetState extends State<BulkPricingToolsSheet> {
  String _bulkAction = 'percentage';
  double _adjustmentValue = 10.0;
  String _selectedCategory = 'all';
  final TextEditingController _reasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.orange.shade600,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Icon(Icons.tune, color: Colors.white),
                const SizedBox(width: 12),
                const Text(
                  'Bulk Pricing Tools',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          // Bulk action controls
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action type selection
                  const Text('Adjustment Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _bulkAction,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'percentage', child: Text('Percentage Increase/Decrease')),
                      DropdownMenuItem(value: 'fixed', child: Text('Fixed Amount Increase/Decrease')),
                      DropdownMenuItem(value: 'set', child: Text('Set to Specific Value')),
                      DropdownMenuItem(value: 'optimize', child: Text('AI Price Optimization')),
                    ],
                    onChanged: (value) => setState(() => _bulkAction = value!),
                  ),

                  const SizedBox(height: 16),

                  // Adjustment value
                  const Text('Adjustment Value:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      suffixText: _bulkAction == 'percentage' ? '%' : '₦',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) => _adjustmentValue = double.tryParse(value) ?? 0.0,
                  ),

                  const SizedBox(height: 16),

                  // Category filter
                  const Text('Apply to:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Items')),
                      DropdownMenuItem(value: 'bestsellers', child: Text('Best Sellers Only')),
                      DropdownMenuItem(value: 'lowstock', child: Text('Low Stock Items')),
                      DropdownMenuItem(value: 'category', child: Text('Specific Category')),
                    ],
                    onChanged: (value) => setState(() => _selectedCategory = value!),
                  ),

                  const SizedBox(height: 16),

                  // Reason
                  const Text('Reason:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Explain why you\'re making this change',
                    ),
                    maxLines: 2,
                  ),

                  const Spacer(),

                  // Preview and apply
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _previewBulkChanges(),
                          icon: const Icon(Icons.preview),
                          label: const Text('Preview Changes'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: () => _applyBulkChanges(),
                          icon: const Icon(Icons.update),
                          label: const Text('Apply Changes'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _previewBulkChanges() {
    // Show preview of bulk changes
  }

  void _applyBulkChanges() {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for the bulk change')),
      );
      return;
    }

    // Generate bulk update data and apply
    final updates = <Map<String, dynamic>>[];
    // Implementation would generate updates based on selected criteria
    
    widget.onBulkUpdate(updates, _reasonController.text.trim());
    Navigator.pop(context);
  }
}