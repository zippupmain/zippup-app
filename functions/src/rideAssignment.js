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
 * Cloud Function triggered when a new ride document is created with status 'requesting'
 * Finds the closest available driver and assigns them to the ride
 */
exports.assignDriverToRide = functions.firestore
  .document('rides/{rideId}')
  .onCreate(async (snap, context) => {
    const rideData = snap.data();
    const rideId = context.params.rideId;

    // Only process if status is 'requesting'
    if (rideData.status !== 'requesting') {
      console.log(`Ride ${rideId} status is ${rideData.status}, not processing`);
      return null;
    }

    console.log(`Processing ride request ${rideId} for vehicle class ${rideData.vehicleClass}`);

    try {
      // Get ride location for proximity search
      const rideLocation = rideData.pickupLocation;
      if (!rideLocation || !rideLocation.latitude || !rideLocation.longitude) {
        console.error('Ride location is missing or invalid');
        return null;
      }

      // Query available drivers within 5km radius
      const driversRef = geofirestore.collection('drivers');
      const center = new admin.firestore.GeoPoint(rideLocation.latitude, rideLocation.longitude);
      const radiusInKm = 5;

      // Create geo query for drivers within radius
      const geoQuery = driversRef.near({
        center: center,
        radius: radiusInKm
      });

      const nearbyDrivers = await geoQuery.get();
      console.log(`Found ${nearbyDrivers.docs.length} drivers within ${radiusInKm}km`);

      // Filter drivers based on availability and vehicle class
      const availableDrivers = [];
      
      for (const driverDoc of nearbyDrivers.docs) {
        const driverData = driverDoc.data();
        const driverId = driverDoc.id;

        // Check driver availability criteria
        const isEligible = 
          driverData.isOnline === true &&
          driverData.isAvailable === true &&
          driverData.serviceType === 'transport' &&
          driverData.vehicleInfo?.class === rideData.vehicleClass &&
          driverData.fcmToken; // Must have FCM token for notifications

        if (isEligible) {
          availableDrivers.push({
            id: driverId,
            data: driverData,
            distance: driverDoc.distance // Distance from GeoFirestore query
          });
        }
      }

      console.log(`Found ${availableDrivers.length} available drivers matching criteria`);

      if (availableDrivers.length === 0) {
        console.log('No available drivers found');
        // Optionally update ride status to indicate no drivers available
        await snap.ref.update({
          status: 'no_drivers_available',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return null;
      }

      // Sort by distance and pick the closest driver
      availableDrivers.sort((a, b) => a.distance - b.distance);
      const closestDriver = availableDrivers[0];

      console.log(`Assigning closest driver: ${closestDriver.id} (${closestDriver.distance}km away)`);

      // Update ride document with assigned driver
      await snap.ref.update({
        driverId: closestDriver.id,
        status: 'driver_assigned',
        assignedAt: admin.firestore.FieldValue.serverTimestamp(),
        driverDistance: closestDriver.distance
      });

      // Mark driver as temporarily unavailable
      await db.collection('drivers').doc(closestDriver.id).update({
        isAvailable: false,
        currentRideId: rideId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });

      // Send high-priority FCM notification to driver
      const notificationPayload = {
        token: closestDriver.data.fcmToken,
        notification: {
          title: '🚗 New Ride Request!',
          body: `Pickup: ${rideData.pickupAddress || 'Location provided'}`,
        },
        data: {
          type: 'ride_request',
          rideId: rideId,
          pickupAddress: rideData.pickupAddress || '',
          destinationAddress: rideData.destinationAddress || '',
          estimatedFare: rideData.estimatedFare?.toString() || '0',
          distance: closestDriver.distance.toString(),
          passengerName: rideData.passengerName || 'Passenger'
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'ride_requests',
            priority: 'high',
            defaultSound: false,
            sound: 'ride_request_sound',
            tag: `ride_${rideId}`,
            sticky: true,
            localOnly: false,
            defaultVibrateTimings: false,
            vibrateTimingsMillis: [0, 250, 250, 250],
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
                title: '🚗 New Ride Request!',
                body: `Pickup: ${rideData.pickupAddress || 'Location provided'}`
              },
              sound: 'ride_request_sound.wav',
              badge: 1,
              'content-available': 1,
              category: 'RIDE_REQUEST'
            }
          }
        }
      };

      try {
        const response = await admin.messaging().send(notificationPayload);
        console.log('FCM notification sent successfully:', response);
      } catch (error) {
        console.error('Error sending FCM notification:', error);
      }

      // Set 60-second timeout to check if driver accepts
      setTimeout(async () => {
        await checkDriverResponse(rideId, closestDriver.id);
      }, 60000);

      console.log(`Successfully assigned driver ${closestDriver.id} to ride ${rideId}`);
      return null;

    } catch (error) {
      console.error('Error in assignDriverToRide:', error);
      
      // Update ride status to error state
      await snap.ref.update({
        status: 'assignment_error',
        error: error.message,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return null;
    }
  });

/**
 * Check if driver responded to ride request within timeout period
 */
async function checkDriverResponse(rideId, driverId) {
  try {
    console.log(`Checking driver response for ride ${rideId} after 60 seconds`);
    
    const rideDoc = await db.collection('rides').doc(rideId).get();
    
    if (!rideDoc.exists) {
      console.log(`Ride ${rideId} no longer exists`);
      return;
    }

    const rideData = rideDoc.data();
    
    // If status is still 'driver_assigned', driver didn't respond in time
    if (rideData.status === 'driver_assigned') {
      console.log(`Driver ${driverId} did not respond to ride ${rideId}, reassigning...`);
      
      // Mark driver as available again
      await db.collection('drivers').doc(driverId).update({
        isAvailable: true,
        currentRideId: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Reset ride status to 'requesting' to trigger reassignment
      await db.collection('rides').doc(rideId).update({
        status: 'requesting',
        driverId: admin.firestore.FieldValue.delete(),
        assignedAt: admin.firestore.FieldValue.delete(),
        driverDistance: admin.firestore.FieldValue.delete(),
        timeoutCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`Ride ${rideId} status reset to 'requesting' for reassignment`);
    } else {
      console.log(`Ride ${rideId} status is now ${rideData.status}, no timeout action needed`);
    }
    
  } catch (error) {
    console.error('Error checking driver response:', error);
  }
}

/**
 * Handle driver acceptance/decline actions
 */
exports.handleDriverResponse = functions.firestore
  .document('rides/{rideId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const rideId = context.params.rideId;

    // Check if status changed to 'accepted'
    if (before.status === 'driver_assigned' && after.status === 'accepted') {
      console.log(`Driver ${after.driverId} accepted ride ${rideId}`);
      
      // Keep driver marked as unavailable since they're now on a ride
      await db.collection('drivers').doc(after.driverId).update({
        isAvailable: false,
        currentRideId: rideId,
        onRide: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return null;
    }

    // Check if status changed to 'cancelled_by_driver'
    if (before.status === 'driver_assigned' && after.status === 'cancelled_by_driver') {
      console.log(`Driver ${after.driverId} declined ride ${rideId}`);
      
      // Mark driver as available again
      await db.collection('drivers').doc(after.driverId).update({
        isAvailable: true,
        currentRideId: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      // Reset ride status to 'requesting' to find another driver
      await change.after.ref.update({
        status: 'requesting',
        driverId: admin.firestore.FieldValue.delete(),
        assignedAt: admin.firestore.FieldValue.delete(),
        driverDistance: admin.firestore.FieldValue.delete(),
        declineCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      return null;
    }

    return null;
  });