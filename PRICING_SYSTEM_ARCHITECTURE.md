# 💰 Flexible Pricing Configuration System - Complete Architecture

## 🏗️ System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRICING SYSTEM ARCHITECTURE                  │
├─────────────────────────────────────────────────────────────────┤
│  👑 ADMIN CONTROL LAYER                                         │
│  ├─ Global pricing templates (transport, emergency, etc.)       │
│  ├─ Vendor pricing rights management                            │
│  ├─ Price monitoring and outlier detection                     │
│  └─ Override capabilities for policy violations                │
│                                                                 │
│  🏪 VENDOR AUTONOMY LAYER                                       │
│  ├─ Independent pricing for food, grocery, marketplace         │
│  ├─ Real-time price updates and inventory management           │
│  ├─ Competitive pricing analytics                              │
│  └─ Revenue optimization tools                                 │
│                                                                 │
│  🧮 PRICING CALCULATION ENGINE                                  │
│  ├─ Dynamic pricing resolution (admin vs vendor)               │
│  ├─ Multi-factor pricing (distance, time, surge, etc.)        │
│  ├─ Real-time price validation and error handling              │
│  └─ Currency conversion and localization                       │
│                                                                 │
│  📊 AUDIT & MONITORING LAYER                                    │
│  ├─ Complete price change tracking                             │
│  ├─ Vendor pricing analytics and alerts                       │
│  ├─ Policy violation detection                                 │
│  └─ Revenue impact analysis                                    │
└─────────────────────────────────────────────────────────────────┘
```

### Pricing Authority Matrix

| Service Category | Pricing Authority | Admin Oversight | Vendor Rights |
|------------------|-------------------|-----------------|---------------|
| **Transport** | Admin Controlled | Full Control | None |
| **Emergency** | Admin Controlled | Full Control | None |
| **Moving** | Admin Controlled | Full Control | None |
| **Food** | Vendor Autonomous | Audit & Override | Full Pricing |
| **Grocery** | Vendor Autonomous | Audit & Override | Full Pricing |
| **Marketplace** | Vendor Autonomous | Audit & Override | Full Pricing |
| **Rentals** | Vendor Autonomous | Audit & Override | Full Pricing |
| **Hire Services** | Mixed Model | Template + Override | Limited Pricing |

---

## 🗄️ Comprehensive Database Schema

### 1. `services` Collection (Service Category Configuration)
```javascript
{
  // Document ID: service identifier
  _id: "transport",
  name: "Transport Services",
  displayName: "🚗 Transport",
  
  // Pricing authority configuration
  hasPricingAutonomy: false, // true = vendors set prices, false = admin controlled
  allowsVendorOverrides: false, // Can vendors request price changes?
  requiresAdminApproval: true, // Do price changes need admin approval?
  
  // Service characteristics
  category: "mobility", // mobility | marketplace | professional | emergency
  isDistanceBased: true, // Uses distance/time calculations
  isItemBased: false, // Uses individual item pricing
  isTimeBased: true, // Includes time-based pricing
  
  // Pricing model configuration
  pricingModel: {
    type: "dynamic", // dynamic | fixed | tiered | auction
    factors: ["distance", "time", "demand", "surge"], // Pricing factors
    surgeEnabled: true,
    minimumPrice: 500, // NGN
    maximumPrice: 50000, // NGN
    currency: "NGN"
  },
  
  // Admin control settings
  adminControls: {
    canSetBasePrices: true,
    canSetSurgeRates: true,
    canOverrideVendorPrices: true,
    canSuspendVendorPricing: true,
    requiresApprovalThreshold: 10000 // NGN - prices above this need approval
  },
  
  // Audit and monitoring
  monitoring: {
    trackPriceChanges: true,
    alertOnOutliers: true,
    outlierThreshold: 2.0, // Standard deviations from mean
    reviewCycle: "weekly" // How often admin reviews pricing
  },
  
  // Metadata
  createdAt: Timestamp,
  updatedAt: Timestamp,
  createdBy: "admin_user_123"
}
```

### 2. `pricing_templates` Collection (Admin-Defined Pricing Rules)
```javascript
{
  // Document ID: auto-generated
  _id: "template_transport_standard",
  serviceId: "transport",
  serviceClass: "standard", // Optional - for service-specific pricing
  subcategory: "taxi", // Optional - for granular control
  
  // Base pricing structure
  basePricing: {
    basePrice: 1000, // NGN - minimum charge
    pricePerKm: 150, // NGN per kilometer
    pricePerMinute: 25, // NGN per minute
    minimumFare: 500, // NGN
    maximumFare: 25000, // NGN
    currency: "NGN"
  },
  
  // Dynamic pricing factors
  dynamicFactors: {
    // Surge pricing
    surgeMultipliers: {
      low: 1.0,
      medium: 1.3,
      high: 1.7,
      peak: 2.5,
      emergency: 3.0
    },
    
    // Time-based pricing
    timeOfDayMultipliers: {
      "06:00-09:00": 1.2, // Morning rush
      "09:00-17:00": 1.0, // Normal hours
      "17:00-20:00": 1.3, // Evening rush
      "20:00-06:00": 1.1  // Night hours
    },
    
    // Day-based pricing
    dayOfWeekMultipliers: {
      monday: 1.0,
      tuesday: 1.0,
      wednesday: 1.0,
      thursday: 1.0,
      friday: 1.1,
      saturday: 1.2,
      sunday: 1.1
    },
    
    // Weather-based surge
    weatherMultipliers: {
      clear: 1.0,
      rain: 1.3,
      heavy_rain: 1.8,
      storm: 2.2
    }
  },
  
  // Geographic pricing variations
  geographicPricing: {
    zones: {
      "lagos_island": {
        multiplier: 1.4,
        minimumFare: 800
      },
      "victoria_island": {
        multiplier: 1.6, 
        minimumFare: 1000
      },
      "mainland": {
        multiplier: 1.0,
        minimumFare: 500
      }
    }
  },
  
  // Special conditions
  specialConditions: {
    airportPickup: {
      additionalFee: 500,
      multiplier: 1.2
    },
    tollRoads: {
      includeTolls: true,
      estimatedTollFee: 200
    },
    waitingTime: {
      freeMinutes: 3,
      chargePerMinute: 50
    }
  },
  
  // Admin metadata
  version: 1,
  isActive: true,
  effectiveFrom: Timestamp,
  effectiveUntil: null,
  createdBy: "admin_user_123",
  approvedBy: "super_admin_456",
  createdAt: Timestamp,
  updatedAt: Timestamp,
  
  // Change tracking
  changeReason: "Updated base pricing for Q1 2024",
  previousVersion: "template_transport_standard_v0"
}
```

### 3. `vendors` Collection (Enhanced with Pricing Rights)
```javascript
{
  // Document ID: vendor identifier
  _id: "vendor_burger_shop_123",
  userId: "user_owner_456", // Owner's account
  businessName: "Mama's Burger Shop",
  
  // Service classification
  serviceId: "food",
  category: "restaurant",
  subcategory: "fast_food",
  
  // Pricing authority configuration
  pricingConfiguration: {
    hasPricingRights: true, // Can set own prices
    isPricingEnabled: true, // Currently allowed to set prices
    pricingModel: "item_based", // item_based | service_based | hybrid
    
    // Admin controls
    adminControls: {
      suspendedBy: null, // admin_id if pricing rights suspended
      suspendedAt: null,
      suspensionReason: null,
      lastReviewedAt: Timestamp,
      lastReviewedBy: "admin_user_123",
      reviewStatus: "approved", // approved | under_review | flagged
    },
    
    // Pricing constraints (set by admin)
    constraints: {
      minimumItemPrice: 100, // NGN
      maximumItemPrice: 50000, // NGN
      maximumMarkup: 3.0, // 300% markup limit
      requiresApprovalAbove: 10000, // NGN
      canSetSurgePricing: false, // Usually false for food vendors
    },
    
    // Performance tracking
    pricingMetrics: {
      averageItemPrice: 1250.0,
      priceChangeFrequency: 2.5, // changes per week
      customerPriceRating: 4.2, // How customers rate pricing fairness
      competitiveIndex: 0.85, // Compared to similar vendors
      lastPriceUpdate: Timestamp
    }
  },
  
  // Business operations
  businessInfo: {
    location: {
      latitude: 6.5244,
      longitude: 3.3792,
      address: "123 Restaurant Street, Lagos"
    },
    operatingHours: {
      monday: { open: "08:00", close: "22:00" },
      // ... other days
    },
    deliveryRadius: 10.0, // km
    minimumOrderValue: 1500, // NGN
  },
  
  // Financial information
  financialInfo: {
    platformCommissionRate: 0.15, // 15% platform commission
    paymentMethods: ["card", "cash", "wallet"],
    taxId: "encrypted_tax_id_123",
    bankAccount: "encrypted_account_456"
  },
  
  // Performance metrics
  performanceMetrics: {
    totalRevenue: 2500000, // NGN
    totalOrders: 1250,
    averageOrderValue: 2000,
    customerRating: 4.7,
    responseTime: 15.5 // minutes average
  }
}
```

### 4. `items` Collection (Vendor Products/Services)
```javascript
{
  // Document ID: auto-generated item ID
  _id: "item_burger_classic_123",
  vendorId: "vendor_burger_shop_123",
  
  // Item identification
  name: "Classic Beef Burger",
  description: "Juicy beef patty with lettuce, tomato, and special sauce",
  category: "burgers",
  subcategory: "beef_burgers",
  
  // Pricing configuration
  pricing: {
    // Current pricing
    currentPrice: 2500, // NGN
    originalPrice: 2800, // For discount display
    currency: "NGN",
    
    // Pricing source and validation
    isUsingCustomPrice: true, // Vendor set custom price
    priceSource: "vendor", // vendor | admin_template | admin_override
    lastPriceUpdate: Timestamp,
    priceUpdatedBy: "vendor_owner_456",
    
    // Admin oversight
    adminReview: {
      status: "approved", // approved | pending | flagged | rejected
      reviewedBy: "admin_user_123",
      reviewedAt: Timestamp,
      reviewNotes: "Price reasonable for market segment",
      flaggedReason: null // price_too_high | price_too_low | suspicious_change
    },
    
    // Pricing analytics
    priceAnalytics: {
      competitorAveragePrice: 2200, // Market intelligence
      priceElasticity: 0.85, // Demand sensitivity to price changes
      optimalPriceRange: { min: 2000, max: 2800 },
      lastOptimizationDate: Timestamp
    },
    
    // Historical pricing
    priceHistory: [
      {
        price: 2300,
        effectiveFrom: "2024-01-01T00:00:00Z",
        effectiveUntil: "2024-01-15T00:00:00Z",
        reason: "Ingredient cost increase",
        updatedBy: "vendor_owner_456"
      }
    ]
  },
  
  // Item characteristics
  itemDetails: {
    sku: "BURGER_CLASSIC_001",
    preparationTime: 12, // minutes
    availability: "available", // available | out_of_stock | discontinued
    tags: ["beef", "popular", "signature"],
    allergens: ["gluten", "dairy"],
    nutritionalInfo: {
      calories: 650,
      protein: 25,
      carbs: 45,
      fat: 35
    }
  },
  
  // Inventory and operations
  inventory: {
    trackInventory: true,
    currentStock: 50,
    lowStockThreshold: 10,
    autoDisableWhenOut: true,
    restockNotification: true
  },
  
  // Performance metrics
  salesMetrics: {
    totalSold: 456,
    revenue: 1140000, // NGN
    averageRating: 4.6,
    orderFrequency: 2.3, // orders per day
    profitMargin: 0.65 // 65% profit margin
  },
  
  // Metadata
  createdAt: Timestamp,
  updatedAt: Timestamp,
  isActive: true
}
```

### 5. `pricing_audit_log` Collection (Complete Audit Trail)
```javascript
{
  // Document ID: auto-generated
  _id: "audit_price_change_abc123",
  
  // Change identification
  changeType: "vendor_price_update", // admin_template_update | vendor_price_update | admin_override | pricing_suspension
  entityType: "item", // item | template | vendor | service
  entityId: "item_burger_classic_123",
  
  // Change details
  changeDetails: {
    field: "currentPrice",
    oldValue: 2300,
    newValue: 2500,
    changeAmount: 200,
    changePercentage: 8.7,
    currency: "NGN"
  },
  
  // Context information
  changeContext: {
    reason: "Ingredient cost increase due to inflation",
    category: "cost_adjustment", // cost_adjustment | competitive_pricing | promotion | error_correction
    impactLevel: "medium", // low | medium | high | critical
    affectedCustomers: 0, // Customers with pending orders
    marketCondition: "inflation" // normal | inflation | recession | high_demand
  },
  
  // Actor information
  actor: {
    userId: "vendor_owner_456",
    role: "vendor", // admin | super_admin | vendor | system
    name: "John Doe",
    vendorId: "vendor_burger_shop_123", // If applicable
    ipAddress: "192.168.1.100", // For security tracking
    userAgent: "Mozilla/5.0...",
    sessionId: "session_abc123"
  },
  
  // Admin review (for vendor changes)
  adminReview: {
    status: "auto_approved", // auto_approved | pending | approved | rejected
    reviewedBy: null,
    reviewedAt: null,
    reviewNotes: null,
    autoApprovalReason: "Within acceptable price range"
  },
  
  // Impact analysis
  impactAnalysis: {
    estimatedRevenueImpact: 1500, // NGN per day
    customerDemandImpact: -0.05, // -5% estimated demand change
    competitivePosition: "above_average", // below_average | average | above_average
    marketShareImpact: 0.02 // +2% estimated market share change
  },
  
  // System metadata
  timestamp: Timestamp,
  processingTime: 0.15, // seconds to process change
  systemVersion: "1.2.3",
  
  // Compliance and legal
  compliance: {
    taxImplications: "none", // none | vat_change | tax_rate_change
    regulatoryCompliance: "compliant", // compliant | needs_review | violation
    priceDisclosureRequired: false
  }
}
```

### 6. `pricing_policies` Collection (Business Rules)
```javascript
{
  // Document ID: policy identifier
  _id: "policy_food_pricing_2024",
  
  // Policy scope
  applicableServices: ["food", "grocery"],
  policyType: "vendor_pricing_guidelines",
  
  // Policy rules
  rules: {
    // Price change limits
    maxPriceIncreasePerDay: 0.20, // 20% max increase per day
    maxPriceDecreasePerDay: 0.50, // 50% max decrease per day
    cooldownPeriod: 3600, // seconds between price changes
    
    // Approval requirements
    autoApprovalThresholds: {
      priceIncrease: 0.10, // 10% - auto-approve below this
      priceDecrease: 0.30, // 30% - auto-approve below this
      absoluteAmount: 1000 // NGN - auto-approve changes below this
    },
    
    // Violation detection
    violationThresholds: {
      priceGouging: 3.0, // 300% above market average
      predatoryPricing: 0.3, // 30% below cost estimate
      rapidChanges: 5, // More than 5 changes per day
      suspiciousPatterns: true // AI-based pattern detection
    },
    
    // Consequences
    violations: {
      firstOffense: "warning",
      secondOffense: "temporary_suspension",
      thirdOffense: "pricing_rights_revocation",
      appealProcess: true
    }
  },
  
  // Policy metadata
  version: "2024.1",
  effectiveDate: Timestamp,
  expiryDate: null,
  isActive: true,
  createdBy: "admin_policy_team",
  approvedBy: "super_admin_456"
}
```

---

## 🧮 Dynamic Pricing Calculation Engine

### Core Pricing Calculation Logic

```javascript
/**
 * Calculate final price for any service/item with multi-source pricing
 * Handles admin-controlled vs vendor-autonomous pricing seamlessly
 */
async function calculateFinalPrice(params) {
  const {
    itemId,
    vendorId,
    serviceId,
    serviceClass,
    distance = 0,
    duration = 0,
    customerLocation,
    orderMetadata = {}
  } = params;

  console.log(`💰 Calculating price for ${serviceId}/${serviceClass} - Item: ${itemId}`);

  try {
    // Step 1: Determine pricing authority
    const pricingAuthority = await determinePricingAuthority(serviceId, vendorId);
    console.log(`📋 Pricing authority: ${pricingAuthority.source}`);

    let basePrice = 0;
    let pricingBreakdown = {
      source: pricingAuthority.source,
      basePricing: {},
      dynamicFactors: {},
      finalPrice: 0,
      currency: 'NGN'
    };

    // Step 2: Calculate base price based on authority
    switch (pricingAuthority.source) {
      case 'vendor_autonomous':
        basePrice = await calculateVendorPrice(itemId, vendorId);
        pricingBreakdown.basePricing = await getVendorPricingDetails(itemId);
        break;
        
      case 'admin_controlled':
        basePrice = await calculateAdminPrice(serviceId, serviceClass, distance, duration);
        pricingBreakdown.basePricing = await getAdminPricingDetails(serviceId, serviceClass);
        break;
        
      case 'admin_override':
        basePrice = await calculateOverridePrice(itemId, vendorId);
        pricingBreakdown.basePricing = await getOverridePricingDetails(itemId);
        break;
        
      default:
        throw new Error(`Unknown pricing authority: ${pricingAuthority.source}`);
    }

    console.log(`💵 Base price calculated: ${basePrice}`);

    // Step 3: Apply dynamic factors (if applicable)
    if (pricingAuthority.allowsDynamicPricing) {
      const dynamicFactors = await calculateDynamicFactors({
        serviceId,
        basePrice,
        customerLocation,
        orderMetadata,
        currentTime: new Date()
      });

      pricingBreakdown.dynamicFactors = dynamicFactors;
      basePrice = applyDynamicFactors(basePrice, dynamicFactors);
    }

    // Step 4: Apply platform fees and adjustments
    const platformAdjustments = await calculatePlatformAdjustments(basePrice, serviceId, vendorId);
    const finalPrice = applyPlatformAdjustments(basePrice, platformAdjustments);

    pricingBreakdown.finalPrice = finalPrice;
    pricingBreakdown.platformAdjustments = platformAdjustments;

    // Step 5: Validate pricing constraints
    await validatePricingConstraints(finalPrice, serviceId, vendorId);

    // Step 6: Log pricing calculation for audit
    await logPricingCalculation({
      itemId,
      vendorId,
      serviceId,
      pricingBreakdown,
      calculationTime: Date.now()
    });

    console.log(`✅ Final price: ${finalPrice} ${pricingBreakdown.currency}`);
    
    return {
      success: true,
      finalPrice: finalPrice,
      currency: pricingBreakdown.currency,
      breakdown: pricingBreakdown,
      calculatedAt: new Date().toISOString()
    };

  } catch (error) {
    console.error(`❌ Pricing calculation error:`, error);
    
    // Fallback to safe default pricing
    const fallbackPrice = await getFallbackPrice(serviceId, serviceClass);
    
    return {
      success: false,
      finalPrice: fallbackPrice,
      currency: 'NGN',
      error: error.message,
      usedFallback: true
    };
  }
}

/**
 * Determine who has pricing authority for this service/vendor combination
 */
async function determinePricingAuthority(serviceId, vendorId) {
  try {
    // Get service configuration
    const serviceDoc = await admin.firestore()
      .collection('services')
      .doc(serviceId)
      .get();

    if (!serviceDoc.exists) {
      throw new Error(`Service not found: ${serviceId}`);
    }

    const serviceData = serviceDoc.data();
    
    // If service doesn't allow vendor pricing, admin controls
    if (!serviceData.hasPricingAutonomy) {
      return {
        source: 'admin_controlled',
        allowsDynamicPricing: serviceData.pricingModel?.surgeEnabled || false,
        constraints: serviceData.adminControls || {}
      };
    }

    // Check if vendor has pricing rights
    if (vendorId) {
      const vendorDoc = await admin.firestore()
        .collection('vendors')
        .doc(vendorId)
        .get();

      if (vendorDoc.exists) {
        const vendorData = vendorDoc.data();
        const pricingConfig = vendorData.pricingConfiguration || {};
        
        // Check if vendor pricing is enabled and not suspended
        if (pricingConfig.hasPricingRights && pricingConfig.isPricingEnabled) {
          // Check for admin override
          if (pricingConfig.adminControls?.suspendedBy) {
            return {
              source: 'admin_override',
              allowsDynamicPricing: false,
              reason: 'vendor_pricing_suspended',
              suspendedBy: pricingConfig.adminControls.suspendedBy
            };
          }
          
          return {
            source: 'vendor_autonomous',
            allowsDynamicPricing: pricingConfig.canSetSurgePricing || false,
            constraints: pricingConfig.constraints || {}
          };
        }
      }
    }

    // Default to admin control
    return {
      source: 'admin_controlled',
      allowsDynamicPricing: serviceData.pricingModel?.surgeEnabled || false,
      constraints: serviceData.adminControls || {}
    };

  } catch (error) {
    console.error('❌ Error determining pricing authority:', error);
    return {
      source: 'admin_controlled',
      allowsDynamicPricing: false,
      error: error.message
    };
  }
}

/**
 * Calculate vendor-set pricing
 */
async function calculateVendorPrice(itemId, vendorId) {
  try {
    const itemDoc = await admin.firestore()
      .collection('items')
      .doc(itemId)
      .get();

    if (!itemDoc.exists) {
      throw new Error(`Item not found: ${itemId}`);
    }

    const itemData = itemDoc.data();
    
    // Validate vendor ownership
    if (itemData.vendorId !== vendorId) {
      throw new Error(`Vendor ${vendorId} does not own item ${itemId}`);
    }

    // Check if using custom pricing
    if (itemData.pricing?.isUsingCustomPrice) {
      const price = itemData.pricing.currentPrice;
      
      // Validate price is within constraints
      await validateVendorPriceConstraints(price, vendorId);
      
      return price;
    } else {
      // Fall back to admin template pricing
      return await calculateAdminPrice(itemData.serviceId, itemData.serviceClass, 0, 0);
    }

  } catch (error) {
    console.error(`❌ Error calculating vendor price:`, error);
    throw error;
  }
}

/**
 * Calculate admin-controlled pricing with dynamic factors
 */
async function calculateAdminPrice(serviceId, serviceClass, distance, duration) {
  try {
    // Get pricing template
    const templateQuery = await admin.firestore()
      .collection('pricing_templates')
      .where('serviceId', '==', serviceId)
      .where('serviceClass', '==', serviceClass)
      .where('isActive', '==', true)
      .limit(1)
      .get();

    if (templateQuery.empty) {
      throw new Error(`No pricing template found for ${serviceId}/${serviceClass}`);
    }

    const template = templateQuery.docs[0].data();
    const basePricing = template.basePricing;

    // Calculate base price
    let calculatedPrice = basePricing.basePrice || 0;
    
    // Add distance-based pricing
    if (distance > 0 && basePricing.pricePerKm) {
      calculatedPrice += distance * basePricing.pricePerKm;
    }
    
    // Add time-based pricing
    if (duration > 0 && basePricing.pricePerMinute) {
      calculatedPrice += duration * basePricing.pricePerMinute;
    }
    
    // Apply minimum fare
    calculatedPrice = Math.max(calculatedPrice, basePricing.minimumFare || 0);
    
    // Apply maximum fare
    if (basePricing.maximumFare) {
      calculatedPrice = Math.min(calculatedPrice, basePricing.maximumFare);
    }

    return calculatedPrice;

  } catch (error) {
    console.error(`❌ Error calculating admin price:`, error);
    throw error;
  }
}

/**
 * Apply dynamic pricing factors (surge, time, weather, etc.)
 */
async function calculateDynamicFactors(params) {
  const { serviceId, basePrice, customerLocation, orderMetadata, currentTime } = params;
  
  try {
    const factors = {
      surge: 1.0,
      timeOfDay: 1.0,
      dayOfWeek: 1.0,
      weather: 1.0,
      demand: 1.0,
      supply: 1.0
    };

    // Get current surge level
    const surgeLevel = await getCurrentSurgeLevel(serviceId, customerLocation);
    factors.surge = getSurgeMultiplier(surgeLevel);

    // Time-based pricing
    const hour = currentTime.getHours();
    factors.timeOfDay = getTimeOfDayMultiplier(hour);

    // Day of week pricing
    const dayOfWeek = currentTime.getDay();
    factors.dayOfWeek = getDayOfWeekMultiplier(dayOfWeek);

    // Weather-based surge
    const weather = await getCurrentWeather(customerLocation);
    factors.weather = getWeatherMultiplier(weather);

    // Real-time demand/supply analysis
    const demandSupply = await analyzeDemandSupply(serviceId, customerLocation);
    factors.demand = demandSupply.demandMultiplier;
    factors.supply = demandSupply.supplyMultiplier;

    return factors;

  } catch (error) {
    console.error('❌ Error calculating dynamic factors:', error);
    
    // Return neutral factors on error
    return {
      surge: 1.0,
      timeOfDay: 1.0,
      dayOfWeek: 1.0,
      weather: 1.0,
      demand: 1.0,
      supply: 1.0
    };
  }
}

/**
 * Apply dynamic factors to base price
 */
function applyDynamicFactors(basePrice, factors) {
  let adjustedPrice = basePrice;
  
  // Apply each factor multiplicatively
  Object.values(factors).forEach(factor => {
    adjustedPrice *= factor;
  });
  
  return Math.round(adjustedPrice);
}

/**
 * Validate pricing constraints and business rules
 */
async function validatePricingConstraints(finalPrice, serviceId, vendorId) {
  try {
    // Get service constraints
    const serviceDoc = await admin.firestore().collection('services').doc(serviceId).get();
    const serviceConstraints = serviceDoc.data()?.pricingModel || {};

    // Check minimum/maximum price limits
    if (serviceConstraints.minimumPrice && finalPrice < serviceConstraints.minimumPrice) {
      throw new Error(`Price below minimum: ${finalPrice} < ${serviceConstraints.minimumPrice}`);
    }

    if (serviceConstraints.maximumPrice && finalPrice > serviceConstraints.maximumPrice) {
      throw new Error(`Price above maximum: ${finalPrice} > ${serviceConstraints.maximumPrice}`);
    }

    // Vendor-specific constraints (if applicable)
    if (vendorId) {
      const vendorDoc = await admin.firestore().collection('vendors').doc(vendorId).get();
      const vendorConstraints = vendorDoc.data()?.pricingConfiguration?.constraints || {};

      if (vendorConstraints.maximumItemPrice && finalPrice > vendorConstraints.maximumItemPrice) {
        throw new Error(`Price exceeds vendor limit: ${finalPrice} > ${vendorConstraints.maximumItemPrice}`);
      }

      if (vendorConstraints.minimumItemPrice && finalPrice < vendorConstraints.minimumItemPrice) {
        throw new Error(`Price below vendor minimum: ${finalPrice} < ${vendorConstraints.minimumItemPrice}`);
      }
    }

    return true;

  } catch (error) {
    console.error('❌ Pricing validation error:', error);
    throw error;
  }
}
```

---

## 🔧 API Endpoints Implementation

### Admin Pricing Management APIs

```javascript
/**
 * Get pricing template for a service
 */
exports.getServicePricingTemplate = functions.https.onCall(async (data, context) => {
  // Verify admin authentication
  if (!context.auth || !await isAdmin(context.auth.uid)) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { serviceId, serviceClass } = data;

  try {
    let query = admin.firestore()
      .collection('pricing_templates')
      .where('serviceId', '==', serviceId)
      .where('isActive', '==', true);

    if (serviceClass) {
      query = query.where('serviceClass', '==', serviceClass);
    }

    const templates = await query.get();
    
    return {
      success: true,
      templates: templates.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }))
    };

  } catch (error) {
    throw new functions.https.HttpsError('internal', `Failed to get pricing template: ${error.message}`);
  }
});

/**
 * Update service pricing template
 */
exports.updateServicePricingTemplate = functions.https.onCall(async (data, context) => {
  if (!context.auth || !await isAdmin(context.auth.uid)) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { serviceId, serviceClass, pricingData, changeReason } = data;

  try {
    // Validate pricing data
    await validatePricingData(pricingData);

    // Create new template version
    const templateRef = admin.firestore().collection('pricing_templates').doc();
    
    await templateRef.set({
      serviceId: serviceId,
      serviceClass: serviceClass || null,
      ...pricingData,
      version: await getNextTemplateVersion(serviceId, serviceClass),
      isActive: true,
      effectiveFrom: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: context.auth.uid,
      changeReason: changeReason || 'Admin pricing update'
    });

    // Deactivate previous template
    await deactivatePreviousTemplate(serviceId, serviceClass);

    // Log pricing change
    await logPricingAudit({
      changeType: 'admin_template_update',
      entityType: 'template',
      entityId: templateRef.id,
      changeDetails: pricingData,
      actor: {
        userId: context.auth.uid,
        role: 'admin'
      },
      changeContext: {
        reason: changeReason,
        category: 'admin_adjustment'
      }
    });

    return {
      success: true,
      templateId: templateRef.id,
      message: 'Pricing template updated successfully'
    };

  } catch (error) {
    throw new functions.https.HttpsError('internal', `Failed to update pricing template: ${error.message}`);
  }
});

/**
 * Review vendor pricing structure
 */
exports.getVendorPricingStructure = functions.https.onCall(async (data, context) => {
  if (!context.auth || !await isAdmin(context.auth.uid)) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { vendorId } = data;

  try {
    // Get vendor information
    const vendorDoc = await admin.firestore().collection('vendors').doc(vendorId).get();
    
    if (!vendorDoc.exists) {
      throw new Error(`Vendor not found: ${vendorId}`);
    }

    const vendorData = vendorDoc.data();

    // Get all vendor items with pricing
    const itemsQuery = await admin.firestore()
      .collection('items')
      .where('vendorId', '==', vendorId)
      .where('isActive', '==', true)
      .get();

    const items = itemsQuery.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    // Calculate pricing analytics
    const analytics = await calculateVendorPricingAnalytics(items);

    return {
      success: true,
      vendor: {
        id: vendorId,
        businessName: vendorData.businessName,
        pricingConfiguration: vendorData.pricingConfiguration,
        serviceId: vendorData.serviceId
      },
      items: items,
      analytics: analytics,
      reviewStatus: vendorData.pricingConfiguration?.adminControls?.reviewStatus || 'pending'
    };

  } catch (error) {
    throw new functions.https.HttpsError('internal', `Failed to get vendor pricing: ${error.message}`);
  }
});

/**
 * Toggle vendor pricing rights (suspend/restore)
 */
exports.toggleVendorPricingRights = functions.https.onCall(async (data, context) => {
  if (!context.auth || !await isAdmin(context.auth.uid)) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { vendorId, enable, reason } = data;

  try {
    const vendorRef = admin.firestore().collection('vendors').doc(vendorId);
    const vendorSnap = await vendorRef.get();

    if (!vendorSnap.exists) {
      throw new Error(`Vendor not found: ${vendorId}`);
    }

    const updateData = {
      'pricingConfiguration.isPricingEnabled': enable,
      'pricingConfiguration.lastModifiedAt': admin.firestore.FieldValue.serverTimestamp(),
      'pricingConfiguration.lastModifiedBy': context.auth.uid
    };

    if (!enable) {
      // Suspending pricing rights
      updateData['pricingConfiguration.adminControls.suspendedBy'] = context.auth.uid;
      updateData['pricingConfiguration.adminControls.suspendedAt'] = admin.firestore.FieldValue.serverTimestamp();
      updateData['pricingConfiguration.adminControls.suspensionReason'] = reason;
    } else {
      // Restoring pricing rights
      updateData['pricingConfiguration.adminControls.suspendedBy'] = null;
      updateData['pricingConfiguration.adminControls.suspendedAt'] = null;
      updateData['pricingConfiguration.adminControls.suspensionReason'] = null;
      updateData['pricingConfiguration.adminControls.restoredAt'] = admin.firestore.FieldValue.serverTimestamp();
    }

    await vendorRef.update(updateData);

    // Log admin action
    await logPricingAudit({
      changeType: enable ? 'pricing_rights_restored' : 'pricing_rights_suspended',
      entityType: 'vendor',
      entityId: vendorId,
      changeDetails: { enabled: enable, reason: reason },
      actor: {
        userId: context.auth.uid,
        role: 'admin'
      }
    });

    // Notify vendor
    await notifyVendorOfPricingChange(vendorId, enable, reason);

    return {
      success: true,
      vendorId: vendorId,
      pricingEnabled: enable,
      message: enable ? 'Pricing rights restored' : 'Pricing rights suspended'
    };

  } catch (error) {
    throw new functions.https.HttpsError('internal', `Failed to toggle pricing rights: ${error.message}`);
  }
});
```

### Vendor Pricing Management APIs

```javascript
/**
 * Get vendor's items and pricing
 */
exports.getVendorItemsPricing = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const vendorId = await getVendorIdForUser(context.auth.uid);
  if (!vendorId) {
    throw new functions.https.HttpsError('permission-denied', 'Vendor access required');
  }

  try {
    // Check if vendor has pricing rights
    const pricingRights = await checkVendorPricingRights(vendorId);
    if (!pricingRights.hasPricingRights) {
      throw new Error('Vendor does not have pricing rights');
    }

    // Get all vendor items
    const itemsQuery = await admin.firestore()
      .collection('items')
      .where('vendorId', '==', vendorId)
      .where('isActive', '==', true)
      .orderBy('name')
      .get();

    const items = itemsQuery.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      // Include pricing analytics for each item
      analytics: calculateItemPricingAnalytics(doc.data())
    }));

    // Calculate vendor pricing summary
    const summary = await calculateVendorPricingSummary(items);

    return {
      success: true,
      vendorId: vendorId,
      pricingRights: pricingRights,
      items: items,
      summary: summary
    };

  } catch (error) {
    throw new functions.https.HttpsError('internal', `Failed to get vendor pricing: ${error.message}`);
  }
});

/**
 * Update item price
 */
exports.updateItemPrice = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { itemId, newPrice, reason } = data;
  const vendorId = await getVendorIdForUser(context.auth.uid);

  try {
    // Validate vendor owns item
    const itemDoc = await admin.firestore().collection('items').doc(itemId).get();
    
    if (!itemDoc.exists || itemDoc.data().vendorId !== vendorId) {
      throw new Error('Item not found or access denied');
    }

    const itemData = itemDoc.data();
    const oldPrice = itemData.pricing?.currentPrice || 0;

    // Validate pricing rights
    const pricingRights = await checkVendorPricingRights(vendorId);
    if (!pricingRights.isPricingEnabled) {
      throw new Error('Vendor pricing rights are suspended');
    }

    // Validate price constraints
    await validatePriceChange({
      vendorId: vendorId,
      itemId: itemId,
      oldPrice: oldPrice,
      newPrice: newPrice,
      constraints: pricingRights.constraints
    });

    // Determine if admin approval is required
    const requiresApproval = await checkIfApprovalRequired(oldPrice, newPrice, pricingRights.constraints);

    // Update item pricing
    const updateData = {
      'pricing.currentPrice': newPrice,
      'pricing.lastPriceUpdate': admin.firestore.FieldValue.serverTimestamp(),
      'pricing.priceUpdatedBy': context.auth.uid,
      'pricing.priceSource': 'vendor',
      'pricing.isUsingCustomPrice': true,
      
      // Add to price history
      'pricing.priceHistory': admin.firestore.FieldValue.arrayUnion({
        price: newPrice,
        previousPrice: oldPrice,
        effectiveFrom: admin.firestore.FieldValue.serverTimestamp(),
        reason: reason || 'Vendor price update',
        updatedBy: context.auth.uid,
        requiresApproval: requiresApproval
      })
    };

    if (requiresApproval) {
      updateData['pricing.adminReview.status'] = 'pending';
      updateData['pricing.adminReview.submittedAt'] = admin.firestore.FieldValue.serverTimestamp();
    } else {
      updateData['pricing.adminReview.status'] = 'auto_approved';
      updateData['pricing.adminReview.autoApprovedAt'] = admin.firestore.FieldValue.serverTimestamp();
    }

    await itemDoc.ref.update(updateData);

    // Log price change
    await logPricingAudit({
      changeType: 'vendor_price_update',
      entityType: 'item',
      entityId: itemId,
      changeDetails: {
        field: 'currentPrice',
        oldValue: oldPrice,
        newValue: newPrice,
        changeAmount: newPrice - oldPrice,
        changePercentage: ((newPrice - oldPrice) / oldPrice) * 100
      },
      actor: {
        userId: context.auth.uid,
        role: 'vendor',
        vendorId: vendorId
      },
      changeContext: {
        reason: reason,
        category: 'vendor_adjustment',
        requiresApproval: requiresApproval
      }
    });

    // Notify admin if approval required
    if (requiresApproval) {
      await notifyAdminOfPendingPriceReview(itemId, vendorId, oldPrice, newPrice);
    }

    return {
      success: true,
      itemId: itemId,
      oldPrice: oldPrice,
      newPrice: newPrice,
      requiresApproval: requiresApproval,
      message: requiresApproval ? 'Price change submitted for admin approval' : 'Price updated successfully'
    };

  } catch (error) {
    throw new functions.https.HttpsError('internal', `Failed to update item price: ${error.message}`);
  }
});

/**
 * Bulk update vendor pricing
 */
exports.bulkUpdateVendorPricing = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { priceUpdates, reason } = data; // Array of {itemId, newPrice}
  const vendorId = await getVendorIdForUser(context.auth.uid);

  try {
    // Validate pricing rights
    const pricingRights = await checkVendorPricingRights(vendorId);
    if (!pricingRights.isPricingEnabled) {
      throw new Error('Vendor pricing rights are suspended');
    }

    // Validate all price changes
    const validationResults = await Promise.all(
      priceUpdates.map(update => validateBulkPriceUpdate(vendorId, update))
    );

    const failedValidations = validationResults.filter(result => !result.valid);
    if (failedValidations.length > 0) {
      throw new Error(`Validation failed for ${failedValidations.length} items`);
    }

    // Process updates in batches
    const batch = admin.firestore().batch();
    const auditEntries = [];

    for (const update of priceUpdates) {
      const itemRef = admin.firestore().collection('items').doc(update.itemId);
      
      batch.update(itemRef, {
        'pricing.currentPrice': update.newPrice,
        'pricing.lastPriceUpdate': admin.firestore.FieldValue.serverTimestamp(),
        'pricing.priceUpdatedBy': context.auth.uid,
        'pricing.bulkUpdateId': `bulk_${Date.now()}`,
      });

      auditEntries.push({
        changeType: 'vendor_bulk_price_update',
        entityType: 'item',
        entityId: update.itemId,
        changeDetails: {
          oldValue: update.oldPrice,
          newValue: update.newPrice
        }
      });
    }

    await batch.commit();

    // Log bulk audit entry
    await logBulkPricingAudit(auditEntries, context.auth.uid, reason);

    return {
      success: true,
      updatedItems: priceUpdates.length,
      message: `Successfully updated ${priceUpdates.length} item prices`
    };

  } catch (error) {
    throw new functions.https.HttpsError('internal', `Bulk price update failed: ${error.message}`);
  }
});
```

---

## 🎛️ Admin Pricing Dashboard

### Admin Control Interface

```dart
class AdminPricingDashboard extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pricing Management'),
          backgroundColor: Colors.indigo.shade600,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.settings), text: 'Templates'),
              Tab(icon: Icon(Icons.store), text: 'Vendor Pricing'),
              Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
              Tab(icon: Icon(Icons.policy), text: 'Policies'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PricingTemplatesTab(),
            VendorPricingTab(),
            PricingAnalyticsTab(),
            PricingPoliciesTab(),
          ],
        ),
      ),
    );
  }
}

class PricingTemplatesTab extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Service selector
        _buildServiceSelector(),
        
        // Pricing template editor
        Expanded(child: _buildTemplateEditor()),
        
        // Save button
        _buildSaveButton(),
      ],
    );
  }

  Widget _buildTemplateEditor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Base pricing section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Base Pricing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _basePriceController,
                          decoration: const InputDecoration(
                            labelText: 'Base Price (₦)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _pricePerKmController,
                          decoration: const InputDecoration(
                            labelText: 'Price per KM (₦)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pricePerMinuteController,
                          decoration: const InputDecoration(
                            labelText: 'Price per Minute (₦)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _minimumFareController,
                          decoration: const InputDecoration(
                            labelText: 'Minimum Fare (₦)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Surge pricing section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Surge Pricing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Switch(
                        value: _surgeEnabled,
                        onChanged: (value) => setState(() => _surgeEnabled = value),
                      ),
                    ],
                  ),
                  
                  if (_surgeEnabled) ...[
                    const SizedBox(height: 16),
                    
                    // Surge multipliers
                    ...['Low', 'Medium', 'High', 'Peak', 'Emergency'].map((level) =>
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 80,
                              child: Text('${level}:', style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            Expanded(
                              child: Slider(
                                value: _surgeMultipliers[level.toLowerCase()] ?? 1.0,
                                min: 1.0,
                                max: 4.0,
                                divisions: 30,
                                label: '${(_surgeMultipliers[level.toLowerCase()] ?? 1.0).toStringAsFixed(1)}x',
                                onChanged: (value) => setState(() => _surgeMultipliers[level.toLowerCase()] = value),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                '${(_surgeMultipliers[level.toLowerCase()] ?? 1.0).toStringAsFixed(1)}x',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Time-based pricing
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Time-Based Pricing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // Time slots with multipliers
                  ...['Morning Rush (6-9 AM)', 'Normal Hours (9 AM-5 PM)', 'Evening Rush (5-8 PM)', 'Night Hours (8 PM-6 AM)'].map((timeSlot) =>
                    ListTile(
                      title: Text(timeSlot),
                      trailing: SizedBox(
                        width: 100,
                        child: TextFormField(
                          decoration: const InputDecoration(
                            suffixText: 'x',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
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
}

class VendorPricingTab extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Vendor search and filter
        _buildVendorFilters(),
        
        // Vendor pricing overview
        Expanded(child: _buildVendorPricingList()),
      ],
    );
  }

  Widget _buildVendorPricingList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('vendors')
          .where('pricingConfiguration.hasPricingRights', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final vendors = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: vendors.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final vendorData = vendors[index].data() as Map<String, dynamic>;
            return VendorPricingCard(
              vendorId: vendors[index].id,
              vendorData: vendorData,
              onTogglePricing: _toggleVendorPricing,
              onReviewPricing: _reviewVendorPricing,
            );
          },
        );
      },
    );
  }
}

class VendorPricingCard extends StatelessWidget {
  final String vendorId;
  final Map<String, dynamic> vendorData;
  final Function(String, bool) onTogglePricing;
  final Function(String) onReviewPricing;

  @override
  Widget build(BuildContext context) {
    final pricingConfig = vendorData['pricingConfiguration'] ?? {};
    final isPricingEnabled = pricingConfig['isPricingEnabled'] ?? false;
    final businessName = vendorData['businessName'] ?? 'Unknown Vendor';
    final serviceId = vendorData['serviceId'] ?? 'unknown';

    return Card(
      elevation: 2,
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
                  child: Text(businessName[0], style: TextStyle(color: Colors.indigo.shade700)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(businessName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('${serviceId.toUpperCase()} Service', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                
                // Pricing status toggle
                Switch(
                  value: isPricingEnabled,
                  onChanged: (value) => onTogglePricing(vendorId, value),
                  activeColor: Colors.green,
                ),
              ],
            ),

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
                    Expanded(child: _buildMetricChip('Avg Price', '₦${metrics['avgPrice'] ?? 0}', Colors.green)),
                    Expanded(child: _buildMetricChip('Changes', '${metrics['changesThisWeek'] ?? 0}', Colors.orange)),
                    Expanded(child: _buildMetricChip('Rating', '${(metrics['priceRating'] ?? 0.0).toStringAsFixed(1)}', Colors.purple)),
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
                    onPressed: () => _showVendorPricingDetails(context, vendorId),
                    icon: const Icon(Icons.analytics),
                    label: const Text('View Analytics'),
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
```

---

## 🏪 Vendor Pricing Dashboard

### Vendor Pricing Management Interface

```dart
class VendorPricingDashboard extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pricing Management'),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _showBulkPricingDialog(),
            icon: const Icon(Icons.edit_note),
            tooltip: 'Bulk Price Update',
          ),
          IconButton(
            onPressed: () => _showPricingAnalytics(),
            icon: const Icon(Icons.analytics),
            tooltip: 'Pricing Analytics',
          ),
        ],
      ),
      body: Column(
        children: [
          // Pricing status and metrics
          _buildPricingStatusCard(),
          
          // Item search and filters
          _buildItemFilters(),
          
          // Items list with pricing
          Expanded(child: _buildItemsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showQuickPriceAdjustment(),
        icon: const Icon(Icons.tune),
        label: const Text('Quick Adjust'),
        backgroundColor: Colors.orange.shade600,
      ),
    );
  }

  Widget _buildPricingStatusCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade400, Colors.orange.shade600],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.store, color: Colors.white, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pricing Control',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _pricingEnabled ? 'You have full pricing control' : 'Pricing rights suspended',
                      style: TextStyle(color: Colors.white.withOpacity(0.9)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _pricingEnabled ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  _pricingEnabled ? 'ACTIVE' : 'SUSPENDED',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Pricing metrics row
          Row(
            children: [
              Expanded(child: _buildMetricItem('Total Items', '$_totalItems', Icons.inventory)),
              Expanded(child: _buildMetricItem('Avg Price', '₦$_avgPrice', Icons.attach_money)),
              Expanded(child: _buildMetricItem('This Week', '$_changesThisWeek changes', Icons.trending_up)),
              Expanded(child: _buildMetricItem('Rating', '${_priceRating.toStringAsFixed(1)}/5', Icons.star)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('items')
          .where('vendorId', isEqualTo: _currentVendorId)
          .where('isActive', isEqualTo: true)
          .orderBy('salesMetrics.totalSold', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data!.docs;

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final itemData = items[index].data() as Map<String, dynamic>;
            return VendorItemPricingCard(
              itemId: items[index].id,
              itemData: itemData,
              onPriceUpdate: _updateItemPrice,
              pricingEnabled: _pricingEnabled,
            );
          },
        );
      },
    );
  }
}

class VendorItemPricingCard extends StatelessWidget {
  final String itemId;
  final Map<String, dynamic> itemData;
  final Function(String, double, String) onPriceUpdate;
  final bool pricingEnabled;

  @override
  Widget build(BuildContext context) {
    final pricing = itemData['pricing'] ?? {};
    final currentPrice = (pricing['currentPrice'] as num?)?.toDouble() ?? 0.0;
    final salesMetrics = itemData['salesMetrics'] ?? {};
    final adminReview = pricing['adminReview'] ?? {};

    return Card(
      elevation: 1,
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
                        itemData['name'] ?? 'Unknown Item',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        itemData['category'] ?? 'Uncategorized',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      
                      // Sales info
                      Row(
                        children: [
                          Icon(Icons.trending_up, size: 16, color: Colors.green),
                          const SizedBox(width: 4),
                          Text('${salesMetrics['totalSold'] ?? 0} sold'),
                          const SizedBox(width: 12),
                          Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text('${(salesMetrics['averageRating'] ?? 0.0).toStringAsFixed(1)}'),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Current price display
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₦${currentPrice.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    
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
            Row(
              children: [
                // Quick price adjustment buttons
                IconButton(
                  onPressed: pricingEnabled ? () => _quickAdjustPrice(-100) : null,
                  icon: Icon(Icons.remove_circle, color: pricingEnabled ? Colors.red : Colors.grey),
                  tooltip: 'Decrease ₦100',
                ),
                
                Expanded(
                  child: Slider(
                    value: currentPrice,
                    min: 100,
                    max: 10000,
                    divisions: 99,
                    label: '₦${currentPrice.toStringAsFixed(0)}',
                    onChanged: pricingEnabled ? (value) => _onPriceSliderChanged(value) : null,
                    onChangeEnd: pricingEnabled ? (value) => _updatePrice(value) : null,
                  ),
                ),
                
                IconButton(
                  onPressed: pricingEnabled ? () => _quickAdjustPrice(100) : null,
                  icon: Icon(Icons.add_circle, color: pricingEnabled ? Colors.green : Colors.grey),
                  tooltip: 'Increase ₦100',
                ),
                
                // Detailed price editor
                IconButton(
                  onPressed: pricingEnabled ? () => _showDetailedPriceEditor() : null,
                  icon: Icon(Icons.edit, color: pricingEnabled ? Colors.blue : Colors.grey),
                  tooltip: 'Edit Price',
                ),
              ],
            ),

            // Pricing analytics preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildAnalyticItem('Revenue', '₦${salesMetrics['revenue'] ?? 0}')),
                  Expanded(child: _buildAnalyticItem('Margin', '${((salesMetrics['profitMargin'] ?? 0) * 100).toStringAsFixed(0)}%')),
                  Expanded(child: _buildAnalyticItem('Demand', _getDemandTrend(salesMetrics))),
                  Expanded(child: _buildAnalyticItem('Competition', _getCompetitivePosition(pricing))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
}
```

This comprehensive pricing system provides:

- ✅ **Flexible admin control** with global pricing templates
- ✅ **Vendor autonomy** for marketplace services with oversight
- ✅ **Dynamic pricing calculation** with multi-factor support
- ✅ **Complete audit trail** for transparency and dispute resolution
- ✅ **Advanced security** with encrypted sensitive data
- ✅ **Real-time pricing analytics** for optimization
- ✅ **Policy enforcement** with automatic violation detection

Ready for the next phase of implementation! 🚀