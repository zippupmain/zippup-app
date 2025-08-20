import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';
import axios from 'axios';
import corsLib from 'cors';

admin.initializeApp();

const cors = corsLib({ origin: true });

// Read secrets from env (configure via Firebase env: functions:config:set)
const STRIPE_SECRET = process.env.STRIPE_SECRET || functions.config().stripe?.secret;
const FLW_SECRET = process.env.FLW_SECRET || functions.config().flw?.secret;
const stripe = STRIPE_SECRET ? new Stripe(STRIPE_SECRET, { apiVersion: '2024-06-20' }) : null;

export const createStripeCheckout = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
    if (!stripe) return res.status(500).json({ error: 'Stripe not configured' });
    try {
      const { items = [], currency = 'USD', success_url, cancel_url } = req.body || {};
      const line_items = (items as any[]).map((it) => ({
        price_data: {
          currency,
          product_data: { name: it.name || 'Item' },
          unit_amount: Number(it.amount) || 0,
        },
        quantity: Number(it.quantity) || 1,
      }));

      const session = await stripe.checkout.sessions.create({
        mode: 'payment',
        line_items,
        success_url: success_url || 'https://example.com/success',
        cancel_url: cancel_url || 'https://example.com/cancel',
      });
      return res.json({ id: session.id, url: session.url, checkoutUrl: session.url });
    } catch (e: any) {
      console.error('Stripe error', e);
      return res.status(500).json({ error: e?.message || 'Stripe error' });
    }
  });
});

export const createFlutterwaveCheckout = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    if (req.method !== 'POST') return res.status(405).send('Method Not Allowed');
    if (!FLW_SECRET) return res.status(500).json({ error: 'Flutterwave not configured' });
    try {
      const { amount, currency = 'NGN' } = req.body || {};
      const payload = {
        tx_ref: 'tx_' + Date.now(),
        amount,
        currency,
        payment_options: 'card,banktransfer,ussd',
        redirect_url: 'https://example.com/redirect',
        customer: { email: 'guest@example.com', name: 'Guest' },
        customizations: { title: 'ZippUp Order' },
      };
      const r = await axios.post('https://api.flutterwave.com/v3/payments', payload, {
        headers: { Authorization: `Bearer ${FLW_SECRET}` },
      });
      const link = r.data?.data?.link;
      return res.json({ checkoutUrl: link });
    } catch (e: any) {
      console.error('Flutterwave error', e?.response?.data || e);
      return res.status(500).json({ error: e?.message || 'Flutterwave error' });
    }
  });
});

// Google Places autocomplete proxy (avoids exposing keys & CORS)
export const placesAutocomplete = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      const input = (req.body?.input || req.query?.input || '').toString();
      if (!input || input.length < 3) return res.json({ predictions: [] });
      const key = process.env.GOOGLE_MAPS_KEY || functions.config().google?.maps_key;
      if (!key) return res.status(500).json({ error: 'Google Maps key not configured' });
      const url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
      const r = await axios.get(url, { params: { input, key } });
      return res.json({ predictions: r.data?.predictions || [] });
    } catch (e: any) {
      console.error('Places error', e?.response?.data || e);
      return res.status(500).json({ error: e?.message || 'Places error' });
    }
  });
});

export const geocode = functions.https.onRequest(async (req, res) => {
  return cors(req, res, async () => {
    try {
      const lat = req.body?.lat || req.query?.lat;
      const lng = req.body?.lng || req.query?.lng;
      const key = process.env.GOOGLE_MAPS_KEY || functions.config().google?.maps_key;
      if (!key) return res.status(500).json({ error: 'Google Maps key not configured' });
      const url = 'https://maps.googleapis.com/maps/api/geocode/json';
      const r = await axios.get(url, { params: { latlng: `${lat},${lng}`, key } });
      const result = r.data?.results?.[0];
      const country = result?.address_components?.find((c: any) => c.types?.includes('country'));
      return res.json({ address: result?.formatted_address, country: country?.long_name, countryCode: country?.short_name });
    } catch (e: any) {
      console.error('Geocode error', e?.response?.data || e);
      return res.status(500).json({ error: e?.message || 'Geocode error' });
    }
  });
});

