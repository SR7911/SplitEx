# Play Store Deployment Guide — SplitEx

---

## 1. Prerequisites & Requirements

### Developer Account
- Google Play Console account ($25 one-time fee)
- Sign up at: https://play.google.com/console

### Legal Documents (Mandatory)
- **Privacy Policy** — Hosted on a public URL (e.g., GitHub Pages, Firebase Hosting, or any website)
  - Must describe: what data you collect, how you use it, Firebase/Google analytics disclosure
  - Required because app uses: Firebase Auth (email, name), Firebase Storage (photos), Firestore (expense data)
- **Terms of Service** — Recommended but optional for listing

### App Assets Required

| Asset | Specification |
|-------|--------------|
| App Icon | 512x512 PNG (32-bit, no alpha for Play Store icon) |
| Feature Graphic | 1024x500 PNG or JPG |
| Phone Screenshots | Min 2, max 8 | 16:9 or 9:16 ratio, min 320px, max 3840px |
| Tablet Screenshots | Optional but recommended (7" and 10") |
| Short Description | Max 80 characters |
| Full Description | Max 4000 characters |

### App Signing
- Upload key (for first upload)
- Google manages signing key via Play App Signing (recommended)

---

## 2. Pre-Deployment Checklist

### Code Changes
- [ ] Set `DevConfig.skipAuth = false` in `lib/config/dev_config.dart`
- [ ] Remove all debug/test data references
- [ ] Ensure `debugShowCheckedModeBanner: false` in `app.dart` ✅ (already done)
- [ ] Verify Firebase project is on production (not test mode)

### Firebase Production Setup
- [ ] Deploy Firestore security rules (`firestore.rules`)
- [ ] Enable Email/Password auth provider
- [ ] Enable Google Sign-In provider
- [ ] Add release SHA-1 and SHA-256 to Firebase Console → Project Settings → Android app
- [ ] Set Firestore to production mode (not test mode)
- [ ] Verify Firebase Storage rules (for avatar uploads)

### Android Configuration
- [ ] Update `android/app/build.gradle.kts`:
  - Set `applicationId` (e.g., `com.yourname.splitex`)
  - Set `minSdk` to 23 (Android 6.0)
  - Set `targetSdk` to 34
  - Set `versionCode` and `versionName`
- [ ] Configure signing in `android/app/build.gradle.kts`
- [ ] Update `android/app/src/main/AndroidManifest.xml`:
  - Internet permission (auto-added by Firebase)
  - UPI intent query for Android 11+:
    ```xml
    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="upi" />
        </intent>
    </queries>
    ```
- [ ] Add app icon using `flutter_launcher_icons` or manually

### App Content
- [ ] Replace placeholder URLs in settings (`splitex.app/terms`, `splitex.app/privacy`)
- [ ] Ensure app version matches `pubspec.yaml` version

---

## 3. Generate Release Build

### Step 1: Create Upload Keystore
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
- Remember the password and alias
- Store keystore file securely (DO NOT commit to git)

### Step 2: Configure Signing in Gradle

Create `android/key.properties`:
```properties
storePassword=<your-password>
keyPassword=<your-password>
keyAlias=upload
storeFile=<path-to>/upload-keystore.jks
```

Update `android/app/build.gradle.kts`:
```kotlin
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}
```

### Step 3: Build App Bundle
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```
Output: `build/app/outputs/bundle/release/app-release.aab`

---

## 4. Play Console Setup & Upload

### Step 1: Create App
1. Go to Play Console → Create app
2. Fill: App name, Default language, App/Game, Free/Paid
3. Accept declarations

### Step 2: Store Listing
1. **Main store listing**:
   - App name: `SplitEx`
   - Short description: `Split expenses with roommates. Track who owes what. Settle via UPI.`
   - Full description: (detailed app features)
2. Upload screenshots (phone, optionally tablet)
3. Upload feature graphic (1024x500)
4. Upload app icon (512x512)

### Step 3: Content Rating
1. Fill the IARC questionnaire
   - Category: Utility/Finance
   - No violence, no sexual content, no gambling
   - Result: Likely "Everyone" / PEGI 3

### Step 4: Target Audience & Content
1. Target age group: 18+ (financial app)
2. Not designed for children
3. Not an ads-supported app (if no ads)

### Step 5: App Privacy
1. **Data Safety form** — Declare what data you collect:

| Data Type | Collected | Shared | Purpose |
|-----------|-----------|--------|---------|
| Email address | Yes | No | Account authentication |
| Name | Yes | No | Display in app |
| Profile photo | Yes | No | User identification |
| Financial info (expenses) | Yes | No | App functionality |
| App interactions | Yes | No | App functionality |

2. Link your Privacy Policy URL

### Step 6: App Access
- If app requires login to review, provide test credentials to Google:
  - Email: `reviewer@splitex.app`
  - Password: `<test-password>`

### Step 7: Upload AAB
1. Go to Release → Production → Create new release
2. Upload `app-release.aab`
3. Add release notes (e.g., "Initial release — split expenses, track balances, settle via UPI")
4. Review and roll out to production

---

## 5. Post-Upload Review Process

| Step | Duration |
|------|----------|
| Upload & submit | Immediate |
| Google review | 1-7 days (first app may take longer) |
| Approval / Rejection | Email notification |
| Live on Play Store | Within hours of approval |

### Common Rejection Reasons & Fixes
| Reason | Fix |
|--------|-----|
| No privacy policy | Host privacy policy and link in app + listing |
| No delete account option | ✅ Already implemented in settings |
| Broken login flow | Ensure test account works |
| Misleading description | Match description to actual features |
| Crashes on launch | Test release build on physical device first |

---

## 6. Post-Launch Essentials

- [ ] Monitor Firebase Crashlytics for crashes
- [ ] Monitor Play Console → Android Vitals for ANRs
- [ ] Reply to user reviews
- [ ] Plan update cycle (bug fixes → v1.0.1, features → v1.1.0)
- [ ] Set up staged rollout for future updates (10% → 50% → 100%)

---

## 7. Estimated Costs

| Item | Cost |
|------|------|
| Google Play Developer account | $25 (one-time) |
| Firebase Spark plan | Free |
| Privacy Policy hosting (GitHub Pages) | Free |
| Domain for privacy policy (optional) | ~$10/year |
| **Total minimum** | **$25** |

---

## 8. Timeline Estimate

| Task | Time |
|------|------|
| Generate keystore & configure signing | 30 min |
| Create app icons & screenshots | 2-3 hours |
| Write store listing & descriptions | 1 hour |
| Host privacy policy | 30 min |
| Fill Play Console forms | 1-2 hours |
| Build & upload AAB | 15 min |
| Google review | 1-7 days |
| **Total** | **~1 day of work + review wait** |

---

*End of Document*
