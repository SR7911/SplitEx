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

### Loan & EMI Manager *(Planned — Not Yet Implemented)*
- **Dashboard (Hero Card Layout)**
  - Hero card per loan showing: lender name, principal, outstanding balance, next EMI date & amount, status badge (Active / Partially Settled / Settled / Foreclosed)
  - Radial progress ring gauge: total settled vs remaining outstanding
  - Amortization stacked bar chart: interest vs principal split per month
  - Quick-action buttons: Log Payment, Partial Prepayment, Force Close (Foreclosure)
- **Add / Edit Loan**
  - Inputs: lender name, principal amount, annual interest rate (0% supported for retail EMIs), tenure (months or years), loan start date, monthly EMI due date
  - System auto-calculates: EMI amount (standard amortization formula), loan end date, full amortization schedule
  - Editing principal or rate triggers full schedule recalculation
- **Amortization Ledger**
  - Month-by-month breakdown: EMI paid, interest component, principal deducted, remaining balance
  - Accessible via bottom sheet on the Reports page
- **Payment Logging**
  - Standard EMI: deducts fixed principal + interest for the month
  - Partial prepayment: reduces remaining principal immediately, recalculates future EMIs (tenure fixed, EMI reduces)
  - Force close / foreclosure: clears remaining principal + accrued interest to date, marks loan as Foreclosed
- **Recurring Integration**
  - On loan creation → auto-creates a recurring transaction entry in Personal Finance (monthly, EMI amount, category: Loan EMI)
  - On loan closure / foreclosure → auto-disables the linked recurring transaction
  - Recurring entry reflects updated EMI amount after any partial prepayment
- **Reports Page**
  - List of all loans with status filters
  - Tap any loan → bottom sheet with full amortization schedule, past EMI history (date + amount), next EMI date & amount
- **Firebase Data Store**
  - Collection: `users/{uid}/loans` — loan metadata + status
  - Sub-collection: `loans/{loanId}/payments` — individual payment log entries
  - Linked recurring transaction ID stored on the loan document for sync

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
│   ├── home/        # Main dashboard
│   ├── room/        # Room CRUD, detail, settings
│   ├── expense/     # Room expenses
│   ├── bills/       # Fixed bills
│   ├── personal/    # Personal finance (8 screens)
│   ├── loans/       # Loan & EMI manager (planned)
│   ├── analytics/   # Charts
│   ├── activity/    # Audit log
│   ├── settings/    # User preferences
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

### Loan & EMI Manager (Priority 1)
See full BRD: `docs/LOAN_EMI_BRD.md`

**Screens to build:**
- `loans/loan_dashboard_screen.dart` — hero cards + radial ring + bar chart
- `loans/add_edit_loan_screen.dart` — loan form with auto-calculation
- `loans/loan_reports_screen.dart` — list view + bottom sheet amortization ledger
- `loans/loan_detail_screen.dart` — payment history, next/past EMI details

**Services / Providers to build:**
- `services/loan_service.dart` — Firestore CRUD, amortization engine, partial payment recalc, force close
- `providers/loan_provider.dart` — Riverpod state for loan list + selected loan

**Integration points:**
- `services/loan_service.dart` ↔ `services/recurring_service.dart` — auto-create/disable recurring on loan add/close
- Loan document stores `linkedRecurringId` for two-way sync

**Firebase collections:**
```
users/{uid}/loans/{loanId}
  - lenderName, principal, annualRate, tenureMonths
  - startDate, emiDueDay, endDate (auto)
  - baseEmi (auto), remainingPrincipal, status
  - linkedRecurringId

users/{uid}/loans/{loanId}/payments/{paymentId}
  - date, emiPaid, principalDeducted, interestPaid
  - remainingAfter, type (standard | partial | foreclosure)
```

**Amortization formula:**
```
EMI = P × [r(1+r)^n] / [(1+r)^n - 1]   where r = annualRate/1200, n = tenureMonths
Monthly Interest = remainingPrincipal × r
Principal Deducted = EMI - Monthly Interest
```

**Status flags:** Active → Partially Settled → Settled / Foreclosed

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

### Known issues
- Image upload issue
- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase for Flutter](https://firebase.google.com/docs/flutter/setup)
- [Riverpod](https://riverpod.dev/)
