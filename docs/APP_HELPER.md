# SplitEx — App Flow & Architecture Guide

Updated 2026-10-21. See the [recent changelog](CHANGELOG.md), [file reference](FILE_EXPLANATION.md) and [deployment guide](DEPLOYMENT.md). Detailed feature guides: [Bank SMS recording](../BANK_SMS_RECORDING.md) and [personal finance additions](../PERSONAL_FINANCE_FEATURES.md).

---

## What is SplitEx?

SplitEx is a multi-module expense management app built with Flutter + Firebase:
1. **Room-based splitting** — Roommates create shared rooms, log expenses, auto-calculate who owes whom, and settle via UPI
2. **Personal finance** — Track income/expenses, budgets, recurring entries, debts and loan EMIs; review bank SMS, manage accounts/transfers, browse scheduled payments, review monthly spending and track savings goals
3. **Group Expenses** — Create/join groups with invite codes, split expenses equally or selectively, view simplified debts
4. **Project Tracker** — Personal project budgets with category breakdown, vendor tracking, and status management

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
    │   budget usage, category budgets, pie chart, weekly spending summary,
    │   recent transactions, recurring
    │
    ├── Add Transaction (FAB)
    │     ├── Enter: Amount, Title, Category, Date, Notes
    │     ├── Optional: "Involves someone else?" toggle
    │     │     ├── "I Lent" → person owes you (saved as expense)
    │     │     └── "I Borrowed" → you owe person (saved as income)
    │     └── Save → Firestore (users/{uid}/personal_transactions)
    │
    ├── All Transactions → Day-wise grouped list + FAB
    │     └── Tap → View/Edit bottom sheet (shows debt info if applicable)
    │
    ├── Reports → Bottom sheet with stats, category donut, breakdown, weekly analysis, daily bar chart
    │     ├── Tap any category chip or breakdown row → filtered transaction list for that category
    │     ├── Weekly Analysis: 4-week bars (W1–W4), avg/high/low highlights, trend insight
    │     └── Daily Spending: bar chart with weekday vs weekend color coding
    │
    ├── Debts → Debt Dashboard (/personal/debt-dashboard)
    │     ├── Debt summaries, activity chart and detail sheets
    │     ├── View All → All-time list (/personal/debts)
    │     │     └── Lent / Borrowed / Settled tabs and summary
    │     └── Monthly Debts → Monthly list (/personal/debt-list)
    │           ├── Month navigation, summaries, search and filters
    │           └── Expand/collapse top categories; add debt FAB
    │
    ├── Debts & Settlements (/personal/debts)
    │     ├── Lent: Receive; Borrowed: Repay; full/partial settlement date
    │     ├── Partial debts: original amount struck before remaining balance
    │     └── Tap to edit; settlement/write-off history on each debt
    │
    ├── Budgets → Category budget management
    │     ├── Healthy: 0–70% (green)
    │     ├── Warning: 70–100% (orange)
    │     └── Over Budget: >100% (red)
    │
    └── Recurring → Active/Past with add/pause/delete
```

**Debt balance logic:**
- Lent → saved as `type: expense` (deducts balance on creation)
- Borrowed → saved as `type: income` (adds to balance on creation)
- Lent settled → auto-creates `type: income` entry in settlement month
- Borrowed repaid → auto-creates `type: expense` on the selected settlement date
- Full and partial settlements both use the chosen date; it cannot precede the original debt date
- Remaining balance = `max(0, amount - settledAmount - writtenOffAmount)`
- Close debt → warning, write off the unpaid balance, retain history; no cash transaction is generated
- Editing a debt updates its original personal transaction. Paid/written-off amounts constrain the minimum amount; settlement history restricts changes of person/direction
- Optional `dueDate` is the expected repayment date used by the calendar; it is separate from an actual settlement date

**Key files:** `personal_expense_tab.dart`, `add_personal_transaction_screen.dart`, `add_debt_sheet.dart`, `debt_dashboard_screen.dart`, `debt_list_screen.dart`, `personal_debts_screen.dart`, `personal_reports_screen.dart`, `personal_transactions_screen.dart`, `personal_transaction_reads.dart`, `firestore_personal_transaction_repository.dart`

### 8. Group Expenses Flow
```
Groups Tab (Home Screen)
    │
    ├── List of user's groups (with archived badge)
    │
    ├── Create Group → name, description, start/end dates → generates 6-char invite code
    │
    ├── Join Group → enter 6-char code → added to group memberIds
    │
    └── Group Dashboard (3 tabs)
          ├── Overview: invite code card, per-member balance cards
          ├── Expenses: list with long-press delete, FAB to add
          │     └── Add Expense Sheet: title, amount, category, date,
          │           split type (equal / select members)
          └── Settle Up: simplified debts (reuses BalanceService.simplifyDebts)

Admin controls: archive/restore group
Member controls: leave group
```

**Key files:** `groups_list_screen.dart`, `group_dashboard_screen.dart`, `group_expense_sheet.dart`, `group_service.dart`, `group_provider.dart`

### 9. Project Tracker Flow
```
Projects Tab (Home Screen)
    │
    ├── List of user's projects (budget progress bar, status badge)
    │
    ├── Create Project → name, description, type, estimated budget, dates
    │
    └── Project Dashboard (2 tabs)
          ├── Overview: budget card (spent vs estimated), category breakdown bars
          └── Expenses: list with long-press delete, FAB to add
                └── Add Expense Sheet: title, amount, category (15 universal),
                      vendor, payment method (cash/UPI/card/bank), notes

Status management: active → completed / paused (popup menu)
```

**Key files:** `projects_list_screen.dart`, `project_dashboard_screen.dart`, `add_project_expense_sheet.dart`, `project_service.dart`, `project_provider.dart`

### 10. Loan & EMI Manager Flow
```
Personal Tab → Loans & EMI
    │
    ├── Loan List Screen
    │     ├── Hero card: total outstanding, borrowed vs lent, monthly EMI
    │     ├── Per-loan card:
    │     │     ├── Remaining amount + status badge
    │     │     ├── Animated progress bar (% paid)
    │     │     ├── EMI amount chip
    │     │     ├── X/Y EMIs paid chip
    │     │     └── Next: DD MMM due date chip
    │     ├── On entry: check missed EMI dates and prompt to record them
    │     └── FAB → Add Loan sheet
    │
    ├── Add Loan Sheet
    │     ├── Loan type: Borrowed / Lent
    │     ├── Title, lender/borrower name, principal, rate, tenure, EMI due day
    │     ├── Loan Start Date picker
    │     ├── First EMI Date picker (auto = start + 1 month, overridable)
    │     ├── EMI override toggle + custom EMI field
    │     ├── Charges & Fees (processing, insurance, other, 18% GST)
    │     ├── Live EMI preview + total payable
    │     └── On save: checks for missed EMIs → prompts backdating dialog
    │
    └── Loan Detail Screen (3 tabs)
          ├── Overview tab
          │     ├── Hero card: remaining, progress bar, rate/tenure/end chips
          │     ├── EMI line: “EMI ₹XXXX · 3/24 paid · Next: 05 Jul”
          │     ├── Action buttons: Log EMI | Prepay | Force Close
          │     └── Payment history (EMI / Partial / Foreclosure badges)
          ├── Reports tab
          │     ├── Pie chart: principal paid/remaining + interest paid/remaining
          │     ├── Monthly principal vs interest bar chart
          │     └── Payment history list
          └── Schedule tab (borrowed loans only)
                └── Month-by-month amortization table; paid months highlighted
```

**EMI auto-expense logging:**
- Every logged payment (EMI / partial / foreclosure) auto-creates a `personal_transactions` expense with category `Loan EMI`
- Tagged with `loanSourceId` on the transaction document
- EMI payment logs and their matching personal expenses use stable IDs and an atomic transaction for retry protection
- Partial/foreclosure payment expenses retain their source/date duplicate guard
- Appears in the personal expense list under the correct month
- Missing past EMIs are checked when entering Loans & EMI and require confirmation in the existing popup; this is not an unattended due-date scheduler

**EMI schedule anchor:**
- `emiStartDate` field stores the user-set first EMI date
- If not set, `effectiveEmiStart = startDate + 1 month` (auto)
- All amortization, missed-EMI detection, and `endDate` computation use `effectiveEmiStart`

**Key files:** `loan_list_screen.dart`, `loan_detail_screen.dart`, `add_loan_sheet.dart`, `loan_reports_screen.dart`, `personal_loan.dart`, `personal_loan_payment.dart`, `personal_loan_providers.dart`, `firestore_personal_loan_repository.dart`

---

## Personal Finance Tools and Entry Points

The Personal dashboard's tools section places Accounts & Wallets beside Payment Calendar, followed by Monthly Money Review beside Savings Goals. On Android, the SMS inbox shows pending reviews below these tools.

| Entry point | Route | Purpose |
|-------------|-------|---------|
| Personal → Accounts & Wallets | `/personal/accounts` | Accounts, tracked balances and transfer history |
| Personal → Payment Calendar | `/personal/calendar` | Monthly payment forecast and agenda |
| Personal → Monthly Money Review | `/personal/money-review` | Selected dashboard month, category changes and budget checks |
| Personal → Savings Goals | `/personal/goals` | Active/archived goals and progress |
| Open a goal | `/personal/goals/:goalId` | Contributions, withdrawals and history |
| Personal → SMS Review Inbox | `/personal/sms-review` | Review captured Android alerts |
| Settings → Bank SMS Recording | `/settings/bank-sms` | Disclosure, capture permission, sender trust and rules |
| Bank SMS Recording → Merchant Category Rules | `/personal/merchant-rules` | Add/edit/pause/delete merchant category rules |

### Bank SMS recording and review

1. The user opts in to capture new bank SMS after reading the disclosure and grants `RECEIVE_SMS`. There is no inbox/history scan and no `READ_SMS` or `SEND_SMS` permission.
2. Native Android capture queues candidate financial alerts locally. A connectivity-constrained background job or foreground resume invokes Dart parsing and import processing.
3. The parser recognizes supported INR debit/credit messages and rejects OTPs, failed payments, requests, promotional and balance-only alerts. Untrusted senders, credits, uncertain alerts and potential duplicates require review.
4. A user can record a reviewed personal expense/income, create an own-account transfer, link an existing transaction/transfer, or dismiss the alert. Linking an existing EMI or settlement avoids recording it twice.
5. Future clear debits can be recorded automatically only with automatic recording enabled, a trusted sender, a payee/reference/account ending and no review condition. Merchant rules can select a category without bypassing these safeguards.

Accepted imports and durable receipts are written atomically. Receipts prevent repeat imports even after an imported transaction is edited or deleted. Raw SMS and pending review items remain in app-private device storage, excluded from Android backups; signing out or changing users clears them. Android delivery/background restrictions can delay processing, and missed messages cannot be recovered by scanning history. SMS creates personal entries/transfers only; it does not create group expenses or automatically settle a debt/loan.

### Accounts and own-account transfers

Tracked balance = opening balance + assigned income - assigned expenses + incoming transfers - outgoing transfers. Credit card debt is stored as a negative balance. Transfers have their own collection and do not change spending, income or budget totals. Existing transactions remain unassigned until edited; archiving preserves history and prevents new assignments/transfers.

SMS can assign an account automatically only when its four-digit ending matches exactly one active non-cash account. These are bookkeeping balances, not live bank balances. Loan, recurring and settlement entries can be assigned by editing their resulting personal transaction.

### Payment calendar

The Monday-first grid supports month arrows/swipes, a date jump, Today, event filters and daily/whole-month agendas. Events project loan EMIs, recurring schedules and debts with repayment dates. Monthly dates clamp to short-month endings; loan-linked recurring entries are excluded to avoid duplicate events. Partial debts show the unpaid balance; closed loans have no future unpaid installments.

The calendar is read-only. Opening a date/event never logs an expense or verifies a bank payment. EMI events match existing logs once within the 15-day matching window; recurring recorded status follows its last run. Schedule edits can change projected history, and undated debts do not appear.

### Monthly Money Review and Savings Goals

The review opens the dashboard's selected month and supports its own month navigation. Current-month comparisons use equal elapsed dates in the previous month, clamped for short months; completed months use full-month comparisons. Income/expense totals follow the Personal dashboard, including lending/borrowing and settlement entries. Transfers and savings progress are excluded. Category changes, budget overruns and uncategorized expenses support drill-down; tapping an uncategorized expense edits the original record. Outstanding debt totals are explicitly **current across all months**, not historical month-end balances.

Savings Goals tracks targets, optional dates/account labels and dated contribution/withdrawal history. Amounts use integer paise; atomic aggregate/history writes and stable entry IDs protect retries. Withdrawals or history deletions cannot leave negative savings. Archive preserves history and blocks new entries/history changes until restored. Progress is a planning record: it does not reserve an account balance, move funds or create income/expenses.

### Personal storage additions

All paths below are scoped to the authenticated owner under `users/{uid}`; other users cannot read or write them through the new rules.

| Path | Stored data |
|------|-------------|
| `personal_accounts/{accountId}` | Name, cash/bank/credit-card type, opening balance, optional last four digits, archive state |
| `personal_transfers/{transferId}` | Source/destination account IDs, positive amount, date and note |
| `bank_sms_receipts/{receiptId}` | Durable SMS import/link identity and target metadata; no raw body |
| `merchant_category_rules/{ruleId}` | Normalized sender/merchant, category and enabled state; deterministic rule ID |
| `personal_savings_goals/{goalId}` | Title, `targetMinor`, `savedMinor`, optional `targetDate`/`accountId`, archive state and creation timestamp |
| `personal_savings_goals/{goalId}/entries/{entryId}` | Signed `amountMinor` in paise, date and note |

Existing `personal_transactions` now supports `accountId`, debt `dueDate`, `writtenOffAmount` and settlement/write-off history. SMS-created entries add source/reference/sender/account-ending/message-ID metadata. Optional fields keep older records readable. Recurring records can include `createdAt` as the calendar's start bound. Reviews and forecasts are derived locally/from existing collections; there is no separate monthly-review or calendar collection.

Deploy the updated [Firestore rules](../firestore.rules) before live use; building the app does not deploy them. See [deployment checks](DEPLOYMENT.md) for App Check, Android SMS permissions and physical-device verification.

### Shared finance UI

New tools reuse the Gilmer theme, `AppSectionHeader`, `AppFinanceTile`, `AppFinanceEmptyState` and `PersonalFormSheet`. Compact tiles use 13-point titles, 11-point secondary text, 14-point amounts and 38-pixel icon boxes; cards use 16-pixel padding and sections use 20-pixel gaps. Shared account/due-date pickers and themed sheets keep entry forms consistent across light/dark modes.

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

## Group Data Isolation

Group data lives at root level, scoped by groupId:
```
groups/{groupId}/expenses/{expenseId}
```
Membership enforced via `memberIds` array on the group document.

## Project Data Isolation

Projects are user-private, scoped under the user's document:
```
users/{uid}/projects/{projectId}/expenses/{expenseId}
```
No sharing — only the owner can read/write.

## Loan Data Isolation

Loans are user-private, scoped under the user's document:
```
users/{uid}/loans/{loanId}/payments/{paymentId}
```
Each payment auto-logs to `users/{uid}/personal_transactions` with `loanSourceId` for traceability.

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
3. Deploy updated Firestore rules and configure production App Check in both foreground and SMS background entrypoints (see [DEPLOYMENT.md](DEPLOYMENT.md))
4. Run: `flutter run --release`

---

## Environment Setup Required

- Flutter SDK compatible with the project's Dart constraint and Android build configuration
- Dart SDK (^3.11.5)
- Firebase project with:
  - Authentication (Email + Google)
  - Cloud Firestore
  - Cloud Storage
  - Cloud Messaging (FCM)
- Android Studio / VS Code
- Physical device or emulator supported by the resolved Android minSdk; physical Android testing is required to verify actual SMS delivery/background execution

---

*End of Document*
