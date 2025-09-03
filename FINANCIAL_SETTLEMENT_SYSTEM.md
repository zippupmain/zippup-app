# 💰 Automated Financial Settlement & Geolocation System

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                FINANCIAL SETTLEMENT ARCHITECTURE                │
├─────────────────────────────────────────────────────────────────┤
│  💳 PAYMENT PROCESSING LAYER                                    │
│  ├─ Multi-currency support with real-time exchange rates       │
│  ├─ Automated commission calculation and deduction             │
│  ├─ Instant wallet crediting for digital payments              │
│  └─ Delayed commission deduction for cash payments             │
│                                                                 │
│  🏦 WALLET MANAGEMENT SYSTEM                                    │
│  ├─ Multi-currency wallet balances                             │
│  ├─ Automatic negative balance handling                        │
│  ├─ Provider status management (active/overdue)                │
│  └─ Grace period enforcement with settlement cycles            │
│                                                                 │
│  🌍 GEOLOCATION SERVICES                                        │
│  ├─ IP-based country detection with GPS validation             │
│  ├─ Currency auto-selection based on location                  │
│  ├─ Country-biased address search and validation               │
│  └─ Anti-spoofing measures and location verification           │
│                                                                 │
│  🔔 INTELLIGENT NOTIFICATION SYSTEM                             │
│  ├─ Unread count management with real-time updates             │
│  ├─ Deep-link routing to relevant app sections                 │
│  ├─ Priority-based notification delivery                       │
│  └─ Cross-platform synchronization                             │
│                                                                 │
│  📱 LOCALIZED DIGITAL SERVICES                                  │
│  ├─ Country-specific service configurations                    │
│  ├─ Dynamic provider lists based on location                  │
│  ├─ Localized pricing and denomination structures              │
│  └─ Regulatory compliance per jurisdiction                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🗄️ Comprehensive Database Schema

### 1. `wallets` Collection
```javascript
{
  // Document ID: user_id
  userId: "provider_123",
  
  // Multi-currency balances
  balances: {
    NGN: {
      available: 45000.0,        // Available for withdrawal
      pending: 2500.0,          // Pending settlements
      total: 47500.0,           // Total balance
      lastUpdated: Timestamp
    },
    USD: {
      available: 120.50,
      pending: 8.75,
      total: 129.25,
      lastUpdated: Timestamp
    },
    ZAR: {
      available: -150.0,        // Negative balance (debt to platform)
      pending: 0.0,
      total: -150.0,
      lastUpdated: Timestamp
    }
  },
  
  // Primary currency (based on user's location)
  primaryCurrency: "NGN",
  
  // Account status and debt management
  accountStatus: {
    status: "active", // active | payment_overdue | suspended | frozen
    overdueSince: null, // Timestamp when account went overdue
    gracePeriodsUsed: 0, // Number of grace periods used this month
    maxGracePeriods: 3, // Maximum grace periods allowed
    
    // Debt tracking
    totalDebt: {
      NGN: 0.0,
      USD: 0.0,
      ZAR: 150.0 // Outstanding debt in ZAR
    },
    
    // Settlement requirements
    minimumTopUpRequired: {
      ZAR: 200.0 // Must add at least R200 to clear debt + buffer
    },
    
    // Automatic restrictions
    canReceiveNewOrders: false, // Blocked due to overdue payment
    canWithdrawFunds: false,    // Blocked until debt cleared
    requiresImmediateSettlement: true
  },
  
  // Payment methods for auto top-up
  linkedPaymentMethods: [
    {
      id: "pm_card_123",
      type: "card", // card | bank_account | mobile_money
      provider: "stripe",
      last4: "4242",
      brand: "visa",
      isDefault: true,
      isVerified: true,
      country: "ZA",
      currency: "ZAR"
    }
  ],
  
  // Automatic settlement configuration
  autoSettlement: {
    enabled: true,
    triggerAmount: -100.0, // Auto top-up when balance goes below -$100
    topUpAmount: 500.0,    // Top up $500 when triggered
    maxAutoTopUps: 3,      // Maximum auto top-ups per month
    usedThisMonth: 1,      // Auto top-ups used this month
    lastAutoTopUp: Timestamp
  },
  
  // Wallet security
  security: {
    pin: "encrypted_pin_hash",
    twoFactorEnabled: true,
    lastSecurityUpdate: Timestamp,
    failedPinAttempts: 0,
    lockedUntil: null,
    
    // Fraud prevention
    dailyTransactionLimit: {
      NGN: 500000.0, // ₦500,000 daily limit
      USD: 1000.0,   // $1,000 daily limit
      ZAR: 15000.0   // R15,000 daily limit
    },
    suspiciousActivityFlags: 0
  },
  
  // Performance metrics
  metrics: {
    totalEarnings: {
      allTime: { NGN: 1250000.0, USD: 3200.0, ZAR: 45000.0 },
      thisMonth: { NGN: 85000.0, USD: 220.0, ZAR: 3200.0 },
      thisWeek: { NGN: 18000.0, USD: 45.0, ZAR: 650.0 }
    },
    
    transactionCounts: {
      totalTransactions: 456,
      commissionsDeducted: 123,
      topUpsCompleted: 8,
      withdrawalsCompleted: 12
    },
    
    averageOrderValue: { NGN: 2500.0, USD: 8.5, ZAR: 125.0 },
    commissionRate: 0.15, // 15% platform commission
  },
  
  // Timestamps
  createdAt: Timestamp,
  updatedAt: Timestamp,
  lastTransactionAt: Timestamp
}
```

### 2. `transactions` Collection (Complete Financial Audit Trail)
```javascript
{
  // Document ID: auto-generated transaction ID
  transactionId: "txn_abc123def456",
  
  // Transaction identification
  orderId: "order_abc123", // Related order/service
  userId: "provider_123",  // Wallet owner
  
  // Transaction details
  type: "commission_deduction", // commission_deduction | earnings_credit | wallet_topup | withdrawal | refund
  category: "order_settlement", // order_settlement | wallet_management | refund_processing
  
  // Financial amounts
  amount: -375.0, // Negative for debits, positive for credits
  currency: "NGN",
  
  // Commission breakdown (for order settlements)
  commissionDetails: {
    orderTotal: 2500.0,
    platformCommissionRate: 0.15,
    platformCommission: 375.0,
    providerEarnings: 2125.0,
    
    // Additional fees
    processingFee: 50.0,
    serviceFee: 25.0,
    tax: 187.5, // 7.5% VAT
    
    // Net calculation
    netToProvider: 2125.0, // What provider receives
    netToPlatform: 375.0   // What platform earns
  },
  
  // Wallet balance tracking
  balanceTracking: {
    previousBalance: 12500.0,
    newBalance: 12125.0,
    balanceAfterTransaction: 12125.0,
    
    // Multi-currency tracking
    affectedCurrency: "NGN",
    exchangeRate: 1.0, // If currency conversion involved
    originalAmount: -375.0,
    convertedAmount: -375.0
  },
  
  // Payment method details
  paymentMethod: {
    type: "cash", // cash | card | wallet | bank_transfer | mobile_money
    provider: null, // stripe | paystack | flutterwave | etc.
    reference: null, // External payment reference
    
    // For cash transactions
    collectedBy: "provider_123",
    collectedAt: Timestamp,
    verifiedBy: "customer_456" // Customer confirmation
  },
  
  // Transaction status and processing
  status: "completed", // pending | processing | completed | failed | reversed
  processingStatus: {
    initiated: Timestamp,
    processed: Timestamp,
    completed: Timestamp,
    
    // Error handling
    failureReason: null,
    retryCount: 0,
    maxRetries: 3
  },
  
  // Geolocation context
  locationContext: {
    country: "NG", // ISO country code
    currency: "NGN",
    exchangeRate: 1.0,
    ipAddress: "197.210.xxx.xxx", // Masked for privacy
    gpsLocation: {
      latitude: 6.5244,
      longitude: 3.3792,
      accuracy: 10.0
    },
    timezone: "Africa/Lagos"
  },
  
  // Regulatory and compliance
  compliance: {
    taxCalculation: {
      taxRate: 0.075, // 7.5% VAT
      taxAmount: 187.5,
      taxId: "VAT_NG_2024_001"
    },
    
    amlCompliance: {
      riskLevel: "low", // low | medium | high
      kycStatus: "verified",
      sanctionsCheck: "passed",
      pep_check: "passed" // Politically Exposed Person
    },
    
    reportingRequirements: {
      requiresTaxReporting: true,
      requiresAMLReporting: false,
      reportingThreshold: 1000000.0 // ₦1M threshold
    }
  },
  
  // Audit and reconciliation
  auditTrail: {
    createdBy: "system", // system | admin | user
    approvedBy: null,
    reviewedBy: null,
    
    // External system references
    externalReferences: {
      paymentGatewayId: "pi_stripe_123",
      bankReference: "TXN_BANK_456",
      regulatoryReference: "REG_NG_789"
    },
    
    // Reconciliation
    reconciledAt: null,
    reconciliationBatch: null,
    discrepancyFlags: []
  },
  
  // Metadata
  metadata: {
    deviceInfo: {
      platform: "android",
      appVersion: "1.2.3",
      deviceId: "device_hash_123"
    },
    
    businessContext: {
      serviceType: "transport",
      serviceClass: "standard",
      providerId: "provider_123",
      customerId: "customer_456"
    }
  },
  
  // Timestamps
  createdAt: Timestamp,
  processedAt: Timestamp,
  settledAt: Timestamp
}
```

### 3. `notifications` Collection
```javascript
{
  // Document ID: auto-generated notification ID
  notificationId: "notif_abc123",
  
  // Recipient information
  userId: "provider_123",
  userRole: "provider", // customer | provider | driver | admin
  
  // Notification content
  title: "💰 Earnings Credited",
  message: "₦2,125 has been added to your wallet for order #ABC123",
  
  // Rich notification data
  richData: {
    type: "earnings_credit", // earnings_credit | commission_deduction | payment_overdue | order_update
    category: "financial", // financial | order | system | promotional
    priority: "normal", // low | normal | high | critical
    
    // Visual presentation
    icon: "💰",
    color: "#4CAF50", // Green for positive financial events
    image: null,
    
    // Structured data for rich display
    structuredData: {
      amount: 2125.0,
      currency: "NGN",
      orderId: "order_abc123",
      orderType: "transport",
      commissionDeducted: 375.0,
      netEarnings: 2125.0
    }
  },
  
  // Interaction tracking
  isRead: false,
  readAt: null,
  clickedAt: null,
  
  // Deep linking and actions
  actionPath: "/wallet/transaction/txn_abc123def456", // Where to navigate when clicked
  deepLink: "zippup://wallet?transactionId=txn_abc123def456",
  
  // Action buttons (optional)
  actions: [
    {
      id: "view_transaction",
      title: "View Details",
      action: "/wallet/transaction/txn_abc123def456",
      style: "primary"
    },
    {
      id: "withdraw_funds",
      title: "Withdraw",
      action: "/wallet/withdraw",
      style: "secondary"
    }
  ],
  
  // Delivery tracking
  delivery: {
    channels: ["in_app", "push", "email"], // Delivery channels used
    deliveredVia: ["in_app", "push"], // Successfully delivered via
    deliveryAttempts: 1,
    lastDeliveryAttempt: Timestamp,
    
    // Push notification details
    pushNotification: {
      sent: true,
      sentAt: Timestamp,
      platform: "android",
      fcmMessageId: "fcm_msg_123",
      clickedAt: null
    }
  },
  
  // Expiration and cleanup
  expiresAt: Timestamp, // Auto-delete after 90 days if read
  autoDeleteAfterRead: false, // Keep important financial notifications
  
  // Grouping and threading
  threadId: "earnings_thread_123", // Group related notifications
  parentNotificationId: null, // For reply/update notifications
  
  // Localization
  localization: {
    locale: "en_NG", // English Nigeria
    timezone: "Africa/Lagos",
    currency: "NGN",
    dateFormat: "DD/MM/YYYY",
    numberFormat: "1,234.56"
  },
  
  // Timestamps
  createdAt: Timestamp,
  updatedAt: Timestamp,
  scheduledFor: null // For scheduled notifications
}
```

### 4. `digital_services_config` Collection
```javascript
{
  // Document ID: country_service combination
  _id: "NG_airtime",
  
  // Geographic configuration
  countryCode: "NG", // ISO 3166-1 alpha-2
  countryName: "Nigeria",
  region: "West Africa",
  
  // Service configuration
  serviceType: "airtime", // airtime | data | bills | utilities
  serviceName: "Mobile Airtime Top-up",
  isActive: true,
  
  // Service providers for this country
  providers: [
    {
      id: "mtn_ng",
      name: "MTN Nigeria",
      displayName: "MTN",
      logo: "https://cdn.zippup.com/logos/mtn_ng.png",
      
      // Network information
      networkCode: "621_20", // Mobile Network Code
      ussdCode: "*555#",
      
      // Supported denominations
      denominations: [
        { value: 100, display: "₦100", popular: true },
        { value: 200, display: "₦200", popular: true },
        { value: 500, display: "₦500", popular: true },
        { value: 1000, display: "₦1,000", popular: true },
        { value: 2000, display: "₦2,000", popular: false },
        { value: 5000, display: "₦5,000", popular: false }
      ],
      
      // Pricing and fees
      fees: {
        processingFee: 10.0, // ₦10 processing fee
        feeType: "fixed", // fixed | percentage
        minimumFee: 5.0,
        maximumFee: 100.0
      },
      
      // API configuration
      apiConfig: {
        provider: "reloadly", // reloadly | ding | topup
        productId: "mtn_nigeria_airtime",
        endpoint: "https://api.reloadly.com/airtime/topup",
        requiresValidation: true,
        validationRegex: "^234[0-9]{10}$" // Nigerian phone number format
      },
      
      // Operational status
      isOperational: true,
      lastStatusCheck: Timestamp,
      averageProcessingTime: 15.0, // seconds
      successRate: 0.98 // 98% success rate
    },
    
    // Additional providers...
    {
      id: "glo_ng",
      name: "Globacom Nigeria",
      displayName: "Glo",
      // ... similar structure
    },
    {
      id: "airtel_ng", 
      name: "Airtel Nigeria",
      displayName: "Airtel",
      // ... similar structure
    },
    {
      id: "9mobile_ng",
      name: "9mobile Nigeria", 
      displayName: "9mobile",
      // ... similar structure
    }
  ],
  
  // Country-specific configuration
  countryConfig: {
    currency: "NGN",
    currencySymbol: "₦",
    decimalPlaces: 2,
    
    // Phone number validation
    phoneNumberFormat: {
      regex: "^234[0-9]{10}$",
      example: "2348012345678",
      displayFormat: "+234 801 234 5678"
    },
    
    // Regulatory requirements
    regulatory: {
      requiresKYC: true,
      kycThreshold: 50000.0, // ₦50,000
      requiresTaxId: false,
      maxTransactionAmount: 100000.0, // ₦100,000
      
      // Compliance monitoring
      sanctionsScreening: true,
      amlMonitoring: true,
      cftMonitoring: false // Counter Financing of Terrorism
    },
    
    // Business hours and availability
    operatingHours: {
      timezone: "Africa/Lagos",
      businessDays: ["monday", "tuesday", "wednesday", "thursday", "friday"],
      businessHours: { start: "06:00", end: "23:00" },
      weekendHours: { start: "08:00", end: "22:00" },
      
      // Holiday calendar
      holidays: [
        { date: "2024-01-01", name: "New Year's Day" },
        { date: "2024-10-01", name: "Independence Day" }
      ]
    }
  },
  
  // Metadata
  version: "1.0",
  lastUpdated: Timestamp,
  updatedBy: "admin_user_123",
  effectiveFrom: Timestamp,
  effectiveUntil: null
}
```

### 5. `geolocation_sessions` Collection
```javascript
{
  // Document ID: user_id
  userId: "user_123",
  
  // Current location determination
  currentLocation: {
    // Primary location sources
    ipGeolocation: {
      country: "NG",
      countryName: "Nigeria", 
      city: "Lagos",
      region: "Lagos State",
      latitude: 6.5244,
      longitude: 3.3792,
      accuracy: "city", // country | region | city | precise
      provider: "maxmind", // maxmind | ipapi | geoip2
      confidence: 0.95,
      lastUpdated: Timestamp
    },
    
    gpsLocation: {
      latitude: 6.5244,
      longitude: 3.3792,
      accuracy: 10.0, // meters
      altitude: 45.0,
      heading: 180.0,
      speed: 0.0,
      lastUpdated: Timestamp,
      source: "gps" // gps | network | passive
    },
    
    // Resolved location (final determination)
    resolvedLocation: {
      country: "NG",
      currency: "NGN", 
      timezone: "Africa/Lagos",
      locale: "en_NG",
      confidence: 0.98,
      resolutionMethod: "gps_primary_ip_fallback",
      lastResolved: Timestamp
    }
  },
  
  // Anti-spoofing measures
  locationVerification: {
    // Cross-validation between sources
    ipGpsConsistency: true, // IP and GPS locations match
    consistencyScore: 0.95,
    
    // Suspicious activity detection
    rapidLocationChanges: false, // Detected impossible travel
    vpnDetected: false,
    proxyDetected: false,
    
    // Device consistency
    deviceLocationHistory: [
      {
        country: "NG",
        timestamp: Timestamp,
        source: "gps",
        confidence: 0.98
      }
    ],
    
    // Verification status
    locationTrusted: true,
    trustScore: 0.95,
    lastVerified: Timestamp,
    
    // Flags and warnings
    suspiciousFlags: [],
    warningLevel: "none" // none | low | medium | high
  },
  
  // Service availability based on location
  availableServices: {
    transport: true,
    food: true,
    grocery: true,
    emergency: true,
    hire: true,
    digital: true,
    
    // Location-specific restrictions
    restrictions: [],
    lastUpdated: Timestamp
  },
  
  // Address search configuration
  addressSearchConfig: {
    countryBias: "NG",
    language: "en",
    components: {
      country: "ng" // Strict country filtering
    },
    
    // Search providers
    primaryProvider: "google_places",
    fallbackProvider: "mapbox_search",
    
    // Search preferences
    allowFuzzyMatching: true,
    requirePreciseCoordinates: false, // Allow "The Mall" style addresses
    maxResults: 10,
    searchRadius: 50000 // 50km search radius
  },
  
  // Session tracking
  session: {
    sessionId: "session_abc123",
    startedAt: Timestamp,
    lastActivity: Timestamp,
    deviceInfo: {
      platform: "android",
      model: "Samsung Galaxy S21",
      osVersion: "Android 12",
      appVersion: "1.2.3"
    }
  }
}
```

---

## 💳 Financial Settlement Logic

### Core Settlement Function

```javascript
/**
 * Automated financial settlement for completed orders
 * Handles commission deduction, wallet crediting, and debt management
 */
async function settleTransaction(orderId) {
  console.log(`💰 Processing settlement for order: ${orderId}`);
  
  try {
    // Step 1: Get order details and validate
    const orderData = await getOrderDetails(orderId);
    if (!orderData || orderData.status !== 'completed') {
      throw new Error(`Order ${orderId} is not ready for settlement`);
    }

    // Step 2: Calculate financial breakdown
    const financialBreakdown = await calculateFinancialBreakdown(orderData);
    
    // Step 3: Determine settlement strategy based on payment method
    if (orderData.paymentMethod === 'cash') {
      await processCashSettlement(orderId, orderData, financialBreakdown);
    } else {
      await processDigitalSettlement(orderId, orderData, financialBreakdown);
    }

    console.log(`✅ Settlement completed for order: ${orderId}`);
    return { success: true, orderId: orderId };

  } catch (error) {
    console.error(`❌ Settlement failed for order ${orderId}:`, error);
    await handleSettlementError(orderId, error);
    throw error;
  }
}

/**
 * Calculate comprehensive financial breakdown
 */
async function calculateFinancialBreakdown(orderData) {
  const orderTotal = orderData.total || 0;
  const currency = orderData.currency || 'NGN';
  const serviceType = orderData.serviceType || 'transport';
  
  // Get commission rate (service and provider specific)
  const commissionRate = await getCommissionRate(orderData.serviceType, orderData.providerId);
  
  // Calculate breakdown
  const platformCommission = orderTotal * commissionRate;
  const processingFee = await calculateProcessingFee(orderTotal, orderData.paymentMethod);
  const taxAmount = await calculateTax(orderTotal, orderData.country);
  
  // Net calculations
  const totalDeductions = platformCommission + processingFee + taxAmount;
  const providerEarnings = orderTotal - totalDeductions;
  
  return {
    orderTotal: orderTotal,
    currency: currency,
    
    // Platform revenue
    platformCommission: platformCommission,
    commissionRate: commissionRate,
    processingFee: processingFee,
    taxAmount: taxAmount,
    totalPlatformRevenue: platformCommission + processingFee + taxAmount,
    
    // Provider revenue
    providerEarnings: providerEarnings,
    providerEarningsRate: providerEarnings / orderTotal,
    
    // Breakdown for transparency
    breakdown: {
      orderValue: orderTotal,
      platformCommission: `-${platformCommission}`,
      processingFee: `-${processingFee}`,
      tax: `-${taxAmount}`,
      netToProvider: providerEarnings
    }
  };
}

/**
 * Process cash payment settlement
 * Provider collected cash, platform deducts commission from wallet
 */
async function processCashSettlement(orderId, orderData, financialBreakdown) {
  const providerId = orderData.providerId;
  const currency = orderData.currency;
  
  console.log(`💵 Processing cash settlement for provider: ${providerId}`);
  
  try {
    // Step 1: Credit full amount to provider (they collected cash)
    await creditProviderWallet({
      userId: providerId,
      amount: financialBreakdown.orderTotal,
      currency: currency,
      type: 'cash_collection_credit',
      orderId: orderId,
      description: `Cash collected for order #${orderId.substring(0, 8)}`
    });

    // Step 2: Immediately deduct platform commission
    const deductionResult = await deductCommissionFromWallet({
      userId: providerId,
      amount: financialBreakdown.platformCommission,
      currency: currency,
      orderId: orderId,
      breakdown: financialBreakdown
    });

    // Step 3: Handle insufficient funds scenario
    if (!deductionResult.success && deductionResult.reason === 'insufficient_funds') {
      await handleInsufficientFundsForCash(providerId, orderId, financialBreakdown, deductionResult);
    }

    console.log(`✅ Cash settlement completed for order: ${orderId}`);

  } catch (error) {
    console.error(`❌ Cash settlement error:`, error);
    throw error;
  }
}

/**
 * Process digital payment settlement  
 * Customer paid digitally, credit net amount to provider
 */
async function processDigitalSettlement(orderId, orderData, financialBreakdown) {
  const providerId = orderData.providerId;
  const currency = orderData.currency;
  
  console.log(`💳 Processing digital settlement for provider: ${providerId}`);
  
  try {
    // For digital payments, credit only the net earnings (after commission)
    await creditProviderWallet({
      userId: providerId,
      amount: financialBreakdown.providerEarnings,
      currency: currency,
      type: 'earnings_credit',
      orderId: orderId,
      description: `Earnings for order #${orderId.substring(0, 8)} (${financialBreakdown.commissionRate * 100}% commission deducted)`,
      breakdown: financialBreakdown
    });

    // Record platform commission as earned (no deduction needed)
    await recordPlatformRevenue({
      orderId: orderId,
      amount: financialBreakdown.platformCommission,
      currency: currency,
      revenueType: 'commission',
      breakdown: financialBreakdown
    });

    console.log(`✅ Digital settlement completed for order: ${orderId}`);

  } catch (error) {
    console.error(`❌ Digital settlement error:`, error);
    throw error;
  }
}

/**
 * Handle insufficient funds for cash commission deduction
 */
async function handleInsufficientFundsForCash(providerId, orderId, financialBreakdown, deductionResult) {
  console.log(`⚠️ Insufficient funds for commission deduction: ${providerId}`);
  
  try {
    const currency = financialBreakdown.currency;
    const commissionOwed = financialBreakdown.platformCommission;
    
    // Step 1: Force deduction (creating negative balance)
    await forceCommissionDeduction({
      userId: providerId,
      amount: commissionOwed,
      currency: currency,
      orderId: orderId,
      reason: 'cash_commission_insufficient_funds'
    });

    // Step 2: Update provider account status
    await updateProviderAccountStatus({
      userId: providerId,
      newStatus: 'payment_overdue',
      reason: 'insufficient_funds_commission_deduction',
      debtAmount: commissionOwed,
      currency: currency,
      orderId: orderId,
      gracePeriodsRemaining: await getGracePeriodsRemaining(providerId)
    });

    // Step 3: Start grace period countdown
    const gracePeriodHours = await getGracePeriodDuration(providerId);
    await schedulePaymentEnforcement(providerId, gracePeriodHours);

    // Step 4: Notify provider of overdue status
    await notifyProviderOfOverdueStatus({
      userId: providerId,
      debtAmount: commissionOwed,
      currency: currency,
      gracePeriodHours: gracePeriodHours,
      orderId: orderId
    });

    console.log(`⚠️ Provider ${providerId} account set to payment_overdue`);

  } catch (error) {
    console.error(`❌ Error handling insufficient funds:`, error);
    throw error;
  }
}

/**
 * Credit provider wallet with transaction logging
 */
async function creditProviderWallet(params) {
  const { userId, amount, currency, type, orderId, description, breakdown } = params;
  
  try {
    // Use transaction for atomic wallet update
    await admin.firestore().runTransaction(async (transaction) => {
      const walletRef = admin.firestore().collection('wallets').doc(userId);
      const walletSnap = await transaction.get(walletRef);
      
      let walletData = {};
      if (walletSnap.exists) {
        walletData = walletSnap.data();
      }

      // Update balance
      const currentBalance = walletData.balances?.[currency]?.available || 0;
      const newBalance = currentBalance + amount;
      
      const updateData = {
        [`balances.${currency}.available`]: newBalance,
        [`balances.${currency}.total`]: newBalance + (walletData.balances?.[currency]?.pending || 0),
        [`balances.${currency}.lastUpdated`]: admin.firestore.FieldValue.serverTimestamp(),
        'updatedAt': admin.firestore.FieldValue.serverTimestamp(),
        'lastTransactionAt': admin.firestore.FieldValue.serverTimestamp()
      };

      if (!walletSnap.exists) {
        updateData.userId = userId;
        updateData.primaryCurrency = currency;
        updateData.createdAt = admin.firestore.FieldValue.serverTimestamp();
      }

      transaction.set(walletRef, updateData, { merge: true });

      // Create transaction record
      const transactionRef = admin.firestore().collection('transactions').doc();
      transaction.set(transactionRef, {
        transactionId: transactionRef.id,
        orderId: orderId,
        userId: userId,
        type: type,
        category: 'order_settlement',
        amount: amount,
        currency: currency,
        
        balanceTracking: {
          previousBalance: currentBalance,
          newBalance: newBalance,
          affectedCurrency: currency
        },
        
        commissionDetails: breakdown || null,
        
        status: 'completed',
        processingStatus: {
          initiated: admin.firestore.FieldValue.serverTimestamp(),
          completed: admin.firestore.FieldValue.serverTimestamp()
        },
        
        locationContext: await getCurrentLocationContext(userId),
        
        metadata: {
          description: description,
          settlementType: 'automatic',
          businessContext: {
            serviceType: orderData?.serviceType,
            providerId: userId,
            customerId: orderData?.customerId
          }
        },
        
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    // Send wallet credit notification
    await sendWalletNotification({
      userId: userId,
      type: 'wallet_credit',
      amount: amount,
      currency: currency,
      orderId: orderId,
      newBalance: await getWalletBalance(userId, currency)
    });

    console.log(`✅ Credited ${currency} ${amount} to provider ${userId} wallet`);

  } catch (error) {
    console.error(`❌ Error crediting provider wallet:`, error);
    throw error;
  }
}

/**
 * Deduct commission from provider wallet
 */
async function deductCommissionFromWallet(params) {
  const { userId, amount, currency, orderId, breakdown } = params;
  
  try {
    // Check current wallet balance
    const currentBalance = await getWalletBalance(userId, currency);
    
    if (currentBalance >= amount) {
      // Sufficient funds - normal deduction
      await debitProviderWallet({
        userId: userId,
        amount: amount,
        currency: currency,
        type: 'commission_deduction',
        orderId: orderId,
        description: `Platform commission for order #${orderId.substring(0, 8)}`,
        breakdown: breakdown
      });
      
      return { success: true, newBalance: currentBalance - amount };
      
    } else {
      // Insufficient funds - return failure for special handling
      return {
        success: false,
        reason: 'insufficient_funds',
        currentBalance: currentBalance,
        requiredAmount: amount,
        shortfall: amount - currentBalance
      };
    }

  } catch (error) {
    console.error(`❌ Error deducting commission:`, error);
    return {
      success: false,
      reason: 'processing_error',
      error: error.message
    };
  }
}

/**
 * Force commission deduction (creating negative balance)
 */
async function forceCommissionDeduction(params) {
  const { userId, amount, currency, orderId, reason } = params;
  
  try {
    await admin.firestore().runTransaction(async (transaction) => {
      const walletRef = admin.firestore().collection('wallets').doc(userId);
      const walletSnap = await transaction.get(walletRef);
      
      const walletData = walletSnap.data() || {};
      const currentBalance = walletData.balances?.[currency]?.available || 0;
      const newBalance = currentBalance - amount; // Will be negative
      
      // Update wallet with negative balance
      transaction.update(walletRef, {
        [`balances.${currency}.available`]: newBalance,
        [`balances.${currency}.total`]: newBalance,
        [`balances.${currency}.lastUpdated`]: admin.firestore.FieldValue.serverTimestamp(),
        
        // Update debt tracking
        [`accountStatus.totalDebt.${currency}`]: Math.abs(Math.min(0, newBalance)),
        'accountStatus.status': 'payment_overdue',
        'accountStatus.overdueSince': admin.firestore.FieldValue.serverTimestamp(),
        'accountStatus.canReceiveNewOrders': false,
        
        'updatedAt': admin.firestore.FieldValue.serverTimestamp()
      });

      // Create transaction record for forced deduction
      const transactionRef = admin.firestore().collection('transactions').doc();
      transaction.set(transactionRef, {
        transactionId: transactionRef.id,
        orderId: orderId,
        userId: userId,
        type: 'forced_commission_deduction',
        category: 'debt_collection',
        amount: -amount, // Negative amount for debit
        currency: currency,
        
        balanceTracking: {
          previousBalance: currentBalance,
          newBalance: newBalance,
          wentNegative: newBalance < 0,
          debtCreated: Math.abs(Math.min(0, newBalance))
        },
        
        status: 'completed',
        metadata: {
          reason: reason,
          forcedDeduction: true,
          settlementType: 'cash_commission_recovery'
        },
        
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    console.log(`⚠️ Forced commission deduction: ${currency} ${amount} from provider ${userId}`);

  } catch (error) {
    console.error(`❌ Error in forced commission deduction:`, error);
    throw error;
  }
}

/**
 * Update provider account status and restrictions
 */
async function updateProviderAccountStatus(params) {
  const { userId, newStatus, reason, debtAmount, currency, orderId, gracePeriodsRemaining } = params;
  
  try {
    const statusUpdate = {
      'accountStatus.status': newStatus,
      'accountStatus.lastStatusUpdate': admin.firestore.FieldValue.serverTimestamp(),
      'accountStatus.statusReason': reason,
      'updatedAt': admin.firestore.FieldValue.serverTimestamp()
    };

    if (newStatus === 'payment_overdue') {
      statusUpdate['accountStatus.overdueSince'] = admin.firestore.FieldValue.serverTimestamp();
      statusUpdate['accountStatus.canReceiveNewOrders'] = false;
      statusUpdate['accountStatus.canWithdrawFunds'] = false;
      statusUpdate[`accountStatus.totalDebt.${currency}`] = debtAmount;
      statusUpdate[`accountStatus.minimumTopUpRequired.${currency}`] = debtAmount * 1.1; // 10% buffer
      
      // Grace period management
      if (gracePeriodsRemaining > 0) {
        const gracePeriodEnd = new Date(Date.now() + (24 * 60 * 60 * 1000)); // 24 hours
        statusUpdate['accountStatus.gracePeriodEnd'] = admin.firestore.Timestamp.fromDate(gracePeriodEnd);
        statusUpdate['accountStatus.gracePeriodsUsed'] = admin.firestore.FieldValue.increment(1);
      }
    }

    await admin.firestore().collection('wallets').doc(userId).update(statusUpdate);

    // Update provider profile to block new requests
    const providerQuery = await admin.firestore()
      .collection('provider_profiles')
      .where('userId', '==', userId)
      .get();

    const batch = admin.firestore().batch();
    providerQuery.docs.forEach(doc => {
      batch.update(doc.ref, {
        'availabilityStatus': newStatus === 'payment_overdue' ? 'payment_suspended' : 'available',
        'paymentStatus': newStatus,
        'lastPaymentStatusUpdate': admin.firestore.FieldValue.serverTimestamp()
      });
    });

    await batch.commit();

    console.log(`✅ Provider ${userId} status updated to: ${newStatus}`);

  } catch (error) {
    console.error(`❌ Error updating provider status:`, error);
    throw error;
  }
}

/**
 * Schedule automatic payment enforcement after grace period
 */
async function schedulePaymentEnforcement(providerId, gracePeriodHours) {
  try {
    // Create scheduled task for payment enforcement
    await admin.firestore().collection('scheduled_tasks').add({
      taskType: 'enforce_payment_overdue',
      providerId: providerId,
      scheduledFor: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + (gracePeriodHours * 60 * 60 * 1000))
      ),
      status: 'scheduled',
      
      taskData: {
        gracePeriodHours: gracePeriodHours,
        enforcementActions: [
          'block_new_orders',
          'suspend_provider_profiles', 
          'send_final_notice',
          'escalate_to_collections'
        ]
      },
      
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`⏰ Scheduled payment enforcement for provider ${providerId} in ${gracePeriodHours} hours`);

  } catch (error) {
    console.error(`❌ Error scheduling payment enforcement:`, error);
  }
}
```

---

## 🌍 Geolocation & Currency System

### Location Resolution Service

```dart
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class GeolocationService {
  static final GeolocationService _instance = GeolocationService._internal();
  factory GeolocationService() => _instance;
  GeolocationService._internal();

  /// Resolve user's current location and currency
  Future<LocationResult> resolveUserLocation({
    bool useGPS = true,
    bool validateConsistency = true,
  }) async {
    try {
      print('🌍 Resolving user location...');

      // Step 1: Get IP-based location (always available)
      final ipLocation = await _getIPBasedLocation();
      
      // Step 2: Get GPS location (if available and permitted)
      GPSLocation? gpsLocation;
      if (useGPS) {
        gpsLocation = await _getGPSLocation();
      }

      // Step 3: Resolve final location with anti-spoofing
      final resolvedLocation = await _resolveLocationWithValidation(
        ipLocation, 
        gpsLocation,
        validateConsistency,
      );

      // Step 4: Get currency and locale information
      final currencyInfo = await _getCurrencyForCountry(resolvedLocation.country);
      
      // Step 5: Configure address search for this location
      final addressConfig = _configureAddressSearch(resolvedLocation);

      final result = LocationResult(
        country: resolvedLocation.country,
        countryName: resolvedLocation.countryName,
        city: resolvedLocation.city,
        region: resolvedLocation.region,
        coordinates: resolvedLocation.coordinates,
        currency: currencyInfo.currency,
        currencySymbol: currencyInfo.symbol,
        timezone: resolvedLocation.timezone,
        locale: resolvedLocation.locale,
        confidence: resolvedLocation.confidence,
        addressSearchConfig: addressConfig,
        validatedAt: DateTime.now(),
      );

      // Step 6: Cache location for session
      await _cacheLocationSession(result);

      print('✅ Location resolved: ${result.country} (${result.currency})');
      return result;

    } catch (e) {
      print('❌ Location resolution error: $e');
      
      // Return safe fallback location
      return _getFallbackLocation();
    }
  }

  /// Get IP-based geolocation
  Future<IPLocation> _getIPBasedLocation() async {
    try {
      // Use multiple IP geolocation providers for reliability
      final providers = [
        'https://ipapi.co/json/',
        'https://ip-api.com/json/',
        'https://ipinfo.io/json?token=YOUR_TOKEN',
      ];

      for (final provider in providers) {
        try {
          final response = await http.get(Uri.parse(provider));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            
            return IPLocation(
              country: data['country_code'] ?? data['countryCode'] ?? 'US',
              countryName: data['country_name'] ?? data['country'] ?? 'United States',
              city: data['city'] ?? 'Unknown',
              region: data['region'] ?? data['region_name'] ?? 'Unknown',
              latitude: double.tryParse(data['latitude']?.toString() ?? '0') ?? 0.0,
              longitude: double.tryParse(data['longitude']?.toString() ?? '0') ?? 0.0,
              timezone: data['timezone'] ?? 'UTC',
              isp: data['isp'] ?? 'Unknown',
              confidence: 0.8, // IP geolocation confidence
              provider: provider,
            );
          }
        } catch (e) {
          print('❌ IP provider $provider failed: $e');
          continue;
        }
      }

      throw Exception('All IP geolocation providers failed');

    } catch (e) {
      print('❌ IP geolocation error: $e');
      rethrow;
    }
  }

  /// Get GPS-based location with permission handling
  Future<GPSLocation?> _getGPSLocation() async {
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever || 
          permission == LocationPermission.denied) {
        print('⚠️ GPS permission denied');
        return null;
      }

      // Get current position with high accuracy
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Reverse geocode to get country information
      final countryInfo = await _reverseGeocodeCountry(
        position.latitude, 
        position.longitude,
      );

      return GPSLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        heading: position.heading,
        speed: position.speed,
        country: countryInfo.country,
        countryName: countryInfo.countryName,
        confidence: _calculateGPSConfidence(position),
        timestamp: DateTime.fromMillisecondsSinceEpoch(position.timestamp.millisecondsSinceEpoch),
      );

    } catch (e) {
      print('❌ GPS location error: $e');
      return null;
    }
  }

  /// Resolve location with anti-spoofing validation
  Future<ResolvedLocation> _resolveLocationWithValidation(
    IPLocation ipLocation,
    GPSLocation? gpsLocation,
    bool validateConsistency,
  ) async {
    try {
      // If GPS is available, use it as primary with IP validation
      if (gpsLocation != null) {
        if (validateConsistency) {
          final isConsistent = _validateLocationConsistency(ipLocation, gpsLocation);
          
          if (!isConsistent) {
            print('⚠️ Location inconsistency detected - potential spoofing');
            
            // Use IP location if GPS seems spoofed
            if (_detectGPSSpoofing(ipLocation, gpsLocation)) {
              print('🚨 GPS spoofing detected, using IP location');
              return _buildResolvedLocation(ipLocation, null, 0.6);
            }
          }
        }

        // GPS location validated, use as primary
        return _buildResolvedLocation(ipLocation, gpsLocation, 0.95);
      }

      // No GPS available, use IP location only
      return _buildResolvedLocation(ipLocation, null, 0.8);

    } catch (e) {
      print('❌ Location validation error: $e');
      return _buildResolvedLocation(ipLocation, null, 0.5);
    }
  }

  /// Validate consistency between IP and GPS locations
  bool _validateLocationConsistency(IPLocation ipLocation, GPSLocation gpsLocation) {
    // Check if GPS and IP locations are in the same country
    if (ipLocation.country != gpsLocation.country) {
      print('⚠️ Country mismatch: IP=${ipLocation.country}, GPS=${gpsLocation.country}');
      return false;
    }

    // Calculate distance between IP and GPS coordinates
    final distance = Geolocator.distanceBetween(
      ipLocation.latitude,
      ipLocation.longitude,
      gpsLocation.latitude,
      gpsLocation.longitude,
    ) / 1000; // Convert to kilometers

    // Allow reasonable distance variance (500km for large countries)
    const maxAllowedDistance = 500.0;
    if (distance > maxAllowedDistance) {
      print('⚠️ Distance too large: ${distance.toStringAsFixed(2)}km');
      return false;
    }

    return true;
  }

  /// Detect potential GPS spoofing
  bool _detectGPSSpoofing(IPLocation ipLocation, GPSLocation gpsLocation) {
    // Multiple spoofing indicators
    
    // 1. Impossible accuracy (GPS claiming sub-meter accuracy is suspicious)
    if (gpsLocation.accuracy < 1.0) {
      print('🚨 Suspicious GPS accuracy: ${gpsLocation.accuracy}m');
      return true;
    }

    // 2. Exact coordinates (spoofed locations often use exact coordinates)
    if (gpsLocation.latitude % 1 == 0 && gpsLocation.longitude % 1 == 0) {
      print('🚨 Suspicious exact coordinates');
      return true;
    }

    // 3. Impossible travel (if we have location history)
    // This would check against previous known locations

    // 4. Mock location detection (Android)
    // This would use platform-specific APIs to detect mock locations

    return false;
  }

  /// Configure address search based on resolved location
  AddressSearchConfig _configureAddressSearch(ResolvedLocation location) {
    return AddressSearchConfig(
      countryBias: location.country.toLowerCase(),
      language: _getLanguageForCountry(location.country),
      components: {
        'country': location.country.toLowerCase(),
      },
      strictCountryFiltering: true,
      allowFuzzyMatching: true,
      requirePreciseCoordinates: false, // Allow "The Mall" style addresses
      maxResults: 10,
      searchRadius: _getSearchRadiusForCountry(location.country),
    );
  }
}

/// Address search service with country-based filtering
class AddressSearchService {
  
  /// Search addresses with strict country filtering
  Future<List<AddressResult>> searchAddresses({
    required String query,
    required double latitude,
    required double longitude,
    required String countryCode,
    int maxResults = 10,
  }) async {
    try {
      print('🔍 Searching addresses: "$query" in $countryCode');

      // Configure search with country bias
      final searchConfig = AddressSearchConfig(
        countryBias: countryCode.toLowerCase(),
        language: 'en', // Default to English
        components: {
          'country': countryCode.toLowerCase(),
        },
        strictCountryFiltering: true,
        location: LatLng(latitude, longitude),
        radius: 50000, // 50km radius
      );

      // Use primary search provider (Google Places)
      List<AddressResult> results = [];
      
      try {
        results = await _searchWithGooglePlaces(query, searchConfig);
      } catch (e) {
        print('❌ Google Places failed: $e');
        
        // Fallback to Mapbox
        try {
          results = await _searchWithMapbox(query, searchConfig);
        } catch (e2) {
          print('❌ Mapbox fallback failed: $e2');
        }
      }

      // Filter and validate results
      final validResults = results
          .where((result) => _validateAddressResult(result, countryCode))
          .take(maxResults)
          .toList();

      print('✅ Found ${validResults.length} valid addresses');
      return validResults;

    } catch (e) {
      print('❌ Address search error: $e');
      return [];
    }
  }

  /// Search with Google Places API
  Future<List<AddressResult>> _searchWithGooglePlaces(
    String query,
    AddressSearchConfig config,
  ) async {
    final apiKey = 'YOUR_GOOGLE_PLACES_API_KEY';
    final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&location=${config.location!.latitude},${config.location!.longitude}'
        '&radius=${config.radius}'
        '&components=country:${config.countryBias}'
        '&language=${config.language}'
        '&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final predictions = List<Map<String, dynamic>>.from(data['predictions'] ?? []);
      
      // Get detailed place information for each prediction
      final results = <AddressResult>[];
      
      for (final prediction in predictions) {
        final placeId = prediction['place_id'];
        final placeDetails = await _getPlaceDetails(placeId, apiKey);
        
        if (placeDetails != null) {
          results.add(AddressResult(
            placeId: placeId,
            name: prediction['structured_formatting']['main_text'] ?? '',
            fullAddress: prediction['description'] ?? '',
            shortAddress: prediction['structured_formatting']['secondary_text'] ?? '',
            latitude: placeDetails['geometry']['location']['lat'],
            longitude: placeDetails['geometry']['location']['lng'],
            country: _extractCountryFromComponents(placeDetails['address_components']),
            types: List<String>.from(prediction['types'] ?? []),
            confidence: 0.9,
            provider: 'google_places',
          ));
        }
      }
      
      return results;
    } else {
      throw Exception('Google Places API error: ${response.statusCode}');
    }
  }

  /// Validate address result belongs to correct country
  bool _validateAddressResult(AddressResult result, String expectedCountry) {
    // Strict country validation
    if (result.country?.toUpperCase() != expectedCountry.toUpperCase()) {
      print('❌ Address country mismatch: expected $expectedCountry, got ${result.country}');
      return false;
    }

    // Validate coordinates are reasonable
    if (result.latitude.abs() > 90 || result.longitude.abs() > 180) {
      print('❌ Invalid coordinates: ${result.latitude}, ${result.longitude}');
      return false;
    }

    // Allow addresses without precise coordinates (like "The Mall")
    // The requirement is just valid lat/lng, not precise street numbers
    return true;
  }
}
```

---

## 🔔 Intelligent Notification System

### Notification Management Service

```dart
class NotificationManagementService {
  static final NotificationManagementService _instance = NotificationManagementService._internal();
  factory NotificationManagementService() => _instance;
  NotificationManagementService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  /// Create notification with intelligent routing
  Future<String> createNotification({
    required String userId,
    required String title,
    required String message,
    required String actionPath,
    String? deepLink,
    NotificationType type = NotificationType.info,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic>? structuredData,
    List<NotificationAction>? actions,
    Duration? expiresIn,
  }) async {
    try {
      print('🔔 Creating notification for user: $userId');

      // Generate notification ID
      final notificationId = _generateNotificationId();

      // Build notification document
      final notificationDoc = {
        'notificationId': notificationId,
        'userId': userId,
        'userRole': await _getUserRole(userId),
        
        // Content
        'title': title,
        'message': message,
        
        // Rich notification data
        'richData': {
          'type': type.toString(),
          'category': _categorizeNotification(type, structuredData),
          'priority': priority.toString(),
          'icon': _getIconForType(type),
          'color': _getColorForType(type),
          'structuredData': structuredData ?? {},
        },
        
        // Interaction tracking
        'isRead': false,
        'readAt': null,
        'clickedAt': null,
        'interactionCount': 0,
        
        // Routing and actions
        'actionPath': actionPath,
        'deepLink': deepLink ?? 'zippup://$actionPath',
        'actions': actions?.map((a) => a.toMap()).toList() ?? [],
        
        // Delivery configuration
        'delivery': {
          'channels': _determineDeliveryChannels(priority, type),
          'deliveredVia': [],
          'deliveryAttempts': 0,
          'maxDeliveryAttempts': _getMaxDeliveryAttempts(priority),
        },
        
        // Expiration and cleanup
        'expiresAt': expiresIn != null 
          ? Timestamp.fromDate(DateTime.now().add(expiresIn))
          : null,
        'autoDeleteAfterRead': _shouldAutoDelete(type),
        
        // Localization
        'localization': await _getLocalizationForUser(userId),
        
        // Timestamps
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Store notification
      await _db.collection('notifications').doc(notificationId).set(notificationDoc);

      // Trigger delivery
      await _deliverNotification(notificationId, notificationDoc);

      // Update unread count cache
      await _updateUnreadCount(userId);

      print('✅ Notification created: $notificationId');
      return notificationId;

    } catch (e) {
      print('❌ Error creating notification: $e');
      rethrow;
    }
  }

  /// Mark notification as read and update counts
  Future<void> markAsRead(String notificationId, String userId) async {
    try {
      await _db.runTransaction((transaction) async {
        final notificationRef = _db.collection('notifications').doc(notificationId);
        final notificationSnap = await transaction.get(notificationRef);

        if (!notificationSnap.exists) {
          throw Exception('Notification not found');
        }

        final notificationData = notificationSnap.data()!;
        
        // Validate user ownership
        if (notificationData['userId'] != userId) {
          throw Exception('Unauthorized access to notification');
        }

        // Check if already read
        if (notificationData['isRead'] == true) {
          return; // Already read, no action needed
        }

        // Mark as read
        transaction.update(notificationRef, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
          'interactionCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Update unread count cache
      await _updateUnreadCount(userId);

      print('✅ Notification marked as read: $notificationId');

    } catch (e) {
      print('❌ Error marking notification as read: $e');
      rethrow;
    }
  }

  /// Get unread notification count for user
  Future<int> getUnreadCount(String userId) async {
    try {
      // Use cached count for performance
      final cachedCount = await _getCachedUnreadCount(userId);
      if (cachedCount != null) {
        return cachedCount;
      }

      // Calculate fresh count
      final unreadSnap = await _db.collection('notifications')
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .where('expiresAt', isGreaterThan: Timestamp.now()) // Exclude expired
          .count()
          .get();

      final count = unreadSnap.count ?? 0;

      // Cache the count
      await _cacheUnreadCount(userId, count);

      return count;

    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Get notifications with pagination and filtering
  Future<List<Map<String, dynamic>>> getNotifications({
    required String userId,
    bool includeRead = true,
    int limit = 20,
    String? lastNotificationId,
    NotificationCategory? category,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db.collection('notifications')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true);

      // Filter by read status
      if (!includeRead) {
        query = query.where('isRead', isEqualTo: false);
      }

      // Filter by category
      if (category != null) {
        query = query.where('richData.category', isEqualTo: category.toString());
      }

      // Pagination
      if (lastNotificationId != null) {
        final lastDoc = await _db.collection('notifications').doc(lastNotificationId).get();
        if (lastDoc.exists) {
          query = query.startAfterDocument(lastDoc);
        }
      }

      final notificationsSnap = await query.limit(limit).get();
      
      return notificationsSnap.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
        'timeAgo': _formatTimeAgo(doc.data()['createdAt'] as Timestamp?),
      }).toList();

    } catch (e) {
      print('❌ Error getting notifications: $e');
      return [];
    }
  }

  /// Update unread count cache
  Future<void> _updateUnreadCount(String userId) async {
    try {
      final count = await _calculateFreshUnreadCount(userId);
      
      // Cache in Redis or Firestore for performance
      await _db.collection('notification_counts').doc(userId).set({
        'unreadCount': count,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Trigger real-time update to UI
      await _sendUnreadCountUpdate(userId, count);

    } catch (e) {
      print('❌ Error updating unread count: $e');
    }
  }

  /// Deliver notification via multiple channels
  Future<void> _deliverNotification(String notificationId, Map<String, dynamic> notificationData) async {
    try {
      final userId = notificationData['userId'];
      final priority = notificationData['richData']['priority'];
      final channels = List<String>.from(notificationData['delivery']['channels']);

      final deliveryResults = <String>[];

      // In-app notification (always delivered)
      deliveryResults.add('in_app');

      // Push notification
      if (channels.contains('push')) {
        final pushSuccess = await _sendPushNotification(userId, notificationData);
        if (pushSuccess) deliveryResults.add('push');
      }

      // Email notification (for important financial notifications)
      if (channels.contains('email') && _shouldSendEmail(notificationData)) {
        final emailSuccess = await _sendEmailNotification(userId, notificationData);
        if (emailSuccess) deliveryResults.add('email');
      }

      // SMS notification (for critical alerts)
      if (channels.contains('sms') && priority == 'critical') {
        final smsSuccess = await _sendSMSNotification(userId, notificationData);
        if (smsSuccess) deliveryResults.add('sms');
      }

      // Update delivery status
      await _db.collection('notifications').doc(notificationId).update({
        'delivery.deliveredVia': deliveryResults,
        'delivery.lastDeliveryAttempt': FieldValue.serverTimestamp(),
        'delivery.deliveryAttempts': FieldValue.increment(1),
      });

    } catch (e) {
      print('❌ Error delivering notification: $e');
    }
  }
}
```

---

## 📱 Localized Digital Services

### Country-Specific Service Configuration

```dart
class LocalizedDigitalServicesService {
  static final LocalizedDigitalServicesService _instance = LocalizedDigitalServicesService._internal();
  factory LocalizedDigitalServicesService() => _instance;
  LocalizedDigitalServicesService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Get airtime providers for user's current country
  Future<List<AirtimeProvider>> getAirtimeProviders({
    String? countryCode,
    double? latitude,
    double? longitude,
  }) async {
    try {
      // Resolve country if not provided
      final resolvedCountry = countryCode ?? await _resolveUserCountry(latitude, longitude);
      
      print('📱 Getting airtime providers for country: $resolvedCountry');

      // Get service configuration for this country
      final serviceDoc = await _db.collection('digital_services_config')
          .doc('${resolvedCountry}_airtime')
          .get();

      if (!serviceDoc.exists) {
        print('❌ No airtime service configured for country: $resolvedCountry');
        return [];
      }

      final serviceData = serviceDoc.data()!;
      final providers = List<Map<String, dynamic>>.from(serviceData['providers'] ?? []);

      // Filter operational providers and build response
      final airtimeProviders = <AirtimeProvider>[];
      
      for (final providerData in providers) {
        if (providerData['isOperational'] == true) {
          airtimeProviders.add(AirtimeProvider(
            id: providerData['id'],
            name: providerData['name'],
            displayName: providerData['displayName'],
            logo: providerData['logo'],
            networkCode: providerData['networkCode'],
            
            // Denominations with localized formatting
            denominations: List<Map<String, dynamic>>.from(providerData['denominations'])
                .map((d) => AirtimeDenomination(
                  value: (d['value'] as num).toDouble(),
                  display: d['display'],
                  isPopular: d['popular'] ?? false,
                ))
                .toList(),
            
            // Fees and pricing
            fees: AirtimeFees(
              processingFee: (providerData['fees']['processingFee'] as num).toDouble(),
              feeType: providerData['fees']['feeType'],
              minimumFee: (providerData['fees']['minimumFee'] as num).toDouble(),
              maximumFee: (providerData['fees']['maximumFee'] as num).toDouble(),
            ),
            
            // Service metrics
            metrics: ProviderMetrics(
              averageProcessingTime: (providerData['averageProcessingTime'] as num).toDouble(),
              successRate: (providerData['successRate'] as num).toDouble(),
              isOperational: providerData['isOperational'],
              lastStatusCheck: (providerData['lastStatusCheck'] as Timestamp).toDate(),
            ),
          ));
        }
      }

      // Sort by popularity and success rate
      airtimeProviders.sort((a, b) => b.metrics.successRate.compareTo(a.metrics.successRate));

      print('✅ Found ${airtimeProviders.length} airtime providers for $resolvedCountry');
      return airtimeProviders;

    } catch (e) {
      print('❌ Error getting airtime providers: $e');
      return [];
    }
  }

  /// Get bill payment services for user's country
  Future<List<BillPaymentService>> getBillPaymentServices({
    String? countryCode,
    String? serviceCategory, // utilities | telecommunications | insurance
  }) async {
    try {
      final resolvedCountry = countryCode ?? await _resolveUserCountry();
      
      print('🧾 Getting bill payment services for: $resolvedCountry');

      Query<Map<String, dynamic>> query = _db.collection('digital_services_config')
          .where('countryCode', isEqualTo: resolvedCountry)
          .where('serviceType', isEqualTo: 'bills')
          .where('isActive', isEqualTo: true);

      if (serviceCategory != null) {
        query = query.where('category', isEqualTo: serviceCategory);
      }

      final servicesSnap = await query.get();
      final billServices = <BillPaymentService>[];

      for (final doc in servicesSnap.docs) {
        final serviceData = doc.data();
        
        billServices.add(BillPaymentService(
          id: doc.id,
          name: serviceData['serviceName'],
          category: serviceData['category'],
          providers: List<Map<String, dynamic>>.from(serviceData['providers'])
              .map((p) => BillProvider.fromMap(p))
              .toList(),
          countryConfig: CountryConfig.fromMap(serviceData['countryConfig']),
        ));
      }

      return billServices;

    } catch (e) {
      print('❌ Error getting bill payment services: $e');
      return [];
    }
  }

  /// Resolve user's country from various sources
  Future<String> _resolveUserCountry([double? lat, double? lng]) async {
    try {
      // Try GPS location first
      if (lat != null && lng != null) {
        final gpsCountry = await _getCountryFromCoordinates(lat, lng);
        if (gpsCountry != null) return gpsCountry;
      }

      // Fall back to IP geolocation
      final ipLocation = await _getIPLocation();
      if (ipLocation.country.isNotEmpty) {
        return ipLocation.country;
      }

      // Ultimate fallback to user profile
      final userCountry = await _getUserCountryFromProfile();
      if (userCountry != null) return userCountry;

      // Default fallback
      return 'US';

    } catch (e) {
      print('❌ Error resolving user country: $e');
      return 'US';
    }
  }
}

/// Data models for digital services
class AirtimeProvider {
  final String id;
  final String name;
  final String displayName;
  final String logo;
  final String networkCode;
  final List<AirtimeDenomination> denominations;
  final AirtimeFees fees;
  final ProviderMetrics metrics;

  const AirtimeProvider({
    required this.id,
    required this.name,
    required this.displayName,
    required this.logo,
    required this.networkCode,
    required this.denominations,
    required this.fees,
    required this.metrics,
  });
}

class AirtimeDenomination {
  final double value;
  final String display;
  final bool isPopular;

  const AirtimeDenomination({
    required this.value,
    required this.display,
    required this.isPopular,
  });
}

enum NotificationType {
  info,
  success,
  warning,
  error,
  financial,
  order,
  system,
  promotional,
}

enum NotificationPriority {
  low,
  normal,
  high,
  critical,
}

enum NotificationCategory {
  financial,
  order,
  system,
  promotional,
  security,
}
```

---

## 🔒 Security & Fraud Prevention

### Financial Security Service

```dart
class FinancialSecurityService {
  
  /// Validate wallet transaction with fraud detection
  static Future<SecurityValidationResult> validateWalletTransaction({
    required String userId,
    required double amount,
    required String currency,
    required String transactionType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      print('🔒 Validating wallet transaction for user: $userId');

      final validationChecks = <String, bool>{};
      final securityFlags = <String>[];
      final riskFactors = <String>[];

      // 1. Amount validation
      validationChecks['amount_valid'] = await _validateTransactionAmount(
        userId, amount, currency, transactionType);
      
      // 2. Daily limit check
      validationChecks['daily_limit_ok'] = await _checkDailyTransactionLimit(
        userId, amount, currency);
      
      // 3. Velocity checks (rapid transactions)
      validationChecks['velocity_ok'] = await _checkTransactionVelocity(userId);
      
      // 4. Device consistency
      validationChecks['device_consistent'] = await _validateDeviceConsistency(userId);
      
      // 5. Location consistency
      validationChecks['location_consistent'] = await _validateLocationConsistency(userId);
      
      // 6. Account status validation
      validationChecks['account_status_ok'] = await _validateAccountStatus(userId);
      
      // 7. AML/KYC compliance
      validationChecks['aml_compliant'] = await _checkAMLCompliance(userId, amount);
      
      // 8. Sanctions screening
      validationChecks['sanctions_clear'] = await _checkSanctionsList(userId);

      // Calculate risk score
      final riskScore = _calculateTransactionRiskScore(validationChecks, riskFactors);
      
      // Determine action based on risk
      SecurityAction action = SecurityAction.allow;
      if (riskScore > 0.8) {
        action = SecurityAction.block;
      } else if (riskScore > 0.6) {
        action = SecurityAction.requireAdditionalVerification;
      } else if (riskScore > 0.4) {
        action = SecurityAction.flagForReview;
      }

      return SecurityValidationResult(
        isValid: action == SecurityAction.allow,
        riskScore: riskScore,
        action: action,
        validationChecks: validationChecks,
        securityFlags: securityFlags,
        riskFactors: riskFactors,
        recommendedAction: _getRecommendedSecurityAction(action, riskScore),
      );

    } catch (e) {
      print('❌ Security validation error: $e');
      return SecurityValidationResult(
        isValid: false,
        riskScore: 1.0,
        action: SecurityAction.block,
        validationChecks: {},
        securityFlags: ['validation_error'],
        riskFactors: ['system_error'],
        recommendedAction: 'Block transaction due to validation error',
      );
    }
  }

  /// Encrypt sensitive financial data
  static Future<String> encryptFinancialData(String data, String userId) async {
    try {
      // Use AES encryption with user-specific key derivation
      final key = await _deriveUserEncryptionKey(userId);
      final encrypted = await _encryptWithAES(data, key);
      
      return encrypted;
    } catch (e) {
      print('❌ Encryption error: $e');
      rethrow;
    }
  }

  /// Decrypt sensitive financial data
  static Future<String> decryptFinancialData(String encryptedData, String userId) async {
    try {
      final key = await _deriveUserEncryptionKey(userId);
      final decrypted = await _decryptWithAES(encryptedData, key);
      
      return decrypted;
    } catch (e) {
      print('❌ Decryption error: $e');
      rethrow;
    }
  }

  /// Validate location authenticity
  static Future<bool> validateLocationAuthenticity({
    required double latitude,
    required double longitude,
    required String userId,
  }) async {
    try {
      // 1. Check against user's location history
      final locationHistory = await _getUserLocationHistory(userId);
      final isLocationPlausible = _validateLocationPlausibility(
        latitude, longitude, locationHistory);

      // 2. Cross-validate with IP geolocation
      final ipLocation = await _getIPLocation();
      final ipGpsConsistency = _validateIPGPSConsistency(
        ipLocation, latitude, longitude);

      // 3. Check for mock location indicators
      final isMockLocation = await _detectMockLocation(latitude, longitude);

      return isLocationPlausible && ipGpsConsistency && !isMockLocation;

    } catch (e) {
      print('❌ Location validation error: $e');
      return false;
    }
  }
}

enum SecurityAction {
  allow,
  flagForReview,
  requireAdditionalVerification,
  block,
}

class SecurityValidationResult {
  final bool isValid;
  final double riskScore;
  final SecurityAction action;
  final Map<String, bool> validationChecks;
  final List<String> securityFlags;
  final List<String> riskFactors;
  final String recommendedAction;

  const SecurityValidationResult({
    required this.isValid,
    required this.riskScore,
    required this.action,
    required this.validationChecks,
    required this.securityFlags,
    required this.riskFactors,
    required this.recommendedAction,
  });
}
```

This comprehensive system provides:

- ✅ **Automated financial settlement** with multi-currency support
- ✅ **Intelligent commission handling** for cash vs digital payments
- ✅ **Robust debt management** with grace periods and enforcement
- ✅ **Geolocation-based services** with anti-spoofing measures
- ✅ **Smart notification system** with unread counts and deep linking
- ✅ **Localized digital services** tailored to user's country
- ✅ **Enterprise security** with fraud detection and compliance
- ✅ **Complete audit trail** for regulatory compliance

Ready for the implementation phase! 🚀