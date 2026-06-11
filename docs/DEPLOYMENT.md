# SplitEx — Deployment & Production Guide

---

## 1. Pre-Deployment Checklist

### Code Changes
- [ ] Set `DevConfig.skipAuth = false` in `lib/config/dev_config.dart`
- [ ] Remove all debug/test data references
- [ ] Verify Firebase project is on production (not test mode)

### Firebase Production Setup
- [ ] Deploy `firestore.rules` to Firebase Console → Firestore → Rules
- [ ] Enable Email/Password auth provider
- [ ] Enable Google Sign-In provider
- [ ] Add release SHA-1 and SHA-256 to Firebase Console → Project Settings → Android app
- [ ] Set Firestore to production mode
- [ ] Verify Firebase Storage rules

### Firestore Indexes Required
- `notifications`: `targetUserId` ASC + `createdAt` DESC
- `notifications`: `targetUserId` ASC + `isRead` ASC
- `settlements`: `toUserId` ASC + `status` ASC
- `personal_transactions`: `debtType` ASC + `date` DESC
- `personal_transactions`: `month` ASC + `date` DESC

### Android Configuration
- [ ] Update `android/app/build.gradle.kts`: applicationId, minSdk (23), targetSdk (34), versionCode/Name
- [ ] Configure signing config
- [ ] Update AndroidManifest.xml with UPI intent query:
  ```xml
  <queries>
      <intent>
          <action android:name="android.intent.action.VIEW" />
          <data android:scheme="upi" />
      </intent>
  </queries>
  ```

### Test Plan
- [ ] Email registration → profile setup → room creation
- [ ] Google Sign-In → profile setup
- [ ] Second user join room via invite code
- [ ] Add expense (equal split) → verify both users see it
- [ ] Dashboard shows correct balances
- [ ] Settle Up → UPI intent opens → settlement recorded
- [ ] Personal expense → Add with debt → Shows in debts screen
- [ ] Settle debt → Shows as disabled
- [ ] Notifications arrive for other user
- [ ] Activity log shows all actions
- [ ] Sign out and sign in again → data persists

---

## 2. Generate Release Build

### Create Upload Keystore
```bash
keytool -genkey -v -keystore split-ex-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias split_ex
```

> ⚠️ NEVER lose this file. Back it up securely.

### Configure Signing

Create `android/key.properties`:
```properties
storePassword=<your-password>
keyPassword=<your-password>
keyAlias=split_ex
storeFile=../../split-ex-release.jks
```

### Build App Bundle
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

---

## 3. Firebase Manual Steps

### Add SHA-1 Fingerprints

Get debug fingerprint:
```bash
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android
```

Get release fingerprint:
```bash
keytool -list -v -keystore split-ex-release.jks -alias split_ex
```

Add both SHA-1 values in Firebase Console → Project Settings → Android app → Add fingerprint.

Download updated `google-services.json` and replace in `android/app/`.

### Deploy Firestore Rules
1. Firebase Console → Firestore Database → Rules tab
2. Replace content with `firestore.rules` from project
3. Click Publish

### Enable Auth Providers
1. Firebase Console → Authentication → Sign-in method
2. Enable Email/Password (toggle ON)
3. Add new provider → Google → toggle ON → set support email → Save

### Enable Crashlytics
1. Firebase Console → Crashlytics → complete setup wizard
2. Build and run release app — it auto-reports

### Delete Test Data
Remove `dev_user_001/002/003` from `users` collection and their associated rooms/notifications.

---

## 4. Play Store Deployment

### Requirements
- Google Play Console account ($25 one-time)
- Privacy Policy hosted on a public URL
- App assets:

| Asset | Specification |
|-------|--------------|
| App Icon | 512x512 PNG |
| Feature Graphic | 1024x500 PNG/JPG |
| Phone Screenshots | Min 2, max 8 |
| Short Description | Max 80 characters |
| Full Description | Max 4000 characters |

### Upload Process
1. Play Console → Create app → fill details
2. Store listing: name, descriptions, screenshots, feature graphic
3. Content rating: Utility/Finance, "Everyone"
4. Data safety: declare email, name, financial data (not shared)
5. Link Privacy Policy URL
6. Release → Production → Upload AAB → Add release notes → Roll out

### Data Safety Declaration

| Data Type | Collected | Shared | Purpose |
|-----------|-----------|--------|---------|
| Email address | Yes | No | Authentication |
| Name | Yes | No | Display in app |
| Profile photo | Yes | No | User identification |
| Financial info | Yes | No | App functionality |

### Post-Upload
- Google review: 1-7 days
- Monitor Crashlytics and Android Vitals
- Staged rollout for future updates (10% → 50% → 100%)

---

## 5. Costs

| Item | Cost |
|------|------|
| Google Play Developer account | $25 (one-time) |
| Firebase Spark plan | Free |
| Privacy Policy hosting | Free (GitHub Pages) |
| **Total minimum** | **$25** |
