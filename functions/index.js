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
  // Handle ride acceptance timeout (70s)
  const rides = await admin.firestore().collection('rides').where('status', '==', 'requested').get();
  for (const d of rides.docs) {
    const createdAt = new Date(d.get('createdAt') || now).getTime();
    if (now - createdAt > 70 * 1000) {
      // write a notification to rider; frontend will prompt
      await d.ref.set({ timeout: true }, { merge: true });
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
		createdAt: admin.firestore.FieldValue.serverTimestamp(),
	});
	// Choose provider
	// Try Stripe for USD/EUR/GBP; otherwise Flutterwave
	let checkoutUrl = null;
	try {
		if (['USD','EUR','GBP'].includes(currency)) {
			const secret = (await admin.firestore().doc('_config/stripe').get()).get('secret') || process.env.STRIPE_SECRET || (functions.config().stripe && functions.config().stripe.secret);
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
			const secret = (await admin.firestore().doc('_config/flutterwave').get()).get('secret') || process.env.FLW_SECRET || (functions.config().flutterwave && functions.config().flutterwave.secret);
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
	const { provider, phone, amount, country } = data || {};
	if (!phone || !amount) throw new functions.https.HttpsError('invalid-argument', 'phone, amount required');
	const cfg = await getDigitalConfig();
	const txRef = `airtime_${uid}_${Date.now()}`;
	const txDoc = await admin.firestore().collection('digital_tx').doc(txRef).set({
		userId: uid, type: 'airtime', provider: provider || null, phone, amount, country: country || null, status: 'queued', createdAt: admin.firestore.FieldValue.serverTimestamp(),
	});
	// TODO: integrate with aggregator (e.g., Flutterwave Bills or Reloadly) using cfg
	return { ref: txRef, status: 'queued' };
});

exports.dataPurchase = functions.region('us-central1').https.onCall(async (data, context) => {
	const uid = context.auth && context.auth.uid;
	if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
	const { provider, phone, bundleId, amount, country } = data || {};
	if (!phone || !bundleId) throw new functions.https.HttpsError('invalid-argument', 'phone, bundleId required');
	const cfg = await getDigitalConfig();
	const txRef = `data_${uid}_${Date.now()}`;
	await admin.firestore().collection('digital_tx').doc(txRef).set({
		userId: uid, type: 'data', provider: provider || null, phone, bundleId, amount: amount || null, country: country || null, status: 'queued', createdAt: admin.firestore.FieldValue.serverTimestamp(),
	});
	// TODO: integrate with aggregator using cfg
	return { ref: txRef, status: 'queued' };
});

exports.billPay = functions.region('us-central1').https.onCall(async (data, context) => {
	const uid = context.auth && context.auth.uid;
	if (!uid) throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
	const { billerCode, account, amount, country, metadata } = data || {};
	if (!billerCode || !account || !amount) throw new functions.https.HttpsError('invalid-argument', 'billerCode, account, amount required');
	const cfg = await getDigitalConfig();
	const txRef = `bill_${uid}_${Date.now()}`;
	await admin.firestore().collection('digital_tx').doc(txRef).set({
		userId: uid, type: 'bill', billerCode, account, amount, country: country || null, metadata: metadata || null, status: 'queued', createdAt: admin.firestore.FieldValue.serverTimestamp(),
	});
	// TODO: integrate with aggregator using cfg
	return { ref: txRef, status: 'queued' };
});