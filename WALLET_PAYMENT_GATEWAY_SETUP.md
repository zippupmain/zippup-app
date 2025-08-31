# 💳 ZippUp Wallet & Payment Gateway Configuration Guide

**Current Setup**: Stripe + Flutterwave integration with Cloud Functions

---

## 🏦 **CURRENT PAYMENT INFRASTRUCTURE**

### **✅ Already Implemented:**
- **Stripe Integration**: International card processing
- **Flutterwave Integration**: African payment processing
- **Cloud Functions**: Backend payment processing
- **Commission System**: 15% platform fee handling
- **Cash + Card**: Dual payment acceptance

### **📱 Current Payment Flow:**
```
Customer Payment → Stripe/Flutterwave → Cloud Functions → Platform Commission (15%) → Provider Payout
```

---

## 💰 **WALLET SYSTEM CONFIGURATION**

### **🔧 Recommended Architecture:**

**1. 💳 Customer Wallet:**
```
ZippUp Wallet
├── Balance: ₦50,000
├── Payment Methods:
│   ├── Bank Cards (Stripe/Flutterwave)
│   ├── Bank Transfer (Flutterwave/Paystack)
│   └── Cash Deposits (Agent network)
└── Transaction History
```

**2. 🏪 Provider Wallet:**
```
Provider Wallet
├── Available Balance: ₦45,000 (after 15% commission)
├── Pending Payouts: ₦15,000
├── Withdrawal Methods:
│   ├── Bank Transfer
│   ├── Mobile Money
│   └── Cash Pickup
└── Earnings History
```

### **🔧 Implementation Steps:**

**1. Create Wallet Service:**
```dart
// lib/services/wallet/wallet_service.dart
class WalletService {
  // Customer wallet operations
  Future<double> getWalletBalance(String userId);
  Future<void> addFunds(String userId, double amount, String method);
  Future<void> deductFunds(String userId, double amount, String purpose);
  
  // Provider wallet operations  
  Future<void> creditProvider(String providerId, double amount, String commission);
  Future<void> requestPayout(String providerId, double amount, String method);
  
  // Transaction history
  Future<List<Transaction>> getTransactionHistory(String userId);
}
```

**2. Enhance Payment Service:**
```dart
// lib/services/payments/enhanced_payments_service.dart
class EnhancedPaymentsService {
  // Existing Stripe/Flutterwave
  Future<String> createStripeCheckout({...});
  Future<String> createFlutterwaveCheckout({...});
  
  // New wallet features
  Future<bool> payFromWallet(String userId, double amount);
  Future<void> transferToBank(String userId, String bankAccount, double amount);
  Future<void> buyAirtime(String phoneNumber, double amount, String network);
  Future<void> buyData(String phoneNumber, String dataBundle, String network);
  Future<void> payBill(String billType, String accountNumber, double amount);
}
```

---

## 🌍 **RECOMMENDED PAYMENT GATEWAYS FOR AFRICAN MARKET**

### **🥇 PRIMARY GATEWAYS (Already Integrated):**

**1. 🌊 Flutterwave (African Leader):**
```
Features:
✅ Local Nigerian banks integration
✅ Mobile money (MTN, Airtel, 9mobile)  
✅ USSD payments (*737# GTBank, etc.)
✅ Bank transfer (instant settlement)
✅ International cards
✅ Airtime/Data APIs
✅ Bill payment APIs
```

**2. 💳 Stripe (Global Standard):**
```
Features:
✅ International card processing
✅ Subscription management
✅ Marketplace payments (perfect for ZippUp)
✅ Instant payouts
✅ Comprehensive APIs
✅ Strong fraud protection
```

### **🚀 ADDITIONAL RECOMMENDED GATEWAYS:**

**3. 💰 Paystack (Nigerian Focused):**
```
Features:
✅ Nigerian bank integration
✅ USSD payments
✅ Mobile money
✅ Recurring billing
✅ Transfer recipient APIs
✅ Excellent local support

Integration:
npm install @paystack/inline-js
// Add to Cloud Functions
```

**4. 🏦 Interswitch (Banking Infrastructure):**
```
Features:
✅ Direct bank integration
✅ Verve card processing
✅ QuickTeller bill payments
✅ Institutional transfers
✅ POS integration

Use Case:
- Bill payments (PHCN, Water, Cable TV)
- Bank transfers
- Government payments
```

**5. 📱 Kuda/Opay APIs (Digital Banking):**
```
Features:
✅ Virtual accounts
✅ Instant transfers
✅ Savings/investment
✅ Loan services
✅ Business accounts

Integration:
- Virtual account creation
- Instant settlement
- Business banking features
```

---

## 📱 **DIGITAL SERVICES PAYMENT INTEGRATION**

### **🔧 Current Digital Services in ZippUp:**
- 📞 **Buy Airtime**
- 📶 **Buy Data** 
- 💡 **Pay Bills**
- 💻 **Digital Products**
- 🎁 **Gift Cards**
- 📺 **Subscriptions**

### **🌟 RECOMMENDED API INTEGRATIONS:**

**1. 📞 Airtime/Data Purchase:**
```javascript
// Flutterwave Bills API
const airtimeConfig = {
  endpoint: 'https://api.flutterwave.com/v3/bills',
  services: {
    mtn: 'BIL099',
    airtel: 'BIL100', 
    glo: 'BIL101',
    '9mobile': 'BIL102'
  }
};

// Implementation
async function buyAirtime(phoneNumber, amount, network) {
  return await fetch(airtimeConfig.endpoint, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${FLUTTERWAVE_SECRET_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      country: 'NG',
      customer: phoneNumber,
      amount: amount,
      type: airtimeConfig.services[network]
    })
  });
}
```

**2. 💡 Bill Payments:**
```javascript
// Flutterwave Bills API for utilities
const billServices = {
  electricity: {
    phcn: 'BIL119',
    eko: 'BIL120',
    kano: 'BIL121'
  },
  cable: {
    dstv: 'BIL122',
    gotv: 'BIL123', 
    startimes: 'BIL124'
  },
  internet: {
    spectranet: 'BIL125',
    smile: 'BIL126'
  }
};
```

**3. 🏦 Bank Transfers:**
```javascript
// Flutterwave Transfer API
async function transferToBank(accountNumber, bankCode, amount, narration) {
  return await fetch('https://api.flutterwave.com/v3/transfers', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${FLUTTERWAVE_SECRET_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      account_bank: bankCode,
      account_number: accountNumber,
      amount: amount,
      narration: narration,
      currency: 'NGN',
      reference: generateReference(),
      callback_url: 'https://your-app.com/transfer-callback',
      debit_currency: 'NGN'
    })
  });
}
```

---

## 🔧 **IMPLEMENTATION ROADMAP**

### **Phase 1: Enhanced Wallet System**
```dart
// Create wallet screens and services
lib/features/wallet/
├── presentation/
│   ├── wallet_screen.dart           // Main wallet dashboard
│   ├── add_funds_screen.dart        // Top up wallet
│   ├── withdraw_funds_screen.dart   // Withdraw to bank
│   └── transaction_history_screen.dart
├── services/
│   ├── wallet_service.dart          // Core wallet operations
│   └── transaction_service.dart     // Transaction management
└── models/
    ├── wallet.dart                  // Wallet data model
    └── transaction.dart             // Transaction data model
```

### **Phase 2: Digital Services Integration**
```dart
// Enhance digital services with payment APIs
lib/features/digital/
├── presentation/
│   ├── airtime_purchase_screen.dart  // Buy airtime/data
│   ├── bill_payment_screen.dart      // Pay utilities
│   ├── bank_transfer_screen.dart     // Transfer money
│   └── digital_products_screen.dart  // Buy digital items
├── services/
│   ├── airtime_service.dart         // Airtime/data APIs
│   ├── bills_service.dart           // Bill payment APIs
│   └── transfer_service.dart        // Bank transfer APIs
└── models/
    ├── bill.dart                    // Bill data model
    └── transfer.dart                // Transfer data model
```

### **Phase 3: Payment Gateway Configuration**
```yaml
# Add to pubspec.yaml
dependencies:
  flutterwave_standard: ^1.0.8
  paystack_manager: ^2.3.0
  
# Environment variables
FLUTTERWAVE_PUBLIC_KEY=FLWPUBK_TEST-xxxxx
FLUTTERWAVE_SECRET_KEY=FLWSECK_TEST-xxxxx
PAYSTACK_PUBLIC_KEY=pk_test_xxxxx
PAYSTACK_SECRET_KEY=sk_test_xxxxx
```

---

## 💳 **WALLET FEATURES TO IMPLEMENT**

### **🏦 Customer Wallet Features:**
```
💰 ZippUp Wallet
├── 💵 Balance Display: ₦50,000
├── 📈 Add Funds:
│   ├── Bank Card (Stripe/Flutterwave)
│   ├── Bank Transfer (Flutterwave)
│   ├── USSD (*737#, *770#)
│   └── Agent Deposit
├── 💸 Quick Actions:
│   ├── 📞 Buy Airtime (MTN, Airtel, Glo, 9mobile)
│   ├── 📶 Buy Data (1GB, 2GB, 5GB, 10GB)
│   ├── 💡 Pay Bills (PHCN, DSTV, GOTV, Water)
│   ├── 🏦 Transfer to Bank
│   └── 🛒 Pay for Services
└── 📊 Transaction History
```

### **🏪 Provider Wallet Features:**
```
💼 Provider Wallet
├── 💰 Available: ₦45,000 (after 15% commission)
├── ⏳ Pending: ₦15,000 (processing)
├── 💸 Withdraw:
│   ├── Bank Transfer (Free)
│   ├── Mobile Money (₦50 fee)
│   └── Cash Pickup (₦100 fee)
├── 📊 Earnings Analytics:
│   ├── Daily/Weekly/Monthly
│   ├── Service breakdown
│   └── Commission deductions
└── 💳 Payout Schedule: Weekly auto-payout
```

---

## 🔧 **CLOUD FUNCTIONS ENHANCEMENT**

### **🚀 Add These Functions:**
```javascript
// functions/src/wallet.js
exports.addFundsToWallet = functions.https.onCall(async (data, context) => {
  // Integrate with Flutterwave/Paystack
  // Add funds to user wallet
  // Record transaction
});

exports.withdrawFromWallet = functions.https.onCall(async (data, context) => {
  // Transfer to user bank account
  // Deduct from wallet balance
  // Record transaction
});

exports.buyAirtime = functions.https.onCall(async (data, context) => {
  // Use Flutterwave Bills API
  // Deduct from wallet
  // Purchase airtime
});

exports.payBill = functions.https.onCall(async (data, context) => {
  // Use Flutterwave/Interswitch Bills API
  // Deduct from wallet
  // Pay utility bill
});

exports.transferMoney = functions.https.onCall(async (data, context) => {
  // Bank transfer via Flutterwave
  // Deduct from wallet + fees
  // Send to recipient bank
});
```

---

## 🎯 **DIGITAL SERVICES IMPLEMENTATION**

### **📞 Airtime/Data Purchase Screen:**
```dart
class AirtimePurchaseScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('📞 Buy Airtime')),
      body: Column(
        children: [
          // Network selection (MTN, Airtel, Glo, 9mobile)
          NetworkSelector(),
          
          // Phone number input
          PhoneNumberField(),
          
          // Amount selection (₦100, ₦200, ₦500, ₦1000, Custom)
          AmountSelector(),
          
          // Payment method (Wallet, Card, Bank Transfer)
          PaymentMethodSelector(),
          
          // Purchase button
          PurchaseButton(),
        ],
      ),
    );
  }
}
```

### **💡 Bill Payment Screen:**
```dart
class BillPaymentScreen extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('💡 Pay Bills')),
      body: Column(
        children: [
          // Bill type selection
          BillTypeSelector(types: ['Electricity', 'Cable TV', 'Internet', 'Water']),
          
          // Service provider selection (PHCN, DSTV, etc.)
          ServiceProviderSelector(),
          
          // Account number/meter number
          AccountNumberField(),
          
          // Amount input
          AmountField(),
          
          // Payment method
          PaymentMethodSelector(),
          
          // Pay button
          PayBillButton(),
        ],
      ),
    );
  }
}
```

---

## 🏦 **PAYMENT GATEWAY CONFIGURATION**

### **🔧 Flutterwave Setup (Recommended Primary):**
```dart
// lib/services/payments/flutterwave_service.dart
class FlutterwaveService {
  static const String publicKey = 'FLWPUBK_TEST-xxxxx';
  static const String secretKey = 'FLWSECK_TEST-xxxxx';
  static const String baseUrl = 'https://api.flutterwave.com/v3';
  
  // Wallet funding
  Future<PaymentResponse> fundWallet(double amount, String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments'),
      headers: {
        'Authorization': 'Bearer $secretKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'tx_ref': generateTransactionRef(),
        'amount': amount,
        'currency': 'NGN',
        'customer': {'id': userId},
        'redirect_url': 'https://your-app.com/payment-callback',
      }),
    );
    return PaymentResponse.fromJson(response.data);
  }
  
  // Bank transfer
  Future<TransferResponse> transferToBank({
    required String accountNumber,
    required String bankCode,
    required double amount,
    required String narration,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transfers'),
      headers: {
        'Authorization': 'Bearer $secretKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'account_bank': bankCode,
        'account_number': accountNumber,
        'amount': amount,
        'narration': narration,
        'currency': 'NGN',
      }),
    );
    return TransferResponse.fromJson(response.data);
  }
  
  // Airtime purchase
  Future<BillResponse> buyAirtime({
    required String phoneNumber,
    required double amount,
    required String network,
  }) async {
    final networkCodes = {
      'mtn': 'BIL099',
      'airtel': 'BIL100',
      'glo': 'BIL101',
      '9mobile': 'BIL102',
    };
    
    final response = await http.post(
      Uri.parse('$baseUrl/bills'),
      headers: {
        'Authorization': 'Bearer $secretKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'country': 'NG',
        'customer': phoneNumber,
        'amount': amount,
        'type': networkCodes[network],
      }),
    );
    return BillResponse.fromJson(response.data);
  }
}
```

### **🔧 Paystack Integration (Backup/Alternative):**
```dart
// lib/services/payments/paystack_service.dart
class PaystackService {
  static const String publicKey = 'pk_test_xxxxx';
  static const String secretKey = 'sk_test_xxxxx';
  
  Future<PaymentResponse> initializePayment({
    required double amount,
    required String email,
    required String reference,
  }) async {
    final response = await http.post(
      Uri.parse('https://api.paystack.co/transaction/initialize'),
      headers: {
        'Authorization': 'Bearer $secretKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'amount': (amount * 100).toInt(), // Paystack uses kobo
        'email': email,
        'reference': reference,
        'callback_url': 'https://your-app.com/payment-callback',
      }),
    );
    return PaymentResponse.fromJson(response.data);
  }
}
```

---

## 💰 **COMMISSION & PAYOUT SYSTEM**

### **🔧 Enhanced Commission Handling:**
```dart
// lib/services/commission/commission_service.dart
class CommissionService {
  static const double platformFee = 0.15; // 15%
  
  Future<void> processServicePayment({
    required String serviceId,
    required String providerId,
    required double totalAmount,
    required String paymentMethod,
  }) async {
    final commission = totalAmount * platformFee;
    final providerEarnings = totalAmount - commission;
    
    // Record commission
    await FirebaseFirestore.instance.collection('commissions').add({
      'serviceId': serviceId,
      'providerId': providerId,
      'totalAmount': totalAmount,
      'commission': commission,
      'providerEarnings': providerEarnings,
      'paymentMethod': paymentMethod,
      'createdAt': DateTime.now().toIso8601String(),
    });
    
    // Credit provider wallet
    await _creditProviderWallet(providerId, providerEarnings);
    
    // Record platform revenue
    await _recordPlatformRevenue(commission, serviceId);
  }
  
  Future<void> _creditProviderWallet(String providerId, double amount) async {
    await FirebaseFirestore.instance
      .collection('provider_wallets')
      .doc(providerId)
      .update({
        'availableBalance': FieldValue.increment(amount),
        'totalEarnings': FieldValue.increment(amount),
        'lastUpdated': DateTime.now().toIso8601String(),
      });
  }
}
```

---

## 🚀 **IMPLEMENTATION PRIORITY**

### **🥇 Phase 1 (Immediate - 2 weeks):**
1. **Enhance Wallet UI**: Create wallet screens with balance display
2. **Flutterwave Bills**: Integrate airtime/data purchase APIs
3. **Bank Transfer**: Add withdrawal to bank account functionality
4. **Commission Tracking**: Implement 15% fee collection and provider payouts

### **🥈 Phase 2 (Medium - 1 month):**
1. **Paystack Integration**: Add as secondary payment gateway
2. **Bill Payment APIs**: Electricity, Cable TV, Internet bills
3. **Virtual Accounts**: Auto-generated accounts for easier funding
4. **Advanced Analytics**: Wallet usage, transaction insights

### **🥉 Phase 3 (Advanced - 2 months):**
1. **Interswitch Integration**: Government payments, POS integration
2. **Digital Banking**: Kuda/Opay APIs for advanced features
3. **Savings/Investment**: Wallet interest and investment options
4. **Loan Services**: Provider financing and customer credit

---

## 💡 **RECOMMENDED NEXT STEPS**

### **1. 🔧 Setup Development Environment:**
```bash
# Install payment SDKs
npm install flutterwave-node-v3
npm install paystack
flutter pub add flutterwave_standard
flutter pub add paystack_manager
```

### **2. 🔑 Get API Keys:**
- **Flutterwave**: https://flutterwave.com/dashboard → Settings → API Keys
- **Paystack**: https://paystack.com/dashboard → Settings → API Keys
- **Stripe**: https://dashboard.stripe.com → Developers → API Keys

### **3. 🏦 Bank Integration:**
- **Nigerian Banks**: GTBank, Access, Zenith, UBA, First Bank
- **Mobile Money**: MTN MoMo, Airtel Money
- **USSD Codes**: *737# (GTBank), *770# (Fidelity), etc.

### **4. 📱 Test Environment:**
```
Test Cards:
- Flutterwave: 4187427415564246 (Test Visa)
- Paystack: 4084084084084081 (Test Visa)
- Stripe: 4242424242424242 (Test Visa)

Test Phone: +234XXXXXXXXXX
Test Bank: 044 (Access Bank)
```

---

## 🎯 **EXPECTED RESULTS**

### **💰 Revenue Impact:**
- **Wallet Transactions**: Additional 5-10% revenue from digital services
- **Bill Payments**: ₦50-100 profit per transaction
- **Airtime Sales**: ₦10-20 profit per transaction  
- **Bank Transfers**: ₦100-200 fee per transfer
- **Provider Retention**: Better cash flow = more active providers

### **📱 User Engagement:**
- **Daily Usage**: Wallet features increase daily app opens
- **Stickiness**: Financial services create user dependency
- **Cross-selling**: Wallet users more likely to use other services
- **Market Position**: Becomes essential financial app

---

## 🚀 **YOUR ZIPPUP WALLET ECOSYSTEM**

**With proper implementation, ZippUp becomes:**
- 💳 **Digital Bank**: Full wallet functionality
- 📱 **Super App**: All services + financial services
- 🏦 **Payment Hub**: Airtime, bills, transfers, shopping
- 💰 **Revenue Engine**: Multiple commission streams
- 🌍 **Market Leader**: Comprehensive African service platform

**This wallet integration could increase your app's valuation by 50-100% ($3.75M - $30M+) due to the financial services component and increased user engagement!** 🎯💰✨