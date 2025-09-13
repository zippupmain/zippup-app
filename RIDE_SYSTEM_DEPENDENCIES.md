# Ride System Dependencies

Add these dependencies to your `pubspec.yaml` file:

```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Firebase dependencies
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  firebase_messaging: ^14.7.10
  cloud_functions: ^4.6.13
  
  # Notification dependencies
  flutter_local_notifications: ^17.1.2
  
  # Audio for notification sounds
  audioplayers: ^6.0.0
  
  # Location and mapping (choose one)
  geolocator: ^10.1.0
  geocoding: ^2.1.1
  google_maps_flutter: ^2.5.0  # or flutter_map for alternative
  
  # UI and state management
  provider: ^6.1.1  # or riverpod, bloc, etc.

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

# Add sound files to assets
flutter:
  assets:
    - assets/sounds/
```

## Firebase Cloud Functions Dependencies

For your `functions/package.json`:

```json
{
  "name": "functions",
  "scripts": {
    "build": "tsc",
    "serve": "npm run build && firebase emulators:start --only functions",
    "shell": "npm run build && firebase functions:shell",
    "start": "npm run shell",
    "deploy": "firebase deploy --only functions",
    "logs": "firebase functions:log"
  },
  "engines": {
    "node": "18"
  },
  "main": "lib/index.js",
  "dependencies": {
    "firebase-admin": "^11.11.0",
    "firebase-functions": "^4.5.0",
    "geofirestore": "^5.2.0"
  },
  "devDependencies": {
    "typescript": "^4.9.0",
    "@types/node": "^18.0.0"
  }
}
```

## Required Sound Files

Create these sound files in `assets/sounds/`:

1. `ride_request_sound.mp3` - Loud, attention-grabbing sound for ride requests
2. `ride_request_sound.wav` - iOS version of the sound file

## Android Configuration

Add to `android/app/src/main/res/raw/`:
- `ride_request_sound.mp3` - Android notification sound

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.VIBRATE" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
```

## iOS Configuration

Add to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs location access to find nearby drivers and provide ride services.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs location access to find nearby drivers and provide ride services.</string>
<key>UIBackgroundModes</key>
<array>
    <string>background-fetch</string>
    <string>remote-notification</string>
    <string>location</string>
</array>
```

## Firebase Configuration

1. **Firestore Security Rules** (`firestore.rules`):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Rides collection
    match /rides/{rideId} {
      allow read, write: if request.auth != null && 
        (request.auth.uid == resource.data.customerId || 
         request.auth.uid == resource.data.driverId ||
         isAdmin());
    }
    
    // Drivers collection
    match /drivers/{driverId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == driverId;
    }
    
    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    function isAdmin() {
      return exists(/databases/$(database)/documents/_config/admins/users/$(request.auth.uid));
    }
  }
}
```

2. **Cloud Functions Deployment**:

```bash
cd functions
npm install
npm run deploy
```

## Installation Steps

1. **Add dependencies** to `pubspec.yaml`
2. **Run** `flutter pub get`
3. **Add sound files** to `assets/sounds/`
4. **Configure Android** permissions and notification channel
5. **Configure iOS** permissions and background modes
6. **Deploy Firebase functions** with the ride assignment logic
7. **Set up Firestore security rules**
8. **Test** the complete flow

## Testing the System

1. **Create a test ride** with status 'requesting'
2. **Ensure driver app** is running with notifications enabled
3. **Check Cloud Function logs** for assignment process
4. **Verify FCM notifications** are received
5. **Test driver accept/decline** actions
6. **Monitor real-time updates** in both customer and driver apps

The system provides a complete "Uber-like" experience with real-time driver assignment, push notifications, and live ride tracking.