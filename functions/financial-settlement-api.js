const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

/**
 * 💰 FINANCIAL SETTLEMENT & GEOLOCATION API
 * Complete implementation for automated settlements, wallets, and location services
 */

// ===== FINANCIAL SETTLEMENT FUNCTIONS =====

/**
 * Automated settlement trigger when order is completed
 */
exports.settleOrderTransaction = functions.firestore
  .document('{collection}/{orderId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const { orderId } = context.params;

    // Trigger settlement when order moves to completed status
    if (before.status !== 'completed' && after.status === 'completed') {
      console.log(`🎯 Order completed, triggering settlement: ${orderId}`);
      
      try {
        await settleTransaction(orderId, after);
        console.log(`✅ Settlement completed for order: ${orderId}`);
      } catch (error) {
        console.error(`❌ Settlement failed for order ${orderId}:`, error);
        await handleSettlementError(orderId, error);
      }
    }

    return null;
  });

/**
 * Core settlement function
 */
async function settleTransaction(orderId, orderData) {
  console.log(`💰 Processing settlement for order: ${orderId}`);
  
  try {
    // Step 1: Calculate financial breakdown
    const breakdown = await calculateFinancialBreakdown(orderData);
    console.log(`💵 Financial breakdown:`, breakdown);

    // Step 2: Process settlement based on payment method
    if (orderData.paymentMethod === 'cash') {
      await processCashSettlement(orderId, orderData, breakdown);
    } else {
      await processDigitalSettlement(orderId, orderData, breakdown);
    }

    // Step 3: Update order with settlement info
    await updateOrderWithSettlement(orderId, breakdown);

    // Step 4: Send settlement notifications
    await sendSettlementNotifications(orderData, breakdown);

    return { success: true, breakdown: breakdown };

  } catch (error) {
    console.error(`❌ Settlement error:`, error);
    throw error;
  }
}

/**
 * Calculate comprehensive financial breakdown
 */
async function calculateFinancialBreakdown(orderData) {
  const orderTotal = orderData.total || 0;
  const currency = orderData.currency || await getCurrencyForCountry(orderData.country || 'NG');
  const serviceType = orderData.serviceType || orderData.service || 'transport';
  
  try {
    // Get dynamic commission rate
    const commissionRate = await getCommissionRate(serviceType, orderData.providerId, orderData.vendorId);
    
    // Calculate platform commission
    const platformCommission = Math.round(orderTotal * commissionRate * 100) / 100;
    
    // Calculate processing fees
    const processingFee = await calculateProcessingFee(orderTotal, orderData.paymentMethod, currency);
    
    // Calculate taxes
    const taxInfo = await calculateTaxes(orderTotal, orderData.country || 'NG');
    
    // Calculate net provider earnings
    const totalDeductions = platformCommission + processingFee + taxInfo.totalTax;
    const providerEarnings = Math.round((orderTotal - totalDeductions) * 100) / 100;
    
    return {
      // Order information
      orderId: orderData.id || orderId,
      orderTotal: orderTotal,
      currency: currency,
      paymentMethod: orderData.paymentMethod,
      serviceType: serviceType,
      
      // Platform revenue
      platformCommission: platformCommission,
      commissionRate: commissionRate,
      processingFee: processingFee,
      
      // Tax breakdown
      taxes: taxInfo,
      totalTax: taxInfo.totalTax,
      
      // Provider earnings
      providerEarnings: providerEarnings,
      totalDeductions: totalDeductions,
      netMargin: (providerEarnings / orderTotal) * 100,
      
      // Detailed breakdown for transparency
      breakdown: {
        orderValue: `${currency} ${orderTotal.toFixed(2)}`,
        platformCommission: `-${currency} ${platformCommission.toFixed(2)} (${(commissionRate * 100).toFixed(1)}%)`,
        processingFee: `-${currency} ${processingFee.toFixed(2)}`,
        taxes: `-${currency} ${taxInfo.totalTax.toFixed(2)}`,
        netToProvider: `${currency} ${providerEarnings.toFixed(2)}`
      }
    };

  } catch (error) {
    console.error('❌ Error calculating financial breakdown:', error);
    throw error;
  }
}

/**
 * Process cash payment settlement
 */
async function processCashSettlement(orderId, orderData, breakdown) {
  const providerId = orderData.providerId || orderData.vendorId;
  const customerId = orderData.customerId;
  
  console.log(`💵 Processing cash settlement - Provider: ${providerId}`);
  
  try {
    // Step 1: Credit full order amount to provider (they collected cash)
    await creditProviderWallet({
      userId: providerId,
      amount: breakdown.orderTotal,
      currency: breakdown.currency,
      type: 'cash_collection_credit',
      orderId: orderId,
      description: `Cash collected from customer for order #${orderId.substring(0, 8)}`,
      breakdown: breakdown
    });

    // Step 2: Deduct platform commission from provider wallet
    const deductionResult = await deductCommissionFromWallet({
      userId: providerId,
      amount: breakdown.platformCommission,
      currency: breakdown.currency,
      orderId: orderId,
      breakdown: breakdown
    });

    // Step 3: Handle insufficient funds scenario
    if (!deductionResult.success) {
      await handleInsufficientFunds(providerId, orderId, breakdown, deductionResult);
    }

    console.log(`✅ Cash settlement completed for order: ${orderId}`);

  } catch (error) {
    console.error(`❌ Cash settlement error:`, error);
    throw error;
  }
}

/**
 * Process digital payment settlement
 */
async function processDigitalSettlement(orderId, orderData, breakdown) {
  const providerId = orderData.providerId || orderData.vendorId;
  
  console.log(`💳 Processing digital settlement - Provider: ${providerId}`);
  
  try {
    // For digital payments, credit net earnings directly (commission already deducted)
    await creditProviderWallet({
      userId: providerId,
      amount: breakdown.providerEarnings,
      currency: breakdown.currency,
      type: 'earnings_credit',
      orderId: orderId,
      description: `Earnings for order #${orderId.substring(0, 8)} (${(breakdown.commissionRate * 100).toFixed(1)}% commission deducted)`,
      breakdown: breakdown
    });

    // Record platform revenue
    await recordPlatformRevenue({
      orderId: orderId,
      amount: breakdown.platformCommission,
      currency: breakdown.currency,
      revenueType: 'commission',
      breakdown: breakdown
    });

    console.log(`✅ Digital settlement completed for order: ${orderId}`);

  } catch (error) {
    console.error(`❌ Digital settlement error:`, error);
    throw error;
  }
}

/**
 * Credit provider wallet with atomic transaction
 */
async function creditProviderWallet(params) {
  const { userId, amount, currency, type, orderId, description, breakdown } = params;
  
  try {
    await admin.firestore().runTransaction(async (transaction) => {
      const walletRef = admin.firestore().collection('wallets').doc(userId);
      const walletSnap = await transaction.get(walletRef);
      
      // Get current balance
      const walletData = walletSnap.exists ? walletSnap.data() : {};
      const currentBalance = walletData.balances?.[currency]?.available || 0;
      const newBalance = currentBalance + amount;
      
      // Prepare wallet update
      const walletUpdate = {
        [`balances.${currency}.available`]: newBalance,
        [`balances.${currency}.total`]: newBalance + (walletData.balances?.[currency]?.pending || 0),
        [`balances.${currency}.lastUpdated`]: admin.firestore.FieldValue.serverTimestamp(),
        'primaryCurrency': currency,
        'lastTransactionAt': admin.firestore.FieldValue.serverTimestamp(),
        'updatedAt': admin.firestore.FieldValue.serverTimestamp()
      };

      if (!walletSnap.exists) {
        walletUpdate.userId = userId;
        walletUpdate.createdAt = admin.firestore.FieldValue.serverTimestamp();
      }

      transaction.set(walletRef, walletUpdate, { merge: true });

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
          balanceAfterTransaction: newBalance,
          affectedCurrency: currency
        },
        
        commissionDetails: breakdown,
        
        paymentMethod: {
          type: 'cash',
          collectedBy: userId,
          collectedAt: admin.firestore.FieldValue.serverTimestamp()
        },
        
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
            serviceType: breakdown.serviceType,
            providerId: userId,
            orderId: orderId
          }
        },
        
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    console.log(`✅ Credited ${currency} ${amount} to provider ${userId}`);

  } catch (error) {
    console.error(`❌ Error crediting wallet:`, error);
    throw error;
  }
}

/**
 * Deduct commission from provider wallet
 */
async function deductCommissionFromWallet(params) {
  const { userId, amount, currency, orderId, breakdown } = params;
  
  try {
    // Check wallet balance first
    const walletDoc = await admin.firestore().collection('wallets').doc(userId).get();
    const walletData = walletDoc.exists ? walletDoc.data() : {};
    const currentBalance = walletData.balances?.[currency]?.available || 0;

    if (currentBalance >= amount) {
      // Sufficient funds - proceed with normal deduction
      await admin.firestore().runTransaction(async (transaction) => {
        const newBalance = currentBalance - amount;
        
        transaction.update(walletDoc.ref, {
          [`balances.${currency}.available`]: newBalance,
          [`balances.${currency}.total`]: newBalance + (walletData.balances?.[currency]?.pending || 0),
          [`balances.${currency}.lastUpdated`]: admin.firestore.FieldValue.serverTimestamp(),
          'lastTransactionAt': admin.firestore.FieldValue.serverTimestamp(),
          'updatedAt': admin.firestore.FieldValue.serverTimestamp()
        });

        // Create deduction transaction record
        const transactionRef = admin.firestore().collection('transactions').doc();
        transaction.set(transactionRef, {
          transactionId: transactionRef.id,
          orderId: orderId,
          userId: userId,
          type: 'commission_deduction',
          category: 'order_settlement',
          amount: -amount, // Negative for debit
          currency: currency,
          
          balanceTracking: {
            previousBalance: currentBalance,
            newBalance: newBalance,
            balanceAfterTransaction: newBalance,
            affectedCurrency: currency
          },
          
          commissionDetails: breakdown,
          
          status: 'completed',
          processingStatus: {
            initiated: admin.firestore.FieldValue.serverTimestamp(),
            completed: admin.firestore.FieldValue.serverTimestamp()
          },
          
          metadata: {
            description: `Platform commission for order #${orderId.substring(0, 8)}`,
            settlementType: 'cash_commission_deduction'
          },
          
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
      });

      return { success: true, newBalance: currentBalance - amount };

    } else {
      // Insufficient funds
      return {
        success: false,
        reason: 'insufficient_funds',
        currentBalance: currentBalance,
        requiredAmount: amount,
        shortfall: amount - currentBalance
      };
    }

  } catch (error) {
    console.error(`❌ Commission deduction error:`, error);
    return {
      success: false,
      reason: 'processing_error',
      error: error.message
    };
  }
}

/**
 * Handle insufficient funds for cash commission
 */
async function handleInsufficientFunds(providerId, orderId, breakdown, deductionResult) {
  console.log(`⚠️ Insufficient funds for provider: ${providerId}`);
  
  try {
    const currency = breakdown.currency;
    const commissionOwed = breakdown.platformCommission;
    
    // Step 1: Force deduction (create negative balance)
    await forceCommissionDeduction({
      userId: providerId,
      amount: commissionOwed,
      currency: currency,
      orderId: orderId,
      currentBalance: deductionResult.currentBalance,
      shortfall: deductionResult.shortfall
    });

    // Step 2: Update provider account status
    await updateProviderAccountStatus({
      userId: providerId,
      newStatus: 'payment_overdue',
      debtAmount: deductionResult.shortfall,
      currency: currency,
      orderId: orderId
    });

    // Step 3: Schedule grace period enforcement
    const gracePeriodHours = await getGracePeriodForProvider(providerId);
    await schedulePaymentEnforcement(providerId, gracePeriodHours);

    // Step 4: Send overdue notifications
    await sendOverduePaymentNotifications(providerId, {
      debtAmount: deductionResult.shortfall,
      currency: currency,
      orderId: orderId,
      gracePeriodHours: gracePeriodHours
    });

    console.log(`⚠️ Provider ${providerId} marked as payment_overdue`);

  } catch (error) {
    console.error(`❌ Error handling insufficient funds:`, error);
    throw error;
  }
}

/**
 * Force commission deduction creating negative balance
 */
async function forceCommissionDeduction(params) {
  const { userId, amount, currency, orderId, currentBalance, shortfall } = params;
  
  try {
    await admin.firestore().runTransaction(async (transaction) => {
      const walletRef = admin.firestore().collection('wallets').doc(userId);
      const newBalance = currentBalance - amount; // Will be negative
      
      // Update wallet with negative balance
      transaction.update(walletRef, {
        [`balances.${currency}.available`]: newBalance,
        [`balances.${currency}.total`]: newBalance,
        [`balances.${currency}.lastUpdated`]: admin.firestore.FieldValue.serverTimestamp(),
        
        // Debt tracking
        [`accountStatus.totalDebt.${currency}`]: Math.abs(newBalance),
        'accountStatus.status': 'payment_overdue',
        'accountStatus.overdueSince': admin.firestore.FieldValue.serverTimestamp(),
        'accountStatus.canReceiveNewOrders': false,
        'accountStatus.canWithdrawFunds': false,
        [`accountStatus.minimumTopUpRequired.${currency}`]: Math.abs(newBalance) * 1.1, // 10% buffer
        
        'updatedAt': admin.firestore.FieldValue.serverTimestamp()
      });

      // Create forced deduction transaction
      const transactionRef = admin.firestore().collection('transactions').doc();
      transaction.set(transactionRef, {
        transactionId: transactionRef.id,
        orderId: orderId,
        userId: userId,
        type: 'forced_commission_deduction',
        category: 'debt_collection',
        amount: -amount,
        currency: currency,
        
        balanceTracking: {
          previousBalance: currentBalance,
          newBalance: newBalance,
          wentNegative: true,
          debtCreated: Math.abs(newBalance),
          shortfall: shortfall
        },
        
        status: 'completed',
        
        metadata: {
          reason: 'insufficient_funds_cash_commission',
          forcedDeduction: true,
          settlementType: 'debt_recovery'
        },
        
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    console.log(`⚠️ Forced deduction: ${currency} ${amount} from ${userId} (debt created)`);

  } catch (error) {
    console.error(`❌ Forced deduction error:`, error);
    throw error;
  }
}

// ===== GEOLOCATION & CURRENCY APIs =====

/**
 * Resolve user location and currency
 */
exports.resolveUserLocation = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { latitude, longitude, useGPS = true } = data;

  try {
    // Get client IP for geolocation
    const clientIP = context.rawRequest.ip || 
                     context.rawRequest.headers['x-forwarded-for'] || 
                     context.rawRequest.connection.remoteAddress;

    console.log(`🌍 Resolving location for user: ${context.auth.uid} from IP: ${clientIP}`);

    // Step 1: IP-based geolocation
    const ipLocation = await getIPGeolocation(clientIP);
    
    // Step 2: GPS validation (if provided)
    let gpsLocation = null;
    if (useGPS && latitude && longitude) {
      gpsLocation = await validateGPSLocation(latitude, longitude);
    }

    // Step 3: Resolve final location with anti-spoofing
    const resolvedLocation = await resolveLocationWithValidation(ipLocation, gpsLocation);

    // Step 4: Get currency and configuration for this location
    const currencyInfo = await getCurrencyForCountry(resolvedLocation.country);
    const digitalServices = await getDigitalServicesForCountry(resolvedLocation.country);
    const addressConfig = getAddressSearchConfig(resolvedLocation.country);

    // Step 5: Cache location session
    await cacheLocationSession(context.auth.uid, resolvedLocation);

    return {
      success: true,
      location: {
        country: resolvedLocation.country,
        countryName: resolvedLocation.countryName,
        city: resolvedLocation.city,
        region: resolvedLocation.region,
        coordinates: {
          latitude: resolvedLocation.latitude,
          longitude: resolvedLocation.longitude
        },
        confidence: resolvedLocation.confidence,
        timezone: resolvedLocation.timezone
      },
      currency: {
        code: currencyInfo.code,
        symbol: currencyInfo.symbol,
        name: currencyInfo.name,
        decimalPlaces: currencyInfo.decimalPlaces
      },
      services: {
        digitalServices: digitalServices,
        addressSearch: addressConfig
      },
      resolvedAt: new Date().toISOString()
    };

  } catch (error) {
    console.error('❌ Location resolution error:', error);
    throw new functions.https.HttpsError('internal', `Location resolution failed: ${error.message}`);
  }
});

/**
 * Get IP-based geolocation
 */
async function getIPGeolocation(clientIP) {
  try {
    // Use MaxMind GeoIP2 or similar service
    const response = await axios.get(`https://ipapi.co/${clientIP}/json/`);
    
    if (response.status === 200) {
      const data = response.data;
      
      return {
        country: data.country_code || 'US',
        countryName: data.country_name || 'United States',
        city: data.city || 'Unknown',
        region: data.region || 'Unknown',
        latitude: parseFloat(data.latitude) || 0,
        longitude: parseFloat(data.longitude) || 0,
        timezone: data.timezone || 'UTC',
        isp: data.org || 'Unknown',
        confidence: 0.85,
        source: 'ip_geolocation'
      };
    }

    throw new Error(`IP geolocation API error: ${response.status}`);

  } catch (error) {
    console.error('❌ IP geolocation error:', error);
    
    // Return safe fallback
    return {
      country: 'US',
      countryName: 'United States', 
      city: 'Unknown',
      region: 'Unknown',
      latitude: 0,
      longitude: 0,
      timezone: 'UTC',
      confidence: 0.1,
      source: 'fallback'
    };
  }
}

/**
 * Address autocomplete with country bias
 */
exports.getAddressAutocomplete = functions.https.onCall(async (data, context) => {
  const { input, latitude, longitude, countryCode } = data;

  if (!input || input.trim().length < 2) {
    return { success: true, results: [] };
  }

  try {
    console.log(`🔍 Address search: "${input}" in ${countryCode || 'auto-detect'}`);

    // Resolve country if not provided
    const resolvedCountry = countryCode || await resolveCountryFromCoordinates(latitude, longitude);
    
    // Configure Google Places API with strict country filtering
    const apiKey = functions.config().google.places_api_key;
    const url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json' +
      `?input=${encodeURIComponent(input)}` +
      `&location=${latitude},${longitude}` +
      `&radius=50000` + // 50km radius
      `&components=country:${resolvedCountry.toLowerCase()}` +
      `&language=en` +
      `&key=${apiKey}`;

    const response = await axios.get(url);
    
    if (response.status === 200) {
      const predictions = response.data.predictions || [];
      
      // Get detailed place information
      const results = await Promise.all(
        predictions.slice(0, 10).map(async (prediction) => {
          const placeDetails = await getPlaceDetails(prediction.place_id, apiKey);
          
          return {
            placeId: prediction.place_id,
            name: prediction.structured_formatting?.main_text || '',
            fullAddress: prediction.description || '',
            shortAddress: prediction.structured_formatting?.secondary_text || '',
            coordinates: placeDetails ? {
              latitude: placeDetails.geometry.location.lat,
              longitude: placeDetails.geometry.location.lng
            } : null,
            types: prediction.types || [],
            country: resolvedCountry,
            confidence: 0.9
          };
        })
      );

      // Filter out results without coordinates (if required)
      const validResults = results.filter(result => 
        result.coordinates && 
        Math.abs(result.coordinates.latitude) <= 90 &&
        Math.abs(result.coordinates.longitude) <= 180
      );

      return {
        success: true,
        results: validResults,
        country: resolvedCountry,
        resultCount: validResults.length
      };

    } else {
      throw new Error(`Google Places API error: ${response.status}`);
    }

  } catch (error) {
    console.error('❌ Address autocomplete error:', error);
    throw new functions.https.HttpsError('internal', `Address search failed: ${error.message}`);
  }
});

/**
 * Get country-specific digital services
 */
exports.getDigitalServices = functions.https.onCall(async (data, context) => {
  const { serviceType, countryCode } = data; // serviceType: airtime | data | bills

  try {
    // Resolve country from user's location if not provided
    const resolvedCountry = countryCode || await resolveUserCountryFromRequest(context);
    
    console.log(`📱 Getting ${serviceType || 'all'} services for: ${resolvedCountry}`);

    // Query digital services configuration
    let query = admin.firestore()
      .collection('digital_services_config')
      .where('countryCode', '==', resolvedCountry)
      .where('isActive', '==', true);

    if (serviceType) {
      query = query.where('serviceType', '==', serviceType);
    }

    const servicesSnap = await query.get();
    
    if (servicesSnap.empty) {
      return {
        success: true,
        country: resolvedCountry,
        services: [],
        message: `No ${serviceType || 'digital'} services available for ${resolvedCountry}`
      };
    }

    const services = servicesSnap.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        serviceType: data.serviceType,
        serviceName: data.serviceName,
        providers: data.providers || [],
        countryConfig: data.countryConfig || {},
        isActive: data.isActive
      };
    });

    return {
      success: true,
      country: resolvedCountry,
      services: services,
      currency: await getCurrencyForCountry(resolvedCountry),
      totalProviders: services.reduce((sum, service) => sum + (service.providers?.length || 0), 0)
    };

  } catch (error) {
    console.error('❌ Error getting digital services:', error);
    throw new functions.https.HttpsError('internal', `Failed to get digital services: ${error.message}`);
  }
});

// ===== NOTIFICATION MANAGEMENT APIs =====

/**
 * Mark notification as read
 */
exports.markNotificationAsRead = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { notificationId } = data;
  const userId = context.auth.uid;

  if (!notificationId) {
    throw new functions.https.HttpsError('invalid-argument', 'Notification ID required');
  }

  try {
    await admin.firestore().runTransaction(async (transaction) => {
      const notificationRef = admin.firestore().collection('notifications').doc(notificationId);
      const notificationSnap = await transaction.get(notificationRef);

      if (!notificationSnap.exists) {
        throw new Error('Notification not found');
      }

      const notificationData = notificationSnap.data();
      
      // Validate ownership
      if (notificationData.userId !== userId) {
        throw new Error('Unauthorized access');
      }

      // Check if already read
      if (notificationData.isRead === true) {
        return; // Already read
      }

      // Mark as read
      transaction.update(notificationRef, {
        isRead: true,
        readAt: admin.firestore.FieldValue.serverTimestamp(),
        interactionCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    // Update unread count cache
    await updateUnreadCountCache(userId);

    return { success: true, notificationId: notificationId };

  } catch (error) {
    console.error('❌ Error marking notification as read:', error);
    throw new functions.https.HttpsError('internal', `Failed to mark notification as read: ${error.message}`);
  }
});

/**
 * Get unread notification count
 */
exports.getUnreadNotificationCount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const userId = context.auth.uid;

  try {
    // Check cache first
    const cachedCount = await getCachedUnreadCount(userId);
    if (cachedCount !== null) {
      return { success: true, count: cachedCount, source: 'cache' };
    }

    // Calculate fresh count
    const unreadSnap = await admin.firestore()
      .collection('notifications')
      .where('userId', '==', userId)
      .where('isRead', '==', false)
      .count()
      .get();

    const count = unreadSnap.count || 0;

    // Cache the count
    await cacheUnreadCount(userId, count);

    return { success: true, count: count, source: 'fresh' };

  } catch (error) {
    console.error('❌ Error getting unread count:', error);
    throw new functions.https.HttpsError('internal', `Failed to get unread count: ${error.message}`);
  }
});

// ===== UTILITY FUNCTIONS =====

/**
 * Calculate commission rate based on service and provider
 */
async function getCommissionRate(serviceType, providerId, vendorId) {
  try {
    // Default commission rates by service
    const defaultRates = {
      transport: 0.15,    // 15%
      food: 0.20,         // 20% 
      grocery: 0.15,      // 15%
      emergency: 0.10,    // 10%
      hire: 0.15,         // 15%
      moving: 0.15,       // 15%
      marketplace: 0.05,  // 5%
      default: 0.15       // 15%
    };

    let commissionRate = defaultRates[serviceType] || defaultRates.default;

    // Check for custom vendor commission rates
    if (vendorId) {
      const vendorDoc = await admin.firestore().collection('vendors').doc(vendorId).get();
      if (vendorDoc.exists) {
        const vendorData = vendorDoc.data();
        const customRate = vendorData.financialInfo?.platformCommissionRate;
        if (customRate && typeof customRate === 'number') {
          commissionRate = customRate;
        }
      }
    }

    // Check for provider-specific rates (premium providers might have lower rates)
    if (providerId) {
      const providerDoc = await admin.firestore().collection('provider_profiles')
        .where('userId', '==', providerId)
        .limit(1)
        .get();

      if (!providerDoc.empty) {
        const providerData = providerDoc.docs[0].data();
        const customRate = providerData.financialConfig?.commissionRate;
        if (customRate && typeof customRate === 'number') {
          commissionRate = customRate;
        }
      }
    }

    return Math.min(Math.max(commissionRate, 0.05), 0.30); // Cap between 5% and 30%

  } catch (error) {
    console.error('❌ Error getting commission rate:', error);
    return 0.15; // Safe default
  }
}

/**
 * Calculate processing fees based on payment method
 */
async function calculateProcessingFee(amount, paymentMethod, currency) {
  try {
    const feeStructures = {
      card: { rate: 0.029, fixed: 0 }, // 2.9% for card payments
      cash: { rate: 0, fixed: 0 },     // No processing fee for cash
      wallet: { rate: 0, fixed: 10 },  // Fixed ₦10 for wallet payments
      bank_transfer: { rate: 0.01, fixed: 25 }, // 1% + ₦25 for bank transfers
    };

    const structure = feeStructures[paymentMethod] || feeStructures.card;
    const percentageFee = amount * structure.rate;
    const totalFee = percentageFee + structure.fixed;

    return Math.round(totalFee * 100) / 100; // Round to 2 decimal places

  } catch (error) {
    console.error('❌ Error calculating processing fee:', error);
    return 0;
  }
}

/**
 * Calculate taxes based on country regulations
 */
async function calculateTaxes(amount, countryCode) {
  try {
    // Country-specific tax rates
    const taxRates = {
      NG: { vat: 0.075, withholding: 0.05 },  // Nigeria: 7.5% VAT
      ZA: { vat: 0.15, withholding: 0 },      // South Africa: 15% VAT
      GH: { vat: 0.125, nhil: 0.025 },        // Ghana: 12.5% VAT + 2.5% NHIL
      KE: { vat: 0.16, withholding: 0.05 },   // Kenya: 16% VAT
      US: { sales_tax: 0.08, federal: 0 },    // US: ~8% sales tax (varies by state)
      default: { vat: 0.10, withholding: 0 }  // 10% default
    };

    const rates = taxRates[countryCode] || taxRates.default;
    
    let totalTax = 0;
    const taxBreakdown = {};

    // Calculate each applicable tax
    Object.entries(rates).forEach(([taxType, rate]) => {
      const taxAmount = Math.round(amount * rate * 100) / 100;
      taxBreakdown[taxType] = taxAmount;
      totalTax += taxAmount;
    });

    return {
      countryCode: countryCode,
      totalTax: totalTax,
      breakdown: taxBreakdown,
      applicableRates: rates
    };

  } catch (error) {
    console.error('❌ Tax calculation error:', error);
    return {
      countryCode: countryCode,
      totalTax: 0,
      breakdown: {},
      error: error.message
    };
  }
}

/**
 * Get currency information for country
 */
async function getCurrencyForCountry(countryCode) {
  const currencyMap = {
    NG: { code: 'NGN', symbol: '₦', name: 'Nigerian Naira', decimalPlaces: 2 },
    ZA: { code: 'ZAR', symbol: 'R', name: 'South African Rand', decimalPlaces: 2 },
    GH: { code: 'GHS', symbol: '₵', name: 'Ghanaian Cedi', decimalPlaces: 2 },
    KE: { code: 'KES', symbol: 'KSh', name: 'Kenyan Shilling', decimalPlaces: 2 },
    US: { code: 'USD', symbol: '$', name: 'US Dollar', decimalPlaces: 2 },
    GB: { code: 'GBP', symbol: '£', name: 'British Pound', decimalPlaces: 2 },
    default: { code: 'USD', symbol: '$', name: 'US Dollar', decimalPlaces: 2 }
  };

  return currencyMap[countryCode] || currencyMap.default;
}

module.exports = {
  settleTransaction,
  calculateFinancialBreakdown,
  getCommissionRate,
  getCurrencyForCountry
};