const functions = require('firebase-functions');
const admin = require('firebase-admin');

/**
 * 💰 PRICING MANAGEMENT API
 * Complete implementation for admin and vendor pricing control
 */

// ===== ADMIN PRICING ENDPOINTS =====

/**
 * Get pricing template for a service
 * GET /api/admin/pricing/templates/:service
 */
exports.getServicePricingTemplate = functions.https.onCall(async (data, context) => {
  // Verify admin authentication
  if (!context.auth || !await isAdmin(context.auth.uid)) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { serviceId, serviceClass } = data;

  if (!serviceId) {
    throw new functions.https.HttpsError('invalid-argument', 'Service ID is required');
  }

  try {
    let query = admin.firestore()
      .collection('pricing_templates')
      .where('serviceId', '==', serviceId)
      .where('isActive', '==', true);

    if (serviceClass) {
      query = query.where('serviceClass', '==', serviceClass);
    }

    const templates = await query.get();
    
    const templateData = templates.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      // Add calculated metrics
      usage: await calculateTemplateUsage(doc.id),
      lastModified: doc.data().updatedAt?.toDate?.() || null
    }));

    return {
      success: true,
      serviceId: serviceId,
      serviceClass: serviceClass,
      templates: templateData,
      totalTemplates: templateData.length
    };

  } catch (error) {
    console.error('❌ Error getting pricing template:', error);
    throw new functions.https.HttpsError('internal', `Failed to get pricing template: ${error.message}`);
  }
});

/**
 * Update service pricing template
 * POST /api/admin/pricing/templates/:service
 */
exports.updateServicePricingTemplate = functions.https.onCall(async (data, context) => {
  if (!context.auth || !await isAdmin(context.auth.uid)) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { serviceId, serviceClass, pricingData, changeReason, effectiveDate } = data;

  if (!serviceId || !pricingData) {
    throw new functions.https.HttpsError('invalid-argument', 'Service ID and pricing data are required');
  }

  try {
    // Validate pricing data structure
    const validationResult = validatePricingTemplateData(pricingData);
    if (!validationResult.isValid) {
      throw new Error(`Invalid pricing data: ${validationResult.errors.join(', ')}`);
    }

    // Create new template version
    const templateRef = admin.firestore().collection('pricing_templates').doc();
    const templateData = {
      serviceId: serviceId,
      serviceClass: serviceClass || null,
      ...pricingData,
      
      // Version control
      version: await getNextTemplateVersion(serviceId, serviceClass),
      isActive: true,
      effectiveFrom: effectiveDate ? admin.firestore.Timestamp.fromDate(new Date(effectiveDate)) : admin.firestore.FieldValue.serverTimestamp(),
      effectiveUntil: null,
      
      // Admin metadata
      createdBy: context.auth.uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      changeReason: changeReason || 'Admin pricing update',
      
      // Approval tracking
      approvalStatus: 'approved',
      approvedBy: context.auth.uid,
      approvedAt: admin.firestore.FieldValue.serverTimestamp()
    };

    // Use transaction to ensure atomicity
    await admin.firestore().runTransaction(async (transaction) => {
      // Create new template
      transaction.set(templateRef, templateData);

      // Deactivate previous template(s)
      const previousTemplates = await admin.firestore()
        .collection('pricing_templates')
        .where('serviceId', '==', serviceId)
        .where('serviceClass', '==', serviceClass || null)
        .where('isActive', '==', true)
        .get();

      previousTemplates.docs.forEach(doc => {
        if (doc.id !== templateRef.id) {
          transaction.update(doc.ref, {
            isActive: false,
            deactivatedAt: admin.firestore.FieldValue.serverTimestamp(),
            deactivatedBy: context.auth.uid,
            supersededBy: templateRef.id
          });
        }
      });
    });

    // Log pricing template change
    await logPricingAudit({
      changeType: 'admin_template_update',
      entityType: 'pricing_template',
      entityId: templateRef.id,
      changeDetails: {
        serviceId: serviceId,
        serviceClass: serviceClass,
        pricingData: pricingData,
        previousVersion: await getPreviousTemplateVersion(serviceId, serviceClass)
      },
      actor: {
        userId: context.auth.uid,
        role: 'admin',
        name: await getUserName(context.auth.uid)
      },
      changeContext: {
        reason: changeReason,
        category: 'admin_adjustment',
        impactLevel: 'high' // Template changes affect all orders
      }
    });

    // Notify affected vendors (if any)
    await notifyVendorsOfTemplateChange(serviceId, serviceClass, pricingData);

    return {
      success: true,
      templateId: templateRef.id,
      version: templateData.version,
      effectiveFrom: templateData.effectiveFrom,
      message: 'Pricing template updated successfully'
    };

  } catch (error) {
    console.error('❌ Error updating pricing template:', error);
    throw new functions.https.HttpsError('internal', `Failed to update pricing template: ${error.message}`);
  }
});

/**
 * Review vendor pricing structure
 * GET /api/admin/vendors/:vendorId/pricing
 */
exports.getVendorPricingStructure = functions.https.onCall(async (data, context) => {
  if (!context.auth || !await isAdmin(context.auth.uid)) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { vendorId, includeAnalytics = true } = data;

  if (!vendorId) {
    throw new functions.https.HttpsError('invalid-argument', 'Vendor ID is required');
  }

  try {
    // Get vendor information
    const vendorDoc = await admin.firestore().collection('vendors').doc(vendorId).get();
    
    if (!vendorDoc.exists) {
      throw new Error(`Vendor not found: ${vendorId}`);
    }

    const vendorData = vendorDoc.data();
    const pricingConfig = vendorData.pricingConfiguration || {};

    // Get all vendor items with pricing
    const itemsQuery = await admin.firestore()
      .collection('items')
      .where('vendorId', '==', vendorId)
      .where('isActive', '==', true)
      .get();

    const items = await Promise.all(itemsQuery.docs.map(async (doc) => {
      const itemData = doc.data();
      const itemResult = {
        id: doc.id,
        ...itemData
      };

      // Add pricing analytics if requested
      if (includeAnalytics) {
        itemResult.analytics = await calculateItemPricingAnalytics(doc.id, itemData);
      }

      return itemResult;
    }));

    // Calculate vendor-level pricing analytics
    const vendorAnalytics = includeAnalytics 
      ? await calculateVendorPricingAnalytics(vendorId, items)
      : null;

    // Get recent pricing changes
    const recentChanges = await admin.firestore()
      .collection('pricing_audit_log')
      .where('entityType', '==', 'item')
      .where('actor.vendorId', '==', vendorId)
      .orderBy('timestamp', 'desc')
      .limit(20)
      .get();

    return {
      success: true,
      vendor: {
        id: vendorId,
        businessName: vendorData.businessName,
        serviceId: vendorData.serviceId,
        pricingConfiguration: pricingConfig,
        performanceMetrics: vendorData.performanceMetrics || {}
      },
      items: items,
      analytics: vendorAnalytics,
      recentChanges: recentChanges.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })),
      summary: {
        totalItems: items.length,
        itemsWithCustomPricing: items.filter(item => item.pricing?.isUsingCustomPrice).length,
        averagePrice: items.reduce((sum, item) => sum + (item.pricing?.currentPrice || 0), 0) / items.length,
        priceChangesThisWeek: await countRecentPriceChanges(vendorId, 7),
        flaggedItems: items.filter(item => item.pricing?.adminReview?.status === 'flagged').length
      }
    };

  } catch (error) {
    console.error('❌ Error getting vendor pricing structure:', error);
    throw new functions.https.HttpsError('internal', `Failed to get vendor pricing: ${error.message}`);
  }
});

/**
 * Toggle vendor pricing rights
 * POST /api/admin/vendors/:vendorId/toggle-pricing
 */
exports.toggleVendorPricingRights = functions.https.onCall(async (data, context) => {
  if (!context.auth || !await isAdmin(context.auth.uid)) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { vendorId, enable, reason, notifyVendor = true } = data;

  if (!vendorId || typeof enable !== 'boolean') {
    throw new functions.https.HttpsError('invalid-argument', 'Vendor ID and enable flag are required');
  }

  try {
    const vendorRef = admin.firestore().collection('vendors').doc(vendorId);
    const vendorSnap = await vendorRef.get();

    if (!vendorSnap.exists) {
      throw new Error(`Vendor not found: ${vendorId}`);
    }

    const vendorData = vendorSnap.data();
    const currentStatus = vendorData.pricingConfiguration?.isPricingEnabled || false;

    // Check if change is actually needed
    if (currentStatus === enable) {
      return {
        success: true,
        message: `Pricing rights already ${enable ? 'enabled' : 'disabled'}`,
        noChangeNeeded: true
      };
    }

    // Prepare update data
    const updateData = {
      'pricingConfiguration.isPricingEnabled': enable,
      'pricingConfiguration.lastModifiedAt': admin.firestore.FieldValue.serverTimestamp(),
      'pricingConfiguration.lastModifiedBy': context.auth.uid
    };

    if (!enable) {
      // Suspending pricing rights
      updateData['pricingConfiguration.adminControls.suspendedBy'] = context.auth.uid;
      updateData['pricingConfiguration.adminControls.suspendedAt'] = admin.firestore.FieldValue.serverTimestamp();
      updateData['pricingConfiguration.adminControls.suspensionReason'] = reason || 'Administrative action';
      
      // Revert items to admin template pricing
      await revertVendorItemsToAdminPricing(vendorId);
      
    } else {
      // Restoring pricing rights
      updateData['pricingConfiguration.adminControls.suspendedBy'] = null;
      updateData['pricingConfiguration.adminControls.suspendedAt'] = null;
      updateData['pricingConfiguration.adminControls.suspensionReason'] = null;
      updateData['pricingConfiguration.adminControls.restoredAt'] = admin.firestore.FieldValue.serverTimestamp();
      updateData['pricingConfiguration.adminControls.restoredBy'] = context.auth.uid;
    }

    // Update vendor document
    await vendorRef.update(updateData);

    // Log admin action
    await logPricingAudit({
      changeType: enable ? 'pricing_rights_restored' : 'pricing_rights_suspended',
      entityType: 'vendor',
      entityId: vendorId,
      changeDetails: {
        enabled: enable,
        reason: reason,
        previousStatus: currentStatus,
        affectedItems: await countVendorItems(vendorId)
      },
      actor: {
        userId: context.auth.uid,
        role: 'admin',
        name: await getUserName(context.auth.uid)
      },
      changeContext: {
        reason: reason,
        category: 'admin_enforcement',
        impactLevel: 'high'
      }
    });

    // Notify vendor if requested
    if (notifyVendor) {
      await notifyVendorOfPricingRightsChange(vendorId, enable, reason);
    }

    // Notify admin team of the action
    await notifyAdminTeamOfPricingAction(context.auth.uid, vendorId, enable, reason);

    return {
      success: true,
      vendorId: vendorId,
      pricingEnabled: enable,
      affectedItems: await countVendorItems(vendorId),
      message: enable ? 'Pricing rights restored successfully' : 'Pricing rights suspended successfully'
    };

  } catch (error) {
    console.error('❌ Error toggling vendor pricing rights:', error);
    throw new functions.https.HttpsError('internal', `Failed to toggle pricing rights: ${error.message}`);
  }
});

/**
 * Get pricing analytics and outlier detection
 * GET /api/admin/pricing/analytics
 */
exports.getPricingAnalytics = functions.https.onCall(async (data, context) => {
  if (!context.auth || !await isAdmin(context.auth.uid)) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const { 
    serviceId, 
    timeRange = 30, // days
    includeOutliers = true,
    includeVendorComparison = true 
  } = data;

  try {
    const analytics = {
      overview: await calculatePricingOverview(serviceId, timeRange),
      trends: await calculatePricingTrends(serviceId, timeRange),
      vendorComparison: includeVendorComparison ? await compareVendorPricing(serviceId) : null,
      outliers: includeOutliers ? await detectPricingOutliers(serviceId) : null,
      recommendations: await generatePricingRecommendations(serviceId)
    };

    return {
      success: true,
      serviceId: serviceId,
      timeRange: timeRange,
      analytics: analytics,
      generatedAt: new Date().toISOString()
    };

  } catch (error) {
    console.error('❌ Error getting pricing analytics:', error);
    throw new functions.https.HttpsError('internal', `Failed to get analytics: ${error.message}`);
  }
});

// ===== VENDOR PRICING ENDPOINTS =====

/**
 * Get vendor's items and pricing
 * GET /api/vendor/items/pricing
 */
exports.getVendorItemsPricing = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  try {
    // Get vendor ID for authenticated user
    const vendorId = await getVendorIdForUser(context.auth.uid);
    if (!vendorId) {
      throw new Error('User is not associated with any vendor');
    }

    // Check vendor pricing rights
    const pricingRights = await checkVendorPricingRights(vendorId);
    if (!pricingRights.exists) {
      throw new Error('Vendor not found');
    }

    // Get all vendor items
    const itemsQuery = await admin.firestore()
      .collection('items')
      .where('vendorId', '==', vendorId)
      .where('isActive', '==', true)
      .orderBy('salesMetrics.totalSold', 'desc')
      .get();

    const items = await Promise.all(itemsQuery.docs.map(async (doc) => {
      const itemData = doc.data();
      
      return {
        id: doc.id,
        ...itemData,
        // Add pricing analytics for each item
        analytics: await calculateItemPricingAnalytics(doc.id, itemData),
        competitorPricing: await getCompetitorPricing(itemData.name, itemData.category),
        priceOptimization: await calculatePriceOptimization(doc.id, itemData)
      };
    }));

    // Calculate vendor pricing summary
    const summary = await calculateVendorPricingSummary(vendorId, items);

    // Get recent price change history
    const recentChanges = await admin.firestore()
      .collection('pricing_audit_log')
      .where('actor.vendorId', '==', vendorId)
      .where('changeType', '==', 'vendor_price_update')
      .orderBy('timestamp', 'desc')
      .limit(10)
      .get();

    return {
      success: true,
      vendorId: vendorId,
      pricingRights: {
        hasPricingRights: pricingRights.hasPricingRights,
        isPricingEnabled: pricingRights.isPricingEnabled,
        constraints: pricingRights.constraints,
        suspensionReason: pricingRights.suspensionReason
      },
      items: items,
      summary: summary,
      recentChanges: recentChanges.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      })),
      recommendations: await generateVendorPricingRecommendations(vendorId, items)
    };

  } catch (error) {
    console.error('❌ Error getting vendor items pricing:', error);
    throw new functions.https.HttpsError('internal', `Failed to get vendor pricing: ${error.message}`);
  }
});

/**
 * Update item price
 * POST /api/vendor/items/{itemId}/price
 */
exports.updateItemPrice = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { itemId, newPrice, reason, effectiveDate } = data;

  if (!itemId || typeof newPrice !== 'number' || newPrice < 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Valid item ID and price are required');
  }

  try {
    // Get vendor ID and validate ownership
    const vendorId = await getVendorIdForUser(context.auth.uid);
    if (!vendorId) {
      throw new Error('User is not associated with any vendor');
    }

    // Validate item ownership
    const itemDoc = await admin.firestore().collection('items').doc(itemId).get();
    if (!itemDoc.exists || itemDoc.data().vendorId !== vendorId) {
      throw new Error('Item not found or access denied');
    }

    const itemData = itemDoc.data();
    const oldPrice = itemData.pricing?.currentPrice || 0;

    // Check vendor pricing rights
    const pricingRights = await checkVendorPricingRights(vendorId);
    if (!pricingRights.isPricingEnabled) {
      throw new Error(`Vendor pricing rights are suspended: ${pricingRights.suspensionReason || 'Administrative action'}`);
    }

    // Validate price change
    const validation = await validateVendorPriceChange({
      vendorId: vendorId,
      itemId: itemId,
      oldPrice: oldPrice,
      newPrice: newPrice,
      constraints: pricingRights.constraints
    });

    if (!validation.isValid) {
      throw new Error(`Price validation failed: ${validation.errors.join(', ')}`);
    }

    // Determine if admin approval is required
    const requiresApproval = validation.requiresApproval;
    const effectiveTimestamp = effectiveDate 
      ? admin.firestore.Timestamp.fromDate(new Date(effectiveDate))
      : admin.firestore.FieldValue.serverTimestamp();

    // Prepare price update data
    const priceUpdateData = {
      'pricing.currentPrice': newPrice,
      'pricing.lastPriceUpdate': admin.firestore.FieldValue.serverTimestamp(),
      'pricing.priceUpdatedBy': context.auth.uid,
      'pricing.priceSource': 'vendor',
      'pricing.isUsingCustomPrice': true,
      'pricing.effectiveFrom': effectiveTimestamp,
      
      // Add to price history
      'pricing.priceHistory': admin.firestore.FieldValue.arrayUnion({
        price: newPrice,
        previousPrice: oldPrice,
        changeAmount: newPrice - oldPrice,
        changePercentage: oldPrice > 0 ? ((newPrice - oldPrice) / oldPrice) * 100 : 0,
        effectiveFrom: effectiveTimestamp,
        reason: reason || 'Vendor price adjustment',
        updatedBy: context.auth.uid,
        requiresApproval: requiresApproval,
        approvalStatus: requiresApproval ? 'pending' : 'auto_approved'
      })
    };

    // Set admin review status
    if (requiresApproval) {
      priceUpdateData['pricing.adminReview.status'] = 'pending';
      priceUpdateData['pricing.adminReview.submittedAt'] = admin.firestore.FieldValue.serverTimestamp();
      priceUpdateData['pricing.adminReview.submittedBy'] = context.auth.uid;
    } else {
      priceUpdateData['pricing.adminReview.status'] = 'auto_approved';
      priceUpdateData['pricing.adminReview.autoApprovedAt'] = admin.firestore.FieldValue.serverTimestamp();
      priceUpdateData['pricing.adminReview.autoApprovalReason'] = 'Within acceptable limits';
    }

    // Update item pricing
    await itemDoc.ref.update(priceUpdateData);

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
        changePercentage: oldPrice > 0 ? ((newPrice - oldPrice) / oldPrice) * 100 : 0,
        currency: 'NGN'
      },
      actor: {
        userId: context.auth.uid,
        role: 'vendor',
        vendorId: vendorId,
        name: await getUserName(context.auth.uid)
      },
      changeContext: {
        reason: reason || 'Vendor price adjustment',
        category: 'vendor_adjustment',
        impactLevel: calculatePriceChangeImpact(oldPrice, newPrice),
        requiresApproval: requiresApproval,
        validationWarnings: validation.warnings
      }
    });

    // Notify admin if approval required
    if (requiresApproval) {
      await notifyAdminOfPendingPriceReview({
        itemId: itemId,
        vendorId: vendorId,
        itemName: itemData.name,
        oldPrice: oldPrice,
        newPrice: newPrice,
        reason: reason,
        submittedBy: context.auth.uid
      });
    }

    // Update vendor pricing metrics
    await updateVendorPricingMetrics(vendorId);

    return {
      success: true,
      itemId: itemId,
      oldPrice: oldPrice,
      newPrice: newPrice,
      changeAmount: newPrice - oldPrice,
      changePercentage: oldPrice > 0 ? ((newPrice - oldPrice) / oldPrice) * 100 : 0,
      requiresApproval: requiresApproval,
      effectiveDate: effectiveDate || new Date().toISOString(),
      warnings: validation.warnings,
      message: requiresApproval 
        ? 'Price change submitted for admin approval' 
        : 'Price updated successfully'
    };

  } catch (error) {
    console.error('❌ Error updating item price:', error);
    throw new functions.https.HttpsError('internal', `Failed to update item price: ${error.message}`);
  }
});

/**
 * Bulk update vendor pricing
 * POST /api/vendor/items/bulk-price-update
 */
exports.bulkUpdateVendorPricing = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { priceUpdates, reason, effectiveDate } = data;

  if (!Array.isArray(priceUpdates) || priceUpdates.length === 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Price updates array is required');
  }

  if (priceUpdates.length > 100) {
    throw new functions.https.HttpsError('invalid-argument', 'Maximum 100 items can be updated at once');
  }

  try {
    const vendorId = await getVendorIdForUser(context.auth.uid);
    if (!vendorId) {
      throw new Error('User is not associated with any vendor');
    }

    // Check vendor pricing rights
    const pricingRights = await checkVendorPricingRights(vendorId);
    if (!pricingRights.isPricingEnabled) {
      throw new Error('Vendor pricing rights are suspended');
    }

    // Validate all price updates
    const validationResults = await Promise.all(
      priceUpdates.map(update => validateBulkPriceUpdate(vendorId, update))
    );

    const failedValidations = validationResults.filter(result => !result.isValid);
    if (failedValidations.length > 0) {
      throw new Error(`Validation failed for ${failedValidations.length} items: ${failedValidations.map(v => v.errors.join(', ')).join('; ')}`);
    }

    // Process updates in batches
    const batchSize = 500; // Firestore batch limit
    const batches = [];
    const auditEntries = [];
    const bulkUpdateId = `bulk_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    for (let i = 0; i < priceUpdates.length; i += batchSize) {
      const batch = admin.firestore().batch();
      const batchUpdates = priceUpdates.slice(i, i + batchSize);

      for (const update of batchUpdates) {
        const itemRef = admin.firestore().collection('items').doc(update.itemId);
        
        const updateData = {
          'pricing.currentPrice': update.newPrice,
          'pricing.lastPriceUpdate': admin.firestore.FieldValue.serverTimestamp(),
          'pricing.priceUpdatedBy': context.auth.uid,
          'pricing.bulkUpdateId': bulkUpdateId,
          'pricing.isUsingCustomPrice': true,
          'pricing.priceSource': 'vendor',
          
          // Add to price history
          'pricing.priceHistory': admin.firestore.FieldValue.arrayUnion({
            price: update.newPrice,
            previousPrice: update.oldPrice || 0,
            changeAmount: update.newPrice - (update.oldPrice || 0),
            effectiveFrom: admin.firestore.FieldValue.serverTimestamp(),
            reason: reason || 'Bulk price update',
            updatedBy: context.auth.uid,
            bulkUpdateId: bulkUpdateId,
            requiresApproval: false // Bulk updates typically pre-validated
          })
        };

        batch.update(itemRef, updateData);

        // Prepare audit entry
        auditEntries.push({
          changeType: 'vendor_bulk_price_update',
          entityType: 'item',
          entityId: update.itemId,
          changeDetails: {
            field: 'currentPrice',
            oldValue: update.oldPrice || 0,
            newValue: update.newPrice,
            changeAmount: update.newPrice - (update.oldPrice || 0),
            bulkUpdateId: bulkUpdateId
          }
        });
      }

      batches.push(batch);
    }

    // Execute all batches
    await Promise.all(batches.map(batch => batch.commit()));

    // Log bulk audit entry
    await logBulkPricingAudit({
      bulkUpdateId: bulkUpdateId,
      vendorId: vendorId,
      totalItems: priceUpdates.length,
      auditEntries: auditEntries,
      actor: {
        userId: context.auth.uid,
        role: 'vendor',
        vendorId: vendorId
      },
      changeContext: {
        reason: reason || 'Bulk pricing update',
        category: 'bulk_adjustment'
      }
    });

    // Update vendor metrics
    await updateVendorPricingMetrics(vendorId);

    // Notify admin of significant bulk changes
    if (priceUpdates.length > 50) {
      await notifyAdminOfLargeBulkUpdate(vendorId, priceUpdates.length, bulkUpdateId);
    }

    return {
      success: true,
      vendorId: vendorId,
      bulkUpdateId: bulkUpdateId,
      updatedItems: priceUpdates.length,
      processedBatches: batches.length,
      message: `Successfully updated ${priceUpdates.length} item prices`
    };

  } catch (error) {
    console.error('❌ Error in bulk price update:', error);
    throw new functions.https.HttpsError('internal', `Bulk price update failed: ${error.message}`);
  }
});

/**
 * Get vendor pricing analytics
 * GET /api/vendor/pricing/analytics
 */
exports.getVendorPricingAnalytics = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Authentication required');
  }

  const { timeRange = 30, includeCompetitorData = true } = data;

  try {
    const vendorId = await getVendorIdForUser(context.auth.uid);
    if (!vendorId) {
      throw new Error('User is not associated with any vendor');
    }

    const analytics = {
      // Revenue and pricing performance
      performance: await calculateVendorPricingPerformance(vendorId, timeRange),
      
      // Price optimization opportunities
      optimization: await analyzeVendorPriceOptimization(vendorId),
      
      // Competitive analysis
      competition: includeCompetitorData 
        ? await analyzeVendorCompetitivePosition(vendorId)
        : null,
      
      // Demand elasticity analysis
      elasticity: await calculateVendorPriceElasticity(vendorId, timeRange),
      
      // Recommendations
      recommendations: await generateVendorSpecificRecommendations(vendorId)
    };

    return {
      success: true,
      vendorId: vendorId,
      timeRange: timeRange,
      analytics: analytics,
      generatedAt: new Date().toISOString()
    };

  } catch (error) {
    console.error('❌ Error getting vendor pricing analytics:', error);
    throw new functions.https.HttpsError('internal', `Failed to get vendor analytics: ${error.message}`);
  }
});

// ===== UTILITY FUNCTIONS =====

/**
 * Check if user is admin
 */
async function isAdmin(userId) {
  try {
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) return false;
    
    const userData = userDoc.data();
    return userData.role === 'admin' || userData.role === 'super_admin';
  } catch (error) {
    console.error('❌ Error checking admin status:', error);
    return false;
  }
}

/**
 * Get vendor ID for user
 */
async function getVendorIdForUser(userId) {
  try {
    const vendorQuery = await admin.firestore()
      .collection('vendors')
      .where('userId', '==', userId)
      .limit(1)
      .get();

    return vendorQuery.empty ? null : vendorQuery.docs[0].id;
  } catch (error) {
    console.error('❌ Error getting vendor ID:', error);
    return null;
  }
}

/**
 * Check vendor pricing rights and constraints
 */
async function checkVendorPricingRights(vendorId) {
  try {
    const vendorDoc = await admin.firestore().collection('vendors').doc(vendorId).get();
    
    if (!vendorDoc.exists) {
      return { exists: false };
    }

    const vendorData = vendorDoc.data();
    const pricingConfig = vendorData.pricingConfiguration || {};

    return {
      exists: true,
      hasPricingRights: pricingConfig.hasPricingRights || false,
      isPricingEnabled: pricingConfig.isPricingEnabled || false,
      constraints: pricingConfig.constraints || {},
      suspensionReason: pricingConfig.adminControls?.suspensionReason || null,
      lastReviewed: pricingConfig.adminControls?.lastReviewedAt || null
    };
  } catch (error) {
    console.error('❌ Error checking vendor pricing rights:', error);
    return { exists: false, error: error.message };
  }
}

/**
 * Log pricing audit event
 */
async function logPricingAudit(auditData) {
  try {
    await admin.firestore().collection('pricing_audit_log').add({
      ...auditData,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      auditId: `audit_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      systemVersion: '1.0.0'
    });
  } catch (error) {
    console.error('❌ Error logging pricing audit:', error);
  }
}

/**
 * Calculate pricing impact level
 */
function calculatePriceChangeImpact(oldPrice, newPrice) {
  if (oldPrice === 0) return 'new_item';
  
  const changePercentage = Math.abs((newPrice - oldPrice) / oldPrice) * 100;
  
  if (changePercentage > 50) return 'critical';
  if (changePercentage > 25) return 'high';
  if (changePercentage > 10) return 'medium';
  return 'low';
}

/**
 * Validate pricing template data structure
 */
function validatePricingTemplateData(pricingData) {
  const errors = [];
  
  // Check required fields
  if (!pricingData.basePricing) {
    errors.push('Base pricing configuration is required');
  } else {
    const basePricing = pricingData.basePricing;
    
    if (typeof basePricing.basePrice !== 'number' || basePricing.basePrice < 0) {
      errors.push('Valid base price is required');
    }
    
    if (basePricing.minimumFare && (typeof basePricing.minimumFare !== 'number' || basePricing.minimumFare < 0)) {
      errors.push('Valid minimum fare is required');
    }
    
    if (basePricing.maximumFare && basePricing.maximumFare <= basePricing.minimumFare) {
      errors.push('Maximum fare must be greater than minimum fare');
    }
  }

  // Validate surge multipliers
  if (pricingData.dynamicFactors?.surgeMultipliers) {
    const surgeMultipliers = pricingData.dynamicFactors.surgeMultipliers;
    Object.entries(surgeMultipliers).forEach(([level, multiplier]) => {
      if (typeof multiplier !== 'number' || multiplier < 1.0 || multiplier > 5.0) {
        errors.push(`Invalid surge multiplier for ${level}: must be between 1.0 and 5.0`);
      }
    });
  }

  return {
    isValid: errors.length === 0,
    errors: errors
  };
}

module.exports = {
  // Export functions for testing
  calculatePriceChangeImpact,
  validatePricingTemplateData,
  isAdmin,
  getVendorIdForUser,
  checkVendorPricingRights
};