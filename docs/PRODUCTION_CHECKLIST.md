# Production Checklist

## Before Release

### 1. Disable Dev Mode
- [ ] Set `DevConfig.skipAuth = false` in `lib/config/dev_config.dart`

### 2. Firebase Security
- [ ] Deploy `firestore.rules` to Firebase Console → Firestore → Rules
- [ ] Enable Email/Password auth in Firebase Console → Authentication → Sign-in method
- [ ] Enable Google Sign-In in Firebase Console → Authentication → Sign-in method
- [ ] Add SHA-1 and SHA-256 fingerprints for Google Sign-In (Android)

### 3. Firestore Indexes
Create composite indexes if prompted (or via Firebase Console → Firestore → Indexes):
- `notifications`: `targetUserId` ASC + `createdAt` DESC
- `notifications`: `targetUserId` ASC + `isRead` ASC
- `settlements`: `toUserId` ASC + `status` ASC

### 4. Android Configuration
- [ ] Update `android/app/src/main/AndroidManifest.xml`:
  - Add internet permission (should already be there via Firebase)
  - Add UPI intent query for Android 11+ (package visibility)
- [ ] Add to AndroidManifest.xml inside `<manifest>`:
```xml
<queries>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="upi" />
    </intent>
</queries>
```

### 5. App Signing
- [ ] Generate release keystore
- [ ] Add SHA-1 of release key to Firebase Console
- [ ] Configure `android/app/build.gradle.kts` with signing config

### 6. Test Plan
- [ ] Email registration → profile setup → room creation
- [ ] Google Sign-In → profile setup
- [ ] Second user join room via invite code
- [ ] Add expense (equal split) → verify both users see it
- [ ] Dashboard shows correct balances
- [ ] Settle Up → UPI intent opens → settlement recorded
- [ ] Notifications arrive for other user
- [ ] Activity log shows all actions
- [ ] Month selector navigates correctly
- [ ] Sign out and sign in again → data persists

### 7. Firestore Cleanup
- [ ] Remove test data from Firestore
- [ ] Switch from Test mode rules to production rules (deploy firestore.rules)

### 8. Optional Enhancements
- [ ] Add Firebase Crashlytics for crash reporting
- [ ] Add Firebase Analytics for usage tracking
- [ ] Add app icon and splash screen
- [ ] Add ProGuard rules for release build
