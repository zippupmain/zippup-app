const functions = require('firebase-functions');
const admin = require('firebase-admin');
const Stripe = require('stripe');
const axios = require('axios');

admin.initializeApp();

// Stripe checkout (Callable)
exports.createStripeCheckout = functions.region('us-central1').https.onCall(async (data, context) => {
	const amount = data.amount;
	const currency = data.currency || 'NGN';
	const items = Array.isArray(data.items) ? data.items : [];
	const uid = context.auth && context.auth.uid;
	if (!amount || amount <= 0) throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
	const secret = (await admin.firestore().doc('_config/stripe').get()).get('secret') || process.env.STRIPE_SECRET || (functions.config().stripe && functions.config().stripe.secret);
	if (!secret) throw new functions.https.HttpsError('failed-precondition', 'Stripe secret not configured');
	const stripe = new Stripe(secret);
	const line_items = items.length > 0
		? items.map(it => ({
			price_data: {
				currency,
				product_data: { name: String(it.title || 'Item'), metadata: { itemId: String(it.id || ''), vendorId: String(it.vendorId || '') } },
				unit_amount: Math.round(Number(it.price || 0) * 100),
			},
			quantity: Number(it.quantity || 1),
		}))
		: [{ price_data: { currency, product_data: { name: 'ZippUp Order' }, unit_amount: Math.round(Number(amount) * 100) }, quantity: 1 }];
	const session = await stripe.checkout.sessions.create({
		mode: 'payment',
		payment_method_types: ['card'],
		line_items,
		success_url: 'https://zippup.app/success',
		cancel_url: 'https://zippup.app/cancel',
		metadata: { uid: String(uid || ''), vendorId: String((items[0] && items[0].vendorId) || '') },
	});
	return { checkoutUrl: session.url };
});

// Flutterwave checkout (Callable)
exports.createFlutterwaveCheckout = functions.region('us-central1').https.onCall(async (data, context) => {
	const amount = data.amount;
	const currency = data.currency || 'NGN';
	const items = Array.isArray(data.items) ? data.items : [];
	const uid = context.auth && context.auth.uid;
	if (!amount || amount <= 0) throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
	const secret = (await admin.firestore().doc('_config/flutterwave').get()).get('secret') || process.env.FLW_SECRET || (functions.config().flutterwave && functions.config().flutterwave.secret);
	if (!secret) throw new functions.https.HttpsError('failed-precondition', 'Flutterwave secret not configured');
	const payload = {
		amount,
		currency,
		tx_ref: `zippup_${Date.now()}`,
		redirect_url: 'https://zippup.app/payment-callback',
		customer: { email: 'customer@example.com' },
		meta: { uid: String(uid || ''), vendorId: String((items[0] && items[0].vendorId) || '') },
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

function statusTitle(entity, status) {
	switch (status) {
		case 'accepted': return `${entity} accepted`;
		case 'arriving': return `${entity} arriving`;
		case 'arrived': return `${entity} arrived`;
		case 'enroute': return `${entity} en route`;
		case 'preparing': return `Order preparing`;
		case 'dispatched': return `Order dispatched`;
		case 'assigned': return `Courier assigned`;
		case 'delivered': return `Order delivered`;
		case 'completed': return `${entity} completed`;
		case 'cancelled': return `${entity} cancelled`;
		default: return `${entity} update`;
	}
}

exports.onOrderStatusChange = functions.firestore.document('orders/{orderId}').onUpdate(async (change, context) => {
	const before = change.before.data();
	const after = change.after.data();
	if (before.status === after.status) return null;
	const title = statusTitle('Order', after.status);
	const body = `Status: ${after.status}`;
	await notifyParties([after.buyerId, after.providerId], { title, body }, { type: 'order', orderId: context.params.orderId, status: after.status });
	return null;
});

exports.onRideStatusChange = functions.firestore.document('rides/{rideId}').onUpdate(async (change, context) => {
	const before = change.before.data();
	const after = change.after.data();
	if (before.status === after.status) return null;
	const title = statusTitle('Ride', after.status);
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

exports.distanceMatrix = functions.region('us-central1').https.onCall(async (data, context) => {
	const origin = data.origin; // "lat,lng"
	const destinations = data.destinations; // ["lat,lng", ...]
	if (!origin || !destinations || destinations.length === 0) throw new functions.https.HttpsError('invalid-argument', 'Missing origin/destinations');
	const key = 'AIzaSyAk22rv_OsFJVXUA-GK0PMdEVqBJcNYozI';
	const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${encodeURIComponent(origin)}&destinations=${encodeURIComponent(destinations.join('|'))}&key=${key}`;
	const res = await axios.get(url);
	return res.data;
});

exports.directions = functions.region('us-central1').https.onCall(async (data, context) => {
	const origin = data.origin; // "lat,lng"
	const destination = data.destination; // "lat,lng"
	if (!origin || !destination) throw new functions.https.HttpsError('invalid-argument', 'Missing origin/destination');
	const key = 'AIzaSyAk22rv_OsFJVXUA-GK0PMdEVqBJcNYozI';
	const url = `https://maps.googleapis.com/maps/api/directions/json?origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}&key=${key}`;
	const res = await axios.get(url);
	const route = res.data.routes && res.data.routes[0];
	return { polyline: route && route.overview_polyline && route.overview_polyline.points };
});

exports.placesAutocomplete = functions.region('us-central1').https.onCall(async (data, context) => {
	const input = (data && data.input) || '';
	const sessiontoken = data && data.sessiontoken;
	if (!input || input.length < 3) return { predictions: [] };
	const key = (await admin.firestore().doc('_config/maps').get()).get('key') || process.env.MAPS_KEY || (functions.config().maps && functions.config().maps.key);
	if (!key) throw new functions.https.HttpsError('failed-precondition', 'Maps key not configured');
	let url = `https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${encodeURIComponent(input)}&types=geocode&key=${key}`;
	if (sessiontoken) url += `&sessiontoken=${encodeURIComponent(sessiontoken)}`;
	const res = await axios.get(url);
	const preds = (res.data && res.data.predictions) || [];
	return { predictions: preds.map(p => ({ description: p.description, place_id: p.place_id })) };
});

exports.sendPanicAlert = functions.region('us-central1').https.onCall(async (data, context) => {
	const uid = context.auth && context.auth.uid;
	if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
	const { lat, lng } = data || {};
	// Fetch user emergency contacts (array of phone numbers) and country code
	const userDoc = await admin.firestore().collection('users').doc(uid).get();
	const contacts = userDoc.get('emergencyContacts') || [];
	const country = userDoc.get('country') || 'NG';
	// Admin-configured default emergency line per country stored at _config/emergency/{country}
	const adminLineDoc = await admin.firestore().collection('_config').doc('emergency').get();
	const adminLines = adminLineDoc.exists ? adminLineDoc.data() : {};
	const defaultLine = adminLines && adminLines[country];
	const links = [];
	if (lat && lng) links.push(`https://maps.google.com/?q=${lat},${lng}`);
	const body = `EMERGENCY ALERT! User ${uid} needs help.${links.length ? ` Location: ${links.join(' ')}` : ''}`;
	// Here we demo by writing a notification record; in production integrate with SMS provider
	await admin.firestore().collection('panic_alerts').add({
		uid,
		contacts: contacts.slice(0, 5),
		defaultLine: defaultLine || null,
		message: body,
		createdAt: admin.firestore.FieldValue.serverTimestamp(),
	});
	return { ok: true };
});

exports.geocode = functions.region('us-central1').https.onCall(async (data, context) => {
	const { lat, lng } = data || {};
	if (typeof lat !== 'number' || typeof lng !== 'number') throw new functions.https.HttpsError('invalid-argument', 'lat,lng required');
	const key = 'AIzaSyAk22rv_OsFJVXUA-GK0PMdEVqBJcNYozI';
	const url = `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${key}`;
	const res = await axios.get(url);
	const results = res.data && res.data.results || [];
	const formatted = results[0] && results[0].formatted_address;
	let country = null, countryCode = null;
	if (results[0] && Array.isArray(results[0].address_components)) {
		for (const comp of results[0].address_components) {
			if (comp.types && comp.types.includes('country')) {
				country = comp.long_name;
				countryCode = comp.short_name;
				break;
			}
		}
	}
	return { address: formatted || null, country, countryCode };
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