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
│   └── personal_recurring/{recurringId} ← Recurring transaction templates
├── rooms/{roomId}                       ← Groups/rooms
│   ├── expenses/{expenseId}             ← Expenses in a room
│   ├── bills/{billId}                   ← Bills (rent, electricity, water)
│   ├── settlements/{settlementId}       ← Payment settlements
│   └── activities/{activityId}          ← Activity log
└── notifications/{notificationId}       ← Top-level notifications (notification service)

Firebase Storage
└── receipts/{roomId}/{folder}/{imageFile}  ← Receipt images
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
| `isSettled` | boolean | Whether debt has been settled (default: false) |

**Indexes Required:**
- `month` (ASC) + `date` (DESC) — for monthly transaction listing
- `debtType` (ASC) + `date` (DESC) — for debt screen queries

**Operations:**
- Add transaction (with optional debt fields)
- Update transaction
- Delete transaction
- Stream by month
- Stream debt transactions (`debtType` whereIn `['lent', 'borrowed']`)
- Settle transaction (set `isSettled: true`)

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

### 5. `users/{uid}/notifications` (Subcollection)

**Path:** `users/{uid}/notifications/{notificationId}`  
**Service:** `StorageManagementService`  
**Purpose:** Used by storage management for counting and clearing notifications per user.

| Field | Type | Description |
|-------|------|-------------|
| `createdAt` | timestamp | When notification was created |

---

### 6. `rooms` (Top-level)

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

### 7. `rooms/{roomId}/expenses` (Subcollection)

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

### 8. `rooms/{roomId}/bills` (Subcollection)

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

### 9. `rooms/{roomId}/settlements` (Subcollection)

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

### 10. `rooms/{roomId}/activities` (Subcollection)

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

### 11. `notifications` (Top-level)

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
│  │     └── optional: debtType, personName, isSettled │
│  ├── personal_budgets/{id}      ← category budgets   │
│  ├── personal_recurring/{id}    ← recurring templates│
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
| 5 | `users/{uid}/notifications` | Subcollection | Used by storage mgmt |
| 6 | `rooms` | Top-level | 1 per group |
| 7 | `rooms/{roomId}/expenses` | Subcollection | Many per room/month |
| 8 | `rooms/{roomId}/bills` | Subcollection | Few per room/month |
| 9 | `rooms/{roomId}/settlements` | Subcollection | Per debt resolution |
| 10 | `rooms/{roomId}/activities` | Subcollection | 1 per action |
| 11 | `notifications` | Top-level | Per event × recipients |

**Total: 1 Firestore database, 11 collections, 1 Storage bucket, 1 local store.**
