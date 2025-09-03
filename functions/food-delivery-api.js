const functions = require('firebase-functions');
const admin = require('firebase-admin');

const db = admin.firestore();

/**
 * 🍔 FOOD DELIVERY API ENDPOINTS
 * Complete API implementation for vendor-driver-customer flow
 */

// ===== VENDOR ENDPOINTS =====

/**
 * Vendor accepts order and sets preparation time
 */
exports.vendorAcceptOrder = functions.https.onCall(async (data, context) => {
  // Verify vendor authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Vendor must be authenticated');
  }

  const { orderId, prepTimeEstimate, specialInstructions } = data;
  const vendorId = context.auth.uid;

  if (!orderId || !prepTimeEstimate) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }

  try {
    // Verify vendor owns this order
    const orderRef = db.collection('food_orders').doc(orderId);
    const orderSnap = await orderRef.get();
    
    if (!orderSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Order not found');
    }

    const orderData = orderSnap.data();
    if (orderData.vendorId !== vendorId) {
      throw new functions.https.HttpsError('permission-denied', 'Vendor not authorized for this order');
    }

    if (orderData.status !== 'pending_vendor_acceptance') {
      throw new functions.https.HttpsError('failed-precondition', 'Order cannot be accepted in current state');
    }

    // Calculate preparation deadline
    const prepDeadline = new Date(Date.now() + (prepTimeEstimate * 60 * 1000));
    const estimatedDelivery = new Date(prepDeadline.getTime() + (20 * 60 * 1000)); // +20min for delivery

    // Update order with acceptance
    await orderRef.update({
      status: 'accepted_by_vendor',
      acceptedByVendorAt: admin.firestore.FieldValue.serverTimestamp(),
      prepTimeEstimate: prepTimeEstimate,
      prepTimeDeadline: admin.firestore.Timestamp.fromDate(prepDeadline),
      estimatedDeliveryTime: admin.firestore.Timestamp.fromDate(estimatedDelivery),
      specialInstructions: specialInstructions || null,
    });

    // Log status change
    await _logStatusChange(orderId, 'pending_vendor_acceptance', 'accepted_by_vendor', vendorId, 'vendor');

    // Automatically transition to preparing after 2 seconds
    setTimeout(async () => {
      await orderRef.update({
        status: 'preparing',
        prepStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      await _logStatusChange(orderId, 'accepted_by_vendor', 'preparing', vendorId, 'vendor');
    }, 2000);

    // Notify customer
    await _notifyCustomer(orderData.customerId, 'Order Accepted!', 
      `Your order will be ready in ${prepTimeEstimate} minutes`);

    return {
      success: true,
      orderId: orderId,
      newStatus: 'accepted_by_vendor',
      prepDeadline: prepDeadline.toISOString(),
      estimatedDelivery: estimatedDelivery.toISOString()
    };

  } catch (error) {
    console.error('❌ Error accepting order:', error);
    throw new functions.https.HttpsError('internal', 'Failed to accept order');
  }
});

/**
 * Vendor declines order
 */
exports.vendorDeclineOrder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Vendor must be authenticated');
  }

  const { orderId, reason, message } = data;
  const vendorId = context.auth.uid;

  try {
    const orderRef = db.collection('food_orders').doc(orderId);
    const orderSnap = await orderRef.get();
    
    if (!orderSnap.exists || orderSnap.data().vendorId !== vendorId) {
      throw new functions.https.HttpsError('permission-denied', 'Unauthorized');
    }

    await orderRef.update({
      status: 'declined_by_vendor',
      declinedAt: admin.firestore.FieldValue.serverTimestamp(),
      declineReason: reason,
      declineMessage: message,
    });

    await _logStatusChange(orderId, orderSnap.data().status, 'declined_by_vendor', vendorId, 'vendor');

    // Notify customer and potentially find alternative vendor
    await _notifyCustomer(orderSnap.data().customerId, 'Order Declined', 
      message || 'Restaurant is unable to fulfill your order');

    return { success: true, orderId: orderId };

  } catch (error) {
    throw new functions.https.HttpsError('internal', 'Failed to decline order');
  }
});

/**
 * Mark order as ready for pickup
 */
exports.vendorMarkOrderReady = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Vendor must be authenticated');
  }

  const { orderId, actualPrepTime, pickupInstructions } = data;
  const vendorId = context.auth.uid;

  try {
    const orderRef = db.collection('food_orders').doc(orderId);
    
    await orderRef.update({
      status: 'ready_for_pickup',
      readyForPickupAt: admin.firestore.FieldValue.serverTimestamp(),
      actualPrepTime: actualPrepTime,
      pickupInstructions: pickupInstructions,
    });

    await _logStatusChange(orderId, 'preparing', 'ready_for_pickup', vendorId, 'vendor');

    return { success: true, orderId: orderId };

  } catch (error) {
    throw new functions.https.HttpsError('internal', 'Failed to mark order ready');
  }
});

/**
 * Get nearby available drivers for vendor
 */
exports.getNearbyDrivers = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Vendor must be authenticated');
  }

  const { lat, lng, radius = 10 } = data; // Default 10km radius

  try {
    // Get all available drivers
    const driversQuery = await db.collection('delivery_drivers')
      .where('isOnline', '==', true)
      .where('availabilityStatus', '==', 'available')
      .get();

    const nearbyDrivers = [];

    driversQuery.docs.forEach(doc => {
      const driverData = doc.data();
      const driverLat = driverData.currentLocation?.latitude;
      const driverLng = driverData.currentLocation?.longitude;

      if (driverLat && driverLng) {
        const distance = calculateDistance(lat, lng, driverLat, driverLng);
        
        if (distance <= radius) {
          nearbyDrivers.push({
            id: driverData.userId,
            name: driverData.name,
            rating: driverData.rating || 4.0,
            distance: Math.round(distance * 100) / 100, // Round to 2 decimals
            estimatedArrival: Math.ceil(distance * 2), // 2 minutes per km
            vehicle: driverData.vehicle,
            currentLocation: { lat: driverLat, lng: driverLng },
            totalDeliveries: driverData.totalDeliveries || 0,
          });
        }
      }
    });

    // Sort by distance (closest first)
    nearbyDrivers.sort((a, b) => a.distance - b.distance);

    return { 
      success: true, 
      drivers: nearbyDrivers.slice(0, 20) // Return max 20 drivers
    };

  } catch (error) {
    console.error('❌ Error fetching nearby drivers:', error);
    throw new functions.https.HttpsError('internal', 'Failed to fetch drivers');
  }
});

/**
 * Assign driver to order
 */
exports.assignDriverToOrder = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Vendor must be authenticated');
  }

  const { orderId, driverId, estimatedPickupTime } = data;
  const vendorId = context.auth.uid;

  try {
    // Verify order ownership and status
    const orderRef = db.collection('food_orders').doc(orderId);
    const orderSnap = await orderRef.get();
    
    if (!orderSnap.exists || orderSnap.data().vendorId !== vendorId) {
      throw new functions.https.HttpsError('permission-denied', 'Unauthorized');
    }

    if (orderSnap.data().status !== 'ready_for_pickup') {
      throw new functions.https.HttpsError('failed-precondition', 'Order not ready for driver assignment');
    }

    // Verify driver availability
    const driverQuery = await db.collection('delivery_drivers')
      .where('userId', '==', driverId)
      .where('availabilityStatus', '==', 'available')
      .limit(1)
      .get();

    if (driverQuery.empty) {
      throw new functions.https.HttpsError('failed-precondition', 'Driver not available');
    }

    const driverDoc = driverQuery.docs[0];
    const driverData = driverDoc.data();

    // Use transaction to ensure atomicity
    await db.runTransaction(async (transaction) => {
      // Update order
      transaction.update(orderRef, {
        driverId: driverId,
        driverName: driverData.name,
        driverPhone: driverData.phone,
        driverVehicle: driverData.vehicle,
        status: 'assigned_to_driver',
        assignedToDriverAt: admin.firestore.FieldValue.serverTimestamp(),
        estimatedPickupTime: estimatedPickupTime ? admin.firestore.Timestamp.fromDate(new Date(estimatedPickupTime)) : null,
      });

      // Update driver status
      transaction.update(driverDoc.ref, {
        availabilityStatus: 'assigned',
        currentOrderId: orderId,
        lastAssignedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    await _logStatusChange(orderId, 'ready_for_pickup', 'assigned_to_driver', vendorId, 'vendor');

    // Notify driver
    await _notifyDriver(driverId, 'New Delivery Assignment', 
      `Pickup from ${orderSnap.data().vendorName || 'Restaurant'}`);

    return { 
      success: true, 
      orderId: orderId,
      driverId: driverId,
      driverName: driverData.name 
    };

  } catch (error) {
    console.error('❌ Error assigning driver:', error);
    throw new functions.https.HttpsError('internal', 'Failed to assign driver');
  }
});

// ===== DRIVER ENDPOINTS =====

/**
 * Driver accepts delivery assignment
 */
exports.driverAcceptAssignment = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Driver must be authenticated');
  }

  const { orderId, estimatedArrivalAtVendor, currentLocation } = data;
  const driverId = context.auth.uid;

  try {
    const orderRef = db.collection('food_orders').doc(orderId);
    const orderSnap = await orderRef.get();
    
    if (!orderSnap.exists || orderSnap.data().driverId !== driverId) {
      throw new functions.https.HttpsError('permission-denied', 'Driver not assigned to this order');
    }

    await orderRef.update({
      status: 'accepted_by_driver',
      acceptedByDriverAt: admin.firestore.FieldValue.serverTimestamp(),
      estimatedArrivalAtVendor: estimatedArrivalAtVendor,
      driverLocation: currentLocation,
    });

    await _logStatusChange(orderId, 'assigned_to_driver', 'accepted_by_driver', driverId, 'driver');

    // Notify customer and vendor
    const orderData = orderSnap.data();
    await _notifyCustomer(orderData.customerId, 'Driver Assigned!', 
      `${orderData.driverName} is coming to pick up your order`);

    return { success: true, orderId: orderId };

  } catch (error) {
    throw new functions.https.HttpsError('internal', 'Failed to accept assignment');
  }
});

/**
 * Driver updates delivery status
 */
exports.updateDriverStatus = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Driver must be authenticated');
  }

  const { orderId, status, location, note } = data;
  const driverId = context.auth.uid;

  const validStatuses = [
    'driver_en_route_to_vendor',
    'driver_at_vendor', 
    'order_picked_up',
    'driver_en_route_to_customer',
    'driver_at_customer'
  ];

  if (!validStatuses.includes(status)) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid status');
  }

  try {
    const orderRef = db.collection('food_orders').doc(orderId);
    const orderSnap = await orderRef.get();
    
    if (!orderSnap.exists || orderSnap.data().driverId !== driverId) {
      throw new functions.https.HttpsError('permission-denied', 'Driver not assigned to this order');
    }

    const updateData = {
      status: status,
      [`${status.replace(/_/g, '')}At`]: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (location) {
      updateData.driverLocation = {
        latitude: location.lat,
        longitude: location.lng,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        heading: location.heading || null,
        speed: location.speed || null,
      };
    }

    if (note) {
      updateData.statusNote = note;
    }

    await orderRef.update(updateData);
    await _logStatusChange(orderId, orderSnap.data().status, status, driverId, 'driver');

    // Send appropriate notifications
    const orderData = orderSnap.data();
    let notificationMessage = '';
    
    switch (status) {
      case 'driver_en_route_to_vendor':
        notificationMessage = `${orderData.driverName} is on the way to pick up your order`;
        break;
      case 'order_picked_up':
        notificationMessage = `Your order has been picked up and is on the way!`;
        break;
      case 'driver_en_route_to_customer':
        notificationMessage = `${orderData.driverName} is delivering your order`;
        break;
      case 'driver_at_customer':
        notificationMessage = `Your delivery has arrived! Code: ${orderData.deliveryCode}`;
        break;
    }

    if (notificationMessage) {
      await _notifyCustomer(orderData.customerId, 'Order Update', notificationMessage);
    }

    return { success: true, orderId: orderId, newStatus: status };

  } catch (error) {
    console.error('❌ Error updating driver status:', error);
    throw new functions.https.HttpsError('internal', 'Failed to update status');
  }
});

/**
 * Update driver location (real-time tracking)
 */
exports.updateDriverLocation = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Driver must be authenticated');
  }

  const { latitude, longitude, accuracy, heading, speed } = data;
  const driverId = context.auth.uid;

  try {
    // Update driver's global location
    const driverQuery = await db.collection('delivery_drivers')
      .where('userId', '==', driverId)
      .limit(1)
      .get();

    if (!driverQuery.empty) {
      await driverQuery.docs[0].ref.update({
        currentLocation: {
          latitude: latitude,
          longitude: longitude,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          accuracy: accuracy || 5.0,
          heading: heading || null,
          speed: speed || null,
        },
      });
    }

    // Update location in active order (if any)
    const activeOrderQuery = await db.collection('food_orders')
      .where('driverId', '==', driverId)
      .where('status', 'in', [
        'accepted_by_driver',
        'driver_en_route_to_vendor',
        'driver_at_vendor',
        'order_picked_up',
        'driver_en_route_to_customer',
        'driver_at_customer'
      ])
      .limit(1)
      .get();

    if (!activeOrderQuery.empty) {
      await activeOrderQuery.docs[0].ref.update({
        driverLocation: {
          latitude: latitude,
          longitude: longitude,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          accuracy: accuracy || 5.0,
          heading: heading || null,
          speed: speed || null,
        },
      });
    }

    return { success: true };

  } catch (error) {
    console.error('❌ Error updating driver location:', error);
    throw new functions.https.HttpsError('internal', 'Failed to update location');
  }
});

/**
 * Verify delivery code and complete delivery
 */
exports.verifyDeliveryCode = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Driver must be authenticated');
  }

  const { orderId, deliveryCode, customerSignature, deliveryPhoto, deliveryNotes } = data;
  const driverId = context.auth.uid;

  try {
    // Use transaction for atomic verification
    const result = await db.runTransaction(async (transaction) => {
      const orderRef = db.collection('food_orders').doc(orderId);
      const orderSnap = await transaction.get(orderRef);

      if (!orderSnap.exists) {
        throw new Error('Order not found');
      }

      const orderData = orderSnap.data();

      // Validate driver and order state
      if (orderData.driverId !== driverId) {
        throw new Error('Driver not assigned to this order');
      }

      if (orderData.status !== 'driver_at_customer') {
        throw new Error('Order not ready for delivery verification');
      }

      // Check delivery code
      const correctCode = orderData.deliveryCode;
      const currentAttempts = orderData.codeAttempts || 0;
      const maxAttempts = orderData.maxCodeAttempts || 3;

      if (currentAttempts >= maxAttempts) {
        throw new Error('Maximum code attempts exceeded');
      }

      const isCodeCorrect = deliveryCode.toUpperCase() === correctCode.toUpperCase();

      // Update attempt tracking
      transaction.update(orderRef, {
        codeAttempts: currentAttempts + 1,
        lastCodeAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
        codeAttemptHistory: admin.firestore.FieldValue.arrayUnion([{
          attempt: currentAttempts + 1,
          enteredCode: deliveryCode,
          isCorrect: isCodeCorrect,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        }]),
      });

      if (isCodeCorrect) {
        // Successful delivery
        transaction.update(orderRef, {
          status: 'delivered',
          deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
          codeVerifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          customerSignature: customerSignature,
          deliveryPhoto: deliveryPhoto,
          deliveryNotes: deliveryNotes,
        });

        // Update driver availability
        const driverQuery = await db.collection('delivery_drivers')
          .where('userId', '==', driverId)
          .limit(1)
          .get();

        if (!driverQuery.empty) {
          transaction.update(driverQuery.docs[0].ref, {
            availabilityStatus: 'available',
            currentOrderId: null,
            lastDeliveryCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
            totalDeliveries: admin.firestore.FieldValue.increment(1),
          });
        }

        return { success: true, delivered: true };
      } else {
        // Invalid code
        const remainingAttempts = maxAttempts - (currentAttempts + 1);
        
        if (remainingAttempts <= 0) {
          // Max attempts reached - flag for review
          transaction.update(orderRef, {
            status: 'delivery_verification_failed',
            flaggedForReview: true,
            flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        return { 
          success: false, 
          delivered: false,
          message: `Invalid code. ${remainingAttempts} attempts remaining.`,
          remainingAttempts: remainingAttempts,
          blocked: remainingAttempts <= 0
        };
      }
    });

    // Log status change if delivered
    if (result.delivered) {
      await _logStatusChange(orderId, 'driver_at_customer', 'delivered', driverId, 'driver');
      
      // Notify customer and vendor
      const orderData = (await db.collection('food_orders').doc(orderId).get()).data();
      await _notifyCustomer(orderData.customerId, 'Order Delivered!', 'Enjoy your meal!');
      await _notifyVendor(orderData.vendorId, 'Order Completed', `Order #${orderId.substring(0, 8)} delivered successfully`);
    }

    return result;

  } catch (error) {
    console.error('❌ Error verifying delivery code:', error);
    throw new functions.https.HttpsError('internal', error.message || 'Failed to verify delivery code');
  }
});

// ===== UTILITY FUNCTIONS =====

/**
 * Log order status changes for audit trail
 */
async function _logStatusChange(orderId, previousStatus, newStatus, updatedBy, updatedByRole) {
  try {
    await db.collection('order_status_log').add({
      orderId: orderId,
      previousStatus: previousStatus,
      newStatus: newStatus,
      updatedBy: updatedBy,
      updatedByRole: updatedByRole,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      changeReason: `Status updated by ${updatedByRole}`,
    });
  } catch (error) {
    console.error('❌ Error logging status change:', error);
  }
}

/**
 * Send notification to customer
 */
async function _notifyCustomer(customerId, title, message) {
  try {
    await db.collection('notifications').add({
      userId: customerId,
      title: title,
      body: message,
      type: 'order_update',
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error('❌ Error notifying customer:', error);
  }
}

/**
 * Send notification to vendor
 */
async function _notifyVendor(vendorId, title, message) {
  try {
    await db.collection('notifications').add({
      userId: vendorId,
      title: title,
      body: message,
      type: 'order_update',
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error('❌ Error notifying vendor:', error);
  }
}

/**
 * Send notification to driver
 */
async function _notifyDriver(driverId, title, message) {
  try {
    await db.collection('notifications').add({
      userId: driverId,
      title: title,
      body: message,
      type: 'delivery_assignment',
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error('❌ Error notifying driver:', error);
  }
}

/**
 * Calculate distance between two points using Haversine formula
 */
function calculateDistance(lat1, lng1, lat2, lng2) {
  const R = 6371; // Earth's radius in km
  const dLat = toRadians(lat2 - lat1);
  const dLng = toRadians(lng2 - lng1);
  
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(toRadians(lat1)) * Math.cos(toRadians(lat2)) *
    Math.sin(dLng/2) * Math.sin(dLng/2);
  
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  
  return R * c;
}

function toRadians(degrees) {
  return degrees * (Math.PI / 180);
}