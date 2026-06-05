# Hierarchical Implementation Document (HID)
## SplitEx — Development Roadmap & Execution Order

---

## Overview

This document defines the **exact order** of implementation, structured as a dependency tree. Each phase builds on the previous one. No phase can begin until its prerequisites are complete.

---

## Phase 0: Project Setup & Configuration
> **Duration**: 1-2 days | **Prerequisites**: None

```
Phase 0: Foundation
├── 0.1 Flutter project cleanup (remove boilerplate)
├── 0.2 Folder structure setup
│     ├── lib/models/
│     ├── lib/services/
│     ├── lib/providers/
│     ├── lib/screens/
│     ├── lib/widgets/
│     ├── lib/utils/
│     └── lib/config/
├── 0.3 pubspec.yaml dependencies
│     ├── flutter_riverpod
│     ├── riverpod_annotation + riverpod_generator
│     ├── firebase_core
│     ├── firebase_auth
│     ├── cloud_firestore
│     ├── firebase_messaging
│     ├── flutter_local_notifications
│     ├── fl_chart
│     ├── url_launcher
│     ├── google_sign_in
│     ├── go_router (navigation)
│     ├── intl (date formatting)
│     └── uuid
├── 0.4 Firebase project creation (Console)
│     ├── Create Firebase project
│     ├── Add Android app (google-services.json)
│     ├── Add iOS app (GoogleService-Info.plist)
│     └── Enable Auth providers (Email, Google)
├── 0.5 Firebase initialization in main.dart
├── 0.6 App theming & constants
│     ├── Color palette
│     ├── Text styles
│     └── App-wide constants (categories list, etc.)
└── 0.7 Router setup (go_router with auth redirect)
```

---

## Phase 1: Authentication & User Profile
> **Duration**: 3-4 days | **Prerequisites**: Phase 0

```
Phase 1: Auth
├── 1.1 Data Models
│     └── lib/models/user_model.dart
│           ├── uid, name, email, avatarUrl, upiId, rooms[]
│           └── fromMap() / toMap() serialization
├── 1.2 Auth Service
│     └── lib/services/auth_service.dart
│           ├── signInWithEmail()
│           ├── signUpWithEmail()
│           ├── signInWithGoogle()
│           ├── signOut()
│           └── currentUser stream
├── 1.3 Firestore User Service
│     └── lib/services/user_service.dart
│           ├── createUserProfile()
│           ├── getUserProfile()
│           ├── updateUserProfile()
│           └── userStream()
├── 1.4 Auth Providers
│     └── lib/providers/auth_provider.dart
│           ├── authStateProvider (stream)
│           ├── currentUserProvider
│           └── userProfileProvider
├── 1.5 Screens
│     ├── lib/screens/auth/login_screen.dart
│     │     ├── Email + Password fields
│     │     ├── Google Sign-In button
│     │     └── Navigate to Register
│     ├── lib/screens/auth/register_screen.dart
│     │     ├── Name, Email, Password fields
│     │     └── Create account → auto-login
│     └── lib/screens/profile/profile_setup_screen.dart
│           ├── Display name
│           ├── UPI ID input
│           └── Save → Navigate to Room List
└── 1.6 Auth Guard (Router redirect)
      ├── Unauthenticated → Login
      ├── No profile → Profile Setup
      └── Authenticated → Room List
```

---

## Phase 2: Room Management
> **Duration**: 3-4 days | **Prerequisites**: Phase 1

```
Phase 2: Rooms
├── 2.1 Data Models
│     └── lib/models/room_model.dart
│           ├── id, name, inviteCode, adminId, memberIds[]
│           ├── createdAt, currentMonth, isLocked
│           └── fromMap() / toMap()
├── 2.2 Room Service
│     └── lib/services/room_service.dart
│           ├── createRoom() → generates unique invite code
│           ├── joinRoom(inviteCode)
│           ├── getRoomStream(roomId)
│           ├── getUserRoomsStream(userId)
│           ├── removeMember(roomId, userId)
│           └── transferAdmin(roomId, newAdminId)
├── 2.3 Room Providers
│     └── lib/providers/room_provider.dart
│           ├── userRoomsProvider (stream of user's rooms)
│           ├── currentRoomProvider (selected room)
│           └── roomMembersProvider (member profiles)
├── 2.4 Screens
│     ├── lib/screens/room/room_list_screen.dart
│     │     ├── List of user's rooms
│     │     ├── Create Room FAB
│     │     └── Join Room button
│     ├── lib/screens/room/create_room_screen.dart
│     │     ├── Room name input
│     │     └── Display generated invite code (share)
│     ├── lib/screens/room/join_room_screen.dart
│     │     └── Invite code input → join
│     └── lib/screens/room/room_settings_screen.dart
│           ├── Member list with roles
│           ├── Invite code display + copy
│           └── Admin: Remove member option
└── 2.5 Firestore Security Rules (rooms collection)
```

---

## Phase 3: Expense Management (Core)
> **Duration**: 4-5 days | **Prerequisites**: Phase 2

```
Phase 3: Expenses
├── 3.1 Data Models
│     └── lib/models/expense_model.dart
│           ├── id, title, amount, category, date
│           ├── paidBy, splitType, splitAmong[]
│           ├── createdBy, createdAt, updatedAt, month
│           └── fromMap() / toMap()
├── 3.2 Expense Service
│     └── lib/services/expense_service.dart
│           ├── addExpense(roomId, expense)
│           ├── updateExpense(roomId, expenseId, data)
│           ├── deleteExpense(roomId, expenseId) [admin check]
│           ├── getExpensesStream(roomId, month)
│           └── getExpensesByCategory(roomId, month)
├── 3.3 Splitting Logic
│     └── lib/utils/split_calculator.dart
│           ├── calculateEqualSplit(amount, members)
│           ├── calculateDynamicSplit(amount, selectedMembers)
│           └── calculateOneToOneSplit(amount, fromUser, toUser)
├── 3.4 Expense Providers
│     └── lib/providers/expense_provider.dart
│           ├── expensesStreamProvider(roomId, month)
│           ├── addExpenseProvider
│           └── expenseFilterProvider
├── 3.5 Screens
│     ├── lib/screens/expense/add_expense_screen.dart
│     │     ├── Title, Amount, Category dropdown, Date picker
│     │     ├── Split type selector (Equal / Dynamic / 1-to-1)
│     │     ├── Member checkboxes (for dynamic split)
│     │     └── Save button
│     ├── lib/screens/expense/edit_expense_screen.dart
│     │     ├── Pre-filled form
│     │     └── Role check: own expense OR admin
│     └── lib/screens/expense/expense_list_screen.dart
│           ├── List with category icons
│           ├── Swipe to delete (admin only)
│           └── Filter chips (category, person)
└── 3.6 Firestore Security Rules (expenses subcollection)
      ├── Create: any room member
      ├── Update: creator OR admin
      └── Delete: admin only
```

---

## Phase 4: Dashboard & Balance Calculation
> **Duration**: 3-4 days | **Prerequisites**: Phase 3

```
Phase 4: Dashboard
├── 4.1 Balance Calculation Engine
│     └── lib/utils/balance_calculator.dart
│           ├── calculateNetBalances(expenses, members)
│           │     └── Returns Map<userId, Map<userId, double>>
│           ├── simplifyDebts(balanceMatrix)
│           │     └── Minimize number of transactions
│           ├── getUserBalance(userId, balanceMatrix)
│           │     └── Returns {owes: X, owed: Y}
│           └── getWhoOwesWhom(balanceMatrix)
│                 └── Returns list of (from, to, amount)
├── 4.2 Balance Providers
│     └── lib/providers/balance_provider.dart
│           ├── balanceMatrixProvider(roomId)
│           ├── userBalanceProvider(userId, roomId)
│           └── simplifiedDebtsProvider(roomId)
├── 4.3 Dashboard Screen
│     └── lib/screens/dashboard/dashboard_screen.dart
│           ├── Balance card ("You owe ₹X" / "You are owed ₹Y")
│           ├── Who-owes-whom summary list
│           ├── Total room spend this month
│           ├── Recent 5 expenses
│           └── Bottom navigation (Dashboard, Expenses, Analytics, More)
└── 4.4 Shared Widgets
      ├── lib/widgets/balance_card.dart
      ├── lib/widgets/expense_tile.dart
      └── lib/widgets/who_owes_whom_card.dart
```

---

## Phase 5: Activity Log / Audit Trail
> **Duration**: 2 days | **Prerequisites**: Phase 3

```
Phase 5: Audit Trail
├── 5.1 Data Model
│     └── lib/models/activity_log_model.dart
│           ├── id, userId, userName, action
│           ├── expenseTitle, amount, oldAmount
│           ├── timestamp, details
│           └── fromMap() / toMap()
├── 5.2 Activity Log Service
│     └── lib/services/activity_log_service.dart
│           ├── logAction(roomId, logEntry)
│           └── getActivityStream(roomId)
├── 5.3 Integration into Expense Service
│     ├── On addExpense → log "added"
│     ├── On updateExpense → log "edited" with old/new values
│     └── On deleteExpense → log "deleted"
├── 5.4 Activity Log Provider
│     └── lib/providers/activity_log_provider.dart
│           └── activityStreamProvider(roomId)
└── 5.5 Screen
      └── lib/screens/activity/activity_log_screen.dart
            ├── Chronological timeline UI
            ├── Icon per action type (add/edit/delete)
            └── Timestamp + user name + details
```

---

## Phase 6: Notifications (Local + FCM)
> **Duration**: 3-4 days | **Prerequisites**: Phase 5

```
Phase 6: Notifications
├── 6.1 FCM Setup
│     ├── Enable FCM in Firebase Console
│     ├── Android: Update AndroidManifest.xml
│     └── iOS: APNs certificate setup
├── 6.2 Notification Service
│     └── lib/services/notification_service.dart
│           ├── initialize()
│           ├── requestPermissions()
│           ├── subscribeToRoomTopic(roomId)
│           ├── unsubscribeFromRoomTopic(roomId)
│           └── showLocalNotification(title, body)
├── 6.3 Firestore Listener-based Notifications
│     └── lib/services/expense_listener_service.dart
│           ├── Listen to expenses collection changes
│           ├── On new doc → trigger local notification
│           ├── On modified doc → trigger edit notification
│           └── On removed doc → trigger delete notification
├── 6.4 Notification Provider
│     └── lib/providers/notification_provider.dart
│           └── Manages notification state & in-app feed
└── 6.5 In-App Notification Feed (Optional)
      └── lib/screens/notifications/notification_feed_screen.dart
```

---

## Phase 7: Visual Analytics & Charts
> **Duration**: 2-3 days | **Prerequisites**: Phase 4

```
Phase 7: Analytics
├── 7.1 Analytics Calculation
│     └── lib/utils/analytics_calculator.dart
│           ├── spendByPerson(expenses, members) → Map<name, amount>
│           └── spendByCategory(expenses) → Map<category, amount>
├── 7.2 Analytics Providers
│     └── lib/providers/analytics_provider.dart
│           ├── spendByPersonProvider(roomId, month)
│           └── spendByCategoryProvider(roomId, month)
└── 7.3 Analytics Screen
      └── lib/screens/analytics/analytics_screen.dart
            ├── Tab 1: By Person (Bar chart)
            └── Tab 2: By Category (Pie chart)
```

---

## Phase 8: Settlement & UPI Payments
> **Duration**: 3 days | **Prerequisites**: Phase 4

```
Phase 8: Settlement
├── 8.1 Data Model
│     └── lib/models/settlement_model.dart
│           ├── id, month, fromUserId, toUserId
│           ├── amount, status, settledAt, lockedAt
│           └── fromMap() / toMap()
├── 8.2 Settlement Service
│     └── lib/services/settlement_service.dart
│           ├── closeMonth(roomId) [admin only]
│           │     ├── Set room.isLocked = true
│           │     ├── Calculate final balances
│           │     └── Create settlement docs (pending)
│           ├── markAsSettled(roomId, settlementId)
│           ├── getSettlementsStream(roomId, month)
│           └── getSettlementHistory(roomId)
├── 8.3 UPI Utility
│     └── lib/utils/upi_launcher.dart
│           ├── launchUPI(upiId, amount, name, note)
│           │     └── Format: upi://pay?pa={id}&pn={name}&am={amount}&cu=INR&tn={note}
│           └── copyPaymentDetails(upiId, amount)
├── 8.4 Settlement Providers
│     └── lib/providers/settlement_provider.dart
│           ├── settlementsProvider(roomId, month)
│           └── settlementHistoryProvider(roomId)
└── 8.5 Screens
      ├── lib/screens/settlement/settlement_screen.dart
      │     ├── Net balance per person
      │     ├── "Pay via UPI" button per entry
      │     ├── "Mark as Settled" button
      │     └── Admin: "Close Month" button at top
      └── lib/screens/settlement/history_screen.dart
            └── Past months' settlement records
```

---

## Phase 9: Smart Reminders
> **Duration**: 2-3 days | **Prerequisites**: Phase 6

```
Phase 9: Reminders
├── 9.1 Data Model
│     └── lib/models/reminder_model.dart
│           ├── id, title, scheduledDate, recurringDay
│           ├── advanceHours, targetUserIds[]
│           ├── isActive, createdBy
│           └── fromMap() / toMap()
├── 9.2 Reminder Service
│     └── lib/services/reminder_service.dart
│           ├── createReminder(roomId, reminder)
│           ├── sendManualReminder(roomId, targetUserId)
│           ├── getRemindersStream(roomId)
│           ├── toggleReminder(roomId, reminderId)
│           └── deleteReminder(roomId, reminderId)
├── 9.3 Local Scheduled Notifications
│     └── Extend notification_service.dart
│           ├── scheduleNotification(dateTime, title, body)
│           └── cancelScheduledNotification(id)
├── 9.4 Reminder Provider
│     └── lib/providers/reminder_provider.dart
│           └── remindersStreamProvider(roomId)
└── 9.5 Screen
      └── lib/screens/reminders/reminders_screen.dart
            ├── Active reminders list
            ├── Add reminder form (title, day, time, advance)
            └── Admin: "Send Reminder Now" per user with dues
```

---

## Phase 10: Polish & Production Readiness
> **Duration**: 3-4 days | **Prerequisites**: All above phases

```
Phase 10: Polish
├── 10.1 Error Handling
│     ├── Global error boundary
│     ├── Firestore error handling (quota, network)
│     └── User-friendly error messages
├── 10.2 Loading States
│     ├── Shimmer/skeleton loaders
│     └── Pull-to-refresh on lists
├── 10.3 Empty States
│     ├── No rooms yet
│     ├── No expenses this month
│     └── No activity log
├── 10.4 Offline Indicator
│     └── Banner when no connectivity
├── 10.5 App Icon & Splash Screen
├── 10.6 Firestore Security Rules (final)
│     └── Deploy complete rule set
├── 10.7 Performance Optimization
│     ├── Paginate expense lists (20 per page)
│     ├── Cache user profiles locally
│     └── Minimize Firestore reads
└── 10.8 Testing
      ├── Unit tests: balance calculator, split logic
      ├── Widget tests: key screens
      └── Manual QA pass
```

---

## Dependency Graph (Visual)

```
Phase 0 (Setup)
    │
    ▼
Phase 1 (Auth)
    │
    ▼
Phase 2 (Rooms)
    │
    ▼
Phase 3 (Expenses) ──────────────────┐
    │                                 │
    ├──────────────┐                  │
    ▼              ▼                  ▼
Phase 4        Phase 5           Phase 6
(Dashboard)    (Audit Log)       (Notifications)
    │                                 │
    ├──────────┐                      ▼
    ▼          ▼                 Phase 9
Phase 7    Phase 8              (Reminders)
(Charts)   (Settlement)
    │          │                      │
    └──────────┴──────────────────────┘
                      │
                      ▼
               Phase 10 (Polish)
```

---

## Execution Summary

| Phase | Module | Duration | Cumulative |
|-------|--------|----------|-----------|
| 0 | Project Setup | 1-2 days | 2 days |
| 1 | Authentication | 3-4 days | 6 days |
| 2 | Room Management | 3-4 days | 10 days |
| 3 | Expense Management | 4-5 days | 15 days |
| 4 | Dashboard & Balances | 3-4 days | 19 days |
| 5 | Activity Log | 2 days | 21 days |
| 6 | Notifications | 3-4 days | 25 days |
| 7 | Analytics Charts | 2-3 days | 28 days |
| 8 | Settlement & UPI | 3 days | 31 days |
| 9 | Smart Reminders | 2-3 days | 34 days |
| 10 | Polish & Release | 3-4 days | 38 days |

**Total estimated timeline: ~5-6 weeks**

---

## File Structure (Final)

```
lib/
├── main.dart
├── app.dart
├── config/
│   ├── theme.dart
│   ├── constants.dart
│   └── router.dart
├── models/
│   ├── user_model.dart
│   ├── room_model.dart
│   ├── expense_model.dart
│   ├── activity_log_model.dart
│   ├── settlement_model.dart
│   └── reminder_model.dart
├── services/
│   ├── auth_service.dart
│   ├── user_service.dart
│   ├── room_service.dart
│   ├── expense_service.dart
│   ├── activity_log_service.dart
│   ├── settlement_service.dart
│   ├── reminder_service.dart
│   ├── notification_service.dart
│   └── expense_listener_service.dart
├── providers/
│   ├── auth_provider.dart
│   ├── room_provider.dart
│   ├── expense_provider.dart
│   ├── balance_provider.dart
│   ├── activity_log_provider.dart
│   ├── analytics_provider.dart
│   ├── settlement_provider.dart
│   ├── reminder_provider.dart
│   └── notification_provider.dart
├── screens/
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   ├── profile/
│   │   └── profile_setup_screen.dart
│   ├── room/
│   │   ├── room_list_screen.dart
│   │   ├── create_room_screen.dart
│   │   ├── join_room_screen.dart
│   │   └── room_settings_screen.dart
│   ├── dashboard/
│   │   └── dashboard_screen.dart
│   ├── expense/
│   │   ├── add_expense_screen.dart
│   │   ├── edit_expense_screen.dart
│   │   └── expense_list_screen.dart
│   ├── analytics/
│   │   └── analytics_screen.dart
│   ├── activity/
│   │   └── activity_log_screen.dart
│   ├── settlement/
│   │   ├── settlement_screen.dart
│   │   └── history_screen.dart
│   ├── reminders/
│   │   └── reminders_screen.dart
│   └── notifications/
│       └── notification_feed_screen.dart
├── widgets/
│   ├── balance_card.dart
│   ├── expense_tile.dart
│   ├── who_owes_whom_card.dart
│   ├── category_icon.dart
│   └── loading_shimmer.dart
└── utils/
    ├── split_calculator.dart
    ├── balance_calculator.dart
    ├── analytics_calculator.dart
    └── upi_launcher.dart
```

---

*Ready to begin Phase 0. Proceed?*
