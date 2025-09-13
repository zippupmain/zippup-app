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
 * Cloud Function triggered when a new emergency request is created with status 'requesting'
 * Finds the closest available emergency responder and assigns them to the request
 */
exports.assignResponderToEmergencyRequest = functions.firestore
  .document('emergency_requests/{requestId}')
  .onCreate(async (snap, context) => {
    const requestData = snap.data();
    const requestId = context.params.requestId;

    // Only process if status is 'requesting'
    if (requestData.status !== 'requesting') {
      console.log(`Emergency request ${requestId} status is ${requestData.status}, not processing`);
      return null;
    }

    const emergencyType = requestData.emergencyType; // ambulance, fire_service, security_service, towing_van
    console.log(`Processing ${emergencyType} emergency request ${requestId} with priority ${requestData.priority}`);

    try {
      // Get request location for proximity search
      const requestLocation = requestData.location;
      if (!requestLocation || !requestLocation.latitude || !requestLocation.longitude) {
        console.error('Emergency request location is missing or invalid');
        return null;
      }

      // Determine search radius based on emergency type and priority
      const radiusInKm = _getEmergencySearchRadius(emergencyType, requestData.priority);
      
      // Query available emergency responders
      const respondersRef = geofirestore.collection('emergency_responders');
      const center = new admin.firestore.GeoPoint(requestLocation.latitude, requestLocation.longitude);

      const geoQuery = respondersRef.near({
        center: center,
        radius: radiusInKm
      });

      const nearbyResponders = await geoQuery.get();
      console.log(`Found ${nearbyResponders.docs.length} emergency responders within ${radiusInKm}km`);

      // Filter responders based on availability and service type
      const availableResponders = [];
      
      for (const responderDoc of nearbyResponders.docs) {
        const responderData = responderDoc.data();
        const responderId = responderDoc.id;

        // Check responder availability criteria
        const isEligible = 
          responderData.isOnline === true &&
          responderData.isAvailable === true &&
          responderData.serviceType === 'emergency' &&
          responderData.emergencyTypes?.includes(emergencyType) &&
          responderData.fcmToken && // Must have FCM token for notifications
          _checkEmergencyCapability(responderData, requestData);

        if (isEligible) {
          availableResponders.push({
            id: responderId,
            data: responderData,
            distance: responderDoc.distance
          });
        }
      }

      console.log(`Found ${availableResponders.length} available ${emergencyType} responders matching criteria`);

      if (availableResponders.length === 0) {
        console.log(`No available ${emergencyType} responders found`);
        await snap.ref.update({
          status: 'no_responders_available',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        // For critical emergencies, try expanding search radius
        if (requestData.priority === 'critical' && radiusInKm < 50) {
          console.log('Critical emergency - attempting expanded search');
          setTimeout(() => {
            _attemptExpandedEmergencySearch(requestId, emergencyType);
          }, 30000); // Try expanded search after 30 seconds
        }
        
        return null;
      }

      // Sort by priority: distance first, then rating for non-critical
      // For critical emergencies, distance is the only factor
      availableResponders.sort((a, b) => {
        if (requestData.priority === 'critical') {
          return a.distance - b.distance;
        }
        
        // For other priorities, balance distance and rating
        const distanceDiff = a.distance - b.distance;
        if (Math.abs(distanceDiff) < 3) { // If within 3km, prefer higher rating
          return (b.data.rating || 0) - (a.data.rating || 0);
        }
        return distanceDiff;
      });

      const bestResponder = availableResponders[0];
      console.log(`Assigning best ${emergencyType} responder: ${bestResponder.id} (${bestResponder.distance}km away)`);

      // Calculate ETA based on emergency type and priority
      const estimatedArrival = _calculateEmergencyETA(bestResponder.distance, emergencyType, requestData.priority);

      // Update emergency request with assigned responder
      await snap.ref.update({
        responderId: bestResponder.id,
        status: 'responder_assigned',
        assignedAt: admin.firestore.FieldValue.serverTimestamp(),
        responderDistance: bestResponder.distance,
        estimatedArrival: estimatedArrival,
        priority: requestData.priority || 'medium'
      });

      // Mark responder as temporarily unavailable
      await db.collection('emergency_responders').doc(bestResponder.id).update({
        isAvailable: false,
        currentRequestId: requestId,
        emergencyType: emergencyType,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Send CRITICAL priority FCM notification to responder
      const notificationPayload = _createEmergencyNotification(
        bestResponder.data.fcmToken,
        requestData,
        requestId,
        emergencyType,
        bestResponder.distance
      );

      try {
        const response = await admin.messaging().send(notificationPayload);
        console.log(`${emergencyType} emergency FCM notification sent successfully:`, response);
      } catch (error) {
        console.error(`Error sending ${emergencyType} emergency FCM notification:`, error);
      }

      // Set timeout based on emergency priority (shorter for critical)
      const timeoutMs = _getEmergencyTimeout(requestData.priority);
      setTimeout(async () => {
        await checkEmergencyResponderResponse(requestId, bestResponder.id, emergencyType);
      }, timeoutMs);

      console.log(`Successfully assigned ${emergencyType} responder ${bestResponder.id} to request ${requestId}`);
      return null;

    } catch (error) {
      console.error(`Error in assignResponderToEmergencyRequest for ${emergencyType}:`, error);
      
      await snap.ref.update({
        status: 'assignment_error',
        error: error.message,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return null;
    }
  });

/**
 * Get search radius based on emergency type and priority
 */
function _getEmergencySearchRadius(emergencyType, priority) {
  const baseRadius = {
    'ambulance': 15,      // Wider search for ambulances
    'fire_service': 20,   // Widest search for fire services
    'security_service': 8, // Smaller radius for security
    'towing_van': 25      // Large radius for towing
  };

  const radius = baseRadius[emergencyType] || 10;
  
  // Expand radius for critical emergencies
  if (priority === 'critical') {
    return Math.min(radius * 1.5, 50); // Cap at 50km
  }
  
  return radius;
}

/**
 * Check if responder has required capabilities for the emergency
 */
function _checkEmergencyCapability(responderData, requestData) {
  switch (requestData.emergencyType) {
    case 'ambulance':
      // Check medical certification level
      const requiredLevel = requestData.medicalLevel || 'basic';
      const responderLevel = responderData.medicalCertification || 'basic';
      return _isValidMedicalLevel(responderLevel, requiredLevel);
      
    case 'fire_service':
      // Check fire service capabilities
      const fireTypes = requestData.fireTypes || ['general'];
      const responderCapabilities = responderData.fireCapabilities || ['general'];
      return fireTypes.some(type => responderCapabilities.includes(type));
      
    case 'security_service':
      // Check security service level
      const securityLevel = requestData.securityLevel || 'standard';
      const responderSecurityLevel = responderData.securityLevel || 'standard';
      return _isValidSecurityLevel(responderSecurityLevel, securityLevel);
      
    case 'towing_van':
      // Check towing capacity
      const vehicleWeight = requestData.vehicleWeight || 2000; // kg
      const towingCapacity = responderData.towingCapacity || 3000; // kg
      return towingCapacity >= vehicleWeight;
      
    default:
      return true;
  }
}

/**
 * Validate medical certification level
 */
function _isValidMedicalLevel(responderLevel, requiredLevel) {
  const levels = ['basic', 'intermediate', 'advanced', 'critical_care'];
  const responderIndex = levels.indexOf(responderLevel);
  const requiredIndex = levels.indexOf(requiredLevel);
  return responderIndex >= requiredIndex;
}

/**
 * Validate security service level
 */
function _isValidSecurityLevel(responderLevel, requiredLevel) {
  const levels = ['standard', 'armed', 'vip', 'tactical'];
  const responderIndex = levels.indexOf(responderLevel);
  const requiredIndex = levels.indexOf(requiredLevel);
  return responderIndex >= requiredIndex;
}

/**
 * Calculate ETA for emergency response
 */
function _calculateEmergencyETA(distanceKm, emergencyType, priority) {
  const baseSpeed = {
    'ambulance': 60,      // km/h
    'fire_service': 50,   // km/h  
    'security_service': 45, // km/h
    'towing_van': 40      // km/h
  };

  const speed = baseSpeed[emergencyType] || 45;
  
  // Critical emergencies get priority routing
  const speedMultiplier = priority === 'critical' ? 1.3 : 1.0;
  const effectiveSpeed = speed * speedMultiplier;
  
  const travelTimeMinutes = Math.ceil((distanceKm / effectiveSpeed) * 60);
  const prepTimeMinutes = priority === 'critical' ? 2 : 5;
  const totalMinutes = travelTimeMinutes + prepTimeMinutes;
  
  const eta = new Date();
  eta.setMinutes(eta.getMinutes() + totalMinutes);
  return eta.toISOString();
}

/**
 * Get timeout duration based on priority
 */
function _getEmergencyTimeout(priority) {
  switch (priority) {
    case 'critical': return 30000; // 30 seconds
    case 'high': return 45000;     // 45 seconds  
    case 'medium': return 60000;   // 60 seconds
    case 'low': return 90000;      // 90 seconds
    default: return 60000;
  }
}

/**
 * Create emergency notification payload
 */
function _createEmergencyNotification(fcmToken, requestData, requestId, emergencyType, distance) {
  const emergencyEmojis = {
    'ambulance': '🚑',
    'fire_service': '🚒',
    'security_service': '🚔',
    'towing_van': '🚛'
  };

  const emergencyTitles = {
    'ambulance': 'MEDICAL EMERGENCY',
    'fire_service': 'FIRE EMERGENCY',
    'security_service': 'SECURITY EMERGENCY',
    'towing_van': 'TOWING REQUEST'
  };

  const emoji = emergencyEmojis[emergencyType] || '🚨';
  const title = emergencyTitles[emergencyType] || 'EMERGENCY REQUEST';
  const priority = requestData.priority?.toUpperCase() || 'MEDIUM';

  return {
    token: fcmToken,
    notification: {
      title: `${emoji} ${title}`,
      body: `${priority} PRIORITY • ${distance.toFixed(1)}km away`,
    },
    data: {
      type: 'emergency_request',
      emergencyType: emergencyType,
      requestId: requestId,
      priority: requestData.priority || 'medium',
      location: requestData.address || 'Location provided',
      description: requestData.description || '',
      distance: distance.toString(),
      contactName: requestData.contactName || 'Emergency Contact',
      contactPhone: requestData.contactPhone || '',
      specialInstructions: requestData.specialInstructions || ''
    },
    android: {
      priority: 'high',
      notification: {
        channelId: `${emergencyType}_requests`,
        priority: 'max',
        defaultSound: false,
        sound: `${emergencyType}_emergency_sound`,
        tag: `emergency_${requestId}`,
        sticky: true,
        localOnly: false,
        defaultVibrateTimings: false,
        vibrateTimingsMillis: [0, 200, 200, 200, 200, 200],
        visibility: 'public',
        importance: 'max',
        category: 'alarm'
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
            title: `${emoji} ${title}`,
            body: `${priority} PRIORITY • ${distance.toFixed(1)}km away`
          },
          sound: {
            critical: 1,
            name: `${emergencyType}_emergency_sound.wav`,
            volume: 1.0
          },
          badge: 1,
          'content-available': 1,
          category: 'EMERGENCY_REQUEST',
          'thread-id': emergencyType
        }
      }
    }
  };
}

/**
 * Attempt expanded search for critical emergencies
 */
async function _attemptExpandedEmergencySearch(requestId, emergencyType) {
  try {
    const requestDoc = await db.collection('emergency_requests').doc(requestId).get();
    
    if (!requestDoc.exists || requestDoc.data().status !== 'no_responders_available') {
      return;
    }

    console.log(`Attempting expanded search for critical ${emergencyType} request ${requestId}`);
    
    // Reset status to trigger function again with expanded search
    await requestDoc.ref.update({
      status: 'requesting',
      expandedSearch: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
  } catch (error) {
    console.error('Error in expanded emergency search:', error);
  }
}

/**
 * Check if emergency responder responded within timeout period
 */
async function checkEmergencyResponderResponse(requestId, responderId, emergencyType) {
  try {
    console.log(`Checking ${emergencyType} responder response for request ${requestId}`);
    
    const requestDoc = await db.collection('emergency_requests').doc(requestId).get();
    
    if (!requestDoc.exists) {
      console.log(`Emergency request ${requestId} no longer exists`);
      return;
    }

    const requestData = requestDoc.data();
    
    if (requestData.status === 'responder_assigned') {
      console.log(`${emergencyType} responder ${responderId} did not respond to request ${requestId}, reassigning...`);
      
      // Mark responder as available again
      await db.collection('emergency_responders').doc(responderId).update({
        isAvailable: true,
        currentRequestId: admin.firestore.FieldValue.delete(),
        emergencyType: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Reset request status to 'requesting' to trigger reassignment
      await db.collection('emergency_requests').doc(requestId).update({
        status: 'requesting',
        responderId: admin.firestore.FieldValue.delete(),
        assignedAt: admin.firestore.FieldValue.delete(),
        responderDistance: admin.firestore.FieldValue.delete(),
        estimatedArrival: admin.firestore.FieldValue.delete(),
        timeoutCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`Emergency request ${requestId} status reset to 'requesting' for reassignment`);
    } else {
      console.log(`Emergency request ${requestId} status is now ${requestData.status}, no timeout action needed`);
    }
    
  } catch (error) {
    console.error('Error checking emergency responder response:', error);
  }
}

/**
 * Handle emergency responder acceptance/decline actions
 */
exports.handleEmergencyResponderResponse = functions.firestore
  .document('emergency_requests/{requestId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const requestId = context.params.requestId;

    // Check if status changed to 'accepted'
    if (before.status === 'responder_assigned' && after.status === 'accepted') {
      console.log(`Emergency responder ${after.responderId} accepted request ${requestId}`);
      
      await db.collection('emergency_responders').doc(after.responderId).update({
        isAvailable: false,
        currentRequestId: requestId,
        onEmergency: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return null;
    }

    // Check if status changed to 'cancelled_by_responder'
    if (before.status === 'responder_assigned' && after.status === 'cancelled_by_responder') {
      console.log(`Emergency responder ${after.responderId} declined request ${requestId}`);
      
      // Mark responder as available again
      await db.collection('emergency_responders').doc(after.responderId).update({
        isAvailable: true,
        currentRequestId: admin.firestore.FieldValue.delete(),
        emergencyType: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Reset request status to 'requesting' to find another responder
      await change.after.ref.update({
        status: 'requesting',
        responderId: admin.firestore.FieldValue.delete(),
        assignedAt: admin.firestore.FieldValue.delete(),
        responderDistance: admin.firestore.FieldValue.delete(),
        estimatedArrival: admin.firestore.FieldValue.delete(),
        declineCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return null;
    }

    return null;
  });