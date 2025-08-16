const functions = require('firebase-functions');
const admin = require('firebase-admin');
const Stripe = require('stripe');
const axios = require('axios');

admin.initializeApp();

// Stripe checkout (Callable)
exports.createStripeCheckout = functions.https.onCall(async (data, context) => {
	const amount = data.amount; // in minor units
	const currency = data.currency || 'NGN';
	if (!amount || amount <= 0) throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
	const secret = (await admin.firestore().doc('_config/stripe').get()).get('secret') || process.env.STRIPE_SECRET || (functions.config().stripe && functions.config().stripe.secret);
	if (!secret) throw new functions.https.HttpsError('failed-precondition', 'Stripe secret not configured');
	const stripe = new Stripe(secret);
	const session = await stripe.checkout.sessions.create({
		mode: 'payment',
		payment_method_types: ['card'],
		line_items: [{ price_data: { currency, product_data: { name: 'ZippUp Order' }, unit_amount: amount }, quantity: 1 }],
		success_url: 'https://zippup.app/success',
		cancel_url: 'https://zippup.app/cancel',
	});
	return { checkoutUrl: session.url };
});

// Flutterwave checkout (Callable)
exports.createFlutterwaveCheckout = functions.https.onCall(async (data, context) => {
	const amount = data.amount;
	const currency = data.currency || 'NGN';
	if (!amount || amount <= 0) throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
	const secret = (await admin.firestore().doc('_config/flutterwave').get()).get('secret') || process.env.FLW_SECRET || (functions.config().flutterwave && functions.config().flutterwave.secret);
	if (!secret) throw new functions.https.HttpsError('failed-precondition', 'Flutterwave secret not configured');
	const payload = {
		amount,
		currency,
		tx_ref: `zippup_${Date.now()}`,
		redirect_url: 'https://zippup.app/payment-callback',
		customer: { email: 'customer@example.com' },
	};
	const res = await axios.post('https://api.flutterwave.com/v3/payments', payload, { headers: { Authorization: `Bearer ${secret}` } });
	return { checkoutUrl: res.data && res.data.data && res.data.data.link };
});

// Scheduled reminders (Pub/Sub schedule triggers)
exports.scheduledReminders = functions.pubsub.schedule('every 5 minutes').onRun(async (context) => {
	const now = admin.firestore.Timestamp.now();
	const in5 = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 5 * 60 * 1000));
	const in30 = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 30 * 60 * 1000));
	const in60 = admin.firestore.Timestamp.fromDate(new Date(Date.now() + 60 * 60 * 1000));
	const ridesSnap = await admin.firestore().collection('rides').where('status', '==', 'scheduled').get();
	for (const doc of ridesSnap.docs) {
		const d = doc.data();
		const t = d.scheduledAt && new Date(d.scheduledAt);
		if (!t) continue;
		const diffMin = Math.floor((t.getTime() - Date.now()) / 60000);
		if ([60, 30, 5].includes(diffMin)) {
			await notifyUsersFor(doc.id, diffMin);
		}
	}
	return null;
});

exports.onOrderStatusChange = functions.firestore.document('orders/{orderId}').onUpdate(async (change, context) => {
	const before = change.before.data();
	const after = change.after.data();
	if (before.status === after.status) return null;
	const title = 'Order update';
	const body = `Status: ${after.status}`;
	await notifyParties([after.buyerId, after.providerId], { title, body }, { type: 'order', orderId: context.params.orderId, status: after.status });
	return null;
});

exports.onRideStatusChange = functions.firestore.document('rides/{rideId}').onUpdate(async (change, context) => {
	const before = change.before.data();
	const after = change.after.data();
	if (before.status === after.status) return null;
	const title = 'Ride update';
	const body = `Status: ${after.status}`;
	await notifyParties([after.riderId, after.driverId], { title, body }, { type: 'ride', rideId: context.params.rideId, status: after.status });
	return null;
});

exports.onOrderCreate = functions.firestore.document('orders/{orderId}').onCreate(async (snap, context) => {
	const data = snap.data();
	if (['food', 'groceries'].includes(data.category)) {
		const code = Math.floor(100000 + Math.random() * 900000).toString();
		await snap.ref.update({ deliveryCode: code });
	}
	return null;
});

exports.onOrderDeliveredValidate = functions.firestore.document('orders/{orderId}').onUpdate(async (change, context) => {
	const before = change.before.data();
	const after = change.after.data();
	if (before.status !== 'arrived' && after.status === 'delivered') {
		// Require deliveryCode match
		if (!after.deliveryCodeEntered || after.deliveryCodeEntered !== after.deliveryCode) {
			throw new functions.https.HttpsError('failed-precondition', 'Delivery code invalid');
		}
	}
	return null;
});

exports.distanceMatrix = functions.https.onCall(async (data, context) => {
	const origin = data.origin; // "lat,lng"
	const destinations = data.destinations; // ["lat,lng", ...]
	if (!origin || !destinations || destinations.length === 0) throw new functions.https.HttpsError('invalid-argument', 'Missing origin/destinations');
	const key = (await admin.firestore().doc('_config/maps').get()).get('key') || process.env.MAPS_KEY || (functions.config().maps && functions.config().maps.key);
	if (!key) throw new functions.https.HttpsError('failed-precondition', 'Maps key not configured');
	const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${encodeURIComponent(origin)}&destinations=${encodeURIComponent(destinations.join('|'))}&key=${key}`;
	const res = await axios.get(url);
	return res.data;
});

exports.directions = functions.https.onCall(async (data, context) => {
	const origin = data.origin; // "lat,lng"
	const destination = data.destination; // "lat,lng"
	if (!origin || !destination) throw new functions.https.HttpsError('invalid-argument', 'Missing origin/destination');
	const key = (await admin.firestore().doc('_config/maps').get()).get('key') || process.env.MAPS_KEY || (functions.config().maps && functions.config().maps.key);
	if (!key) throw new functions.https.HttpsError('failed-precondition', 'Maps key not configured');
	const url = `https://maps.googleapis.com/maps/api/directions/json?origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}&key=${key}`;
	const res = await axios.get(url);
	const route = res.data.routes && res.data.routes[0];
	return { polyline: route && route.overview_polyline && route.overview_polyline.points };
});

async function notifyUsersFor(threadId, minutesLeft) {
	const tokens = []; // TODO: collect rider/driver device tokens from users collection
	const payload = {
		notification: {
			title: 'ZippUp Reminder',
			body: `Your scheduled booking is in ${minutesLeft} minutes`,
			sound: 'default'
		},
		data: { threadId: `${threadId}`, type: 'schedule_reminder', minutes: `${minutesLeft}` }
	};
	if (tokens.length > 0) await admin.messaging().sendToDevice(tokens, payload);
}

async function notifyParties(userIds, notif, data) {
	const tokens = [];
	for (const uid of userIds.filter(Boolean)) {
		const doc = await admin.firestore().collection('users').doc(uid).get();
		const token = doc.get('fcmToken');
		if (token) tokens.push(token);
	}
	if (tokens.length === 0) return;
	const payload = { notification: { title: notif.title, body: notif.body, sound: 'default' }, data: Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)])) };
	await admin.messaging().sendToDevice(tokens, payload);
}