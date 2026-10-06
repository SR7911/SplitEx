# SplitEx

A Flutter expense management app with two core modules:
1. **Room-based expense splitting** — Share costs with roommates/groups
2. **Personal finance tracker** — Track income, expenses, budgets, and peer-to-peer debts

## Getting Started

### Prerequisites
- Flutter SDK (^3.11.5) / Dart SDK (^3.11.5)
- Firebase project with Auth, Firestore, Storage, FCM, Crashlytics, and App Check enabled
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
- **Weekly expense analysis** — 4-week bar chart on dashboard tab + detailed weekly section in reports
  - W1–W4 vertical bars with current week highlight and highest-week indicator
  - Trend insight: this week vs last week percentage change
  - Reports sheet: horizontal bars per week with avg, high/low color coding, transaction count, and insight line
- **Category drill-down** — tap any category chip or breakdown row in reports to open a filtered transaction list for that category and month
- Recurring transactions (weekly/monthly) with auto-expiry
- **Peer-to-peer debt tracking (Lent/Borrowed) — Revamped**
  - Dedicated Debt Dashboard with net balance hero card, 6-month bar chart, lent vs borrowed donut chart
  - Most debted people section (consolidated net per person)
  - Monthly Debt List with month navigation, search, and filters (type/status/amount)
  - Dedicated Add Debt sheet with person name autocomplete
  - Settle individual debts with full or partial settlement
  - Settled items shown as disabled (not removed)

### Loan & EMI Manager *(Implemented)*
- **Loan List Screen** (`loans/loan_list_screen.dart`)
  - Hero summary card: total outstanding, borrowed vs lent, monthly EMI
  - Mini stat row: active count, outstanding, monthly EMI
  - Per-loan cards with animated progress bar, status badge (Active / Settled / Foreclosed)
  - Card footer shows: EMI amount, **X/Y EMIs paid**, **Next due date** (e.g. `Next: 05 Jul`)
  - Force close, delete recurring, delete loan via popup menu
- **Add / Edit Loan** (`loans/add_loan_sheet.dart`)
  - Loan type toggle: Borrowed / Lent
  - Inputs: title, lender/borrower name, principal, annual rate (0% supported), tenure, EMI due day, start date
  - **First EMI Date picker** — separate from loan start date; auto-defaults to start + 1 month with override option
  - Auto-calculates EMI (standard amortization formula) with live preview
  - EMI override toggle for custom/actual EMI amounts
  - Charges & Fees section: processing fee, insurance fee, other charges, 18% GST on processing fee
  - Net disbursed amount shown after deductions
  - Edit mode recalculates EMI and syncs linked recurring entry
- **Loan Detail Screen** (`loans/loan_detail_screen.dart`)
  - Hero card: remaining principal, progress bar, rate/tenure/end date chips
  - **EMI progress line**: `EMI ₹XXXX · 3/24 paid · Next: 05 Jul`
  - Action buttons: Log EMI, Partial Prepayment / Record Repayment, Force Close
  - Payment history with type badges (EMI / Partial / Foreclosure), principal + interest breakdown
  - Amortization schedule tab (borrowed loans): month-by-month EMI, principal, interest, balance; paid months highlighted
- **Payment Logging** (`services/loan_service.dart`)
  - Standard EMI: computes interest/principal split from remaining balance
  - Partial prepayment: reduces principal, recalculates future EMI, updates linked recurring amount
  - Force close / foreclosure: pays remaining principal + accrued interest, marks Foreclosed
  - **Each payment auto-logs a personal expense transaction (category: Loan EMI) with dedup guard** — tagged with `loanSourceId` to prevent duplicate entries
- **EMI Schedule accuracy** — `emiStartDate` field lets users set the exact first EMI date; amortization and missed-EMI detection use this as the schedule anchor
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
| State Management | Riverpod (^2.6.1) + riverpod_generator |
| Backend | Firebase (Firestore, Auth, Storage, FCM, Crashlytics, App Check) |
| Charts | fl_chart (^0.70.2) |
| Navigation | go_router (^15.1.2) |
| Payments | UPI deep links (url_launcher) |
| PDF / Export | pdf + share_plus |
| Notifications | flutter_local_notifications |

---

## Project Structure

```
lib/
├── config/
│   ├── constants.dart
│   ├── dev_config.dart
│   ├── router.dart
│   └── theme.dart
├── models/
│   ├── activity_model.dart
│   ├── bill_model.dart
│   ├── expense_model.dart
│   ├── group_expense_model.dart
│   ├── group_model.dart
│   ├── loan_model.dart
│   ├── notification_model.dart
│   ├── personal_transaction_model.dart
│   ├── project_model.dart
│   ├── room_model.dart
│   ├── settlement_model.dart
│   └── user_model.dart
├── providers/
│   ├── activity_provider.dart
│   ├── auth_provider.dart
│   ├── bill_provider.dart
│   ├── connectivity_provider.dart
│   ├── dashboard_provider.dart
│   ├── expense_provider.dart
│   ├── group_provider.dart
│   ├── loan_provider.dart
│   ├── notification_provider.dart
│   ├── personal_expense_provider.dart
│   ├── project_provider.dart
│   ├── room_provider.dart
│   ├── settlement_provider.dart
│   └── theme_provider.dart
├── services/
│   ├── activity_service.dart
│   ├── app_update_service.dart
│   ├── auth_service.dart
│   ├── balance_service.dart
│   ├── bill_service.dart
│   ├── expense_service.dart
│   ├── fcm_service.dart
│   ├── group_service.dart
│   ├── loan_service.dart
│   ├── notification_helper.dart
│   ├── notification_listener.dart
│   ├── notification_service.dart
│   ├── personal_expense_service.dart
│   ├── project_service.dart
│   ├── receipt_generator.dart
│   ├── recurring_processor.dart
│   ├── room_service.dart
│   ├── settlement_service.dart
│   ├── storage_management_service.dart
│   ├── upi_service.dart
│   ├── upload_service.dart
│   ├── usage_tracker.dart
│   └── user_service.dart
├── screens/
│   ├── auth/                    # login_screen, register_screen
│   ├── home/                    # home_screen, room_tab
│   ├── dashboard/               # dashboard_screen
│   ├── profile/                 # profile_setup_screen
│   ├── room/                    # create, join, list, detail, settings, pair_settlement_card
│   ├── expense/                 # add_expense_sheet, view_expense_sheet
│   ├── bills/                   # add_bill_sheet, view_bill_sheet
│   ├── groups/                  # 7 screens — list, create, join, dashboard, expense, settlement, reports
│   ├── projects/                # 7 screens — list, create, dashboard, expenses, debts, reports, add_expense
│   ├── settlement/              # settlement_screen, upi_id_dialog
│   ├── personal/                # 11 files — transactions, budgets, debts, recurring, reports,
│   │                            #   debt_dashboard, debt_list, add_debt_sheet,
│   │                            #   add_personal_transaction, view_personal_transaction, personal_expense_tab
│   ├── loans/                   # loan_list, loan_detail, add_loan_sheet, loan_reports
│   ├── analytics/               # analytics_screen
│   ├── activity/                # activity_screen
│   ├── reminders/               # notifications_screen
│   ├── settings/                # settings, edit_profile, change_password, notification_preferences
│   ├── developer/               # storage_management_screen (dev only)
│   └── splash/                  # splash_screen
├── widgets/
│   ├── design_system/           # app_colors, app_empty_state, app_hero_chip, app_loading_shimmer,
│   │                            #   app_mini_stat_card, app_month_selector, app_quick_action_tile,
│   │                            #   app_section_header, app_spacing, app_stat_card, app_text_styles,
│   │                            #   design_system (barrel export)
│   ├── app_header.dart
│   ├── offline_banner.dart
│   └── receipt_picker.dart
├── utils/
│   └── split_calculator.dart
├── app.dart
└── main.dart
```

---

## Documentation

- [Firebase Collections](FIREBASE_COLLECTIONS.md)
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
