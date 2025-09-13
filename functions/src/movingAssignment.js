const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { GeoFirestore } = require('geofirestore');

// Initialize Firebase Admin SDK if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const geofirestore = new GeoFirestore(db);

/**
 * Cloud Function triggered when a new moving request is created with status 'requesting'
 * Finds the closest available moving provider and assigns them to the request
 */
exports.assignProviderToMovingRequest = functions.firestore
  .document('moving_requests/{requestId}')
  .onCreate(async (snap, context) => {
    const requestData = snap.data();
    const requestId = context.params.requestId;

    // Only process if status is 'requesting'
    if (requestData.status !== 'requesting') {
      console.log(`Moving request ${requestId} status is ${requestData.status}, not processing`);
      return null;
    }

    console.log(`Processing moving request ${requestId} for vehicle type ${requestData.vehicleType}`);

    try {
      // Get request location for proximity search
      const requestLocation = requestData.pickupLocation;
      if (!requestLocation || !requestLocation.latitude || !requestLocation.longitude) {
        console.error('Moving request location is missing or invalid');
        return null;
      }

      // Query available moving providers within 10km radius (larger for moving services)
      const providersRef = geofirestore.collection('moving_providers');
      const center = new admin.firestore.GeoPoint(requestLocation.latitude, requestLocation.longitude);
      const radiusInKm = 10;

      // Create geo query for providers within radius
      const geoQuery = providersRef.near({
        center: center,
        radius: radiusInKm
      });

      const nearbyProviders = await geoQuery.get();
      console.log(`Found ${nearbyProviders.docs.length} moving providers within ${radiusInKm}km`);

      // Filter providers based on availability and vehicle type
      const availableProviders = [];
      
      for (const providerDoc of nearbyProviders.docs) {
        const providerData = providerDoc.data();
        const providerId = providerDoc.id;

        // Check provider availability criteria
        const isEligible = 
          providerData.isOnline === true &&
          providerData.isAvailable === true &&
          providerData.serviceType === 'moving' &&
          providerData.vehicleInfo?.type === requestData.vehicleType &&
          providerData.fcmToken && // Must have FCM token for notifications
          _checkMovingCapacity(providerData, requestData);

        if (isEligible) {
          availableProviders.push({
            id: providerId,
            data: providerData,
            distance: providerDoc.distance // Distance from GeoFirestore query
          });
        }
      }

      console.log(`Found ${availableProviders.length} available moving providers matching criteria`);

      if (availableProviders.length === 0) {
        console.log('No available moving providers found');
        await snap.ref.update({
          status: 'no_providers_available',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return null;
      }

      // Sort by distance and rating, pick the best one
      availableProviders.sort((a, b) => {
        // Primary sort by distance, secondary by rating
        const distanceDiff = a.distance - b.distance;
        if (Math.abs(distanceDiff) < 2) { // If within 2km, prefer higher rating
          return (b.data.rating || 0) - (a.data.rating || 0);
        }
        return distanceDiff;
      });

      const bestProvider = availableProviders[0];
      console.log(`Assigning best moving provider: ${bestProvider.id} (${bestProvider.distance}km away, rating: ${bestProvider.data.rating})`);

      // Update moving request with assigned provider
      await snap.ref.update({
        providerId: bestProvider.id,
        status: 'provider_assigned',
        assignedAt: admin.firestore.FieldValue.serverTimestamp(),
        providerDistance: bestProvider.distance,
        estimatedArrival: _calculateMovingETA(bestProvider.distance)
      });

      // Mark provider as temporarily unavailable
      await db.collection('moving_providers').doc(bestProvider.id).update({
        isAvailable: false,
        currentRequestId: requestId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Send high-priority FCM notification to provider
      const notificationPayload = {
        token: bestProvider.data.fcmToken,
        notification: {
          title: '📦 New Moving Request!',
          body: `${requestData.movingType || 'Moving service'} • ${requestData.rooms || 'N/A'} rooms`,
        },
        data: {
          type: 'moving_request',
          requestId: requestId,
          movingType: requestData.movingType || 'moving',
          pickupAddress: requestData.pickupAddress || '',
          destinationAddress: requestData.destinationAddress || '',
          estimatedCost: requestData.estimatedCost?.toString() || '0',
          distance: bestProvider.distance.toString(),
          customerName: requestData.customerName || 'Customer',
          rooms: requestData.rooms?.toString() || '0',
          movingDate: requestData.movingDate || '',
          specialRequirements: requestData.specialRequirements || ''
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'moving_requests',
            priority: 'high',
            defaultSound: false,
            sound: 'moving_request_sound',
            tag: `moving_${requestId}`,
            sticky: true,
            localOnly: false,
            defaultVibrateTimings: false,
            vibrateTimingsMillis: [0, 300, 300, 300],
            visibility: 'public',
            importance: 'high'
          }
        },
        apns: {
          headers: {
            'apns-priority': '10',
            'apns-push-type': 'alert'
          },
          payload: {
            aps: {
              alert: {
                title: '📦 New Moving Request!',
                body: `${requestData.movingType || 'Moving service'} • ${requestData.rooms || 'N/A'} rooms`
              },
              sound: 'moving_request_sound.wav',
              badge: 1,
              'content-available': 1,
              category: 'MOVING_REQUEST'
            }
          }
        }
      };

      try {
        const response = await admin.messaging().send(notificationPayload);
        console.log('Moving request FCM notification sent successfully:', response);
      } catch (error) {
        console.error('Error sending moving request FCM notification:', error);
      }

      // Set 90-second timeout for moving requests (longer than rides)
      setTimeout(async () => {
        await checkMovingProviderResponse(requestId, bestProvider.id);
      }, 90000);

      console.log(`Successfully assigned moving provider ${bestProvider.id} to request ${requestId}`);
      return null;

    } catch (error) {
      console.error('Error in assignProviderToMovingRequest:', error);
      
      await snap.ref.update({
        status: 'assignment_error',
        error: error.message,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return null;
    }
  });

/**
 * Check moving provider capacity against request requirements
 */
function _checkMovingCapacity(providerData, requestData) {
  const providerCapacity = providerData.vehicleInfo?.capacity || {};
  const requestRequirements = requestData.requirements || {};

  // Check weight capacity
  if (requestRequirements.weight && providerCapacity.maxWeight) {
    if (requestRequirements.weight > providerCapacity.maxWeight) {
      return false;
    }
  }

  // Check volume capacity
  if (requestRequirements.volume && providerCapacity.maxVolume) {
    if (requestRequirements.volume > providerCapacity.maxVolume) {
      return false;
    }
  }

  // Check if provider handles the specific moving type
  const movingTypes = providerData.movingTypes || [];
  if (requestData.movingType && !movingTypes.includes(requestData.movingType)) {
    return false;
  }

  return true;
}

/**
 * Calculate estimated arrival time for moving provider
 */
function _calculateMovingETA(distanceKm) {
  // Moving trucks travel slower, add preparation time
  const travelTimeMinutes = Math.ceil(distanceKm * 4); // 15 km/h average
  const prepTimeMinutes = 15; // Preparation time
  const totalMinutes = travelTimeMinutes + prepTimeMinutes;
  
  const eta = new Date();
  eta.setMinutes(eta.getMinutes() + totalMinutes);
  return eta.toISOString();
}

/**
 * Check if moving provider responded within timeout period
 */
async function checkMovingProviderResponse(requestId, providerId) {
  try {
    console.log(`Checking moving provider response for request ${requestId} after 90 seconds`);
    
    const requestDoc = await db.collection('moving_requests').doc(requestId).get();
    
    if (!requestDoc.exists) {
      console.log(`Moving request ${requestId} no longer exists`);
      return;
    }

    const requestData = requestDoc.data();
    
    if (requestData.status === 'provider_assigned') {
      console.log(`Moving provider ${providerId} did not respond to request ${requestId}, reassigning...`);
      
      // Mark provider as available again
      await db.collection('moving_providers').doc(providerId).update({
        isAvailable: true,
        currentRequestId: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Reset request status to 'requesting' to trigger reassignment
      await db.collection('moving_requests').doc(requestId).update({
        status: 'requesting',
        providerId: admin.firestore.FieldValue.delete(),
        assignedAt: admin.firestore.FieldValue.delete(),
        providerDistance: admin.firestore.FieldValue.delete(),
        estimatedArrival: admin.firestore.FieldValue.delete(),
        timeoutCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`Moving request ${requestId} status reset to 'requesting' for reassignment`);
    } else {
      console.log(`Moving request ${requestId} status is now ${requestData.status}, no timeout action needed`);
    }
    
  } catch (error) {
    console.error('Error checking moving provider response:', error);
  }
}

/**
 * Handle moving provider acceptance/decline actions
 */
exports.handleMovingProviderResponse = functions.firestore
  .document('moving_requests/{requestId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const requestId = context.params.requestId;

    // Check if status changed to 'accepted'
    if (before.status === 'provider_assigned' && after.status === 'accepted') {
      console.log(`Moving provider ${after.providerId} accepted request ${requestId}`);
      
      await db.collection('moving_providers').doc(after.providerId).update({
        isAvailable: false,
        currentRequestId: requestId,
        onJob: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return null;
    }

    // Check if status changed to 'cancelled_by_provider'
    if (before.status === 'provider_assigned' && after.status === 'cancelled_by_provider') {
      console.log(`Moving provider ${after.providerId} declined request ${requestId}`);
      
      // Mark provider as available again
      await db.collection('moving_providers').doc(after.providerId).update({
        isAvailable: true,
        currentRequestId: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Reset request status to 'requesting' to find another provider
      await change.after.ref.update({
        status: 'requesting',
        providerId: admin.firestore.FieldValue.delete(),
        assignedAt: admin.firestore.FieldValue.delete(),
        providerDistance: admin.firestore.FieldValue.delete(),
        estimatedArrival: admin.firestore.FieldValue.delete(),
        declineCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return null;
    }

    return null;
  });