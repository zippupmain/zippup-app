import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Admin Pricing Control Dashboard
/// Provides comprehensive pricing management, vendor oversight, and analytics
class AdminPricingDashboard extends StatefulWidget {
  const AdminPricingDashboard({super.key});

  @override
  State<AdminPricingDashboard> createState() => _AdminPricingDashboardState();
}

class _AdminPricingDashboardState extends State<AdminPricingDashboard> 
    with TickerProviderStateMixin {
  
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Dashboard metrics
  int _totalVendors = 0;
  int _autonomousVendors = 0;
  int _pendingReviews = 0;
  int _pricingViolations = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadDashboardMetrics();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardMetrics() async {
    try {
      // Load key metrics in parallel
      final results = await Future.wait([
        _countTotalVendors(),
        _countAutonomousVendors(),
        _countPendingReviews(),
        _countPricingViolations(),
      ]);

      setState(() {
        _totalVendors = results[0];
        _autonomousVendors = results[1];
        _pendingReviews = results[2];
        _pricingViolations = results[3];
      });

    } catch (e) {
      print('❌ Error loading dashboard metrics: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pricing Management'),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.settings), text: 'Templates'),
            Tab(icon: Icon(Icons.store), text: 'Vendors'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
            Tab(icon: Icon(Icons.policy), text: 'Policies'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildTemplatesTab(),
          _buildVendorsTab(),
          _buildAnalyticsTab(),
          _buildPoliciesTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Key metrics cards
          _buildMetricsGrid(),
          
          const SizedBox(height: 24),
          
          // Recent activity
          _buildRecentActivity(),
          
          const SizedBox(height: 24),
          
          // Quick actions
          _buildQuickActions(),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Vendors',
          '$_totalVendors',
          Icons.store,
          Colors.blue,
          'Active vendors on platform',
        ),
        _buildMetricCard(
          'Autonomous Pricing',
          '$_autonomousVendors',
          Icons.auto_awesome,
          Colors.green,
          'Vendors with pricing rights',
        ),
        _buildMetricCard(
          'Pending Reviews',
          '$_pendingReviews',
          Icons.pending,
          Colors.orange,
          'Price changes awaiting approval',
        ),
        _buildMetricCard(
          'Violations',
          '$_pricingViolations',
          Icons.warning,
          Colors.red,
          'Policy violations this week',
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return Column(
      children: [
        // Service selector
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Row(
            children: [
              const Text('Service:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'transport', child: Text('🚗 Transport')),
                    DropdownMenuItem(value: 'emergency', child: Text('🚨 Emergency')),
                    DropdownMenuItem(value: 'moving', child: Text('📦 Moving')),
                    DropdownMenuItem(value: 'hire', child: Text('🔧 Hire')),
                  ],
                  onChanged: (value) => _onServiceSelected(value),
                  hint: const Text('Select service'),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _createNewTemplate(),
                icon: const Icon(Icons.add),
                label: const Text('New Template'),
              ),
            ],
          ),
        ),
        
        // Templates list
        Expanded(child: _buildTemplatesList()),
      ],
    );
  }

  Widget _buildVendorsTab() {
    return Column(
      children: [
        // Vendor filters and search
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade50,
          child: Column(
            children: [
              // Search bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search vendors...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: _onVendorSearchChanged,
              ),
              
              const SizedBox(height: 12),
              
              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('All'),
                      selected: _vendorFilter == 'all',
                      onSelected: (selected) => _setVendorFilter('all'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Autonomous Pricing'),
                      selected: _vendorFilter == 'autonomous',
                      onSelected: (selected) => _setVendorFilter('autonomous'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Pending Review'),
                      selected: _vendorFilter == 'pending',
                      onSelected: (selected) => _setVendorFilter('pending'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Violations'),
                      selected: _vendorFilter == 'violations',
                      onSelected: (selected) => _setVendorFilter('violations'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Vendors list
        Expanded(child: _buildVendorsList()),
      ],
    );
  }

  Widget _buildVendorsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _getVendorsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final vendors = snapshot.data!.docs;

        if (vendors.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.store, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No vendors found'),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: vendors.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final vendorData = vendors[index].data();
            return AdminVendorPricingCard(
              vendorId: vendors[index].id,
              vendorData: vendorData,
              onTogglePricing: _toggleVendorPricing,
              onReviewPricing: _reviewVendorPricing,
              onViewAnalytics: _viewVendorAnalytics,
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getVendorsStream() {
    Query<Map<String, dynamic>> query = _db.collection('vendors');

    // Apply filters
    switch (_vendorFilter) {
      case 'autonomous':
        query = query.where('pricingConfiguration.hasPricingRights', isEqualTo: true);
        break;
      case 'pending':
        // Would need composite index
        break;
      case 'violations':
        // Would need composite index
        break;
    }

    return query.orderBy('businessName').snapshots();
  }

  // Event handlers
  String _vendorFilter = 'all';
  String _searchQuery = '';

  void _onServiceSelected(String? serviceId) {
    // Handle service selection for templates
  }

  void _onVendorSearchChanged(String query) {
    setState(() => _searchQuery = query);
  }

  void _setVendorFilter(String filter) {
    setState(() => _vendorFilter = filter);
  }

  Future<void> _toggleVendorPricing(String vendorId, bool enable) async {
    // Show reason dialog and toggle pricing rights
    final reason = await _showPricingToggleDialog(enable);
    if (reason != null) {
      try {
        // Call API to toggle pricing rights
        // Implementation would call Firebase Function
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enable ? 'Pricing rights enabled' : 'Pricing rights suspended'),
            backgroundColor: enable ? Colors.green : Colors.orange,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<String?> _showPricingToggleDialog(bool enable) async {
    final reasonController = TextEditingController();
    
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(enable ? 'Enable Pricing Rights' : 'Suspend Pricing Rights'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(enable 
              ? 'This vendor will regain full control over their pricing.'
              : 'This vendor will lose pricing control and revert to admin templates.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (required)',
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
            onPressed: () => Navigator.pop(context, reasonController.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: enable ? Colors.green : Colors.red,
            ),
            child: Text(enable ? 'Enable' : 'Suspend'),
          ),
        ],
      ),
    );
  }

  void _reviewVendorPricing(String vendorId) {
    context.push('/admin/vendor-pricing/$vendorId');
  }

  void _viewVendorAnalytics(String vendorId) {
    context.push('/admin/vendor-analytics/$vendorId');
  }

  void _createNewTemplate() {
    context.push('/admin/pricing/template/new');
  }

  // Metric calculation methods
  Future<int> _countTotalVendors() async {
    try {
      final vendorsSnap = await _db.collection('vendors').count().get();
      return vendorsSnap.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _countAutonomousVendors() async {
    try {
      final autonomousSnap = await _db.collection('vendors')
          .where('pricingConfiguration.hasPricingRights', isEqualTo: true)
          .count()
          .get();
      return autonomousSnap.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _countPendingReviews() async {
    try {
      final pendingSnap = await _db.collection('items')
          .where('pricing.adminReview.status', isEqualTo: 'pending')
          .count()
          .get();
      return pendingSnap.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _countPricingViolations() async {
    try {
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      final violationsSnap = await _db.collection('pricing_audit_log')
          .where('compliance.riskLevel', whereIn: ['high', 'critical'])
          .where('systemContext.timestamp', 
                 isGreaterThanOrEqualTo: Timestamp.fromDate(oneWeekAgo))
          .count()
          .get();
      return violationsSnap.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Widget _buildRecentActivity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Recent Pricing Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.push('/admin/pricing/activity'),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Recent activity stream
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db.collection('pricing_audit_log')
                  .orderBy('systemContext.timestamp', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }

                final activities = snapshot.data!.docs;

                return Column(
                  children: activities.map((doc) {
                    final data = doc.data();
                    return _buildActivityItem(data);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final changeType = activity['changeType'] as String? ?? 'unknown';
    final actor = activity['actor'] as Map<String, dynamic>? ?? {};
    final changeDetails = activity['changeDetails'] as Map<String, dynamic>? ?? {};
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getActivityColor(changeType).withOpacity(0.2),
        child: Icon(_getActivityIcon(changeType), color: _getActivityColor(changeType)),
      ),
      title: Text(_getActivityTitle(changeType, changeDetails)),
      subtitle: Text('${actor['name'] ?? 'Unknown'} • ${_formatTimeAgo(activity['systemContext']?['timestamp'])}'),
      trailing: _buildActivityStatus(activity['compliance']?['riskLevel']),
      onTap: () => _viewActivityDetails(activity),
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                _buildActionCard(
                  'Create Template',
                  Icons.add_circle,
                  Colors.blue,
                  () => _createNewTemplate(),
                ),
                _buildActionCard(
                  'Review Pending',
                  Icons.pending_actions,
                  Colors.orange,
                  () => context.push('/admin/pricing/pending-reviews'),
                ),
                _buildActionCard(
                  'View Violations',
                  Icons.warning,
                  Colors.red,
                  () => context.push('/admin/pricing/violations'),
                ),
                _buildActionCard(
                  'Pricing Analytics',
                  Icons.analytics,
                  Colors.green,
                  () => context.push('/admin/pricing/analytics'),
                ),
                _buildActionCard(
                  'Export Report',
                  Icons.download,
                  Colors.purple,
                  () => _exportPricingReport(),
                ),
                _buildActionCard(
                  'System Health',
                  Icons.health_and_safety,
                  Colors.teal,
                  () => context.push('/admin/pricing/health'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods
  Color _getActivityColor(String changeType) {
    switch (changeType) {
      case 'admin_template_update': return Colors.blue;
      case 'vendor_price_update': return Colors.orange;
      case 'pricing_rights_suspended': return Colors.red;
      case 'pricing_rights_restored': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getActivityIcon(String changeType) {
    switch (changeType) {
      case 'admin_template_update': return Icons.settings;
      case 'vendor_price_update': return Icons.store;
      case 'pricing_rights_suspended': return Icons.block;
      case 'pricing_rights_restored': return Icons.restore;
      default: return Icons.info;
    }
  }

  String _getActivityTitle(String changeType, Map<String, dynamic> details) {
    switch (changeType) {
      case 'admin_template_update':
        return 'Updated pricing template';
      case 'vendor_price_update':
        final oldPrice = details['oldValue'] ?? 0;
        final newPrice = details['newValue'] ?? 0;
        return 'Price changed: ₦$oldPrice → ₦$newPrice';
      case 'pricing_rights_suspended':
        return 'Suspended vendor pricing rights';
      case 'pricing_rights_restored':
        return 'Restored vendor pricing rights';
      default:
        return changeType.replaceAll('_', ' ').toUpperCase();
    }
  }

  Widget _buildActivityStatus(String? riskLevel) {
    if (riskLevel == null) return const SizedBox.shrink();
    
    final color = _getRiskColor(riskLevel);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        riskLevel.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'critical': return Colors.red;
      case 'high': return Colors.orange;
      case 'medium': return Colors.yellow.shade700;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _formatTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    final now = DateTime.now();
    final time = timestamp.toDate();
    final difference = now.difference(time);
    
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  void _viewActivityDetails(Map<String, dynamic> activity) {
    // Show detailed activity information
  }

  void _exportPricingReport() {
    // Export comprehensive pricing report
  }

  Widget _buildAnalyticsTab() {
    return const Center(child: Text('Analytics implementation'));
  }

  Widget _buildPoliciesTab() {
    return const Center(child: Text('Policies implementation'));
  }
}

/// Individual vendor pricing card for admin review
class AdminVendorPricingCard extends StatelessWidget {
  final String vendorId;
  final Map<String, dynamic> vendorData;
  final Function(String, bool) onTogglePricing;
  final Function(String) onReviewPricing;
  final Function(String) onViewAnalytics;

  const AdminVendorPricingCard({
    super.key,
    required this.vendorId,
    required this.vendorData,
    required this.onTogglePricing,
    required this.onReviewPricing,
    required this.onViewAnalytics,
  });

  @override
  Widget build(BuildContext context) {
    final pricingConfig = Map<String, dynamic>.from(vendorData['pricingConfiguration'] ?? {});
    final businessName = vendorData['businessName'] as String? ?? 'Unknown Vendor';
    final serviceId = vendorData['serviceId'] as String? ?? 'unknown';
    final hasPricingRights = pricingConfig['hasPricingRights'] as bool? ?? false;
    final isPricingEnabled = pricingConfig['isPricingEnabled'] as bool? ?? false;
    final suspensionReason = pricingConfig['adminControls']?['suspensionReason'] as String?;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vendor header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.indigo.shade100,
                  child: Text(
                    businessName[0].toUpperCase(),
                    style: TextStyle(
                      color: Colors.indigo.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Row(
                        children: [
                          Text(
                            serviceId.toUpperCase(),
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: hasPricingRights ? Colors.green.shade100 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              hasPricingRights ? 'AUTONOMOUS' : 'ADMIN CONTROLLED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: hasPricingRights ? Colors.green.shade700 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Pricing toggle switch
                if (hasPricingRights) Column(
                  children: [
                    Switch(
                      value: isPricingEnabled,
                      onChanged: (value) => onTogglePricing(vendorId, value),
                      activeColor: Colors.green,
                    ),
                    Text(
                      isPricingEnabled ? 'ENABLED' : 'SUSPENDED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isPricingEnabled ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Suspension notice
            if (!isPricingEnabled && suspensionReason != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pricing Rights Suspended',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            suspensionReason,
                            style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Pricing metrics
            FutureBuilder<Map<String, dynamic>>(
              future: _getVendorPricingMetrics(vendorId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator();
                }

                final metrics = snapshot.data!;
                
                return Row(
                  children: [
                    Expanded(child: _buildMetricChip('Items', '${metrics['totalItems'] ?? 0}', Colors.blue)),
                    Expanded(child: _buildMetricChip('Avg Price', '₦${(metrics['avgPrice'] ?? 0).toStringAsFixed(0)}', Colors.green)),
                    Expanded(child: _buildMetricChip('Changes', '${metrics['changesThisWeek'] ?? 0}/week', Colors.orange)),
                    Expanded(child: _buildMetricChip('Health', _getHealthGrade(metrics['healthScore'] ?? 0), _getHealthColor(metrics['healthScore'] ?? 0))),
                  ],
                );
              },
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onReviewPricing(vendorId),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Review Pricing'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onViewAnalytics(vendorId),
                    icon: const Icon(Icons.analytics),
                    label: const Text('Analytics'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>> _getVendorPricingMetrics(String vendorId) async {
    try {
      // This would typically call a Firebase Function or compute metrics
      // For now, return mock data
      return {
        'totalItems': 25,
        'avgPrice': 1850.0,
        'changesThisWeek': 3,
        'healthScore': 85,
        'priceRating': 4.2,
      };
    } catch (e) {
      return {};
    }
  }

  String _getHealthGrade(int score) {
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  Color _getHealthColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }
}

/// Pricing policy violation detector
class PricingViolationDetector {
  
  /// Detect potential pricing violations
  static Future<List<PricingViolation>> detectViolations({
    required String vendorId,
    int analysisWindowDays = 7,
  }) async {
    try {
      final violations = <PricingViolation>[];
      final startDate = DateTime.now().subtract(Duration(days: analysisWindowDays));

      // Get vendor's recent pricing changes
      final changesSnap = await FirebaseFirestore.instance
          .collection('pricing_audit_log')
          .where('actor.vendorId', isEqualTo: vendorId)
          .where('changeType', isEqualTo: 'vendor_price_update')
          .where('systemContext.timestamp', 
                 isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .orderBy('systemContext.timestamp', descending: true)
          .get();

      final changes = changesSnap.docs.map((doc) => doc.data()).toList();

      // Violation detection algorithms
      
      // 1. Excessive price increases (potential gouging)
      for (final change in changes) {
        final changePercentage = (change['changeDetails']['changePercentage'] as num?)?.toDouble() ?? 0.0;
        if (changePercentage > 200) { // 200% increase
          violations.add(PricingViolation(
            type: ViolationType.priceGouging,
            severity: ViolationSeverity.critical,
            description: 'Excessive price increase: ${changePercentage.toStringAsFixed(1)}%',
            auditId: change['auditId'],
            detectedAt: DateTime.now(),
            recommendedAction: 'Immediate review and potential pricing rights suspension',
          ));
        }
      }

      // 2. Rapid price changes (market manipulation)
      if (changes.length > 10) {
        violations.add(PricingViolation(
          type: ViolationType.rapidPriceChanges,
          severity: ViolationSeverity.high,
          description: '${changes.length} price changes in $analysisWindowDays days',
          detectedAt: DateTime.now(),
          recommendedAction: 'Review pricing strategy with vendor',
        ));
      }

      // 3. Predatory pricing (below cost)
      for (final change in changes) {
        final newPrice = (change['changeDetails']['newValue'] as num?)?.toDouble() ?? 0.0;
        final estimatedCost = await _estimateItemCost(change['entityId']);
        
        if (estimatedCost != null && newPrice < estimatedCost * 0.7) { // 30% below estimated cost
          violations.add(PricingViolation(
            type: ViolationType.predatoryPricing,
            severity: ViolationSeverity.high,
            description: 'Price potentially below cost: ₦$newPrice vs estimated cost ₦$estimatedCost',
            auditId: change['auditId'],
            detectedAt: DateTime.now(),
            recommendedAction: 'Verify cost structure and pricing rationale',
          ));
        }
      }

      return violations;

    } catch (e) {
      print('❌ Error detecting violations: $e');
      return [];
    }
  }

  static Future<double?> _estimateItemCost(String itemId) async {
    // This would integrate with cost estimation algorithms
    // For now, return null to skip cost-based violation detection
    return null;
  }
}

/// Data classes for pricing violations
class PricingViolation {
  final ViolationType type;
  final ViolationSeverity severity;
  final String description;
  final String? auditId;
  final DateTime detectedAt;
  final String recommendedAction;

  const PricingViolation({
    required this.type,
    required this.severity,
    required this.description,
    this.auditId,
    required this.detectedAt,
    required this.recommendedAction,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString(),
      'severity': severity.toString(),
      'description': description,
      'auditId': auditId,
      'detectedAt': detectedAt.toIso8601String(),
      'recommendedAction': recommendedAction,
    };
  }
}

enum ViolationType {
  priceGouging,
  predatoryPricing,
  rapidPriceChanges,
  marketManipulation,
  policyViolation,
}

enum ViolationSeverity {
  low,
  medium,
  high,
  critical,
}