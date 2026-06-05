# Production Setup - Manual Steps

---

## 1. Generate Release Keystore

### 📟 Run in Terminal (Command Prompt)

```bash
cd c:\Users\S3378\AndroidStudioProjects\split_ex
keytool -genkey -v -keystore split-ex-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias split_ex
```

It will ask you these questions one by one. Type your answer and press Enter:

| Prompt | What to enter |
|--------|---------------|
| Enter keystore password | Choose a strong password (e.g. `SplitEx@2025`) — **write it down** |
| Re-enter new password | Same password again |
| What is your first and last name? | Your real name |
| What is the name of your organizational unit? | Anything (e.g. `Mobile`) |
| What is the name of your organization? | `SplitEx` |
| What is the name of your City or Locality? | Your city (e.g. `Mumbai`) |
| What is the name of your State or Province? | Your state (e.g. `Maharashtra`) |
| What is the two-letter country code? | `IN` (for India) |
| Is CN=... correct? | Type `yes` |
| Enter key password for split_ex | Just press Enter (uses same password) |

After this, a file called `split-ex-release.jks` will appear in your project root folder.

> ⚠️ **NEVER delete or lose this file.** Without it you cannot update your app on Play Store. Back it up to Google Drive, USB, or another safe place.

---

## 2. Update android/key.properties

### 📝 Open in any text editor (VS Code, Notepad, etc.)

File location: `android/key.properties`

Replace the placeholder values with the password you chose in Step 1:

```properties
storePassword=SplitEx@2025
keyPassword=SplitEx@2025
keyAlias=split_ex
storeFile=../../split-ex-release.jks
```

> `storeFile` path is relative to `android/app/` folder. `../../` means project root — where the `.jks` file is.

---

## 3. Add SHA-1 Fingerprints to Firebase Console

### 📟 Run in Terminal — Get debug fingerprint

```bash
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android
```

It will print something like:
```
Certificate fingerprints:
    SHA1: AA:BB:CC:DD:EE:FF:11:22:33:44:55:66:77:88:99:00:AA:BB:CC:DD
    SHA256: 12:34:56:78:...
```

**Copy the SHA1 value** (the full `AA:BB:CC:...` part).

### 📟 Run in Terminal — Get release fingerprint

```bash
keytool -list -v -keystore c:\Users\S3378\AndroidStudioProjects\split_ex\split-ex-release.jks -alias split_ex
```

It will ask for your keystore password (the one from Step 1). Enter it.

**Copy the SHA1 value** from the output.

### 🌐 Open in Browser — Add fingerprints to Firebase

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Click ⚙️ (gear icon, top-left) → **Project settings**
4. Scroll down to **Your apps** section → find the Android app (`com.splitex.in.app`)
5. Click **Add fingerprint**
6. Paste the **debug SHA-1** → Click **Save**
7. Click **Add fingerprint** again
8. Paste the **release SHA-1** → Click **Save**
9. Click **Download google-services.json** button
10. Replace the file at `android/app/google-services.json` with the newly downloaded one

---

## 4. Deploy Firestore Rules

### 🌐 Open in Browser

1. Go to [Firebase Console](https://console.firebase.google.com) → Select your project
2. Left sidebar → Click **Firestore Database**
3. Click the **Rules** tab (at the top)
4. **Select all** the existing text and **delete** it
5. Now open the file `firestore.rules` from your project root in any text editor
6. **Copy everything** from that file
7. **Paste** it into the Firebase Rules editor
8. Click the blue **Publish** button

You should see a green checkmark confirming the rules are live.

---

## 5. Enable Auth Providers

### 🌐 Open in Browser

1. Go to [Firebase Console](https://console.firebase.google.com) → Select your project
2. Left sidebar → Click **Authentication**
3. Click **Get started** if it's your first time (otherwise go to **Sign-in method** tab)

**Enable Email/Password:**
1. Click on **Email/Password**
2. Toggle the first switch **ON**
3. Leave "Email link (passwordless sign-in)" OFF
4. Click **Save**

**Enable Google Sign-In:**
1. Click **Add new provider**
2. Select **Google**
3. Toggle it **ON**
4. Select your Gmail as the **Project support email**
5. Click **Save**

---

## 6. Enable Crashlytics

### 🌐 Open in Browser

1. Go to [Firebase Console](https://console.firebase.google.com) → Select your project
2. Left sidebar → Click **Crashlytics**
3. If it shows a setup wizard, just click through it
4. It will show "Waiting for your first crash report" — this is normal

Crashlytics will start working automatically once you run the release app and it encounters any crash. No additional setup needed — the code is already integrated.

### 📟 (Optional) Verify with a test crash — Run in Terminal

Build and install the release app:
```bash
cd c:\Users\S3378\AndroidStudioProjects\split_ex
flutter build apk --release
flutter install --release
```

Open the app → use it briefly → close it. Check the Crashlytics dashboard after 5 minutes. If no crash happened, that's actually good — means your app is stable!

---

## 7. Delete Test Data from Firestore

### 🌐 Open in Browser

1. Go to [Firebase Console](https://console.firebase.google.com) → Select your project
2. Left sidebar → Click **Firestore Database**
3. Make sure you're on the **Data** tab

**Delete test users:**
1. Click on the `users` collection (left panel)
2. You'll see documents listed. Find `dev_user_001`
3. Click on it → Click the **⋮** (three dots) at the top-right → **Delete document**
4. Confirm deletion
5. Repeat for `dev_user_002` and `dev_user_003`

**Delete test rooms:**
1. Click on the `rooms` collection
2. Click on each room document
3. Look at the `memberIds` field — if it contains `dev_user_001`, `dev_user_002`, or `dev_user_003`, delete that room
4. Click **⋮** → **Delete document** → Check "Also delete subcollections" → Confirm

**Delete test notifications:**
1. Click on the `notifications` collection
2. Look for documents where `targetUserId` = `dev_user_001`, `dev_user_002`, or `dev_user_003`
3. Delete each one

> 💡 If ALL your data is test data (no real users yet), you can delete entire collections:
> Click ⋮ next to collection name → **Delete collection** → Confirm

---

## Final Verification

### 📟 Run in Terminal

```bash
cd c:\Users\S3378\AndroidStudioProjects\split_ex
flutter build apk --release
flutter install --release
```

### ✅ Test on your phone

- [ ] App opens to Login screen (NOT home screen)
- [ ] Google Sign-In button works → signs you in
- [ ] Email registration works → creates account
- [ ] After login → Profile setup screen appears
- [ ] After profile setup → Home screen with room list
- [ ] Create a room → works
- [ ] Add an expense → works
- [ ] Dashboard shows correct balances
- [ ] Notifications arrive
- [ ] Check Firebase Crashlytics dashboard (should show no crashes = good!)

---

## Summary of Icons Used

| Icon | Meaning |
|------|---------|
| 📟 | Run this command in Terminal / Command Prompt |
| 🌐 | Do this in your web browser (Firebase Console) |
| 📝 | Edit a file in text editor |
| ✅ | Manual testing on phone |
