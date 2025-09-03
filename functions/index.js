const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const { MatchingEngine } = require('./dispatch/matchingEngine');
const matchingEngine = new MatchingEngine();

exports.dispatchOrder = functions.firestore
  .document('{collection}/{orderId}')
  .onCreate(async (snapshot, context) => {
    const { collection, orderId } = context.params;
    const orderData = snapshot.data();

    const dispatchableCollections = ['rides', 'emergency_bookings', 'moving_bookings', 'hire_bookings'];
    if (!dispatchableCollections.includes(collection)) return null;

    if (!orderData.service || !orderData.serviceClass || orderData.status !== 'pending') {
      return null;
    }

    console.log(`🆕 Dispatching: ${collection}/${orderId}`);

    try {
      const customerLocation = orderData.customerLocation || orderData.pickupLocation;
      
      const success = await matchingEngine.dispatchRequest({
        orderId,
        service: orderData.service,
        serviceClass: orderData.serviceClass,
        customerLat: customerLocation.latitude,
        customerLng: customerLocation.longitude,
        customerId: orderData.customerId,
        additionalData: orderData
      });

      console.log(`${success ? '✅' : '❌'} Dispatch result for ${orderId}: ${success}`);

    } catch (error) {
      console.error(`❌ Dispatch error for ${orderId}:`, error);
    }

    return null;
  });

exports.handleProviderResponse = functions.firestore
  .document('provider_responses/{responseId}')
  .onCreate(async (snapshot, context) => {
    const response = snapshot.data();
    const { orderId, providerId, action } = response;

    if (action === 'accept') {
      await matchingEngine.handleProviderAcceptance(orderId, providerId);
    } else if (action === 'decline') {
      await matchingEngine.handleProviderDecline(orderId, providerId);
    }

    await snapshot.ref.delete();
    return null;
  });