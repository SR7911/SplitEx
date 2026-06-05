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
│   └── notifications/{notificationId}   ← Per-user notifications (storage mgmt)
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

**Operations:**
- Create profile on sign-up
- Read profile (stream or one-time)
- Update profile fields (name, avatar, UPI ID)
- Check if profile exists
- Add/remove room IDs from `rooms` array

---

### 2. `users/{uid}/notifications` (Subcollection)

**Path:** `users/{uid}/notifications/{notificationId}`  
**Service:** `StorageManagementService`  
**Purpose:** Used by storage management for counting and clearing notifications per user.

| Field | Type | Description |
|-------|------|-------------|
| `createdAt` | timestamp | When notification was created |

**Operations:**
- Count notifications per month (for storage stats)
- Clear notifications by month (batch delete)

---

### 3. `rooms` (Top-level)

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

**Operations:**
- Create room (generates invite code)
- Join room via invite code
- Stream user's rooms (where `memberIds` arrayContains userId)
- Stream single room
- Remove member / leave room

---

### 4. `rooms/{roomId}/expenses` (Subcollection)

**Path:** `rooms/{roomId}/expenses/{expenseId}`  
**Service:** `ExpenseService`, `StorageManagementService`  
**Purpose:** Individual expenses added by room members.

| Field | Type | Description |
|-------|------|-------------|
| `title` | string | Expense description |
| `amount` | number | Amount in currency |
| `category` | string | Category (e.g., "Food", "Transport", "Other") |
| `date` | timestamp | Date of expense |
| `paidBy` | string | UID of person who paid |
| `splitType` | string | `equal`, `dynamic`, or `oneToOne` |
| `splitAmong` | array\<string\> | UIDs of people sharing cost |
| `createdBy` | string | UID of person who added it |
| `createdAt` | timestamp | Record creation time |
| `updatedAt` | timestamp? | Last update time |
| `month` | string | Month identifier (`yyyy-MM`) |
| `receiptUrl` | string? | Firebase Storage URL of receipt image |

**Operations:**
- Add expense
- Update expense (title, amount, category, split, etc.)
- Delete expense
- Stream expenses by month
- Stream all expenses
- Clear expenses by month (storage mgmt)

---

### 5. `rooms/{roomId}/bills` (Subcollection)

**Path:** `rooms/{roomId}/bills/{billId}`  
**Service:** `BillService`, `StorageManagementService`  
**Purpose:** Recurring bills like rent, electricity, water.

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | `rent`, `electricity`, or `water` |
| `amount` | number | Bill amount |
| `paidBy` | string | UID of payer |
| `month` | string | Month identifier (`yyyy-MM`) |
| `date` | timestamp | Bill date |
| `receiptUrl` | string? | Receipt image URL |
| `createdAt` | timestamp | Record creation time |

**Operations:**
- Add bill
- Update bill
- Delete bill
- Stream bills by month
- Clear bills by month (storage mgmt)

---

### 6. `rooms/{roomId}/settlements` (Subcollection)

**Path:** `rooms/{roomId}/settlements/{settlementId}`  
**Service:** `SettlementService`, `StorageManagementService`  
**Purpose:** Records of payments between members to settle debts.

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

**Operations:**
- Create settlement (status = pending)
- Confirm settlement (status = confirmed + confirmedAt)
- Add UPI reference
- Stream all settlements (ordered by createdAt desc)
- Stream pending settlements for a user (receiver)
- Clear settlements by month (storage mgmt)

---

### 7. `rooms/{roomId}/activities` (Subcollection)

**Path:** `rooms/{roomId}/activities/{activityId}`  
**Service:** `ActivityService`, `StorageManagementService`  
**Purpose:** Audit log of all actions in a room.

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Activity type (see enum below) |
| `performedBy` | string | UID of person who performed action |
| `description` | string | Human-readable description |
| `createdAt` | timestamp | When action occurred |
| `metadata` | map? | Extra context data |

**Activity Types:**
- `expenseAdded`, `expenseEdited`, `expenseDeleted`
- `settlementCreated`, `settlementConfirmed`
- `memberJoined`, `memberLeft`
- `roomCreated`, `roomSettingsChanged`

**Operations:**
- Log activity
- Stream activities (limit 100, ordered by createdAt desc)
- Clear activities by month (storage mgmt)

---

### 8. `notifications` (Top-level)

**Path:** `notifications/{notificationId}`  
**Service:** `NotificationService`  
**Purpose:** Push-style notifications sent to users about room events.

| Field | Type | Description |
|-------|------|-------------|
| `roomId` | string | Room that triggered notification |
| `targetUserId` | string | UID of recipient |
| `title` | string | Notification title |
| `body` | string | Notification body text |
| `type` | string | Notification type (see enum below) |
| `isRead` | boolean | Whether user has read it |
| `createdAt` | timestamp | When notification was sent |

**Notification Types:**
- `expenseAdded`, `expenseDeleted`
- `reminder`, `settlement`, `memberJoined`

**Operations:**
- Send notification to multiple users (batch write)
- Stream notifications for a user (limit 50)
- Mark as read (single or all)
- Stream unread count

---

## Firebase Storage

**Path:** `receipts/{roomId}/{subfolder}/{filename}`  
**Service:** `UploadService`, `StorageManagementService`  
**Purpose:** Stores receipt images uploaded with expenses or bills.

**Operations:**
- Upload image (from `UploadService`)
- List all images in a room
- Delete all images in a room (storage mgmt)
- Estimate storage usage (~512KB per image)

---

## Local Storage (SharedPreferences)

| Key | Type | Description |
|-----|------|-------------|
| `usage_date` | string | Date string (`yyyy-MM-dd`) of last tracking |
| `daily_reads` | int | Firestore reads tracked today |
| `daily_writes` | int | Firestore writes tracked today |

**Purpose:** Tracks approximate daily Firestore usage to stay within free-tier limits.

---

## Data Cleanup (StorageManagementService)

Every collection supports clearing by month:

| Method | Target |
|--------|--------|
| `clearExpensesByMonth(roomId, month)` | `rooms/{roomId}/expenses` where `month == x` |
| `clearBillsByMonth(roomId, month)` | `rooms/{roomId}/bills` where `month == x` |
| `clearActivitiesByMonth(roomId, month)` | `rooms/{roomId}/activities` by timestamp range |
| `clearSettlementsByMonth(roomId, month)` | `rooms/{roomId}/settlements` by timestamp range |
| `clearNotificationsByMonth(userId, month)` | `users/{uid}/notifications` by timestamp range |
| `clearAllDataByMonth(roomId, userId, month)` | All 5 above combined |
| `clearAllImages(roomId)` | Firebase Storage `receipts/{roomId}/` |

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
| 2 | `users/{uid}/notifications` | Subcollection | Used by storage mgmt |
| 3 | `rooms` | Top-level | 1 per group |
| 4 | `rooms/{roomId}/expenses` | Subcollection | Many per room/month |
| 5 | `rooms/{roomId}/bills` | Subcollection | Few per room/month |
| 6 | `rooms/{roomId}/settlements` | Subcollection | Per debt resolution |
| 7 | `rooms/{roomId}/activities` | Subcollection | 1 per action |
| 8 | `notifications` | Top-level | Per event × recipients |

**Total: 1 Firestore database, 8 collections, 1 Storage bucket, 1 local store.**
