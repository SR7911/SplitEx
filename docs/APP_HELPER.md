# SplitEx — App Flow & Architecture Guide

---

## What is SplitEx?

SplitEx is a dual-purpose expense management app built with Flutter + Firebase:
1. **Room-based splitting** — Roommates create shared rooms, log expenses, auto-calculate who owes whom, and settle via UPI
2. **Personal finance** — Track personal income/expenses, set budgets, manage recurring transactions, and track peer-to-peer debts (Lent/Borrowed)

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Flutter App                       │
│                                                     │
│  Screens ←→ Providers (Riverpod) ←→ Services       │
│                                          │          │
└──────────────────────────────────────────┼──────────┘
                                           │
                                           ▼
┌─────────────────────────────────────────────────────┐
│                   Firebase                           │
│  ┌──────────┐  ┌───────────┐  ┌─────────────────┐  │
│  │   Auth   │  │ Firestore │  │ Cloud Storage   │  │
│  │(Email,   │  │(Users,    │  │(Avatars,        │  │
│  │ Google)  │  │ Rooms,    │  │ Receipts)       │  │
│  └──────────┘  │ Expenses, │  └─────────────────┘  │
│                │ Settlements│                       │
│  ┌──────────┐  │ Activities)│                       │
│  │   FCM    │  └───────────┘                       │
│  │(Push)    │                                       │
│  └──────────┘                                       │
└─────────────────────────────────────────────────────┘
```

---

## App Flow (User Journey)

### 1. Authentication Flow
```
App Launch
    │
    ├── Has active session? ──Yes──→ Has profile? ──Yes──→ Home Screen
    │                                     │
    │                                     No
    │                                     │
    │                                     ▼
    │                              Profile Setup Screen
    │                              (Enter name → save to Firestore)
    No
    │
    ▼
Login Screen
    ├── Email + Password → Sign In
    ├── Google Sign-In → Auto-create session
    └── "Don't have account?" → Register Screen
                                    └── Create account → Auto-login → Profile Setup
```

**Key files:** `login_screen.dart`, `register_screen.dart`, `profile_setup_screen.dart`, `auth_service.dart`

### 2. Home Screen Flow
```
Home Screen (after auth)
    │
    ├── No rooms? → Empty state → Create/Join Room
    │
    └── Has room(s)? → Show:
         ├── Greeting header (user name + month)
         ├── Month balance card (owe/owed amount)
         ├── Room card (name, members, invite code)
         ├── Category pie chart
         ├── Spending summary (total vs personal)
         ├── Quick actions (Add Expense / Settle Up)
         ├── Recent activity feed
         └── Onboarding tips (if new user)
```

**Key files:** `home_screen.dart`, `dashboard_provider.dart`

### 3. Expense Flow
```
User taps "Add Expense"
    │
    ▼
Add Expense Sheet/Screen
    ├── Enter: Title, Amount, Category, Date
    ├── Select: Paid By (which member)
    ├── Select: Split type
    │     ├── Equal (÷ all members)
    │     ├── Dynamic (select specific members)
    │     └── Custom (manual amounts)
    └── Save
         │
         ├── Write expense to Firestore
         ├── Log activity ("User added Groceries ₹500")
         └── Trigger notification to other members
```

**Key files:** `add_expense_sheet.dart`, `expense_service.dart`, `split_calculator.dart`, `activity_service.dart`

### 4. Balance Calculation Flow
```
Expenses in Firestore (for current month)
    │
    ▼
Balance Service reads all expenses
    │
    ├── For each expense:
    │     paidBy pays full amount
    │     splitAmong[] each owe (amount ÷ split count)
    │
    ├── Build balance matrix:
    │     User A owes User B: ₹X
    │     User B owes User A: ₹Y
    │
    └── Net calculation:
          If A owes B ₹500, B owes A ₹200
          → Net: A owes B ₹300
```

**Key files:** `balance_service.dart`, `dashboard_provider.dart`

### 5. Settlement Flow
```
Room Detail → Settlements Tab
    │
    ├── Shows who-owes-whom with net amounts
    │
    ├── Debtor taps "Pay via UPI"
    │     └── Opens UPI app (GPay/PhonePe) with pre-filled:
    │           receiver UPI ID, amount, note
    │
    ├── After payment, marks settlement as "pending confirmation"
    │
    └── Receiver confirms → status = "confirmed"
         └── Activity logged
```

**Key files:** `settlement_screen.dart`, `settlement_service.dart`, `upi_service.dart`

### 6. Notification Flow
```
Expense added/edited/deleted
    │
    ├── Activity logged to Firestore
    │
    ├── Notification document created (target: other members)
    │
    └── On target user's device:
         ├── Firestore listener detects new notification doc
         ├── flutter_local_notifications shows system notification
         └── In-app badge count updates
```

**Key files:** `notification_service.dart`, `notification_listener.dart`, `fcm_service.dart`, `notifications_screen.dart`

---

### 7. Personal Finance Flow
```
Personal Tab (Bottom Nav)
    │
    ├── Dashboard shows: greeting, financial status, income/expense pills,
    │   budget usage, category budgets, pie chart, recent transactions, recurring
    │
    ├── Add Transaction (FAB)
    │     ├── Enter: Amount, Title, Category, Date, Notes
    │     ├── Optional: "Involves someone else?" toggle
    │     │     ├── "I Lent" → person owes you
    │     │     └── "I Borrowed" → you owe person
    │     └── Save → Firestore (users/{uid}/personal_transactions)
    │
    ├── All Transactions → Day-wise grouped list + FAB
    │     └── Tap → View/Edit bottom sheet (shows debt info if applicable)
    │
    ├── Reports → Bottom sheet with pie chart + daily bar chart
    │
    ├── Debts & Settlements
    │     ├── Lent section: green, "Settled?" button
    │     ├── Borrowed section: red, "Settle Up" button
    │     └── Settled items: greyed out, strikethrough, no action
    │
    ├── Budgets → Category budget management
    │
    └── Recurring → Active/Past with add/pause/delete
```

**Key files:** `personal_expense_tab.dart`, `add_personal_transaction_screen.dart`, `personal_debts_screen.dart`, `personal_expense_service.dart`, `personal_expense_provider.dart`

---

## State Management Pattern

```
Screen (UI) ←── watches ──→ Provider (Riverpod)
                                    │
                             reads/watches
                                    │
                                    ▼
                            Service (business logic)
                                    │
                              CRUD operations
                                    │
                                    ▼
                            Firebase (Firestore/Auth/Storage)
```

- **Screens** — Only UI rendering, delegates all logic to providers
- **Providers** — Expose streams/futures from services, hold transient state
- **Services** — Firestore/Auth/Storage operations, business logic
- **Models** — Data classes with `fromMap()`/`toMap()` serialization

---

## Data Flow Example: Adding an Expense

```
1. User fills form on AddExpenseSheet
2. Calls expenseService.addExpense(roomId, expenseModel)
3. expenseService writes to Firestore: rooms/{roomId}/expenses/{id}
4. expenseService calls activityService.logActivity(...)
5. activityService writes to Firestore: rooms/{roomId}/activities/{id}
6. Firestore stream triggers → expensesStreamProvider emits new list
7. All screens watching this provider rebuild with new data
8. NotificationListener detects new activity → shows local notification
9. Balance recalculates automatically (derived provider)
```

---

## Offline Behavior

```
User has no internet
    │
    ├── Firestore offline persistence kicks in
    ├── All reads serve from local cache
    ├── All writes queue locally
    ├── OfflineBanner widget shows "No connection" banner
    │
    └── Internet restored:
         ├── Queued writes sync to server
         ├── Streams emit updated data
         └── Banner disappears
```

**Key files:** `connectivity_provider.dart`, `offline_banner.dart`, Firestore settings in `main.dart`

---

## Authentication Guard (Router Redirect Logic)

```dart
redirect: (context, state) {
  isLoggedIn?
    ├── No  → redirect to /login
    └── Yes → hasProfile?
                ├── No  → redirect to /profile-setup
                └── Yes → allow navigation
}
```

**Key file:** `router.dart`

---

## Room-Based Data Isolation

All expense, settlement, and activity data is scoped under a room:
```
rooms/{roomId}/expenses/{expenseId}
rooms/{roomId}/settlements/{settlementId}
rooms/{roomId}/activities/{activityId}
```

This ensures:
- Users only see data from their own rooms
- Firestore rules can enforce membership checks
- Multiple rooms don't interfere with each other

---

## Key Design Decisions

| Decision | Why |
|----------|-----|
| Riverpod over BLoC | Less boilerplate, better provider composition |
| Firestore over REST API | Real-time streams, offline persistence, free tier |
| go_router | Declarative routing with auth guards |
| Subcollections over root collections | Data isolation per room, simpler security rules |
| Client-side notifications | No Cloud Functions needed (free tier) |
| UPI intents over payment gateway | No payment processing needed, just redirect |
| Month-based expense grouping | Natural billing cycle, efficient queries |
| Dev mode config | Easy multi-device testing without real auth |

---

## How to Run the App

### Development Mode (testing without auth)
1. Set `DevConfig.skipAuth = true` in `lib/config/dev_config.dart`
2. Set `DevConfig.devUserId` to your test user ID
3. Run: `flutter run`

### Production Mode
1. Set `DevConfig.skipAuth = false`
2. Ensure Firebase Auth providers are enabled
3. Run: `flutter run --release`

---

## Environment Setup Required

- Flutter SDK (^3.11.5)
- Dart SDK (^3.11.5)
- Firebase project with:
  - Authentication (Email + Google)
  - Cloud Firestore
  - Cloud Storage
  - Cloud Messaging (FCM)
- Android Studio / VS Code
- Physical device or emulator (API 23+)

---

*End of Document*
