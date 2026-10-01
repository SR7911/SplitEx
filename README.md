# SplitEx

A Flutter expense management app with two core modules:
1. **Room-based expense splitting** — Share costs with roommates/groups
2. **Personal finance tracker** — Track income, expenses, budgets, and peer-to-peer debts

## Getting Started

### Prerequisites
- Flutter SDK (^3.11.5)
- Firebase project with Auth, Firestore, Storage, and FCM enabled
- Android Studio / VS Code

### Setup
1. Clone the repo
2. Place `google-services.json` in `android/app/`
3. Run `flutter pub get`
4. Run `flutter run`

---

## Features

### Room Expense Splitting
- Create/join rooms with invite codes
- Add expenses with equal, dynamic, or 1-to-1 splits
- Track who owes whom with debt simplification
- Settle via UPI (GPay, PhonePe, Paytm)
- Activity log & audit trail
- Bill management (rent, electricity, water)
- Analytics with charts (by person, by category)
- Push notifications for expense actions
- Admin controls (lock month, remove members)

### Personal Finance
- Track income & expenses with 19+ categories
- Monthly financial dashboard with animated summaries
- Category budgets with progress tracking
- Day-wise transaction grouping with daily totals
- Spending breakdown pie chart
- Daily spending bar chart (weekday vs weekend)
- Recurring transactions (weekly/monthly) with auto-expiry
- **Peer-to-peer debt tracking (Lent/Borrowed)**
  - Tag transactions with a person's name
  - Separate Lent vs Borrowed views
  - Settle individual debts with confirmation
  - Settled items shown as disabled (not removed)

### Loan & EMI Manager *(Implemented)*
- **Loan List Screen** (`loans/loan_list_screen.dart`)
  - Hero summary card: total outstanding, borrowed vs lent, monthly EMI
  - Mini stat row: active count, outstanding, monthly EMI
  - Per-loan cards with animated progress bar, status badge (Active / Settled / Foreclosed)
  - Force close, delete recurring, delete loan via popup menu
- **Add / Edit Loan** (`loans/add_loan_sheet.dart`)
  - Loan type toggle: Borrowed / Lent
  - Inputs: title, lender/borrower name, principal, annual rate (0% supported), tenure, EMI due day, start date
  - Auto-calculates EMI (standard amortization formula) with live preview
  - EMI override toggle for custom/actual EMI amounts
  - Charges & Fees section: processing fee, insurance fee, other charges, 18% GST on processing fee
  - Net disbursed amount shown after deductions
  - Edit mode recalculates EMI and syncs linked recurring entry
- **Loan Detail Screen** (`loans/loan_detail_screen.dart`)
  - Hero card: remaining principal, progress bar, rate/tenure/end date chips
  - Action buttons: Log EMI, Partial Prepayment / Record Repayment, Force Close
  - Payment history with type badges (EMI / Partial / Foreclosure), principal + interest breakdown
  - Amortization schedule tab (borrowed loans): month-by-month EMI, principal, interest, balance; paid months highlighted
- **Payment Logging** (`services/loan_service.dart`)
  - Standard EMI: computes interest/principal split from remaining balance
  - Partial prepayment: reduces principal, recalculates future EMI, updates linked recurring amount
  - Force close / foreclosure: pays remaining principal + accrued interest, marks Foreclosed
  - Each payment auto-logs a personal expense transaction (category: Loan EMI)
- **Recurring Integration**
  - Loan closure / foreclosure → auto-disables linked recurring transaction
  - Partial prepayment → updates recurring amount to new recalculated EMI
  - Loan document stores `recurringId` for two-way sync
- **Firebase Data Store**
  - Collection: `users/{uid}/loans` — loan metadata + status
  - Sub-collection: `loans/{loanId}/payments` — individual payment log entries
  - Linked recurring transaction ID stored on the loan document for sync

> **Not yet implemented from original BRD:** radial progress ring gauge, amortization stacked bar chart on dashboard
> **Implemented:** dedicated reports screen with status filters (`loans/loan_reports_screen.dart`)

### General
- Email/Password and Google Sign-In
- Light/Dark/System theme with 10 color palettes
- Offline support (Firestore persistence)
- Splash screen with update checker
- Settings (profile, password, notifications, export)

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) |
| State Management | Riverpod |
| Backend | Firebase (Firestore, Auth, Storage, FCM) |
| Charts | fl_chart |
| Navigation | go_router |
| Payments | UPI deep links (url_launcher) |

---

## Project Structure

```
lib/
├── config/          # Theme, router, constants
├── models/          # Data classes (Firestore serialization)
├── services/        # Firebase operations & business logic
├── providers/       # Riverpod state management
├── screens/
│   ├── auth/        # Login, Register
│   ├── home/        # Main shell + room tab
│   ├── dashboard/   # Personal finance dashboard
│   ├── profile/     # Profile setup
│   ├── room/        # Room CRUD, detail, settings
│   ├── expense/     # Room expense sheets
│   ├── bills/       # Fixed bill sheets
│   ├── groups/      # Group expense splitting (7 screens)
│   ├── projects/    # Project-based expenses (7 screens)
│   ├── settlement/  # Settlement flow + UPI dialog
│   ├── personal/    # Personal finance (transactions, budgets, debts, recurring)
│   ├── loans/       # Loan & EMI manager (list, detail, add/edit sheet)
│   ├── analytics/   # Charts
│   ├── activity/    # Audit log
│   ├── reminders/   # Notifications screen
│   ├── settings/    # User preferences (4 screens)
│   ├── developer/   # Storage management (dev only)
│   └── splash/      # Splash + update check
├── widgets/         # Reusable components
└── utils/           # Pure utility functions
```

---

## Documentation

- [Firebase Collections](FIREBASE_COLLECTIONS.md)
- [Personal Expense Screens](docs/PERSONAL_EXPENSE.md)
- [File Explanations](docs/FILE_EXPLANATION.md)
- [App Architecture](docs/APP_HELPER.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Changelog](docs/CHANGELOG.md)

---

## Known Issues

- Image upload issue
- Settlement UPI apps showing error during payment (GPay, PhonePe, Paytm)
- Clicking settle up in homepage moves to expense tab instead of settlement tab
- Settlement tab showing same data when changing months
- Pending settlements showing in activity log and recent activity
- Home page selecting other month shows current month recent activity

---

## Future Requirements

### Loan & EMI Manager — Remaining Items
Core implementation is done. Remaining enhancements from the original BRD:
- `loans/loan_dashboard_screen.dart` — radial progress ring gauge + amortization stacked bar chart
- ~~`loans/loan_reports_screen.dart`~~ ✅ Done — status filter chips, per-loan summary cards, amortization schedule + payment history bottom sheet
- Auto-create recurring entry on loan creation (currently manual)

---

### Nice-to-Have
- Receipt scanning (OCR)
- Multi-currency support with conversion
- Export reports (PDF/CSV)
- In-app chat per group
- Monthly spending trends over time

### Settings & Account (Priority 2)
- Phone auth (OTP)
- Biometric lock (Face ID / Fingerprint)
- Help Center / FAQs
- Anonymous sign-in

---

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase for Flutter](https://firebase.google.com/docs/flutter/setup)
- [Riverpod](https://riverpod.dev/)
