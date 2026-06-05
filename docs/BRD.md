# Business Requirements Document (BRD)
## SplitEx — Roommate Expense Splitting App

---

## 1. Document Information

| Field | Details |
|-------|---------|
| Project Name | SplitEx |
| Platform | Android & iOS (Flutter) |
| Backend | Firebase (Free Tier - Spark Plan) |
| State Management | Riverpod |
| Version | 1.0.0 |
| Author | Admin |
| Last Updated | 2024 |

---

## 2. Executive Summary

SplitEx is a mobile application designed for roommates/flatmates to track shared household expenses, split costs fairly, and settle dues seamlessly. The app enables real-time collaboration within a "Room," role-based access control, visual spend analytics, smart reminders, and one-click UPI settlements — all powered by Firebase's free tier with offline-first capability.

---

## 3. Problem Statement

Roommates face recurring conflicts over:
- Who paid for what and when
- Unequal or forgotten expense splits
- Lack of transparency in edits/deletions
- No structured way to settle monthly dues
- Manual tracking via spreadsheets or WhatsApp groups is error-prone

---

## 4. Target Users

| User Type | Description |
|-----------|-------------|
| Admin (Room Creator) | Creates the room, manages members, has full CRUD access, closes monthly cycles |
| Member (Roommate) | Joins a room via invite, adds/edits own expenses, views balances |

---

## 5. Functional Requirements

### 5.1 Authentication & Onboarding

| ID | Requirement | Priority |
|----|-------------|----------|
| AUTH-01 | User registration via Email/Password | High |
| AUTH-02 | Google Sign-In integration | High |
| AUTH-03 | Phone number OTP login | Medium |
| AUTH-04 | Profile setup (Name, Avatar, UPI ID) | High |
| AUTH-05 | Persistent login session | High |

### 5.2 Room Management

| ID | Requirement | Priority |
|----|-------------|----------|
| ROOM-01 | Create a new Room with a unique invite code | High |
| ROOM-02 | Join an existing Room using invite code | High |
| ROOM-03 | Admin can remove members from the Room | Medium |
| ROOM-04 | Admin can transfer admin role to another member | Low |
| ROOM-05 | Display Room member list with roles | High |
| ROOM-06 | A user can be part of multiple Rooms | Medium |

### 5.3 User Roles & Access Control

| ID | Requirement | Priority |
|----|-------------|----------|
| ROLE-01 | Admin: Full CRUD on all expenses | High |
| ROLE-02 | Admin: Can delete any expense | High |
| ROLE-03 | Admin: Can close/lock monthly cycle | High |
| ROLE-04 | Admin: Can send manual reminders | High |
| ROLE-05 | Member: Can add new expenses | High |
| ROLE-06 | Member: Can edit only their own expenses | High |
| ROLE-07 | Member: Cannot delete any expense | High |
| ROLE-08 | Role enforcement via Firestore Security Rules (server-side) | High |

### 5.4 Expense Management

| ID | Requirement | Priority |
|----|-------------|----------|
| EXP-01 | Add Expense: Title, Amount (₹), Category, Date, Paid By | High |
| EXP-02 | Categories: Rent, Groceries, Electricity, Maid, Wi-Fi, Food, Transport, Other | High |
| EXP-03 | Custom category creation | Low |
| EXP-04 | Edit expense (own for Member, any for Admin) | High |
| EXP-05 | Delete expense (Admin only) | High |
| EXP-06 | Attach receipt image (optional) | Low |
| EXP-07 | Expense list with filters (by date, category, person) | Medium |

### 5.5 Splitting Mechanics

| ID | Requirement | Priority |
|----|-------------|----------|
| SPLIT-01 | Equal Split: Cost ÷ total room members | High |
| SPLIT-02 | Dynamic Split: Select specific members to split among | High |
| SPLIT-03 | 1-to-1 Sharing: Private ledger between two users | Medium |
| SPLIT-04 | Unequal Split: Custom amount per person | Low |
| SPLIT-05 | Percentage Split: Custom % per person | Low |

### 5.6 Dashboard & Balances

| ID | Requirement | Priority |
|----|-------------|----------|
| DASH-01 | Show current user's net balance ("You owe ₹X" / "You are owed ₹Y") | High |
| DASH-02 | Who-owes-whom matrix (simplified debt graph) | High |
| DASH-03 | Quick summary: Total room spend this month | High |
| DASH-04 | Recent expenses list (last 5-10 entries) | Medium |
| DASH-05 | Debt simplification algorithm (minimize total transactions) | Medium |

### 5.7 Visual Analytics

| ID | Requirement | Priority |
|----|-------------|----------|
| CHART-01 | Bar/Pie chart: Spend by Person (this month) | High |
| CHART-02 | Bar/Pie chart: Spend by Category (this month) | High |
| CHART-03 | Monthly trend line chart | Low |
| CHART-04 | Filter charts by date range | Low |

### 5.8 Notifications & Alerts

| ID | Requirement | Priority |
|----|-------------|----------|
| NOTIF-01 | Push notification when a new expense is added | High |
| NOTIF-02 | Push notification when an expense is edited | High |
| NOTIF-03 | Push notification when an expense is deleted | High |
| NOTIF-04 | Notification payload: Actor name, action, expense title, amount | High |
| NOTIF-05 | In-app notification feed | Medium |

### 5.9 Smart Reminders

| ID | Requirement | Priority |
|----|-------------|----------|
| REM-01 | Admin: Manual "Remind" button per user with pending dues | High |
| REM-02 | Scheduled reminders for recurring bills (e.g., Rent on 28th) | Medium |
| REM-03 | Advance alert: X days/hours before due date | Medium |
| REM-04 | Snooze/dismiss reminder | Low |

### 5.10 Audit Trail & Activity Log

| ID | Requirement | Priority |
|----|-------------|----------|
| LOG-01 | Chronological activity feed for the Room | High |
| LOG-02 | Log entry fields: User Name, Action (Added/Edited/Deleted), Timestamp, Item Details | High |
| LOG-03 | Show old value vs new value on edits | Medium |
| LOG-04 | Activity log is read-only for all users | High |

### 5.11 Settlement & Payouts

| ID | Requirement | Priority |
|----|-------------|----------|
| SETTLE-01 | Admin: "Close Month" locks the current ledger | High |
| SETTLE-02 | Generate net balance sheet on month close | High |
| SETTLE-03 | One-click UPI payment (GPay, PhonePe, Paytm) | High |
| SETTLE-04 | UPI intent with pre-filled: receiver UPI ID, amount, note | High |
| SETTLE-05 | Mark debt as "Settled" manually after payment | High |
| SETTLE-06 | Settlement history (past months) | Medium |

---

## 6. Non-Functional Requirements

| ID | Requirement | Details |
|----|-------------|---------|
| NFR-01 | Offline Support | Firestore offline persistence; app functional without internet, syncs when online |
| NFR-02 | Performance | Dashboard loads < 2 seconds; smooth 60fps scrolling |
| NFR-03 | Security | Firestore rules enforce role-based access; no client-side-only checks |
| NFR-04 | Scalability | Supports up to 10 members per room (free tier optimized) |
| NFR-05 | Data Privacy | User data stored only in Firebase; no third-party analytics |
| NFR-06 | Availability | 99.9% (Firebase SLA) |
| NFR-07 | Minimum OS | Android 6.0+ / iOS 13+ |
| NFR-08 | App Size | < 30 MB |

---

## 7. Technical Architecture

### 7.1 Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) |
| State Management | Riverpod + Riverpod Generator |
| Backend | Firebase (Firestore, Auth, FCM) |
| Local Cache | Firestore offline persistence |
| Charts | fl_chart |
| Notifications | Firebase Cloud Messaging + flutter_local_notifications |
| UPI Integration | url_launcher (UPI deep links) |
| Image Storage | Firebase Storage (if receipt feature enabled) |

### 7.2 Firebase Collections Schema

```
users/
  └── {userId}
        ├── name: string
        ├── email: string
        ├── avatarUrl: string
        ├── upiId: string
        └── rooms: [roomId1, roomId2]

rooms/
  └── {roomId}
        ├── name: string
        ├── inviteCode: string
        ├── adminId: string
        ├── memberIds: [userId1, userId2, ...]
        ├── createdAt: timestamp
        ├── currentMonth: string (e.g., "2024-07")
        └── isLocked: boolean

rooms/{roomId}/expenses/
  └── {expenseId}
        ├── title: string
        ├── amount: number
        ├── category: string
        ├── date: timestamp
        ├── paidBy: userId
        ├── splitType: "equal" | "dynamic" | "one-to-one"
        ├── splitAmong: [userId1, userId2, ...]
        ├── createdBy: userId
        ├── createdAt: timestamp
        ├── updatedAt: timestamp
        └── month: string (e.g., "2024-07")

rooms/{roomId}/activityLog/
  └── {logId}
        ├── userId: string
        ├── userName: string
        ├── action: "added" | "edited" | "deleted"
        ├── expenseTitle: string
        ├── amount: number
        ├── oldAmount: number (for edits)
        ├── timestamp: timestamp
        └── details: string

rooms/{roomId}/settlements/
  └── {settlementId}
        ├── month: string
        ├── fromUserId: string
        ├── toUserId: string
        ├── amount: number
        ├── status: "pending" | "settled"
        ├── settledAt: timestamp
        └── lockedAt: timestamp

rooms/{roomId}/reminders/
  └── {reminderId}
        ├── title: string
        ├── scheduledDate: timestamp
        ├── recurringDay: number (1-31)
        ├── advanceHours: number
        ├── targetUserIds: [userId1, ...]
        ├── isActive: boolean
        └── createdBy: userId
```

### 7.3 Firestore Security Rules (Summary)

```
- users/{userId}: Read/write only by the owner
- rooms/{roomId}: Read by members; write by admin
- rooms/{roomId}/expenses:
    - Create: Any member
    - Update: Creator of the expense OR admin
    - Delete: Admin only
- rooms/{roomId}/activityLog: Read by members; write by system (via app logic)
- rooms/{roomId}/settlements: Read by members; write by admin
```

---

## 8. User Flows

### 8.1 Onboarding Flow
```
App Launch → Login/Register → Profile Setup (Name, UPI ID) → Create Room / Join Room → Dashboard
```

### 8.2 Add Expense Flow
```
Dashboard → FAB (+) → Expense Form → Select Split Type → Choose Members (if dynamic) → Save → Notification sent to all → Activity Log updated
```

### 8.3 Settlement Flow
```
Admin: Dashboard → Close Month → Net balances calculated → Settlement screen → Member taps "Pay via UPI" → UPI app opens with pre-filled data → Mark as Settled
```

### 8.4 Reminder Flow
```
Admin: Dashboard → Reminders → Manual: Select user → Send Now
                              → Scheduled: Set date/time/recurrence → Save
```

---

## 9. Screen List

| # | Screen | Description |
|---|--------|-------------|
| 1 | Splash Screen | App logo + auto-login check |
| 2 | Login Screen | Email/Google/Phone auth |
| 3 | Register Screen | New user signup |
| 4 | Profile Setup | Name, avatar, UPI ID |
| 5 | Room List | User's rooms with create/join options |
| 6 | Create Room | Room name + generate invite code |
| 7 | Join Room | Enter invite code |
| 8 | Dashboard | Balances, who-owes-whom, recent expenses |
| 9 | Add/Edit Expense | Form with split options |
| 10 | Expense List | All expenses with filters |
| 11 | Analytics | Charts (by person, by category) |
| 12 | Activity Log | Chronological timeline |
| 13 | Settlement | Month-end balances + UPI pay buttons |
| 14 | Reminders | Manual + scheduled reminders |
| 15 | Room Settings | Members, roles, invite code |
| 16 | Profile/Settings | Edit profile, logout |

---

## 10. Firebase Free Tier Constraints & Mitigations

| Constraint | Limit | Mitigation |
|-----------|-------|------------|
| Firestore reads | 50,000/day | Paginate lists, use local cache aggressively |
| Firestore writes | 20,000/day | Batch writes, debounce edits |
| Firestore storage | 1 GB | No large files; receipt images compressed |
| FCM | Unlimited | No concern |
| Auth | Unlimited | No concern |
| Cloud Functions | Not available on free tier | Use client-side triggers for notifications |

### Notification Strategy (Without Cloud Functions)

Since Cloud Functions require the Blaze (paid) plan, notifications will be handled via:

1. **FCM Topic Messaging**: Each room is a topic. All members subscribe to the room topic.
2. **Client-side Firestore listeners**: When a new expense document appears in the snapshot listener, the app triggers a local notification using `flutter_local_notifications`.
3. **Foreground notifications**: Handled in-app via Firestore stream listeners showing snackbars/banners.
4. **Background sync**: When the app is in background, Firestore listeners persist (on Android) and can trigger local notifications.

> **Note**: True cross-device push notifications (when app is killed) require either Cloud Functions (Blaze plan) or a third-party service like OneSignal (free tier available). This can be added in v1.1 if needed.

---

## 11. Assumptions & Constraints

| # | Assumption/Constraint |
|---|----------------------|
| 1 | Maximum 10 members per room |
| 2 | All amounts are in INR (₹) |
| 3 | Users must have a UPI ID for settlement feature |
| 4 | Internet required for initial sync; offline mode for viewing cached data |
| 5 | No web version in v1.0 (mobile only) |
| 6 | No payment gateway integration — UPI is intent-based only (no transaction verification) |
| 7 | Receipt image upload deferred to v1.1 |

---

## 12. Success Metrics

| Metric | Target |
|--------|--------|
| Onboarding completion rate | > 80% |
| Daily active usage per room | > 60% of members |
| Average expense entry time | < 15 seconds |
| Settlement completion rate | > 90% within 3 days of month close |
| App crash rate | < 0.5% |

---

## 13. Release Plan

| Phase | Scope | Timeline |
|-------|-------|----------|
| v1.0 - MVP | Auth, Room, Expenses (Equal + Dynamic split), Dashboard, Balances, Activity Log, UPI Settlement | 4-5 weeks |
| v1.1 | Analytics charts, Scheduled reminders, 1-to-1 sharing, Cross-device push notifications | 2-3 weeks |
| v1.2 | Receipt uploads, Custom categories, Monthly trends, Multi-room support | 2-3 weeks |

---

## 14. Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Firebase free tier quota exceeded | App stops syncing | Aggressive caching, paginated queries, usage monitoring |
| Push notifications without Cloud Functions | Members miss updates when app is killed | Firestore listeners + local notifications; upgrade to Blaze or use OneSignal in v1.1 |
| UPI intent not supported on all devices | Settlement fails | Show manual "Copy UPI ID + Amount" fallback |
| Member disputes over edits | Trust issues | Audit log with full edit history |
| Offline data conflicts | Stale data shown | Firestore handles merge conflicts; show sync status indicator |

---

## 15. Glossary

| Term | Definition |
|------|-----------|
| Room | A shared space/group where roommates track expenses together |
| Admin | The room creator with full control |
| Member | A roommate who can add/edit own expenses |
| Split | The division of an expense amount among selected users |
| Settlement | The act of paying one's owed balance at month-end |
| Ledger | The complete record of all expenses for a given month |
| UPI | Unified Payments Interface — India's real-time payment system |

---

*End of Document*
