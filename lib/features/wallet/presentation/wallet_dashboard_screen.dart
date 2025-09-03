import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Comprehensive wallet dashboard for providers and customers
/// Shows balances, transactions, debt management, and top-up options
class WalletDashboardScreen extends StatefulWidget {
  const WalletDashboardScreen({super.key});

  @override
  State<WalletDashboardScreen> createState() => _WalletDashboardScreenState();
}

class _WalletDashboardScreenState extends State<WalletDashboardScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _userId;
  Map<String, dynamic>? _walletData;
  String _selectedCurrency = 'NGN';
  bool _loading = true;

  // Balance display
  double _currentBalance = 0.0;
  String _accountStatus = 'active';
  Map<String, double> _debts = {};
  
  @override
  void initState() {
    super.initState();
    _initializeWallet();
  }

  Future<void> _initializeWallet() async {
    try {
      _userId = FirebaseAuth.instance.currentUser?.uid;
      if (_userId == null) return;

      // Load wallet data
      await _loadWalletData();
      
      // Resolve user's currency based on location
      final currency = await _resolveUserCurrency();
      setState(() {
        _selectedCurrency = currency;
        _loading = false;
      });

    } catch (e) {
      print('❌ Error initializing wallet: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _loadWalletData() async {
    try {
      final walletDoc = await _db.collection('wallets').doc(_userId).get();
      
      if (walletDoc.exists) {
        setState(() {
          _walletData = walletDoc.data();
          _updateBalanceDisplay();
        });
      } else {
        // Create wallet if doesn't exist
        await _createWallet();
      }

    } catch (e) {
      print('❌ Error loading wallet data: $e');
    }
  }

  void _updateBalanceDisplay() {
    if (_walletData == null) return;

    final balances = Map<String, dynamic>.from(_walletData!['balances'] ?? {});
    final accountStatus = Map<String, dynamic>.from(_walletData!['accountStatus'] ?? {});
    final totalDebt = Map<String, dynamic>.from(accountStatus['totalDebt'] ?? {});

    setState(() {
      _currentBalance = (balances[_selectedCurrency]?['available'] as num?)?.toDouble() ?? 0.0;
      _accountStatus = accountStatus['status'] ?? 'active';
      _debts = Map<String, double>.from(totalDebt.map((k, v) => MapEntry(k, (v as num).toDouble())));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showCurrencySelector(),
            icon: const Icon(Icons.currency_exchange),
          ),
          IconButton(
            onPressed: () => context.push('/wallet/settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadWalletData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // Balance section
              _buildBalanceSection(),
              
              // Account status (if overdue)
              if (_accountStatus != 'active') _buildAccountStatusSection(),
              
              // Quick actions
              _buildQuickActionsSection(),
              
              // Recent transactions
              _buildRecentTransactionsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceSection() {
    final isNegative = _currentBalance < 0;
    final displayBalance = _currentBalance.abs();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isNegative 
            ? [Colors.red.shade600, Colors.red.shade400]
            : [Colors.green.shade600, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isNegative ? Icons.warning : Icons.account_balance_wallet,
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isNegative ? 'Outstanding Debt' : 'Available Balance',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${_getCurrencySymbol(_selectedCurrency)}${displayBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Currency selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  _selectedCurrency,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Multi-currency balances
          if (_walletData?['balances'] != null) _buildMultiCurrencyBalances(),
        ],
      ),
    );
  }

  Widget _buildMultiCurrencyBalances() {
    final balances = Map<String, dynamic>.from(_walletData!['balances']);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All Currencies',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        
        Wrap(
          spacing: 12,
          children: balances.entries.map((entry) {
            final currency = entry.key;
            final balance = (entry.value['available'] as num?)?.toDouble() ?? 0.0;
            final isSelected = currency == _selectedCurrency;
            
            return GestureDetector(
              onTap: () => setState(() => _selectedCurrency = currency),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected 
                    ? Colors.white.withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected 
                    ? Border.all(color: Colors.white, width: 2)
                    : null,
                ),
                child: Text(
                  '$currency ${_getCurrencySymbol(currency)}${balance.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAccountStatusSection() {
    final statusData = Map<String, dynamic>.from(_walletData?['accountStatus'] ?? {});
    final debtAmount = _debts[_selectedCurrency] ?? 0.0;
    final gracePeriodEnd = statusData['gracePeriodEnd'] as Timestamp?;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade700, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Overdue',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Your account has insufficient funds for platform commissions',
                      style: TextStyle(color: Colors.red.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Debt details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Outstanding Debt:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${_getCurrencySymbol(_selectedCurrency)}${debtAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],
                ),
                
                if (gracePeriodEnd != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Grace Period Ends:'),
                      Text(
                        _formatDateTime(gracePeriodEnd.toDate()),
                        style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showTopUpDialog(debtAmount),
                  icon: const Icon(Icons.add),
                  label: const Text('Top Up Wallet'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.green),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _contactSupport(),
                  icon: const Icon(Icons.support),
                  label: const Text('Contact Support'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              _buildActionCard(
                'Top Up',
                Icons.add_circle,
                Colors.green,
                _accountStatus == 'active' ? () => _showTopUpDialog() : null,
              ),
              _buildActionCard(
                'Withdraw',
                Icons.remove_circle,
                Colors.blue,
                _accountStatus == 'active' && _currentBalance > 0 ? () => _showWithdrawDialog() : null,
              ),
              _buildActionCard(
                'History',
                Icons.history,
                Colors.purple,
                () => context.push('/wallet/transactions'),
              ),
              _buildActionCard(
                'Earnings',
                Icons.trending_up,
                Colors.orange,
                () => context.push('/wallet/earnings'),
              ),
              _buildActionCard(
                'Settings',
                Icons.settings,
                Colors.grey,
                () => context.push('/wallet/settings'),
              ),
              _buildActionCard(
                'Support',
                Icons.help,
                Colors.teal,
                () => _contactSupport(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback? onTap) {
    final isEnabled = onTap != null;
    
    return Card(
      elevation: isEnabled ? 2 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isEnabled ? null : Colors.grey.shade100,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isEnabled ? color : Colors.grey,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isEnabled ? color : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Recent Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push('/wallet/transactions'),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Transactions stream
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _db.collection('transactions')
                .where('userId', isEqualTo: _userId)
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              }

              if (!snapshot.hasData) {
                return const LinearProgressIndicator();
              }

              final transactions = snapshot.data!.docs;

              if (transactions.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(40),
                  child: const Column(
                    children: [
                      Icon(Icons.receipt, size: 48, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No transactions yet'),
                    ],
                  ),
                );
              }

              return Column(
                children: transactions.map((doc) {
                  final txnData = doc.data();
                  return TransactionCard(
                    transactionData: txnData,
                    onTap: () => _showTransactionDetails(doc.id, txnData),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showTopUpDialog([double? minimumAmount]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TopUpWalletSheet(
        currency: _selectedCurrency,
        minimumAmount: minimumAmount,
        currentBalance: _currentBalance,
        onTopUpComplete: () => _loadWalletData(),
      ),
    );
  }

  void _showWithdrawDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WithdrawFundsSheet(
        currency: _selectedCurrency,
        availableBalance: _currentBalance,
        onWithdrawComplete: () => _loadWalletData(),
      ),
    );
  }

  void _showCurrencySelector() {
    if (_walletData == null) return;
    
    final balances = Map<String, dynamic>.from(_walletData!['balances'] ?? {});
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Currency',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            ...balances.entries.map((entry) {
              final currency = entry.key;
              final balance = (entry.value['available'] as num?)?.toDouble() ?? 0.0;
              final isSelected = currency == _selectedCurrency;
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected ? Colors.green : Colors.grey.shade200,
                  child: Text(
                    currency,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(_getCurrencyName(currency)),
                subtitle: Text('${_getCurrencySymbol(currency)}${balance.toStringAsFixed(2)}'),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() => _selectedCurrency = currency);
                  _updateBalanceDisplay();
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _createWallet() async {
    try {
      final currency = await _resolveUserCurrency();
      
      await _db.collection('wallets').doc(_userId).set({
        'userId': _userId,
        'primaryCurrency': currency,
        'balances': {
          currency: {
            'available': 0.0,
            'pending': 0.0,
            'total': 0.0,
            'lastUpdated': FieldValue.serverTimestamp(),
          }
        },
        'accountStatus': {
          'status': 'active',
          'canReceiveNewOrders': true,
          'canWithdrawFunds': true,
          'totalDebt': {},
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _loadWalletData();

    } catch (e) {
      print('❌ Error creating wallet: $e');
    }
  }

  Future<String> _resolveUserCurrency() async {
    try {
      // This would call the location resolution service
      // For now, return a default based on common patterns
      return 'NGN'; // Default to Nigerian Naira
    } catch (e) {
      return 'NGN';
    }
  }

  String _getCurrencySymbol(String currency) {
    const symbols = {
      'NGN': '₦',
      'USD': '\$',
      'ZAR': 'R',
      'GHS': '₵',
      'KES': 'KSh',
      'GBP': '£',
      'EUR': '€',
    };
    return symbols[currency] ?? currency;
  }

  String _getCurrencyName(String currency) {
    const names = {
      'NGN': 'Nigerian Naira',
      'USD': 'US Dollar',
      'ZAR': 'South African Rand',
      'GHS': 'Ghanaian Cedi',
      'KES': 'Kenyan Shilling',
      'GBP': 'British Pound',
      'EUR': 'Euro',
    };
    return names[currency] ?? currency;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _showTransactionDetails(String transactionId, Map<String, dynamic> txnData) {
    showDialog(
      context: context,
      builder: (context) => TransactionDetailsDialog(
        transactionId: transactionId,
        transactionData: txnData,
      ),
    );
  }

  void _contactSupport() {
    // Implementation for contacting support
    context.push('/support/wallet-help');
  }
}

/// Transaction card widget
class TransactionCard extends StatelessWidget {
  final Map<String, dynamic> transactionData;
  final VoidCallback onTap;

  const TransactionCard({
    super.key,
    required this.transactionData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = transactionData['type'] as String? ?? 'unknown';
    final amount = (transactionData['amount'] as num?)?.toDouble() ?? 0.0;
    final currency = transactionData['currency'] as String? ?? 'NGN';
    final createdAt = transactionData['createdAt'] as Timestamp?;
    final description = transactionData['metadata']?['description'] as String? ?? 'Transaction';

    final isCredit = amount > 0;
    final displayAmount = amount.abs();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCredit ? Colors.green.shade100 : Colors.red.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getTransactionIcon(type),
            color: isCredit ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
        title: Text(
          _getTransactionTitle(type),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            if (createdAt != null)
              Text(
                _formatTimeAgo(createdAt.toDate()),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${isCredit ? '+' : '-'}${_getCurrencySymbol(currency)}${displayAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isCredit ? Colors.green.shade700 : Colors.red.shade700,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(transactionData['status']).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _getStatusText(transactionData['status']),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(transactionData['status']),
                ),
              ),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: onTap,
      ),
    );
  }

  IconData _getTransactionIcon(String type) {
    switch (type) {
      case 'earnings_credit': return Icons.trending_up;
      case 'commission_deduction': return Icons.trending_down;
      case 'wallet_topup': return Icons.add_circle;
      case 'withdrawal': return Icons.remove_circle;
      case 'refund': return Icons.undo;
      default: return Icons.receipt;
    }
  }

  String _getTransactionTitle(String type) {
    switch (type) {
      case 'earnings_credit': return 'Earnings Credit';
      case 'commission_deduction': return 'Commission Deducted';
      case 'forced_commission_deduction': return 'Commission (Forced)';
      case 'wallet_topup': return 'Wallet Top-up';
      case 'withdrawal': return 'Withdrawal';
      case 'refund': return 'Refund';
      default: return 'Transaction';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'pending': return Colors.orange;
      case 'failed': return Colors.red;
      case 'processing': return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'completed': return 'COMPLETED';
      case 'pending': return 'PENDING';
      case 'failed': return 'FAILED';
      case 'processing': return 'PROCESSING';
      default: return 'UNKNOWN';
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  String _getCurrencySymbol(String currency) {
    const symbols = {
      'NGN': '₦',
      'USD': '\$',
      'ZAR': 'R',
      'GHS': '₵',
      'KES': 'KSh',
    };
    return symbols[currency] ?? currency;
  }
}

/// Top-up wallet bottom sheet
class TopUpWalletSheet extends StatefulWidget {
  final String currency;
  final double? minimumAmount;
  final double currentBalance;
  final VoidCallback onTopUpComplete;

  const TopUpWalletSheet({
    super.key,
    required this.currency,
    this.minimumAmount,
    required this.currentBalance,
    required this.onTopUpComplete,
  });

  @override
  State<TopUpWalletSheet> createState() => _TopUpWalletSheetState();
}

class _TopUpWalletSheetState extends State<TopUpWalletSheet> {
  final TextEditingController _amountController = TextEditingController();
  String _selectedPaymentMethod = 'card';
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    
    // Pre-fill minimum amount if debt exists
    if (widget.minimumAmount != null) {
      _amountController.text = widget.minimumAmount!.toStringAsFixed(0);
    }
  }

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
              color: Colors.green.shade600,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text(
                  'Top Up Wallet',
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

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current balance display
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Current Balance'),
                            Text(
                              '${_getCurrencySymbol(widget.currency)}${widget.currentBalance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: widget.currentBalance < 0 ? Colors.red : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Amount input
                  const Text('Top-up Amount:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      prefixText: _getCurrencySymbol(widget.currency),
                      hintText: '0.00',
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                  ),

                  if (widget.minimumAmount != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Minimum ${_getCurrencySymbol(widget.currency)}${widget.minimumAmount!.toStringAsFixed(2)} required to clear outstanding debt',
                              style: TextStyle(color: Colors.orange.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Quick amount buttons
                  const Text('Quick Amounts:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _getQuickAmounts().map((amount) =>
                      ActionChip(
                        label: Text('${_getCurrencySymbol(widget.currency)}$amount'),
                        onPressed: () => _amountController.text = amount.toString(),
                      ),
                    ).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Payment method selection
                  const Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...['card', 'bank_transfer', 'mobile_money'].map((method) =>
                    RadioListTile<String>(
                      title: Text(_getPaymentMethodName(method)),
                      value: method,
                      groupValue: _selectedPaymentMethod,
                      onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                    ),
                  ),

                  const Spacer(),

                  // Top-up button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _processing ? null : _processTopUp,
                      icon: _processing 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.add),
                      label: Text(_processing ? 'Processing...' : 'Top Up Wallet'),
                      style: FilledButton.styleFrom(backgroundColor: Colors.green.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<int> _getQuickAmounts() {
    switch (widget.currency) {
      case 'NGN': return [1000, 5000, 10000, 25000, 50000];
      case 'USD': return [10, 25, 50, 100, 250];
      case 'ZAR': return [100, 250, 500, 1000, 2500];
      case 'GHS': return [50, 100, 250, 500, 1000];
      default: return [10, 25, 50, 100, 250];
    }
  }

  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'card': return '💳 Credit/Debit Card';
      case 'bank_transfer': return '🏦 Bank Transfer';
      case 'mobile_money': return '📱 Mobile Money';
      default: return method;
    }
  }

  Future<void> _processTopUp() async {
    final amount = double.tryParse(_amountController.text);
    
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    if (widget.minimumAmount != null && amount < widget.minimumAmount!) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Minimum top-up amount is ${_getCurrencySymbol(widget.currency)}${widget.minimumAmount!.toStringAsFixed(2)}')),
      );
      return;
    }

    setState(() => _processing = true);

    try {
      // Process wallet top-up (would integrate with payment gateway)
      await _processWalletTopUp(amount, _selectedPaymentMethod);
      
      Navigator.pop(context);
      widget.onTopUpComplete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wallet topped up successfully!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Top-up failed: $e')),
      );
    } finally {
      setState(() => _processing = false);
    }
  }

  Future<void> _processWalletTopUp(double amount, String paymentMethod) async {
    // This would integrate with payment processing
    // For now, simulate the process
    await Future.delayed(const Duration(seconds: 2));
    
    // In real implementation, this would:
    // 1. Create payment intent with Stripe/Paystack
    // 2. Process payment
    // 3. Credit wallet upon successful payment
    // 4. Send confirmation notifications
  }

  String _getCurrencySymbol(String currency) {
    const symbols = {
      'NGN': '₦',
      'USD': '\$',
      'ZAR': 'R',
      'GHS': '₵',
      'KES': 'KSh',
    };
    return symbols[currency] ?? currency;
  }
}

/// Transaction details dialog
class TransactionDetailsDialog extends StatelessWidget {
  final String transactionId;
  final Map<String, dynamic> transactionData;

  const TransactionDetailsDialog({
    super.key,
    required this.transactionId,
    required this.transactionData,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Transaction Details'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow('Transaction ID', transactionId.substring(0, 16) + '...'),
            _buildDetailRow('Type', _getTransactionTitle(transactionData['type'])),
            _buildDetailRow('Amount', '${transactionData['currency']} ${transactionData['amount']}'),
            _buildDetailRow('Status', transactionData['status'] ?? 'Unknown'),
            
            if (transactionData['orderId'] != null)
              _buildDetailRow('Order ID', transactionData['orderId']),
            
            if (transactionData['metadata']?['description'] != null)
              _buildDetailRow('Description', transactionData['metadata']['description']),
            
            if (transactionData['createdAt'] != null)
              _buildDetailRow('Date', _formatDateTime((transactionData['createdAt'] as Timestamp).toDate())),
            
            // Commission breakdown (if applicable)
            if (transactionData['commissionDetails'] != null) ...[
              const SizedBox(height: 16),
              const Text('Commission Breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._buildCommissionBreakdown(transactionData['commissionDetails']),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (transactionData['orderId'] != null)
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/orders/${transactionData['orderId']}');
            },
            child: const Text('View Order'),
          ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  List<Widget> _buildCommissionBreakdown(Map<String, dynamic> breakdown) {
    return [
      _buildDetailRow('Order Total', '${breakdown['currency']} ${breakdown['orderTotal']}'),
      _buildDetailRow('Commission Rate', '${(breakdown['commissionRate'] * 100).toStringAsFixed(1)}%'),
      _buildDetailRow('Commission Amount', '${breakdown['currency']} ${breakdown['platformCommission']}'),
      _buildDetailRow('Your Earnings', '${breakdown['currency']} ${breakdown['providerEarnings']}'),
    ];
  }

  String _getTransactionTitle(String? type) {
    switch (type) {
      case 'earnings_credit': return 'Earnings Credit';
      case 'commission_deduction': return 'Commission Deducted';
      case 'wallet_topup': return 'Wallet Top-up';
      case 'withdrawal': return 'Withdrawal';
      default: return type ?? 'Unknown';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}