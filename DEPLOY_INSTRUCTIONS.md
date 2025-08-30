# Firebase Rules Deployment Instructions

## 🚨 **IMPORTANT: Deploy Firebase Rules for Test Mode**

The app is currently blocked by Firebase security rules. To enable test mode:

### **Option 1: Firebase Console (Recommended)**
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your ZippUp project
3. Navigate to **Firestore Database** → **Rules**
4. Replace the current rules with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // TEST MODE: Allow all operations
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

5. Click **Publish**

### **Option 2: Firebase CLI**
```bash
npm install -g firebase-tools
firebase login
firebase deploy --only firestore:rules
```

### **⚠️ Security Note**
These rules allow all operations for testing. Before production:
1. Implement proper user authentication checks
2. Add role-based access controls
3. Validate data before writes
4. Use the commented production rules in `firestore.rules`

## 🎯 **After Rules Deployment**

Your ZippUp app will have:
- ✅ **Global notifications** working everywhere
- ✅ **All service bookings** (hire, emergency, moving, personal)
- ✅ **Real-time tracking** for all services
- ✅ **Cash + card payments** 
- ✅ **Proper name display** from profiles
- ✅ **Haptic notification feedback**

**Test the booking flows in this order:**
1. **Transport** (already working)
2. **Hire** (new enhanced flow)
3. **Emergency** (new priority-based system)
4. **Moving** (enhanced with tracking)
5. **Personal** (new duration-based booking)