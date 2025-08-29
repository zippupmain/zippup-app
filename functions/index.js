const functions = require('firebase-functions');
const admin = require('firebase-admin');
const Stripe = require('stripe');
const axios = require('axios');

admin.initializeApp();
async function getMapsKey() {
  try {
    const snap = await admin.firestore().doc('_config/maps').get();
    const k = snap.get('key');
    if (k) return k;
  } catch {}
  const env = process.env.MAPS_KEY || (functions.config().maps && functions.config().maps.key);
  if (!env) throw new functions.https.HttpsError('failed-precondition', 'Maps key not configured');
  return env;
}

async function getStripeSecretKey() {
  const doc = await admin.firestore().doc('_config/stripe').get();
  return doc.get('secret') || process.env.STRIPE_SECRET || (functions.config().stripe && functions.config().stripe.secret);
}

async function getStripeEndpointSecret() {
  const doc = await admin.firestore().doc('_config/stripe').get();
  return doc.get('endpoint_secret') || process.env.STRIPE_ENDPOINT_SECRET || (functions.config().stripe && functions.config().stripe.endpoint_secret);
}

async function getFlutterwaveSecretKey() {
  const doc = await admin.firestore().doc('_config/flutterwave').get();
  return doc.get('secret') || process.env.FLW_SECRET || (functions.config().flutterwave && functions.config().flutterwave.secret);
}

async function getFlutterwaveWebhookSecret() {
  const doc = await admin.firestore().doc('_config/flutterwave').get();
  return doc.get('webhook_secret') || process.env.FLW_WEBHOOK_SECRET || (functions.config().flutterwave && functions.config().flutterwave.webhook_secret);
}

function removeUndefined(obj) {
  return Object.fromEntries(Object.entries(obj || {}).filter(([, v]) => v !== undefined && v !== null));
}


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

// Auto-timeout/cleanup for orders and rides
exports.timeoutJobs = functions.pubsub.schedule('every 1 minutes').onRun(async () => {
  const now = Date.now();
  // Handle ride acceptance timeout (70s): mark timeout and clear driver to allow fan-out
  const rides = await admin.firestore().collection('rides').where('status', '==', 'requested').get();
  for (const d of rides.docs) {
    const createdAt = new Date(d.get('createdAt') || now).getTime();
    if (now - createdAt > 70 * 1000) {
      // mark timeout and clear any stale driver
      await d.ref.set({ timeout: true, driverId: null }, { merge: true });
      // Fan-out to next available driver not yet attempted
      const attempted = Array.isArray(d.get('attemptedDrivers')) ? d.get('attemptedDrivers') : [];
      if (attempted.length >= 5) {
        // Give up after 5 attempts
        await d.ref.set({ status: 'cancelled', cancelReason: 'no_driver_found', cancelledAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        continue;
      }
      const providersSnap = await admin.firestore().collection('provider_profiles')
        .where('service', '==', 'transport')
        .where('status', '==', 'active')
        .where('availabilityOnline', '==', true)
        .limit(50)
        .get();
      const pickup = d.get('pickup') || d.get('pickupLocation');
      const plat = pickup && (pickup.lat || pickup.latitude);
      const plng = pickup && (pickup.lng || pickup.longitude);
      const candidates = providersSnap.docs
        .map(p => ({ id: p.id, userId: p.get('userId'), lat: p.get('lat'), lng: p.get('lng') }))
        .filter(p => p.userId && !attempted.includes(p.userId))
        .map(p => ({ ...p, dist: (plat && plng && p.lat && p.lng) ? haversineKm(Number(plat), Number(plng), Number(p.lat), Number(p.lng)) : 99999 }))
        .sort((a,b) => a.dist - b.dist);
      if (candidates.length === 0) {
        // No candidates online
        await d.ref.set({ noDriverOnline: true }, { merge: true });
        continue;
      }
      // Pick first candidate (could randomize or sort by distance if available)
      const next = candidates[0];
      await d.ref.set({ driverId: next.userId, timeout: false, attemptedDrivers: admin.firestore.FieldValue.arrayUnion(next.userId) }, { merge: true });
      // Optional: push a notification record for the driver
      await admin.firestore().collection('notifications').add({
        userId: next.userId,
        title: 'New ride request',
        body: 'You have a new ride to accept',
        type: 'ride',
        rideId: d.id,
        read: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }
  // Scheduled orders timeout logic (24h or 7h if within 24h)
  const orders = await admin.firestore().collection('orders').where('status', '==', 'scheduled').get();
  for (const d of orders.docs) {
    const scheduledAtStr = d.get('scheduledAt');
    if (!scheduledAtStr) continue;
    const scheduledAt = new Date(scheduledAtStr).getTime();
    const hoursToGo = (scheduledAt - now) / (1000 * 60 * 60);
    const createdAt = new Date(d.get('createdAt') || now).getTime();
    const elapsedHours = (now - createdAt) / (1000 * 60 * 60);
    const limit = hoursToGo <= 24 ? 7 : 24;
    if (elapsedHours > limit) {
      await d.ref.set({ status: 'cancelled', cancelReason: 'timeout' }, { merge: true });
    }
    if (now > scheduledAt && (d.get('status') || 'scheduled') === 'scheduled') {
      await d.ref.set({ status: 'cancelled', cancelReason: 'schedule elapsed' }, { merge: true });
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
	const key = await getMapsKey();
	const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${encodeURIComponent(origin)}&destinations=${encodeURIComponent(destinations.join('|'))}&key=${key}`;
	const res = await axios.get(url);
	return res.data;
});

exports.directions = functions.region('us-central1').https.onCall(async (data, context) => {
	const origin = data.origin; // "lat,lng"
	const destination = data.destination; // "lat,lng"
	if (!origin || !destination) throw new functions.https.HttpsError('invalid-argument', 'Missing origin/destination');
	const key = await getMapsKey();
	const url = `https://maps.googleapis.com/maps/api/directions/json?origin=${encodeURIComponent(origin)}&destination=${encodeURIComponent(destination)}&key=${key}`;
	const res = await axios.get(url);
	const route = res.data.routes && res.data.routes[0];
	return { polyline: route && route.overview_polyline && route.overview_polyline.points };
});

exports.placesAutocomplete = functions.region('us-central1').https.onCall(async (data, context) => {
	const input = (data && data.input) || '';
	const sessiontoken = data && data.sessiontoken;
	if (!input || input.length < 3) return { predictions: [] };
	const key = await getMapsKey();
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
	const key = await getMapsKey();
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

function haversineKm(lat1, lon1, lat2, lon2) {
  function toRad(d) { return d * Math.PI / 180; }
  const R = 6371; // km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

// Simple geohash encoder (base32) for proximity indexing
const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
function encodeGeohash(lat, lon, precision = 7) {
  let idx = 0, bit = 0, evenBit = true;
  let latMin = -90, latMax = 90;
  let lonMin = -180, lonMax = 180;
  let geohash = '';
  while (geohash.length < precision) {
    if (evenBit) {
      const lonMid = (lonMin + lonMax) / 2;
      if (lon >= lonMid) { idx = idx * 2 + 1; lonMin = lonMid; }
      else { idx = idx * 2; lonMax = lonMid; }
    } else {
      const latMid = (latMin + latMax) / 2;
      if (lat >= latMid) { idx = idx * 2 + 1; latMin = latMid; }
      else { idx = idx * 2; latMax = latMid; }
    }
    evenBit = !evenBit;
    if (++bit == 5) { geohash += _base32.charAt(idx); bit = 0; idx = 0; }
  }
  return geohash;
}

// Propagate users/{uid}.lastLat,lastLng to provider_profiles for proximity fan-out
exports.onUserLocationUpdate = functions.firestore.document('users/{uid}').onUpdate(async (change, context) => {
  const before = change.before.data() || {};
  const after = change.after.data() || {};
  const latB = (before.lastLat != null) ? Number(before.lastLat) : null;
  const lngB = (before.lastLng != null) ? Number(before.lastLng) : null;
  const latA = (after.lastLat != null) ? Number(after.lastLat) : null;
  const lngA = (after.lastLng != null) ? Number(after.lastLng) : null;
  if (latA == null || lngA == null) return null;
  if (latB === latA && lngB === lngA) return null;
  const uid = context.params.uid;
  const snap = await admin.firestore().collection('provider_profiles').where('userId', '==', uid).get();
  const batch = admin.firestore().batch();
  for (const doc of snap.docs) {
    const geohash = encodeGeohash(latA, lngA, 7);
    batch.set(doc.ref, { lat: latA, lng: lngA, geohash, locationUpdatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
  }
  if (!snap.empty) await batch.commit();
  return null;
});

// Role & Provider functions
exports.switchActiveRole = functions.region('us-central1').https.onCall(async (data, context) => {
	const uid = context.auth && context.auth.uid;
	if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
	const role = (data && data.role) || 'customer';
	// Validate: if provider role, user must have a profile with status active
	if (role.startsWith('provider:')) {
		const service = role.split(':')[1];
		const prof = await admin.firestore().collection('provider_profiles').where('userId', '==', uid).where('service', '==', service).where('status', '==', 'active').limit(1).get();
		if (prof.empty) throw new functions.https.HttpsError('failed-precondition', 'Provider profile not active');
	}
	await admin.firestore().collection('users').doc(uid).set({ activeRole: role }, { merge: true });
	return { ok: true, activeRole: role };
});

exports.toggleAvailability = functions.region('us-central1').https.onCall(async (data, context) => {
	const uid = context.auth && context.auth.uid;
	if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
	const { service, online } = data || {};
	if (!service || typeof online !== 'boolean') throw new functions.https.HttpsError('invalid-argument', 'service, online required');
	const q = await admin.firestore().collection('provider_profiles').where('userId', '==', uid).where('service', '==', service).limit(1).get();
	if (q.empty) throw new functions.https.HttpsError('not-found', 'Profile not found');
	await q.docs[0].ref.set({ availabilityOnline: online }, { merge: true });
	return { ok: true };
});

exports.acceptOrder = functions.region('us-central1').https.onCall(async (data, context) => {
	const uid = context.auth && context.auth.uid;
	if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
	const { orderId } = data || {};
	if (!orderId) throw new functions.https.HttpsError('invalid-argument', 'orderId required');
	await admin.firestore().runTransaction(async (t) => {
		const ref = admin.firestore().collection('orders').doc(orderId);
		const snap = await t.get(ref);
		if (!snap.exists) throw new functions.https.HttpsError('not-found', 'Order not found');
		const d = snap.data() || {};
		if (d.providerId) throw new functions.https.HttpsError('failed-precondition', 'Already assigned');
		t.set(ref, { providerId: uid, status: 'accepted', acceptedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
	});
	return { ok: true };
});

exports.declineOrder = functions.region('us-central1').https.onCall(async (data, context) => {
	const uid = context.auth && context.auth.uid;
	if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
	const { orderId } = data || {};
	if (!orderId) throw new functions.https.HttpsError('invalid-argument', 'orderId required');
	await admin.firestore().collection('orders').doc(orderId).collection('offers').doc(uid).set({ status: 'declined', updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
	return { ok: true };
});

// Wallet: Create Topup Checkout (Stripe/Flutterwave) - Scaffold
exports.walletCreateTopup = functions.region('us-central1').https.onCall(async (data, context) => {
	const uid = context.auth && context.auth.uid;
	if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
	const amount = Number(data && data.amount);
	const currency = (data && data.currency) || 'NGN';
	if (!amount || amount <= 0) throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
	// Record intent
	const topupRef = await admin.firestore().collection('wallets').doc(uid).collection('tx').add({
		type: 'topup',
		amount,
		currency,
		status: 'initiated',
		ref: null,
		createdAt: admin.firestore.FieldValue.serverTimestamp(),
	});
	// Choose provider
	// Try Stripe for USD/EUR/GBP; otherwise Flutterwave
	let checkoutUrl = null;
	try {
		if (['USD','EUR','GBP'].includes(currency)) {
			const secret = await getStripeSecretKey();
			if (!secret) throw new Error('Stripe not configured');
			const stripe = new Stripe(secret);
			const session = await stripe.checkout.sessions.create({
				mode: 'payment',
				line_items: [{ price_data: { currency, product_data: { name: 'Wallet Top-up' }, unit_amount: Math.round(amount * 100) }, quantity: 1 }],
				success_url: 'https://zippup.app/wallet?status=success',
				cancel_url: 'https://zippup.app/wallet?status=cancel',
				metadata: { uid, txId: topupRef.id, type: 'wallet_topup' },
			});
			checkoutUrl = session.url;
		} else {
			const secret = await getFlutterwaveSecretKey();
			if (!secret) throw new Error('Flutterwave not configured');
			const payload = { amount, currency, tx_ref: `wallet_${uid}_${Date.now()}`, redirect_url: 'https://zippup.app/wallet-callback', customer: { email: 'customer@example.com' }, meta: { uid, txId: topupRef.id, type: 'wallet_topup' } };
			const res = await axios.post('https://api.flutterwave.com/v3/payments', payload, { headers: { Authorization: `Bearer ${secret}` } });
			checkoutUrl = res.data && res.data.data && res.data.data.link;
		}
	} catch (e) {
		console.error('Topup error', e && (e.response && e.response.data || e));
	}
	await topupRef.set({ checkoutUrl: checkoutUrl || null }, { merge: true });
	return { checkoutUrl, txId: topupRef.id };
});

// Wallet: Peer-to-peer send - Scaffold
exports.walletSend = functions.region('us-central1').https.onCall(async (data, context) => {
	const uid = context.auth && context.auth.uid;
	if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
	const to = (data && data.to) || '';
	const amount = Number(data && data.amount);
	if (!to || !amount || amount <= 0) throw new functions.https.HttpsError('invalid-argument', 'Invalid params');
	// Resolve recipient UID (accept uid or phone)
	let toUid = to;
	if (toUid.length < 20) {
		const q = await admin.firestore().collection('users').where('phone', '==', to).limit(1).get();
		if (!q.empty) toUid = q.docs[0].id;
	}
	if (toUid === uid) throw new functions.https.HttpsError('failed-precondition', 'Cannot send to self');
	await admin.firestore().runTransaction(async (tx) => {
		const senderRef = admin.firestore().collection('wallets').doc(uid);
		const recvRef = admin.firestore().collection('wallets').doc(toUid);
		const [sSnap, rSnap] = await Promise.all([tx.get(senderRef), tx.get(recvRef)]);
		const sBal = Number((sSnap.data() && sSnap.data().balance) || 0);
		if (sBal < amount) throw new functions.https.HttpsError('failed-precondition', 'Insufficient balance');
		tx.set(senderRef, { balance: sBal - amount }, { merge: true });
		const rBal = Number((rSnap.data() && rSnap.data().balance) || 0);
		tx.set(recvRef, { balance: rBal + amount }, { merge: true });
		const now = admin.firestore.FieldValue.serverTimestamp();
		tx.set(senderRef.collection('tx').doc(), { type: 'send', to: toUid, amount, createdAt: now }, { merge: true });
		tx.set(recvRef.collection('tx').doc(), { type: 'receive', from: uid, amount, createdAt: now }, { merge: true });
	});
	return { ok: true };
});

// Wallet: Withdraw request - Scaffold
exports.walletWithdraw = functions.region('us-central1').https.onCall(async (data, context) => {
	const uid = context.auth && context.auth.uid;
	if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
	const amount = Number(data && data.amount);
	const currency = (data && data.currency) || 'NGN';
	if (!amount || amount <= 0) throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
	await admin.firestore().collection('withdrawals').add({ userId: uid, amount, currency, status: 'pending', createdAt: admin.firestore.FieldValue.serverTimestamp() });
	return { ok: true };
});

// Digital: Airtime/Data/Bills - Scaffold using aggregator config
async function getDigitalConfig() {
	const doc = await admin.firestore().doc('_config/digital').get();
	return doc.exists ? doc.data() : {};
}

exports.airtimePurchase = functions.region('us-central1').https.onCall(async (data, context) => {
	const uid = context.auth && context.auth.uid;
	if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
	const { provider, phone, amount, country, currency, reference, billerCode } = data || {};
	if (!phone || !amount) throw new functions.https.HttpsError('invalid-argument', 'phone, amount required');
	const txRef = `airtime_${uid}_${Date.now()}`;
	await admin.firestore().runTransaction(async (t) => {
		const walletRef = admin.firestore().collection('wallets').doc(uid);
		const wSnap = await t.get(walletRef);
		const bal = Number((wSnap.data() && wSnap.data().balance) || 0);
		if (bal < Number(amount)) throw new functions.https.HttpsError('failed-precondition', 'Insufficient balance');
		t.set(admin.firestore().collection('digital_tx').doc(txRef), {
			userId: uid, type: 'airtime', provider: provider || 'flutterwaveBills', phone, amount: Number(amount), currency: currency || null, country: country || null,
			status: 'processing', reference: reference || txRef, createdAt: admin.firestore.FieldValue.serverTimestamp(),
		});
		t.set(walletRef, { balance: bal - Number(amount) }, { merge: true });
		t.set(walletRef.collection('tx').doc(), { type: 'debit', ref: txRef, amount: Number(amount), createdAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
	});
	try {
		const res = await callFlutterwaveBills({ type: 'AIRTIME', country, customer: phone, amount: Number(amount), reference: reference || txRef, biller_code: billerCode });
		await admin.firestore().collection('digital_tx').doc(txRef).set(removeUndefined({ status: (res && res.status) || 'success', providerRef: (res && res.data && res.data.flw_ref) || null, response: res || null }), { merge: true });
		return { ref: txRef, status: 'success' };
	} catch (e) {
		console.error('airtimePurchase error', e && (e.response && e.response.data || e));
		await admin.firestore().runTransaction(async (t) => {
			const walletRef = admin.firestore().collection('wallets').doc(uid);
			const wSnap = await t.get(walletRef);
			const bal = Number((wSnap.data() && wSnap.data().balance) || 0);
			t.set(walletRef, { balance: bal + Number(amount) }, { merge: true });
			t.set(walletRef.collection('tx').doc(), { type: 'refund', ref: txRef, amount: Number(amount), createdAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
			t.set(admin.firestore().collection('digital_tx').doc(txRef), { status: 'failed', error: String(e && (e.response && JSON.stringify(e.response.data) || e.message || e)) }, { merge: true });
		});
		throw new functions.https.HttpsError('internal', 'Airtime purchase failed');
	}
});

exports.dataPurchase = functions.region('us-central1').https.onCall(async (data, context) => {
	const uid = context.auth && context.auth.uid;
	if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
	const { provider, phone, bundleCode, amount, country, currency, reference, billerCode } = data || {};
	if (!phone || !bundleCode || !amount) throw new functions.https.HttpsError('invalid-argument', 'phone, bundleCode, amount required');
	const txRef = `data_${uid}_${Date.now()}`;
	await admin.firestore().runTransaction(async (t) => {
		const walletRef = admin.firestore().collection('wallets').doc(uid);
		const wSnap = await t.get(walletRef);
		const bal = Number((wSnap.data() && wSnap.data().balance) || 0);
		if (bal < Number(amount)) throw new functions.https.HttpsError('failed-precondition', 'Insufficient balance');
		t.set(admin.firestore().collection('digital_tx').doc(txRef), {
			userId: uid, type: 'data', provider: provider || 'flutterwaveBills', phone, bundleCode, amount: Number(amount), currency: currency || null, country: country || null,
			status: 'processing', reference: reference || txRef, createdAt: admin.firestore.FieldValue.serverTimestamp(),
		});
		t.set(walletRef, { balance: bal - Number(amount) }, { merge: true });
		t.set(walletRef.collection('tx').doc(), { type: 'debit', ref: txRef, amount: Number(amount), createdAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
	});
	try {
		const res = await callFlutterwaveBills({ type: 'DATA', country, customer: phone, amount: Number(amount), reference: reference || txRef, item_code: bundleCode, biller_code: billerCode });
		await admin.firestore().collection('digital_tx').doc(txRef).set(removeUndefined({ status: (res && res.status) || 'success', providerRef: (res && res.data && res.data.flw_ref) || null, response: res || null }), { merge: true });
		return { ref: txRef, status: 'success' };
	} catch (e) {
		console.error('dataPurchase error', e && (e.response && e.response.data || e));
		await admin.firestore().runTransaction(async (t) => {
			const walletRef = admin.firestore().collection('wallets').doc(uid);
			const wSnap = await t.get(walletRef);
			const bal = Number((wSnap.data() && wSnap.data().balance) || 0);
			t.set(walletRef, { balance: bal + Number(amount) }, { merge: true });
			t.set(walletRef.collection('tx').doc(), { type: 'refund', ref: txRef, amount: Number(amount), createdAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
			t.set(admin.firestore().collection('digital_tx').doc(txRef), { status: 'failed', error: String(e && (e.response && JSON.stringify(e.response.data) || e.message || e)) }, { merge: true });
		});
		throw new functions.https.HttpsError('internal', 'Data purchase failed');
	}
});

exports.billPay = functions.region('us-central1').https.onCall(async (data, context) => {
	const uid = context.auth && context.auth.uid;
	if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
	const { billerCode, account, amount, country, currency, reference, itemCode, type } = data || {};
	if (!billerCode || !account || !amount) throw new functions.https.HttpsError('invalid-argument', 'billerCode, account, amount required');
	const txRef = `bill_${uid}_${Date.now()}`;
	await admin.firestore().runTransaction(async (t) => {
		const walletRef = admin.firestore().collection('wallets').doc(uid);
		const wSnap = await t.get(walletRef);
		const bal = Number((wSnap.data() && wSnap.data().balance) || 0);
		if (bal < Number(amount)) throw new functions.https.HttpsError('failed-precondition', 'Insufficient balance');
		t.set(admin.firestore().collection('digital_tx').doc(txRef), {
			userId: uid, type: 'bill', billerCode, account, amount: Number(amount), currency: currency || null, country: country || null,
			status: 'processing', reference: reference || txRef, createdAt: admin.firestore.FieldValue.serverTimestamp(),
		});
		t.set(walletRef, { balance: bal - Number(amount) }, { merge: true });
		t.set(walletRef.collection('tx').doc(), { type: 'debit', ref: txRef, amount: Number(amount), createdAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
	});
	try {
		const res = await callFlutterwaveBills({ type: type || 'BILLS', country, customer: account, amount: Number(amount), reference: reference || txRef, biller_code: billerCode, item_code: itemCode });
		await admin.firestore().collection('digital_tx').doc(txRef).set(removeUndefined({ status: (res && res.status) || 'success', providerRef: (res && res.data && res.data.flw_ref) || null, response: res || null }), { merge: true });
		return { ref: txRef, status: 'success' };
	} catch (e) {
		console.error('billPay error', e && (e.response && e.response.data || e));
		await admin.firestore().runTransaction(async (t) => {
			const walletRef = admin.firestore().collection('wallets').doc(uid);
			const wSnap = await t.get(walletRef);
			const bal = Number((wSnap.data() && wSnap.data().balance) || 0);
			t.set(walletRef, { balance: bal + Number(amount) }, { merge: true });
			t.set(walletRef.collection('tx').doc(), { type: 'refund', ref: txRef, amount: Number(amount), createdAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
			t.set(admin.firestore().collection('digital_tx').doc(txRef), { status: 'failed', error: String(e && (e.response && JSON.stringify(e.response.data) || e.message || e)) }, { merge: true });
		});
		throw new functions.https.HttpsError('internal', 'Bill payment failed');
	}
});

async function callFlutterwaveBills(payload) {
	const secret = await getFlutterwaveSecretKey();
	if (!secret) throw new functions.https.HttpsError('failed-precondition', 'Flutterwave bills not configured');
	const ref = payload.reference || `dz_${Date.now()}`;
	const body = removeUndefined({
		country: payload.country,
		customer: payload.customer,
		amount: payload.amount,
		recurrence: 'ONCE',
		type: payload.type,
		reference: ref,
		biller_code: payload.biller_code,
		item_code: payload.item_code,
		meta: payload.meta || {},
	});
	const res = await axios.post('https://api.flutterwave.com/v3/bills', body, { headers: { Authorization: `Bearer ${secret}` } });
	return res.data;
}

exports.walletStripeWebhook = functions.region('us-central1').https.onRequest(async (req, res) => {
	if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
	const endpointSecret = await getStripeEndpointSecret();
	const secret = await getStripeSecretKey();
	if (!endpointSecret || !secret) return res.status(500).send('Stripe not configured');
	let event;
	try {
		const stripe = new Stripe(secret);
		event = stripe.webhooks.constructEvent(req.rawBody, req.headers['stripe-signature'], endpointSecret);
	} catch (err) {
		console.error('Stripe webhook verify failed', err);
		return res.status(400).send(`Webhook Error: ${err.message}`);
	}
	if (event.type === 'checkout.session.completed') {
		const session = event.data.object;
		const uid = session.metadata && session.metadata.uid;
		const txId = session.metadata && session.metadata.txId;
		if (uid && txId) {
			await admin.firestore().runTransaction(async (t) => {
				const txRef = admin.firestore().collection('wallets').doc(uid).collection('tx').doc(txId);
				const walletRef = admin.firestore().collection('wallets').doc(uid);
				const snap = await t.get(txRef);
				if (!snap.exists) return;
				const data = snap.data() || {};
				if (data.status === 'paid') return;
				const amount = Number(data.amount || 0);
				const wSnap = await t.get(walletRef);
				const bal = Number((wSnap.data() && wSnap.data().balance) || 0);
				t.set(walletRef, { balance: bal + amount }, { merge: true });
				t.set(txRef, { status: 'paid', gateway: 'stripe', gatewayRef: session.id, paidAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
				t.set(walletRef.collection('tx').doc(), { type: 'credit', ref: txId, amount, createdAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
			});
		}
	}
	return res.json({ received: true });
});

exports.walletFlutterwaveWebhook = functions.region('us-central1').https.onRequest(async (req, res) => {
	if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
	const hash = req.headers['verif-hash'];
	const expected = await getFlutterwaveWebhookSecret();
	if (!expected || hash !== expected) {
		console.error('Flutterwave webhook invalid signature');
		return res.status(401).send('Unauthorized');
	}
	const payload = req.body || {};
	const data = payload.data || {};
	const meta = data.meta || {};
	if ((payload.event && payload.event.includes('charge')) || data.status === 'successful') {
		const uid = meta.uid;
		const txId = meta.txId;
		if (uid && txId) {
			await admin.firestore().runTransaction(async (t) => {
				const txRef = admin.firestore().collection('wallets').doc(uid).collection('tx').doc(txId);
				const walletRef = admin.firestore().collection('wallets').doc(uid);
				const snap = await t.get(txRef);
				if (!snap.exists) return;
				const doc = snap.data() || {};
				if (doc.status === 'paid') return;
				const amount = Number(doc.amount || 0);
				const wSnap = await t.get(walletRef);
				const bal = Number((wSnap.data() && wSnap.data().balance) || 0);
				t.set(walletRef, { balance: bal + amount }, { merge: true });
				t.set(txRef, { status: 'paid', gateway: 'flutterwave', gatewayRef: data.id || data.flw_ref || null, paidAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
				t.set(walletRef.collection('tx').doc(), { type: 'credit', ref: txId, amount, createdAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
			});
		}
	}
	return res.json({ received: true });
});