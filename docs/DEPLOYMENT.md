# SplitEx — Deployment & Production Guide

Updated 2026-10-21 for the recent personal finance and Android SMS features. Implementation verification is listed below; production rule deployment and physical-device SMS checks remain separate release steps.

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
- [ ] Configure production App Check in **both** `lib/main.dart` and `bankSmsBackgroundMain` in `lib/app/composition/personal_dependencies.dart`; both currently use `AndroidProvider.debug`
- [ ] Deploy the new owner-only personal finance rules described in section 3

### Firestore Indexes Required
- `notifications`: `targetUserId` ASC + `createdAt` DESC
- `notifications`: `targetUserId` ASC + `isRead` ASC
- `settlements`: `toUserId` ASC + `status` ASC
- `personal_transactions`: `debtType` ASC + `date` DESC
- `personal_transactions`: `month` ASC + `date` DESC

### Android Configuration
- [ ] Verify `applicationId` (`com.splitex.in.app`) and resolved SDK levels in `android/app/build.gradle.kts`; min/target/compile SDK values currently come from the installed Flutter SDK
- [ ] Set release version/build number in `pubspec.yaml` (currently `4.1.0+9`), which supplies Android versionName/versionCode
- [ ] Configure and verify release signing using `android/key.properties`; the current Gradle configuration falls back to debug signing when this file is missing
- [ ] Update AndroidManifest.xml with UPI intent query:
  ```xml
  <queries>
      <intent>
          <action android:name="android.intent.action.VIEW" />
          <data android:scheme="upi" />
      </intent>
  </queries>
  ```

### Bank SMS Release Configuration

- [ ] Rebuild and install the Android app after native changes; hot reload does not install the receiver, job service or MethodChannel code
- [ ] Verify the manifest's `RECEIVE_SMS` and `RECEIVE_BOOT_COMPLETED` permissions, SMS receiver and background job service
- [ ] Keep capture opt-in, with the in-app disclosure before requesting SMS permission; the feature does not request `READ_SMS`/`SEND_SMS` or scan message history
- [ ] Preserve the `splitex_bank_sms` exclusions in `backup_rules.xml` and `data_extraction_rules.xml`, referenced by the manifest
- [ ] Review the current [Google Play SMS permissions requirements](https://support.google.com/googleplay/android-developer/answer/10208820) and complete the applicable permissions declaration/review before publishing
- [ ] Update the privacy policy and Data safety answers for SMS processing, parsed financial metadata and local review storage; raw SMS stays on the device

See [Bank SMS recording](../BANK_SMS_RECORDING.md) for capture, sender trust, queue behavior and device checks. Captured messages can be delayed by Android restrictions; no history scan recovers missed delivery.

### Test Plan
- [ ] Email registration → profile setup → room creation
- [ ] Google Sign-In → profile setup
- [ ] Second user join room via invite code
- [ ] Add expense (equal split) → verify both users see it
- [ ] Dashboard shows correct balances
- [ ] Settle Up → UPI intent opens → settlement recorded
- [ ] Personal expense → Add with debt → Shows in debts screen
- [ ] Receive lent money / repay borrowed money → correct dated income/expense, updated remainder and per-debt history
- [ ] Partial settlement → original amount struck through, remaining amount correct; close debt → warning and write-off without cash movement
- [ ] View All debts → Lent/Borrowed/Settled tabs; Monthly Debts → month navigation, expandable categories and summary details
- [ ] Enter Loans & EMI with missed installments → confirmation popup; confirm/retry → one EMI log and matching expense per installment
- [ ] Create/edit/archive/restore accounts; create/edit/delete transfers → correct balances, unchanged spending/budget totals
- [ ] Payment Calendar → month navigation, short-month/leap dates, EMI/recurring/debt events and filters; browsing creates no transactions
- [ ] Monthly Money Review → selected dashboard month, elapsed-date comparison, uncategorized expense editing and current debt balances
- [ ] Savings Goals → dated contribution/withdrawal, history deletion guard, archive/restore; no account transfer or personal transaction created
- [ ] Merchant Category Rules → save from review, edit/pause/delete; future categories update without rewriting older transactions or bypassing sender trust
- [ ] Notifications arrive for other user
- [ ] Activity log shows all actions
- [ ] Sign out and sign in again → data persists

### Physical Android SMS Checks

- [ ] Cancel disclosure, deny/grant/revoke permission, disable capture and verify existing personal finance remains usable
- [ ] Deliver a real supported multipart alert; verify untrusted sender review and explicit sender trust
- [ ] Trusted clear debit → one personal expense; credit/refund/transfer/uncertain alert → review
- [ ] Retry/duplicate delivery → no duplicate; link an existing manual/EMI/settlement entry or own-account transfer
- [ ] Same ending on multiple accounts → no automatic account assignment; unique active ending → correct assignment
- [ ] Offline capture/retry, app-resume processing and app-closed background execution on the target devices
- [ ] Sign out/switch user → local captured/review SMS cleared and no cross-user imports

Automated parser/repository/widget tests do not establish physical SMS delivery or Android background execution.

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

Alternatively, with Firebase CLI installed and authenticated, verify the intended project in `.firebaserc`, then run from the repository root:

```bash
firebase deploy --only firestore:rules
```

The updated rules include these owner-only paths under `users/{uid}`:

- `bank_sms_receipts/{receiptId}` — persistent import/link deduplication
- `personal_accounts/{accountId}` and `personal_transfers/{transferId}` — accounts and own-account transfers
- `merchant_category_rules/{ruleId}` — sender/merchant category preferences
- `personal_savings_goals/{goalId}` and `personal_savings_goals/{goalId}/entries/{entryId}` — goals and progress history

Publish the complete repository rules file so existing room/group/personal permissions remain present. No rules were deployed as part of the implementation verification; building an APK/AAB does not publish them. The new collections require no additional composite indexes beyond the existing queries listed above. Verify ownership isolation against the intended Firebase environment before release.

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

Reassess this baseline declaration for the release's actual behavior. SMS imports upload accepted parsed transaction/transfer data and import metadata; raw messages/review items remain local. Accounts, merchant preferences and savings goals are owner-scoped Firestore data. Reflect those flows and the SMS permission in the privacy policy and store declarations.

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

---

## 6. Recent Implementation Verification

The last implementation check recorded **100 passing tests** and a successful Android debug APK build. These are implementation results, not a production deployment or physical-device SMS sign-off.

```bash
flutter test --dart-define=CAPTURE_PREVIEW=true
flutter build apk --debug --no-pub
```

The optional preview flag generates fixture screenshots under ignored `build/previews/`, including calendar light/dark views, Monthly Money Review, Savings Goals/detail, merchant rules and the Personal tools entry points. The debug APK is `build/app/outputs/flutter-apk/app-debug.apk`. Targeted analysis had no errors or warnings, with style information remaining; this is not a claim that whole-project analysis is clean.

Feature behavior and test scope are detailed in [personal finance additions](../PERSONAL_FINANCE_FEATURES.md). Complete the checklists above before a production release.
