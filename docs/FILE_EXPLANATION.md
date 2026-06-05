# SplitEx — File-by-File Explanation

Every file in the project explained with **What** it does and **Why** it exists.

---

## Root Files

### `pubspec.yaml`
- **What:** Declares app dependencies, metadata, version, and assets.
- **Why:** Flutter needs this to resolve packages, manage versions, and include fonts/assets in the build.

### `analysis_options.yaml`
- **What:** Linting rules for Dart code.
- **Why:** Enforces code quality standards across the project.

### `README.md`
- **What:** Project overview, getting started guide, and future requirements roadmap.
- **Why:** Documentation for developers and contributors.

### `FIREBASE_COLLECTIONS.md`
- **What:** Documents the Firestore database schema (collections, fields, types).
- **Why:** Serves as a reference for the data layer — ensures all developers work against the same schema.

### `firestore.rules`
- **What:** Firestore Security Rules that enforce read/write permissions server-side.
- **Why:** Prevents unauthorized data access. Only room members can read room data; only admin can delete expenses.

---

## `docs/` — Documentation

### `docs/BRD.md`
- **What:** Business Requirements Document — complete specification of what the app should do.
- **Why:** Acts as the single source of truth for features, user roles, data models, and constraints.

### `docs/HID.md`
- **What:** Hierarchical Implementation Document — development order with dependency tree.
- **Why:** Ensures features are built in the correct sequence (can't build expenses before rooms exist).

### `docs/PRODUCTION_CHECKLIST.md`
- **What:** Pre-release checklist (disable dev mode, deploy rules, test flows).
- **Why:** Prevents shipping a broken or insecure app to production.

### `docs/PLAYSTORE_DEPLOYMENT.md`
- **What:** Step-by-step Play Store publishing guide with asset requirements.
- **Why:** Covers everything needed to get the app from code to live on the store.

### `docs/APP_HELPER.md`
- **What:** High-level app flow, architecture diagram, and design decisions.
- **Why:** Helps new developers (or future-you) understand how the app works without reading every file.

---

## `lib/` — Application Source Code

### `lib/main.dart`
- **What:** App entry point. Initializes Firebase, Firestore persistence, notifications, FCM, and runs the app.
- **Why:** Every Flutter app needs a `main()`. This sets up all infrastructure before the UI renders.

### `lib/app.dart`
- **What:** Root `MaterialApp.router` widget. Applies theme, dark mode, router config, and offline banner.
- **Why:** Separates app shell configuration from initialization logic in `main.dart`.

---

## `lib/config/` — App Configuration

### `lib/config/constants.dart`
- **What:** Defines app-wide constants — app name, expense categories list, category icons, pagination limits.
- **Why:** Single source for magic values. Change a category here, it updates everywhere.

### `lib/config/dev_config.dart`
- **What:** Development mode flags — `skipAuth` (bypass login), `devUserId` (simulate a user).
- **Why:** Allows rapid testing without signing in every time. Multi-device testing by changing user ID.

### `lib/config/router.dart`
- **What:** GoRouter configuration — all routes, auth guards (redirect unauthenticated users to login).
- **Why:** Centralized navigation. Auth redirect ensures users can't access screens without logging in.

### `lib/config/theme.dart`
- **What:** Complete theme system — 10 color palettes, light/dark/deep-dark themes, Material 3 styling.
- **Why:** Consistent design language. Users can pick their preferred palette and theme mode.

---

## `lib/models/` — Data Models

### `lib/models/user_model.dart`
- **What:** User data class — uid, name, email, avatarUrl, upiId, rooms list, createdAt.
- **Why:** Represents a user profile in Firestore. Used for displaying names in rooms and UPI settlements.

### `lib/models/room_model.dart`
- **What:** Room data class — id, name, inviteCode, adminId, memberIds, currentMonth, isLocked.
- **Why:** Represents a shared space. Controls who can see/edit data and whether the month's expenses are locked.

### `lib/models/expense_model.dart`
- **What:** Expense data class — title, amount, category, date, paidBy, splitType, splitAmong, month.
- **Why:** Core data unit of the app. Every expense is tracked with who paid, how it's split, and when.

### `lib/models/activity_model.dart`
- **What:** Activity log entry — type (added/edited/deleted/settlement), performedBy, description, metadata.
- **Why:** Audit trail. Users can see who did what and when — builds trust in shared finances.

### `lib/models/bill_model.dart`
- **What:** Fixed bill data class — type (rent/electricity/water), amount, paidBy, month, receiptUrl.
- **Why:** Handles recurring fixed bills separately from ad-hoc expenses (different UI/logic).

### `lib/models/settlement_model.dart`
- **What:** Settlement record — fromUserId, toUserId, amount, status (pending/confirmed), upiRef.
- **Why:** Tracks who paid whom and whether the payment was confirmed. Prevents disputes.

### `lib/models/notification_model.dart`
- **What:** In-app notification — roomId, targetUserId, title, body, type, isRead.
- **Why:** Powers the notification feed and unread badge. Users know when expenses are added without opening the app.

---

## `lib/services/` — Business Logic & Firebase Operations

### `lib/services/auth_service.dart`
- **What:** Firebase Auth operations — signIn (email/Google), signUp, signOut, resetPassword, deleteAccount.
- **Why:** Encapsulates all authentication logic. Screens don't talk to Firebase directly.

### `lib/services/user_service.dart`
- **What:** Firestore user CRUD — createUserProfile, getUserProfile, updateUserProfile, userStream.
- **Why:** Manages the `users` collection. Used by profile setup, edit profile, and member name display.

### `lib/services/room_service.dart`
- **What:** Room CRUD — createRoom (generate invite code), joinRoom, getRoomStream, removeMember.
- **Why:** Handles room lifecycle. Generates unique invite codes for sharing.

### `lib/services/expense_service.dart`
- **What:** Expense CRUD — addExpense, updateExpense, deleteExpense, getExpensesStream (with month filter).
- **Why:** Core service. Every expense operation goes through here, including triggering activity logs.

### `lib/services/balance_service.dart`
- **What:** Calculates net balances from expenses — who owes whom and how much.
- **Why:** The heart of a split app. Reads all expenses for a month and computes the debt matrix.

### `lib/services/settlement_service.dart`
- **What:** Settlement CRUD — createSettlement, confirmSettlement, getSettlementsStream.
- **Why:** Manages the payment lifecycle (pending → confirmed).

### `lib/services/activity_service.dart`
- **What:** Writes activity log entries to Firestore when expenses/settlements change.
- **Why:** Provides transparency. All actions are logged with actor, action, and details.

### `lib/services/bill_service.dart`
- **What:** Fixed bill CRUD — addBill, getBillsStream (for rent, electricity, water).
- **Why:** Separate handling for bills that have receipt uploads and different split logic.

### `lib/services/notification_service.dart`
- **What:** Initializes flutter_local_notifications, creates notification channels, shows system notifications.
- **Why:** Displays OS-level notifications when the app detects new activity.

### `lib/services/notification_listener.dart`
- **What:** Firestore stream listener that watches for new notification documents and triggers local notifications.
- **Why:** Since we don't use Cloud Functions, this client-side listener acts as the notification trigger.

### `lib/services/notification_helper.dart`
- **What:** Helper to create NotificationModel documents in Firestore when actions occur.
- **Why:** Centralized notification creation logic — called by expense/settlement services.

### `lib/services/fcm_service.dart`
- **What:** Firebase Cloud Messaging setup — token management, topic subscription.
- **Why:** Enables push notifications when the app upgrades to Blaze plan or uses server triggers.

### `lib/services/upi_service.dart`
- **What:** Constructs UPI intent URLs and launches payment apps (GPay, PhonePe, Paytm).
- **Why:** Allows one-tap settlement payments with pre-filled receiver ID and amount.

### `lib/services/upload_service.dart`
- **What:** Uploads files (receipt images, avatars) to Firebase Storage.
- **Why:** Generic upload utility used by expense receipts and profile photo features.

### `lib/services/receipt_generator.dart`
- **What:** Generates PDF receipts/reports from expense data.
- **Why:** Users can export or share expense summaries as PDF documents.

### `lib/services/storage_management_service.dart`
- **What:** Admin utility to check Firestore document counts and Storage usage.
- **Why:** Helps admins monitor free tier usage and clean up old data.

---

## `lib/providers/` — State Management (Riverpod)

### `lib/providers/auth_provider.dart`
- **What:** Exposes authServiceProvider, userServiceProvider, authStateProvider (stream), userProfileProvider.
- **Why:** All auth-related state in one place. Screens watch these to react to login/logout.

### `lib/providers/room_provider.dart`
- **What:** userRoomsProvider (stream of user's rooms), currentRoomProvider, roomMembersProvider.
- **Why:** Provides room data to home screen, drawer, and all room-scoped screens.

### `lib/providers/expense_provider.dart`
- **What:** expensesStreamProvider, monthExpensesProvider, expense filter/sort state.
- **Why:** Screens watch these to display expense lists. Month-scoped for billing cycles.

### `lib/providers/dashboard_provider.dart`
- **What:** monthOverallBalanceProvider, currentUserIdProvider, recentActivitiesProvider.
- **Why:** Powers the home screen — balance card, activity feed, spending summaries.

### `lib/providers/activity_provider.dart`
- **What:** activitiesStreamProvider (for activity log screen), recentActivitiesProvider (for home screen).
- **Why:** Real-time activity feed that updates as actions happen.

### `lib/providers/settlement_provider.dart`
- **What:** settlementsStreamProvider, debts calculation, settlement state.
- **Why:** Provides settlement data to the settlement screen and dashboard.

### `lib/providers/bill_provider.dart`
- **What:** billsStreamProvider for the bills section.
- **Why:** Streams fixed bills for display and management.

### `lib/providers/notification_provider.dart`
- **What:** notificationsStreamProvider, unreadCountProvider.
- **Why:** Powers the notification bell badge and notification list screen.

### `lib/providers/theme_provider.dart`
- **What:** themeModeProvider, appPaletteProvider — persisted to SharedPreferences.
- **Why:** Allows users to switch themes/palettes and persist the choice across sessions.

### `lib/providers/connectivity_provider.dart`
- **What:** Monitors network connectivity status.
- **Why:** Drives the offline banner widget — shows "No internet" when disconnected.

---

## `lib/screens/` — UI Screens

### `lib/screens/auth/login_screen.dart`
- **What:** Email/password login form + Google Sign-In button + Forgot Password link.
- **Why:** Entry point for existing users. Guards all app content behind authentication.

### `lib/screens/auth/register_screen.dart`
- **What:** Registration form — name, email, password fields.
- **Why:** New users create accounts here before being redirected to profile setup.

### `lib/screens/profile/profile_setup_screen.dart`
- **What:** One-time setup after first login — enter display name.
- **Why:** Ensures every user has a name to display in rooms before they can proceed.

### `lib/screens/home/home_screen.dart`
- **What:** Main app screen — greeting, balance card, room info, category chart, quick actions, activity feed, drawer.
- **Why:** The dashboard. Users see their financial status at a glance and access all features.

### `lib/screens/room/create_room_screen.dart`
- **What:** Form to create a new room (enter name → generates invite code).
- **Why:** Users need to create a shared space before tracking expenses.

### `lib/screens/room/join_room_screen.dart`
- **What:** Form to enter an invite code and join an existing room.
- **Why:** Second user onboarding — roommates join using a code shared by the creator.

### `lib/screens/room/room_list_screen.dart`
- **What:** Lists all rooms the user belongs to.
- **Why:** Navigation hub when multi-room support is enabled.

### `lib/screens/room/room_detail_screen.dart`
- **What:** Room's main view — tabs for expenses, settlements, members, bills.
- **Why:** Everything related to a specific room in one place.

### `lib/screens/room/room_settings_screen.dart`
- **What:** Room configuration — member list, invite code, admin controls (remove member, lock month).
- **Why:** Admin needs to manage the room. Members can see who's in the group.

### `lib/screens/expense/add_expense_screen.dart`
- **What:** Full-page expense form (title, amount, category, date, split type, members).
- **Why:** Primary data entry screen. Used when navigating from room detail.

### `lib/screens/expense/add_expense_sheet.dart`
- **What:** Bottom sheet version of add expense — quick entry from home screen.
- **Why:** Faster UX. Users can add expenses without leaving the home screen.

### `lib/screens/expense/edit_expense_screen.dart`
- **What:** Pre-filled expense form for editing an existing expense.
- **Why:** Users/admins need to correct mistakes (wrong amount, wrong category).

### `lib/screens/expense/expense_list_screen.dart`
- **What:** Paginated list of all expenses with filter chips (by category, person, date).
- **Why:** Users need to browse and search past expenses.

### `lib/screens/expense/view_expense_sheet.dart`
- **What:** Read-only bottom sheet showing expense details (who paid, split breakdown).
- **Why:** Quick view without navigating to a new screen.

### `lib/screens/bills/add_bill_screen.dart`
- **What:** Form for adding fixed monthly bills (rent, electricity, water) with receipt upload.
- **Why:** Bills have different logic — they're recurring and may need proof of payment.

### `lib/screens/bills/add_bill_sheet.dart`
- **What:** Bottom sheet version of bill entry.
- **Why:** Quick bill logging from the room detail screen.

### `lib/screens/bills/view_bill_sheet.dart`
- **What:** View bill details including receipt image.
- **Why:** Members can verify bills by seeing the uploaded receipt.

### `lib/screens/dashboard/dashboard_screen.dart`
- **What:** Detailed room dashboard — per-member balances, who-owes-whom, charts.
- **Why:** Deeper analytics beyond the home screen summary.

### `lib/screens/analytics/analytics_screen.dart`
- **What:** Charts screen — spend by person (bar chart), spend by category (pie chart).
- **Why:** Visual representation helps users understand spending patterns.

### `lib/screens/activity/activity_screen.dart`
- **What:** Chronological timeline of all room actions — expenses added/edited/deleted, settlements, members joining.
- **Why:** Transparency and accountability. Everyone can see what happened.

### `lib/screens/settlement/settlement_screen.dart`
- **What:** Shows debts with "Pay via UPI" buttons and settlement confirmation.
- **Why:** End-of-month flow. Users see what they owe and can pay with one tap.

### `lib/screens/settlement/upi_id_dialog.dart`
- **What:** Dialog to set/update user's UPI ID before settlement.
- **Why:** UPI payments need a receiver ID. This prompts users who haven't set one.

### `lib/screens/reminders/notifications_screen.dart`
- **What:** In-app notification feed — list of all notifications with read/unread state.
- **Why:** Users review past notifications and mark them as read.

### `lib/screens/admin/storage_management_screen.dart`
- **What:** Admin-only screen showing Firestore document counts and storage usage.
- **Why:** Helps admins stay within free tier limits and identify cleanup needs.

### `lib/screens/settings/settings_screen.dart`
- **What:** Main settings page — edit profile, change password, delete account, currency, notifications, legal, logout, version.
- **Why:** Centralized user preferences and account management.

### `lib/screens/settings/edit_profile_screen.dart`
- **What:** Update display name and profile photo (upload to Firebase Storage).
- **Why:** Users need to change how they appear to roommates.

### `lib/screens/settings/change_password_screen.dart`
- **What:** Re-authenticate with current password, then set new password.
- **Why:** Security requirement. Google-only users see an appropriate message instead.

### `lib/screens/settings/notification_preferences_screen.dart`
- **What:** Toggle switches for expense/reminder/settlement notifications (saved to SharedPreferences).
- **Why:** Users control what alerts they receive — required by app store guidelines.

---

## `lib/utils/` — Utility Functions

### `lib/utils/split_calculator.dart`
- **What:** Pure functions to calculate split amounts — equal split, dynamic split, custom split.
- **Why:** Reusable math logic separated from UI. Easy to unit test.

---

## `lib/widgets/` — Reusable Widgets

### `lib/widgets/offline_banner.dart`
- **What:** Persistent banner at top of screen when device is offline.
- **Why:** Users need to know their actions are queued and not yet synced.

### `lib/widgets/receipt_picker.dart`
- **What:** Image picker widget for selecting/capturing receipt photos.
- **Why:** Reused across expense and bill screens for receipt attachment.

---

## `android/` — Android Platform Code

### `android/app/build.gradle.kts`
- **What:** Android build configuration — SDK versions, dependencies, signing config.
- **Why:** Defines how the Android APK/AAB is compiled.

### `android/app/src/main/AndroidManifest.xml`
- **What:** App permissions, activity declarations, intent filters.
- **Why:** Required by Android OS. Declares what the app needs (internet, camera, notifications).

### `android/build.gradle.kts`
- **What:** Project-level Gradle config — repositories, classpath dependencies.
- **Why:** Sets up the build tool chain for the Android module.

### `android/settings.gradle.kts`
- **What:** Declares which Gradle modules to include in the build.
- **Why:** Required by Gradle to discover the `:app` module and Flutter plugins.

---

## `assets/` — Static Assets

### `assets/fonts/Gilmer-*.otf`
- **What:** Custom Gilmer font family (Light, Regular, Medium, Bold, Heavy weights).
- **Why:** Gives the app a distinct, polished look beyond default system fonts.

---

## Summary Table

| Layer | Count | Purpose |
|-------|-------|---------|
| Config | 4 files | Theme, routing, constants, dev flags |
| Models | 7 files | Data structures for Firestore documents |
| Services | 16 files | Firebase operations & business logic |
| Providers | 10 files | Reactive state management |
| Screens | 24 files | User interface |
| Widgets | 2 files | Reusable UI components |
| Utils | 1 file | Pure utility functions |
| Docs | 5 files | Documentation & guides |
| **Total** | **~69 files** | |

---

*End of Document*
