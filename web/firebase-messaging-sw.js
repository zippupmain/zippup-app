// Minimal stub service worker to satisfy requests for firebase messaging on web
// We are not initializing Firebase Messaging here; this prevents MIME/type errors
self.addEventListener('install', function(event) {
  // Activate immediately
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  // Claim clients so the SW is active without reload
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', function(event) {
  // No-op: messaging disabled in app init
});

