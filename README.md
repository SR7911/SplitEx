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
