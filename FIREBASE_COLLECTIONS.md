# Firebase Collections Documentation — SplitEx

## Overview

| Service | Purpose |
|---------|---------|
| **Cloud Firestore** | Primary NoSQL document database for all app data |
| **Firebase Storage** | File storage for receipt images |
| **Firebase Auth** | Authentication (Email/Password, Google Sign-In) |
| **SharedPreferences** | Local-only daily read/write usage tracking |

---

## Database Structure

```
Firestore (Root)
├── users/{uid}                          ← User profiles
│   ├── notifications/{notificationId}   ← Per-user notifications (storage mgmt)
│   ├── personal_transactions/{txnId}    ← Personal income/expense tracking
│   ├── personal_budgets/{budgetId}      ← Category budgets per month
│   ├── personal_recurring/{recurringId} ← Recurring transaction templates
│   ├── loans/{loanId}                   ← Loan & EMI tracker
│   │   └── payments/{paymentId}         ← Individual loan payment log
│   └── projects/{projectId}            ← Personal project tracker
│       └── expenses/{expenseId}         ← Project expense items
├── rooms/{roomId}                       ← Roommate groups
│   ├── expenses/{expenseId}             ← Expenses in a room
│   ├── bills/{billId}                   ← Bills (rent, electricity, water)
│   ├── settlements/{settlementId}       ← Payment settlements
│   └── activities/{activityId}          ← Activity log
├── groups/{groupId}                     ← Shared expense groups
│   └── expenses/{expenseId}             ← Group expense items
└── notifications/{notificationId}       ← Top-level notifications (notification service)

Firebase Storage
└── receipts/{roomId}/{folder}/{imageFile}  ← Receipt images (rooms only)
```

---

## Collections Detail

### 1. `users` (Top-level)

**Path:** `users/{uid}`  
**Service:** `UserService`, `RoomService`  
**Purpose:** Stores user profile data and room memberships.

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Display name |
| `email` | string | Email address |
| `avatarUrl` | string? | Profile photo URL |
| `upiId` | string? | UPI ID for payments |
| `rooms` | array\<string\> | List of room IDs the user belongs to |
| `createdAt` | timestamp | Account creation time |

---

### 2. `users/{uid}/personal_transactions` (Subcollection)

**Path:** `users/{uid}/personal_transactions/{txnId}`  
**Service:** `PersonalExpenseService`  
**Purpose:** Personal income and expense tracking with optional peer-to-peer debt linking.

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Transaction description |
| `amount` | number | Amount in ₹ |
| `type` | string | `expense` or `income` |
| `category` | string | Category (Food, Transport, Rent, etc.) |
| `date` | timestamp | Transaction date |
| `notes` | string? | Optional notes |
| `userId` | string | Owner UID |
| `month` | string | Month key (`yyyy-MM`) for filtering |
| `createdAt` | timestamp | Record creation time |
| `debtType` | string? | `lent` or `borrowed` (null = no debt) |
| `personName` | string? | Name of person involved in debt |
| `isSettled` | boolean | Whether debt has been fully settled (default: false) |
| `settledAmount` | number | Total amount settled so far (default: 0) |
| `partialSettlements` | array | History of partial settlement entries `[{amount, date, note}]` |
| `loanSourceId` | string? | Loan ID if auto-logged by Loan EMI tracker (used for dedup) |

**Indexes Required:**
- `month` (ASC) + `date` (DESC) — for monthly transaction listing
- `debtType` (ASC) + `date` (DESC) — for debt screen queries

**Operations:**
- Add transaction (with optional debt fields)
- Update transaction
- Delete transaction
- Stream by month
- Stream all debt transactions (`debtType` whereIn `['lent', 'borrowed']`)
- Settle transaction (full: sets `isSettled: true`, `settledAmount = amount`; auto-creates income entry for lent)
- Partial settle (increments `settledAmount`, appends to `partialSettlements`; auto-creates income entry for lent)

---

### 3. `users/{uid}/personal_budgets` (Subcollection)

**Path:** `users/{uid}/personal_budgets/{budgetId}`  
**Service:** `PersonalExpenseService`  
**Purpose:** Per-category spending limits per month.

| Field | Type | Description |
|-------|------|-------------|
| `category` | string | Category name |
| `budget` | number | Budget amount in ₹ |
| `userId` | string | Owner UID |
| `month` | string | Month key (`yyyy-MM`) |

**Operations:**
- Set/update budget (upsert by category + month)
- Delete budget
- Stream budgets by month

---

### 4. `users/{uid}/personal_recurring` (Subcollection)

**Path:** `users/{uid}/personal_recurring/{recurringId}`  
**Service:** `PersonalExpenseService`  
**Purpose:** Templates for recurring expenses that auto-generate transactions.

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Recurring item name |
| `amount` | number | Amount in ₹ |
| `category` | string | Category |
| `type` | string | `expense` or `income` |
| `frequency` | string | `weekly` or `monthly` |
| `dayOfMonth` | number | Day to execute (1-31) |
| `active` | boolean | Whether currently enabled |
| `userId` | string | Owner UID |
| `lastRunDate` | timestamp? | Last execution date |
| `endDate` | timestamp? | Optional end date (null = no expiry) |

**Operations:**
- Add recurring template
- Toggle active/inactive
- Delete recurring
- Stream all recurring for user

---

### 5. `users/{uid}/projects` (Subcollection)

**Path:** `users/{uid}/projects/{projectId}`  
**Service:** `ProjectService`  
**Purpose:** Personal project budget envelopes. Private to the owner — not shared.

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Project name |
| `description` | string? | Optional description |
| `projectType` | string | Type label (Wedding, Construction, Event, etc.) |
| `estimatedBudget` | number | Total budget in ₹ |
| `startDate` | timestamp? | Project start date |
| `targetEndDate` | timestamp? | Target completion date |
| `status` | string | `active`, `completed`, or `paused` |
| `createdBy` | string | Owner UID |
| `createdAt` | timestamp | Record creation time |

**Operations:**
- Create project
- Update status
- Delete project (cascades expenses)
- Stream all projects for user

---

### 6. `users/{uid}/projects/{projectId}/expenses` (Subcollection)

**Path:** `users/{uid}/projects/{projectId}/expenses/{expenseId}`  
**Service:** `ProjectExpenseService`  
**Purpose:** Individual expense items tracked against a project budget.

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Expense description |
| `amount` | number | Amount in ₹ |
| `category` | string | Universal category (Materials, Labor, Services, etc.) |
| `vendor` | string? | Vendor or payee name |
| `paymentMethod` | string | `cash`, `upi`, `card`, or `bankTransfer` |
| `notes` | string? | Optional notes |
| `date` | timestamp | Expense date |
| `createdBy` | string | Owner UID |
| `createdAt` | timestamp | Record creation time |

**Project Categories:** Materials, Labor, Services, Equipment, Transport, Food & Catering, Decoration, Venue, Clothing & Attire, Electronics, Furniture, Utilities, Fees & Permits, Marketing, Miscellaneous

---

### 7. `users/{uid}/notifications` (Subcollection)

**Path:** `users/{uid}/notifications/{notificationId}`  
**Service:** `StorageManagementService`  
**Purpose:** Used by storage management for counting and clearing notifications per user.

| Field | Type | Description |
|-------|------|-------------|
| `createdAt` | timestamp | When notification was created |

---

### 8. `rooms` (Top-level)

**Path:** `rooms/{roomId}`  
**Service:** `RoomService`  
**Purpose:** Groups/rooms where members share expenses.

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Room name |
| `inviteCode` | string | 6-char code (A-Z, 2-9) for joining |
| `adminId` | string | UID of room creator/admin |
| `memberIds` | array\<string\> | List of member UIDs |
| `createdAt` | timestamp | Room creation time |
| `currentMonth` | string | Current active month (`yyyy-MM`) |
| `isLocked` | boolean | Whether room is locked |

---

### 9. `rooms/{roomId}/expenses` (Subcollection)

**Path:** `rooms/{roomId}/expenses/{expenseId}`  
**Service:** `ExpenseService`, `StorageManagementService`  
**Purpose:** Individual expenses added by room members.

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Expense description |
| `amount` | number | Amount in currency |
| `category` | string | Category |
| `date` | timestamp | Date of expense |
| `paidBy` | string | UID of person who paid |
| `splitType` | string | `equal`, `dynamic`, or `oneToOne` |
| `splitAmong` | array\<string\> | UIDs of people sharing cost |
| `createdBy` | string | UID of person who added it |
| `createdAt` | timestamp | Record creation time |
| `updatedAt` | timestamp? | Last update time |
| `month` | string | Month identifier (`yyyy-MM`) |
| `receiptUrl` | string? | Firebase Storage URL of receipt image |

---

### 10. `rooms/{roomId}/bills` (Subcollection)

**Path:** `rooms/{roomId}/bills/{billId}`  
**Service:** `BillService`, `StorageManagementService`  

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | `rent`, `electricity`, or `water` |
| `amount` | number | Bill amount |
| `paidBy` | string | UID of payer |
| `month` | string | Month identifier (`yyyy-MM`) |
| `date` | timestamp | Bill date |
| `receiptUrl` | string? | Receipt image URL |
| `createdAt` | timestamp | Record creation time |

---

### 11. `rooms/{roomId}/settlements` (Subcollection)

**Path:** `rooms/{roomId}/settlements/{settlementId}`  
**Service:** `SettlementService`, `StorageManagementService`  

| Field | Type | Description |
|-------|------|-------------|
| `roomId` | string | Room this settlement belongs to |
| `fromUserId` | string | UID of person paying |
| `toUserId` | string | UID of person receiving |
| `amount` | number | Settlement amount |
| `status` | string | `pending` or `confirmed` |
| `upiRef` | string? | UPI transaction reference |
| `createdAt` | timestamp | When settlement was created |
| `confirmedAt` | timestamp? | When receiver confirmed it |

---

### 12. `rooms/{roomId}/activities` (Subcollection)

**Path:** `rooms/{roomId}/activities/{activityId}`  
**Service:** `ActivityService`, `StorageManagementService`  

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Activity type |
| `performedBy` | string | UID of person who performed action |
| `description` | string | Human-readable description |
| `createdAt` | timestamp | When action occurred |
| `metadata` | map? | Extra context data |

**Activity Types:** `expenseAdded`, `expenseEdited`, `expenseDeleted`, `settlementCreated`, `settlementConfirmed`, `memberJoined`, `memberLeft`, `roomCreated`, `roomSettingsChanged`

---

### 13. `users/{uid}/loans` (Subcollection)

**Path:** `users/{uid}/loans/{loanId}`  
**Service:** `LoanService`  
**Purpose:** Tracks borrowed and lent loans with EMI schedule, payment history, and recurring integration.

| Field | Type | Description |
|-------|------|-------------|
| `userId` | string | Owner UID |
| `title` | string | Loan name (e.g. "HDFC Home Loan") |
| `loanType` | string | `borrowed` (I owe) or `lent` (someone owes me) |
| `principal` | number | Original loan amount in ₹ |
| `annualInterestRate` | number | Annual interest rate (0 for interest-free) |
| `tenureMonths` | number | Total loan tenure in months |
| `startDate` | timestamp | Loan disbursement / start date |
| `emiDueDay` | number | Day of month EMI is due (1–28) |
| `emiStartDate` | timestamp? | Date of first EMI; null = auto (`startDate + 1 month`) |
| `status` | string | `active`, `settled`, or `foreclosed` |
| `lenderBorrowerName` | string? | Bank or person name |
| `notes` | string? | Optional remarks |
| `recurringId` | string? | Linked `personal_recurring` doc ID for two-way sync |
| `customEmi` | number? | User-overridden EMI (overrides calculated EMI) |
| `processingFee` | number | One-time processing fee |
| `insuranceFee` | number | Loan protection insurance fee |
| `otherCharges` | number | Stamp duty, legal, etc. |
| `gstOnFees` | number | 18% GST on processing fee (auto-calculated) |
| `createdAt` | timestamp | Record creation time |

**Computed (not stored):**
- `baseEmi` — standard amortization EMI (or `customEmi` if set)
- `netDisbursed` — principal minus all one-time charges
- `effectiveEmiStart` — `emiStartDate ?? DateTime(startDate.year, startDate.month + 1, emiDueDay)`
- `endDate` — derived from `effectiveEmiStart + tenureMonths`

**Operations:**
- Add loan (with optional missed-EMI backdating on creation)
- Update loan (recalculates EMI, syncs linked recurring amount)
- Delete loan (cascades payment sub-docs)
- Force close / foreclose
- Stream all loans for user

---

### 13a. `users/{uid}/loans/{loanId}/payments` (Subcollection)

**Path:** `users/{uid}/loans/{loanId}/payments/{paymentId}`  
**Service:** `LoanService`  
**Purpose:** Individual payment log entries for a loan.

| Field | Type | Description |
|-------|------|-------------|
| `amount` | number | Total payment amount |
| `principalComponent` | number | Principal portion of this payment |
| `interestComponent` | number | Interest portion of this payment |
| `remainingPrincipalAfter` | number | Remaining principal after this payment |
| `date` | timestamp | Payment date |
| `type` | string | `emi`, `partial`, or `foreclosure` |
| `note` | string? | Optional note (e.g. "Backdated EMI") |
| `createdAt` | timestamp | Record creation time |

**Operations:**
- Log EMI payment (auto-computes interest/principal split)
- Log partial prepayment (reduces principal, recalculates future EMI)
- Log foreclosure (pays remaining principal + accrued interest)
- Each payment auto-creates a `personal_transactions` expense tagged with `loanSourceId` for dedup
- Stream payments for a loan (ordered by date descending)

---

### 14. `notifications` (Top-level)

**Path:** `notifications/{notificationId}`  
**Service:** `NotificationService`  

| Field | Type | Description |
|-------|------|-------------|
| `roomId` | string | Room that triggered notification |
| `targetUserId` | string | UID of recipient |
| `title` | string | Notification title |
| `body` | string | Notification body text |
| `type` | string | Notification type |
| `isRead` | boolean | Whether user has read it |
| `createdAt` | timestamp | When notification was sent |

---

### 15. `groups` (Top-level)

**Path:** `groups/{groupId}`  
**Service:** `GroupService`  
**Purpose:** Shared expense groups. Any user can create or join via invite code.

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Group name |
| `description` | string? | Optional description |
| `startDate` | timestamp? | Group start date |
| `endDate` | timestamp? | Group end date |
| `currency` | string | Currency code (default: INR) |
| `inviteCode` | string | 6-char alphanumeric code for joining |
| `createdBy` | string | UID of group creator (admin) |
| `memberIds` | array\<string\> | List of member UIDs |
| `status` | string | `active` or `archived` |
| `createdAt` | timestamp | Group creation time |

**Operations:**
- Create group (auto-generate invite code)
- Join by invite code
- Leave group
- Archive / restore (admin only)
- Stream user's groups

---

### 16. `groups/{groupId}/expenses` (Subcollection)

**Path:** `groups/{groupId}/expenses/{expenseId}`  
**Service:** `GroupExpenseService`  
**Purpose:** Expenses shared among group members.

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Expense description |
| `amount` | number | Total amount |
| `category` | string | Expense category |
| `notes` | string? | Optional notes |
| `paidBy` | string | UID of person who paid |
| `splitType` | string | `equal` or `select` |
| `splitAmong` | array\<string\> | UIDs sharing the cost |
| `customSplits` | map\<string, number\>? | Manual split amounts per UID |
| `date` | timestamp | Expense date |
| `createdBy` | string | UID who added the expense |
| `createdAt` | timestamp | Record creation time |
| `updatedAt` | timestamp? | Last update time |

**Operations:**
- Add expense
- Update expense
- Delete expense
- Stream expenses for group

---

## Firebase Storage

**Path:** `receipts/{roomId}/{subfolder}/{filename}`  
**Service:** `UploadService`, `StorageManagementService`  

---

## Local Storage (SharedPreferences)

| Key | Type | Description |
|-----|------|-------------|
| `usage_date` | string | Date string (`yyyy-MM-dd`) of last tracking |
| `daily_reads` | int | Firestore reads tracked today |
| `daily_writes` | int | Firestore writes tracked today |

---

## Relationships Diagram

```
┌─────────────────────────────────────────────────────┐
│                      Firebase Auth                    │
│                  (uid = document ID)                  │
└────────────────────────┬────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────┐
│                   users/{uid}                         │
│  rooms: [roomId1, roomId2, ...]                      │
├─────────────────────────────────────────────────────┤
│  ├── personal_transactions/{id} ← expense/income     │
│  │     └── optional: debtType, personName, loanSourceId │
│  ├── personal_budgets/{id}      ← category budgets   │
│  ├── personal_recurring/{id}    ← recurring templates│
│  ├── loans/{id}                 ← loan tracker       │
│  │     └── payments/{id}        ← payment log        │
│  ├── projects/{id}              ← project envelopes  │
│  │     └── expenses/{id}        ← project expenses   │
│  └── notifications/{id}                              │
└────────────────────────┬────────────────────────────┘
                         │ references
                         ▼
┌─────────────────────────────────────────────────────┐
│                  rooms/{roomId}                       │
│  memberIds: [uid1, uid2, ...]                        │
│  adminId: uid                                        │
├─────────────────────────────────────────────────────┤
│  ├── expenses/{id}  ← paidBy: uid, splitAmong: [uid] │
│  ├── bills/{id}     ← paidBy: uid                    │
│  ├── settlements/{id} ← fromUserId, toUserId: uid    │
│  └── activities/{id}  ← performedBy: uid             │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│                 groups/{groupId}                      │
│  memberIds: [uid1, uid2, ...]                        │
│  createdBy: uid (admin)                              │
├─────────────────────────────────────────────────────┤
│  └── expenses/{id}  ← paidBy: uid, splitAmong: [uid] │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│              notifications/{id}                       │
│  targetUserId: uid, roomId: roomId                   │
└─────────────────────────────────────────────────────┘
```

---

## Summary

| # | Collection | Type | Doc Count Growth |
|---|-----------|------|------------------|
| 1 | `users` | Top-level | 1 per user |
| 2 | `users/{uid}/personal_transactions` | Subcollection | Many per user/month |
| 3 | `users/{uid}/personal_budgets` | Subcollection | Few per user/month |
| 4 | `users/{uid}/personal_recurring` | Subcollection | Few per user |
| 5 | `users/{uid}/projects` | Subcollection | Few per user |
| 6 | `users/{uid}/projects/{id}/expenses` | Subcollection | Many per project |
| 7 | `users/{uid}/notifications` | Subcollection | Used by storage mgmt |
| 8 | `rooms` | Top-level | 1 per room |
| 9 | `rooms/{roomId}/expenses` | Subcollection | Many per room/month |
| 10 | `rooms/{roomId}/bills` | Subcollection | Few per room/month |
| 11 | `rooms/{roomId}/settlements` | Subcollection | Per debt resolution |
| 12 | `rooms/{roomId}/activities` | Subcollection | 1 per action |
| 13 | `users/{uid}/loans` | Subcollection | 1 per loan |
| 13a | `users/{uid}/loans/{id}/payments` | Subcollection | 1 per payment |
| 14 | `notifications` | Top-level | Per event × recipients |
| 15 | `groups` | Top-level | 1 per group |
| 16 | `groups/{groupId}/expenses` | Subcollection | Many per group |

**Total: 1 Firestore database, 17 collections, 1 Storage bucket, 1 local store.**
