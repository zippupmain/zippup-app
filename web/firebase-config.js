// Firebase Web initialization (module)
// Uses CDN imports and guards against double initialization

import { initializeApp, getApps } from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-app.js';
import { getAnalytics, isSupported } from 'https://www.gstatic.com/firebasejs/10.12.2/firebase-analytics.js';

const firebaseConfig = {
  apiKey: 'AIzaSyD4QTWO9IBOT82JULaF0fEGfgYDgQH7a1A',
  authDomain: 'zippup-3b5c6.firebaseapp.com',
  projectId: 'zippup-3b5c6',
  storageBucket: 'zippup-3b5c6.appspot.com',
  messagingSenderId: '529547739475',
  appId: '1:529547739475:web:dcc2ce1d73f8b02a3661a6',
  measurementId: 'G-GXQS15STKB'
};

let app = null;
try {
  const apps = getApps();
  app = apps.length ? apps[0] : initializeApp(firebaseConfig);
} catch (e) {
  // In case another SDK initialized concurrently, attempt to read existing app
  try { app = getApps()[0] || null; } catch { /* noop */ }
}

try {
  isSupported().then((ok) => { if (ok && app) getAnalytics(app); });
} catch { /* analytics optional */ }