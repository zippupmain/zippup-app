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