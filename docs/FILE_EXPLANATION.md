# SplitEx — File-by-File Explanation

Reference to the app's main files, with **What** each does and **Why** it exists. Updated 2026-10-21 to include Android SMS recording and the recent personal finance features.

---

## Root Files

### `pubspec.yaml`
- **What:** Declares app dependencies, metadata, version, and assets.
- **Why:** Flutter needs this to resolve packages, manage versions, and include fonts/assets in the build.

### `analysis_options.yaml`
- **What:** Linting rules for Dart code.
- **Why:** Enforces code quality standards across the project.

### `README.md`
- **What:** Project overview, getting started guide, and future requirements roadmap.
- **Why:** Documentation for developers and contributors.

### `FIREBASE_COLLECTIONS.md`
- **What:** Documents the Firestore database schema (collections, fields, types).
- **Why:** Serves as a reference for the data layer — ensures all developers work against the same schema.

### `firestore.rules`
- **What:** Firestore Security Rules that enforce read/write permissions server-side.
- **Why:** Prevents unauthorized data access. Only room members can read room data; only admin can delete expenses.

### `BANK_SMS_RECORDING.md` and `PERSONAL_FINANCE_FEATURES.md`
- **What:** Feature guides for SMS consent/review/importing, accounts/transfers, calendar, monthly review, merchant rules and savings goals.
- **Why:** Explain user entry points, accounting semantics, privacy, setup and verification. Recent storage additions are also summarized in [APP_HELPER.md](APP_HELPER.md).

---

## `docs/` — Documentation

### `docs/CHANGELOG.md`
- **What:** Historical changes plus a dated unreleased section for the recent implementation.
- **Why:** Records behavior changes and verification without implying deployment.

### `docs/DEPLOYMENT.md`
- **What:** Release build, signing, Firebase rules/App Check, SMS permissions and device verification checklist.
- **Why:** Separates implemented functionality from the setup and validation required for production.

### `docs/FILE_EXPLANATION.md`
- **What:** This source-file reference.
- **Why:** Maps features to the files responsible for their data, logic, state and UI.

### `docs/APP_HELPER.md`
- **What:** High-level app flow, architecture diagram, design decisions, and personal finance module reference (navigation, debt balance logic, budget status thresholds).
- **Why:** Helps new developers (or future-you) understand how the app works without reading every file.

---

## `lib/` — Application Source Code

### `lib/main.dart`
- **What:** App entry point. Initializes Firebase, Firestore persistence, notifications, FCM, and runs the app.
- **Why:** Every Flutter app needs a `main()`. This sets up all infrastructure before the UI renders.

### `lib/app.dart`
- **What:** Root `MaterialApp.router` widget. Applies theme, dark mode, router config and offline banner; binds SMS processing to auth changes and foreground resume without blocking startup on optional SMS failures.
- **Why:** Separates app shell configuration from initialization logic in `main.dart`.

---

## `lib/config/` — App Configuration

### `lib/config/constants.dart`
- **What:** Defines app-wide constants — app name, expense categories list, category icons, pagination limits.
- **Why:** Single source for magic values. Change a category here, it updates everywhere.

### `lib/config/dev_config.dart`
- **What:** Development mode flags — `skipAuth` (bypass login), `devUserId` (simulate a user).
- **Why:** Allows rapid testing without signing in every time. Multi-device testing by changing user ID.

### `lib/config/router.dart`
- **What:** GoRouter configuration — all routes, auth guards (redirect unauthenticated users to login).
- **Why:** Centralized navigation. Auth redirect ensures users can't access screens without logging in.

### `lib/config/theme.dart`
- **What:** Complete theme system — 10 color palettes, light/dark/deep-dark themes, Material 3 styling.
- **Why:** Consistent design language. Users can pick their preferred palette and theme mode.

---

## `lib/models/` — Data Models

### `lib/models/group_model.dart`
- **What:** GroupModel data class — id, name, description, startDate, endDate, currency, inviteCode, createdBy, memberIds, status (active/archived), createdAt. Helpers: isArchived, isMember, isAdmin, copyWith.
- **Why:** Represents a shared group for expense splitting outside of rooms. Supports any group type (friends, family, trips).

### `lib/models/group_expense_model.dart`
- **What:** GroupExpenseModel — id, groupId, title, amount, category, notes, paidBy, splitType (GroupSplitType enum: equal/select), splitAmong, customSplits, date, createdBy, createdAt, updatedAt. Has shareFor() and toUpdateMap().
- **Why:** Core data unit for group expenses. Supports equal split across all members or selective split among chosen members.

### `lib/models/project_model.dart`
- **What:** ProjectModel (id, name, description, projectType, estimatedBudget, startDate, targetEndDate, status, createdBy, createdAt) and ProjectExpenseModel (adds vendor, notes, paymentMethod: cash/upi/card/bankTransfer).
- **Why:** Represents a personal project with a budget envelope. ProjectExpenseModel tracks individual spend items against that budget.

### `lib/models/personal_transaction_model.dart`
- **What:** PersonalTransactionModel — personal income/expense fields, optional `accountId`, debt direction/person, optional repayment `dueDate`, settlement/write-off history, `settledAmount` and `writtenOffAmount`. `remainingAmount` clamps `amount - settledAmount - writtenOffAmount` at zero. Recurring records support optional `createdAt` for the calendar's start bound.
- **Why:** Core model for personal finance. Doubles as a debt record when debtType is set. Also receives auto-logged entries from the Loan EMI tracker (tagged with `loanSourceId`).

### `lib/models/loan_model.dart`
- **What:** Three data classes — `LoanModel` (loan metadata: title, loanType, principal, annualInterestRate, tenureMonths, startDate, emiDueDay, emiStartDate, status, charges, recurringId, customEmi), `LoanPaymentModel` (individual payment log: amount, principalComponent, interestComponent, remainingPrincipalAfter, date, type, note), `AmortizationEntry` (computed schedule row: month, dueDate, emi, principal, interest, remainingPrincipal, isPaid). Computed getters: `baseEmi`, `netDisbursed`, `effectiveEmiStart`, `endDate`.
- **Why:** Core data layer for the Loan & EMI module. `emiStartDate` decouples the first EMI date from the loan start date for accurate schedule generation.

### `lib/models/personal_account_model.dart`
- **What:** Cash/bank/credit card accounts, own-account transfers and balance calculation using integer paise arithmetic.
- **Why:** Derives tracked balances from opening balances, assigned transactions and transfers without treating transfers as spending.

### `lib/models/payment_calendar_model.dart`
- **What:** Read-only monthly events projected from loan EMIs, recurring schedules and dated debts, including recorded/overdue/scheduled state.
- **Why:** Centralizes date clamping, log matching and duplicate-schedule exclusion for the calendar.

### `lib/models/monthly_money_review.dart`
- **What:** Monthly totals, category comparisons, budget checks, uncategorized expenses and current outstanding debt summaries.
- **Why:** Keeps selected-month and equal-elapsed-date comparison logic independent of the UI.

### `lib/models/savings_goal_model.dart`
- **What:** Savings targets, optional dates/account labels and signed progress entries, with integer-paise amounts and progress helpers.
- **Why:** Tracks savings plans separately from cash transactions and transfers.

### `lib/models/user_model.dart`
- **What:** User data class — uid, name, email, avatarUrl, upiId, rooms list, createdAt.
- **Why:** Represents a user profile in Firestore. Used for displaying names in rooms and UPI settlements.

### `lib/models/room_model.dart`
- **What:** Room data class — id, name, inviteCode, adminId, memberIds, currentMonth, isLocked.
- **Why:** Represents a shared space. Controls who can see/edit data and whether the month's expenses are locked.

### `lib/models/expense_model.dart`
- **What:** Expense data class — title, amount, category, date, paidBy, splitType, splitAmong, month.
- **Why:** Core data unit of the app. Every expense is tracked with who paid, how it's split, and when.

### `lib/models/activity_model.dart`
- **What:** Activity log entry — type (added/edited/deleted/settlement), performedBy, description, metadata.
- **Why:** Audit trail. Users can see who did what and when — builds trust in shared finances.

### `lib/models/bill_model.dart`
- **What:** Fixed bill data class — type (rent/electricity/water), amount, paidBy, month, receiptUrl.
- **Why:** Handles recurring fixed bills separately from ad-hoc expenses (different UI/logic).

### `lib/models/settlement_model.dart`
- **What:** Settlement record — fromUserId, toUserId, amount, status (pending/confirmed), upiRef.
- **Why:** Tracks who paid whom and whether the payment was confirmed. Prevents disputes.

### `lib/models/notification_model.dart`
- **What:** In-app notification — roomId, targetUserId, title, body, type, isRead.
- **Why:** Powers the notification feed and unread badge. Users know when expenses are added without opening the app.

---

## `lib/services/` — Business Logic & Firebase Operations

### `lib/services/group_service.dart`
- **What:** GroupService (createGroup with random 6-char invite code, joinByCode, leaveGroup, archiveGroup, restoreGroup, getUserGroupsStream, getGroupStream), GroupExpenseService (addExpense, updateExpense, deleteExpense, getExpensesStream), GroupBalanceService (computeNetBalances delegating to BalanceService.simplifyDebts).
- **Why:** All Firestore operations for the Groups module. Reuses existing debt simplification logic for consistency.

### `lib/services/project_service.dart`
- **What:** ProjectService (createProject, updateStatus, deleteProject, getProjectsStream, getProjectStream — scoped under `users/{uid}/projects`), ProjectExpenseService (addExpense, deleteExpense, getExpensesStream).
- **Why:** All Firestore operations for the Project Tracker module. Projects are user-private (not shared).

### `lib/services/auth_service.dart`
- **What:** Firebase Auth operations — signIn (email/Google), signUp, signOut, resetPassword, deleteAccount.
- **Why:** Encapsulates all authentication logic. Screens don't talk to Firebase directly.

### `lib/services/user_service.dart`
- **What:** Firestore user CRUD — createUserProfile, getUserProfile, updateUserProfile, userStream.
- **Why:** Manages the `users` collection. Used by profile setup, edit profile, and member name display.

### `lib/services/room_service.dart`
- **What:** Room CRUD — createRoom (generate invite code), joinRoom, getRoomStream, removeMember.
- **Why:** Handles room lifecycle. Generates unique invite codes for sharing.

### `lib/services/expense_service.dart`
- **What:** Expense CRUD — addExpense, updateExpense, deleteExpense, getExpensesStream (with month filter).
- **Why:** Core service. Every expense operation goes through here, including triggering activity logs.

### `lib/services/balance_service.dart`
- **What:** Calculates net balances from expenses — who owes whom and how much.
- **Why:** The heart of a split app. Reads all expenses for a month and computes the debt matrix.

### `lib/services/settlement_service.dart`
- **What:** Settlement CRUD — createSettlement, confirmSettlement, getSettlementsStream.
- **Why:** Manages the payment lifecycle (pending → confirmed).

### `lib/services/activity_service.dart`
- **What:** Writes activity log entries to Firestore when expenses/settlements change.
- **Why:** Provides transparency. All actions are logged with actor, action, and details.

### `lib/services/bill_service.dart`
- **What:** Fixed bill CRUD — addBill, getBillsStream (for rent, electricity, water).
- **Why:** Separate handling for bills that have receipt uploads and different split logic.

### `lib/services/notification_service.dart`
- **What:** Initializes flutter_local_notifications, creates notification channels, shows system notifications.
- **Why:** Displays OS-level notifications when the app detects new activity.

### `lib/services/notification_listener.dart`
- **What:** Firestore stream listener that watches for new notification documents and triggers local notifications.
- **Why:** Since we don't use Cloud Functions, this client-side listener acts as the notification trigger.

### `lib/services/notification_helper.dart`
- **What:** Helper to create NotificationModel documents in Firestore when actions occur.
- **Why:** Centralized notification creation logic — called by expense/settlement services.

### `lib/services/fcm_service.dart`
- **What:** Firebase Cloud Messaging setup — token management, topic subscription.
- **Why:** Enables push notifications when the app upgrades to Blaze plan or uses server triggers.

### `lib/services/loan_service.dart`
- **What:** Loan CRUD, payment logging, missed-EMI detection and schedules. EMI logs and their personal expenses are saved atomically with stable IDs; partial/foreclosure expense imports retain source/date duplicate checks. Expenses include `loanSourceId`. Schedules use `loan.effectiveEmiStart`.
- **Why:** Encapsulates all loan business logic — amortization math, payment splitting, recurring sync, and personal expense auto-logging with dedup protection.

### `lib/services/personal_expense_service.dart`
- **What:** Firestore CRUD for personal transactions, budgets and recurring entries, including account assignment validation, debt editing, dated partial/full settlements and close-debt write-offs. Lent receipts create income; borrowed repayments create expenses.
- **Why:** All personal finance Firestore operations in one service — transactions, budgets, recurring, and debt settlement.

### `lib/services/bank_sms_parser.dart`
- **What:** Pure parser for supported INR bank/UPI/card debit/credit alerts, sender normalization, review decisions and stable import identities.
- **Why:** Rejects non-payment messages and keeps parsing independently testable without Android or Firestore.

### `lib/services/bank_sms_repository.dart`
- **What:** Reviews duplicate candidates, creates or links personal entries/transfers and stores durable import receipts atomically. Applies merchant categories and can save a rule with an approved new expense.
- **Why:** Protects retries and existing records without uploading raw SMS bodies.

### `lib/services/bank_sms_service.dart`
- **What:** Riverpod/ChangeNotifier bridge to the Android MethodChannel, permission/configuration state, local reviews and foreground/background queue processing. Includes `bankSmsBackgroundMain`.
- **Why:** Coordinates capture/import lifecycle with authentication and Android jobs; account changes clear local SMS state.

### `lib/services/personal_account_service.dart`
- **What:** Owner-scoped account CRUD/archive and own-account transfer create/edit/delete operations, with account validation.
- **Why:** Keeps transfers separate from income/expenses and preserves history when an account is archived.

### `lib/services/merchant_category_service.dart`
- **What:** Owner-scoped normalized sender/merchant category rules, deterministic IDs, suggestions, CRUD and pause/resume providers.
- **Why:** Reuses a chosen category for future matching debit alerts without granting sender trust.

### `lib/services/savings_goal_service.dart`
- **What:** Goal CRUD/archive, progress/history providers and atomic contribution/withdrawal/deletion updates with stable entry IDs.
- **Why:** Preserves aggregate/history consistency and prevents negative progress without creating personal transactions.

### `lib/services/upi_service.dart`
- **What:** Constructs UPI intent URLs and launches payment apps (GPay, PhonePe, Paytm).
- **Why:** Allows one-tap settlement payments with pre-filled receiver ID and amount.

### `lib/services/upload_service.dart`
- **What:** Uploads files (receipt images, avatars) to Firebase Storage.
- **Why:** Generic upload utility used by expense receipts and profile photo features.

### `lib/services/receipt_generator.dart`
- **What:** Generates PDF receipts/reports from expense data.
- **Why:** Users can export or share expense summaries as PDF documents.

### `lib/services/storage_management_service.dart`
- **What:** Admin utility to check Firestore document counts and Storage usage.
- **Why:** Helps admins monitor free tier usage and clean up old data.

---

## `lib/providers/` — State Management (Riverpod)

### `lib/providers/personal_account_provider.dart`
- **What:** Account, transfer and assigned-transaction streams, plus loading/error-aware derived balances.
- **Why:** Recalculates balances when assignments or transfers change.

### `lib/providers/payment_calendar_provider.dart`
- **What:** Combines loan/payment, recurring and debt data for the displayed month.
- **Why:** Supplies the calendar's read-only event projection.

### `lib/providers/monthly_money_review_provider.dart`
- **What:** Month-family provider watching current/previous transactions, budgets and debts.
- **Why:** Keeps review comparisons reactive with explicit loading/error handling. Savings and merchant-rule providers live in their service files.

### `lib/providers/group_provider.dart`
- **What:** groupServiceProvider, groupExpenseServiceProvider, groupBalanceServiceProvider, userGroupsProvider, groupStreamProvider, groupExpensesProvider, groupNetBalancesProvider, groupSimplifiedDebtsProvider, groupUserBalanceProvider, groupTotalExpenseProvider.
- **Why:** Reactive state for the Groups module. Imports currentUserIdProvider from room_provider.dart.

### `lib/providers/project_provider.dart`
- **What:** projectServiceProvider, projectExpenseServiceProvider, userProjectsProvider, projectStreamProvider, projectExpensesProvider, projectTotalSpentProvider, projectCategoryBreakdownProvider.
- **Why:** Reactive state for the Project Tracker module. Imports currentUserIdProvider from room_provider.dart.

### `lib/providers/auth_provider.dart`
- **What:** Exposes authServiceProvider, userServiceProvider, authStateProvider (stream), userProfileProvider.
- **Why:** All auth-related state in one place. Screens watch these to react to login/logout.

### `lib/providers/room_provider.dart`
- **What:** userRoomsProvider (stream of user's rooms), currentRoomProvider, roomMembersProvider.
- **Why:** Provides room data to home screen, drawer, and all room-scoped screens.

### `lib/providers/expense_provider.dart`
- **What:** expensesStreamProvider, monthExpensesProvider, expense filter/sort state.
- **Why:** Screens watch these to display expense lists. Month-scoped for billing cycles.

### `lib/providers/dashboard_provider.dart`
- **What:** monthOverallBalanceProvider, currentUserIdProvider, recentActivitiesProvider.
- **Why:** Powers the home screen — balance card, activity feed, spending summaries.

### `lib/providers/activity_provider.dart`
- **What:** activitiesStreamProvider (for activity log screen), recentActivitiesProvider (for home screen).
- **Why:** Real-time activity feed that updates as actions happen.

### `lib/providers/settlement_provider.dart`
- **What:** settlementsStreamProvider, debts calculation, settlement state.
- **Why:** Provides settlement data to the settlement screen and dashboard.

### `lib/providers/bill_provider.dart`
- **What:** billsStreamProvider for the bills section.
- **Why:** Streams fixed bills for display and management.

### `lib/providers/notification_provider.dart`
- **What:** notificationsStreamProvider, unreadCountProvider.
- **Why:** Powers the notification bell badge and notification list screen.

### `lib/providers/personal_expense_provider.dart`
- **What:** Reactive state for the personal expense tab.

  | Provider | Description |
  |----------|-------------|
  | `personalTransactionsProvider(month)` | Transactions stream for a month |
  | `personalMonthlySummaryProvider(month)` | income / expenses / remaining / budgetUsage |
  | `personalCategorySpendingProvider(month)` | Map of spending per category |
  | `personalBudgetsProvider(month)` | Category budgets stream for a month |
  | `personalRecurringProvider` | All recurring transactions stream |
  | `personalDebtsProvider` | All debt-tagged transactions (all months) |
  | `personalDebtsByMonthProvider(month)` | Debts filtered to a specific month |
  | `personalDebtBalancesProvider` | Net remaining balance per person (uses `remainingAmount`) |
  | `debtPersonSuggestionsProvider` | Sorted unique person names from all debt history |

- **Why:** Screens watch these to display financial data without direct Firestore calls.

### `lib/providers/loan_provider.dart`
- **What:** `loanServiceProvider`, `loansProvider` (stream), `loanPaymentsProvider(loanId)` (stream), `loanRemainingPrincipalProvider(loanId)` (derived from last payment), `loanScheduleProvider(loanId)` (computed amortization), `loanEmiProgressProvider(loanId)` (returns `LoanEmiProgress` with `paidCount`, `totalCount`, `nextDueDate`), `loanSummaryProvider` (aggregate stats across all active loans).
- **Why:** Reactive state for the Loan module. `loanEmiProgressProvider` drives the paid/total EMI count and next due date shown on list cards and the detail hero card.

### `lib/providers/theme_provider.dart`
- **What:** themeModeProvider, appPaletteProvider — persisted to SharedPreferences.
- **Why:** Allows users to switch themes/palettes and persist the choice across sessions.

### `lib/providers/connectivity_provider.dart`
- **What:** Monitors network connectivity status.
- **Why:** Drives the offline banner widget — shows "No internet" when disconnected.

---

## `lib/screens/` — UI Screens

### `lib/screens/personal/personal_tools_section.dart`
- **What:** Dashboard cards for Accounts & Wallets, Payment Calendar, Monthly Money Review and Savings Goals, plus the Android SMS review badge.
- **Why:** Provides consistent entry points and passes the selected dashboard month to the review route.

### `lib/screens/personal/personal_accounts_screen.dart`
- **What:** Tracked account balances, account create/edit/archive/restore, assigned transactions and editable dated transfer history.
- **Why:** Provides account bookkeeping in one place without changing spending totals for own-account transfers.

### `lib/screens/personal/payment_calendar_screen.dart`
- **What:** Full month grid, payment dots/amounts, arrows/swipes/date jump/Today, event filters and day/month agenda.
- **Why:** Gives scheduled payments a calendar view; event taps open existing details without recording anything.

### `lib/screens/personal/monthly_money_review_screen.dart`
- **What:** Monthly income/spending comparison, category changes, budgets, uncategorized expense editing and current debt sheets.
- **Why:** Turns recorded data into a monthly review with direct access to entries that need attention.

### `lib/screens/personal/savings_goals_screen.dart`
- **What:** Goals list and detail screens with target/date/account-label forms, progress history, contributions/withdrawals and archive/restore.
- **Why:** Keeps savings planning and history accessible from Personal.

### `lib/screens/personal/merchant_category_rules_screen.dart`
- **What:** Add/edit/pause/delete sender/merchant category rules.
- **Why:** Gives users control over categories remembered from SMS review.

### `lib/screens/settings/bank_sms_settings_screen.dart`
- **What:** SMS disclosure, capture/permission controls, sender trust and editable review actions; `reviewOnly` also serves the Personal inbox.
- **Why:** Reuses the review workflow for settings and Personal, including linking existing entries and remembering merchant categories.

### `lib/screens/personal/debt_widgets.dart`
- **What:** Shared debt tiles and actions, Receive/Repay controls, remaining/original amount presentation, editing, settlement date and history sheets.
- **Why:** Keeps debt behavior and styling consistent across dashboards and lists.

### `lib/screens/auth/login_screen.dart`
- **What:** Email/password login form + Google Sign-In button + Forgot Password link.
- **Why:** Entry point for existing users. Guards all app content behind authentication.

### `lib/screens/auth/register_screen.dart`
- **What:** Registration form — name, email, password fields.
- **Why:** New users create accounts here before being redirected to profile setup.

### `lib/screens/profile/profile_setup_screen.dart`
- **What:** One-time setup after first login — enter display name.
- **Why:** Ensures every user has a name to display in rooms before they can proceed.

### `lib/screens/home/home_screen.dart`
- **What:** Main app screen — greeting, balance card, room info, category chart, quick actions, activity feed, drawer.
- **Why:** The dashboard. Users see their financial status at a glance and access all features.

### `lib/screens/room/create_room_screen.dart`
- **What:** Form to create a new room (enter name → generates invite code).
- **Why:** Users need to create a shared space before tracking expenses.

### `lib/screens/room/join_room_screen.dart`
- **What:** Form to enter an invite code and join an existing room.
- **Why:** Second user onboarding — roommates join using a code shared by the creator.

### `lib/screens/room/room_list_screen.dart`
- **What:** Lists all rooms the user belongs to.
- **Why:** Navigation hub when multi-room support is enabled.

### `lib/screens/room/room_detail_screen.dart`
- **What:** Room's main view — tabs for expenses, settlements, members, bills.
- **Why:** Everything related to a specific room in one place.

### `lib/screens/room/room_settings_screen.dart`
- **What:** Room configuration — member list, invite code, admin controls (remove member, lock month).
- **Why:** Admin needs to manage the room. Members can see who's in the group.

### `lib/screens/expense/add_expense_sheet.dart`
- **What:** Expense entry bottom sheet with title, amount, category, date, split type, members and receipt attachment.
- **Why:** Faster UX. Users can add expenses without leaving the home screen.

### `lib/screens/expense/view_expense_sheet.dart`
- **What:** Expense detail sheet with permitted inline editing, payer and split breakdown. Expense lists are hosted in the room UI.
- **Why:** Lets authorized users inspect and correct an expense without a separate edit screen.

### `lib/screens/bills/add_bill_sheet.dart`
- **What:** Bottom sheet version of bill entry.
- **Why:** Quick bill logging from the room detail screen.

### `lib/screens/bills/view_bill_sheet.dart`
- **What:** View bill details including receipt image.
- **Why:** Members can verify bills by seeing the uploaded receipt.

### `lib/screens/dashboard/dashboard_screen.dart`
- **What:** Detailed room dashboard — per-member balances, who-owes-whom, charts.
- **Why:** Deeper analytics beyond the home screen summary.

### `lib/screens/analytics/analytics_screen.dart`
- **What:** Charts screen — spend by person (bar chart), spend by category (pie chart).
- **Why:** Visual representation helps users understand spending patterns.

### `lib/screens/activity/activity_screen.dart`
- **What:** Chronological timeline of all room actions — expenses added/edited/deleted, settlements, members joining.
- **Why:** Transparency and accountability. Everyone can see what happened.

### `lib/screens/settlement/settlement_screen.dart`
- **What:** Shows debts with "Pay via UPI" buttons and settlement confirmation.
- **Why:** End-of-month flow. Users see what they owe and can pay with one tap.

### `lib/screens/settlement/upi_id_dialog.dart`
- **What:** Dialog to set/update user's UPI ID before settlement.
- **Why:** UPI payments need a receiver ID. This prompts users who haven't set one.

### `lib/screens/reminders/notifications_screen.dart`
- **What:** In-app notification feed — list of all notifications with read/unread state.
- **Why:** Users review past notifications and mark them as read.

### `lib/screens/developer/storage_management_screen.dart`
- **What:** Admin-only screen showing Firestore document counts and storage usage.
- **Why:** Helps admins stay within free tier limits and identify cleanup needs.

### `lib/screens/groups/groups_list_screen.dart`
- **What:** Lists all groups the user belongs to. Shows archived badge, FAB to create, action button to join by code.
- **Why:** Entry point for the Groups module. Navigates to group dashboard on tap.

### `lib/screens/groups/create_group_screen.dart`
- **What:** Form to create a new group — name, description, start/end date pickers.
- **Why:** Users create a shared group before adding expenses.

### `lib/screens/groups/join_group_screen.dart`
- **What:** 6-character invite code entry with uppercase enforcement.
- **Why:** Second user onboarding — join an existing group via shared code.

### `lib/screens/groups/group_dashboard_screen.dart`
- **What:** 3-tab screen: Overview (invite code card + balance cards), Expenses (list with long-press delete), Settle Up (simplified debts). Admin gets archive/restore menu; non-admin gets leave button.
- **Why:** Central hub for a group — all group data and actions in one place.

### `lib/screens/groups/group_expense_sheet.dart`
- **What:** Bottom sheet for adding group expenses — equal/select split, category dropdown, date picker, member filter chips.
- **Why:** Quick expense entry within a group context.

### `lib/screens/projects/projects_list_screen.dart`
- **What:** Lists all user projects with budget progress bar and status color badge per project.
- **Why:** Entry point for the Project Tracker module.

### `lib/screens/projects/create_project_screen.dart`
- **What:** Form to create a project — name, description, project type dropdown, estimated budget, start/end dates.
- **Why:** Users define a project envelope before tracking expenses against it.

### `lib/screens/projects/project_dashboard_screen.dart`
- **What:** 2-tab screen: Overview (budget card + category breakdown bars), Expenses (list with long-press delete). Status change via popup menu.
- **Why:** Central hub for a project — budget tracking and expense history.

### `lib/screens/projects/add_project_expense_sheet.dart`
- **What:** Bottom sheet for adding project expenses — universal categories, vendor field, payment method chips (cash/UPI/card/bank transfer), notes.
- **Why:** Expense entry scoped to a project with vendor and payment context.

### `lib/screens/personal/personal_expense_tab.dart`
- **What:** Main personal finance dashboard tab with month navigation, financial summary, budget tracking, pie chart, weekly spending summary card, recent transactions, recurring preview, and utility shortcuts.
- **Why:** The primary view for personal expense tracking — provides at-a-glance financial status including a weekly bar chart for closer spend control.

### `lib/screens/personal/add_personal_transaction_screen.dart`
- **What:** Bottom sheet form to add income/expense with optional debt tracking (Lent/Borrowed with person name).
- **Why:** Primary data entry for personal transactions. Debt toggle enables peer-to-peer tracking.

### `lib/screens/personal/personal_transactions_screen.dart`
- **What:** Full transaction list with search, filter chips, day-wise grouping showing daily totals, and FAB. Accepts optional `initialCategory` param to pre-filter by category (used when navigating from reports).
- **Why:** Users browse and search all transactions grouped by date. Category drill-down from reports lands here with the filter pre-applied.

### `lib/screens/personal/view_personal_transaction_sheet.dart`
- **What:** Dual-mode bottom sheet — view transaction details (with debt info) or edit inline.
- **Why:** Quick view/edit without navigating to a new screen.

### `lib/screens/personal/personal_budgets_screen.dart`
- **What:** Manage category budgets with progress bars. Add dialog merges hardcoded + spent categories.
- **Why:** Users set spending limits per category and monitor usage.

### `lib/screens/personal/personal_recurring_screen.dart`
- **What:** Active/Past recurring transactions with detail sheets, pause/resume, delete, and add recurring.
- **Why:** Automate regular expenses (rent, subscriptions) without manual entry each month.

### `lib/screens/personal/personal_reports_screen.dart`
- **What:** Bottom sheet with income/expense stats banner, category distribution donut (tappable chips), spending breakdown bars (tappable rows), weekly analysis section (4-week horizontal bars with avg, high/low highlights, trend insight), and daily spending bar chart (weekday vs weekend).
- **Why:** Monthly and weekly spending insights — category drill-down navigates to a filtered transaction list for that category and month.

### `lib/screens/personal/add_debt_sheet.dart`
- **What:** Debt add/edit sheet with lent/borrowed direction, person suggestions, category, original date, optional account and repayment due date. Lent saves as expense; borrowed saves as income.
- **Why:** Dedicated debt entry flow separate from the general transaction sheet, with person suggestions for faster entry.

### `lib/screens/personal/debt_dashboard_screen.dart`
- **What:** Debt summaries, monthly activity chart with amount tooltips, categories, top lent/borrowed and recent debts, with matching detail sheets. View All opens the all-time list; Monthly Debts opens month-based activity.
- **Why:** Gives users a complete at-a-glance overview of all debt activity across all months in one screen.

### `lib/screens/personal/debt_list_screen.dart`
- **What:** Monthly debt tracking with `AppMonthSelector`, summaries, expandable/collapsible top categories, search and filters, shared debt tiles and add-debt FAB.
- **Why:** Lets users browse and filter debts month by month with full search and filter capability.

### `lib/screens/personal/personal_debts_screen.dart`
- **What:** All-time debt list with amount summaries and Lent/Borrowed/Settled tabs. Shared tiles support editing, Receive/Repay, dated settlement, close-debt warnings and per-debt history.
- **Why:** Tracks peer-to-peer money — who owes you and who you owe — with full settlement workflow.

### `lib/screens/loans/loan_list_screen.dart`
- **What:** Loan list screen with hero summary card, mini stat row, active/closed loan sections. Each `_LoanCard` shows: animated progress bar, remaining amount, status badge, EMI amount, **X/Y EMIs paid chip**, **Next: DD MMM due date chip**. Shared helpers (`loanStatusColor`, `fmtAmount`, `fmtCompact`) and `LoanReportSheet` (pie chart + bar chart + payment history) also live here.
- **Why:** Central list view for all loans. The EMI progress and next due date chips give users an at-a-glance repayment status without opening the detail screen.

### `lib/screens/loans/loan_detail_screen.dart`
- **What:** 3-tab detail screen (Overview, Reports, Schedule). Hero card shows remaining principal, progress bar, rate/tenure/end date chips, and **EMI progress line** (`EMI ₹XXXX · 3/24 paid · Next: 05 Jul`). Action buttons: Log EMI, Prepay, Force Close. Payment history list. Amortization schedule tab (borrowed loans only).
- **Why:** Full loan detail with payment actions and schedule visibility. EMI progress line replaces the static "Due day X" with live paid/total count and next date.

### `lib/screens/loans/add_loan_sheet.dart`
- **What:** Add/Edit loan bottom sheet. Inputs: loan type toggle, title, lender/borrower name, principal, rate, tenure, EMI due day, **Loan Start date picker**, **First EMI Date picker** (separate, with auto-hint and clear button), EMI override toggle, charges & fees section, notes. Shows live EMI preview and total payable. On add, checks for missed EMIs and prompts backdating.
- **Why:** Primary loan data entry. The dedicated First EMI Date picker lets users set the exact schedule anchor independently of the disbursement date.

### `lib/screens/loans/loan_reports_screen.dart`
- **What:** Standalone reports screen with status filter chips, per-loan summary cards, and a bottom sheet showing amortization schedule + payment history for each loan.
- **Why:** Gives users a cross-loan view of repayment status with filtering by active/settled/foreclosed.

### `lib/screens/settings/settings_screen.dart`
- **What:** Main settings page — edit profile, change password, delete account, currency, notifications, legal, logout, version.
- **Why:** Centralized user preferences and account management.

### `lib/screens/settings/edit_profile_screen.dart`
- **What:** Update display name and profile photo (upload to Firebase Storage).
- **Why:** Users need to change how they appear to roommates.

### `lib/screens/settings/change_password_screen.dart`
- **What:** Re-authenticate with current password, then set new password.
- **Why:** Security requirement. Google-only users see an appropriate message instead.

### `lib/screens/settings/notification_preferences_screen.dart`
- **What:** Toggle switches for expense/reminder/settlement notifications (saved to SharedPreferences).
- **Why:** Users control what alerts they receive — required by app store guidelines.

---

## `lib/utils/` — Utility Functions

### `lib/utils/split_calculator.dart`
- **What:** Pure functions to calculate split amounts — equal split, dynamic split, custom split.
- **Why:** Reusable math logic separated from UI. Easy to unit test.

---

## `lib/widgets/` — Reusable Widgets

### `lib/widgets/design_system/app_finance_tile.dart`
- **What:** `AppFinanceTile` and `AppFinanceEmptyState`, exported by `design_system.dart`, with compact typography and themed icon/value presentation.
- **Why:** Matches new finance lists and empty states to the app's existing visual style.

### `lib/widgets/personal_form_sheet.dart`
- **What:** Shared personal-finance modal shell and input styling, including drag handle, rounded top, title/icon and consistent spacing.
- **Why:** Aligns accounts, transfers, goals, merchant rules and SMS forms across themes.

### `lib/widgets/personal_account_picker.dart` and `lib/widgets/debt_due_date_picker.dart`
- **What:** Optional account assignment and debt repayment-date controls.
- **Why:** Reuses validated entry controls across personal/debt/SMS forms.

### `lib/widgets/offline_banner.dart`
- **What:** Persistent banner at top of screen when device is offline.
- **Why:** Users need to know their actions are queued and not yet synced.

### `lib/widgets/receipt_picker.dart`
- **What:** Image picker widget for selecting/capturing receipt photos.
- **Why:** Reused across expense and bill screens for receipt attachment.

---

## `android/` — Android Platform Code

### `android/app/build.gradle.kts`
- **What:** Android build configuration — SDK versions, dependencies, signing config.
- **Why:** Defines how the Android APK/AAB is compiled.

### `android/app/src/main/AndroidManifest.xml`
- **What:** App permissions, activity declarations and intent filters, including opt-in SMS capture receiver, connectivity-constrained job service and references to SMS backup exclusions.
- **Why:** Registers the native SMS components and permissions without requesting message history access.

### `android/app/src/main/kotlin/com/splitex/in/app/BankSms.kt`
- **What:** Owner-bound app-private SMS capture/review queues, multipart receiver, persisted Android job and background Flutter engine invocation.
- **Why:** Receives new alerts after opt-in, keeps raw text local and retries processing with connectivity, subject to Android restrictions.

### `android/app/src/main/kotlin/com/splitex/in/app/MainActivity.kt`
- **What:** Attaches the bank SMS MethodChannel and forwards runtime SMS permission results.
- **Why:** Connects Flutter settings/review state to native Android capture controls.

### `android/app/src/main/res/xml/backup_rules.xml` and `data_extraction_rules.xml`
- **What:** Exclude the `splitex_bank_sms` preferences from Android cloud/device-transfer backups.
- **Why:** Keeps captured raw SMS and local review data out of those backups.

### `android/build.gradle.kts`
- **What:** Project-level Gradle config — repositories, classpath dependencies.
- **Why:** Sets up the build tool chain for the Android module.

### `android/settings.gradle.kts`
- **What:** Declares which Gradle modules to include in the build.
- **Why:** Required by Gradle to discover the `:app` module and Flutter plugins.

---

## `assets/` — Static Assets

### `assets/fonts/Gilmer-*.otf`
- **What:** Custom Gilmer font family (Light, Regular, Medium, Bold, Heavy weights).
- **Why:** Gives the app a distinct, polished look beyond default system fonts.

---

## `test/` — Recent Finance Coverage

| Files | Coverage |
|-------|----------|
| `bank_sms_parser_test.dart`, `bank_sms_repository_test.dart`, `bank_sms_settings_test.dart` | Parsing/rejection, identity/deduplication, import/linking, account matching and review UI |
| `debt_screens_test.dart` | Debt navigation, categories, Receive/Repay, partial amounts and history |
| `payment_calendar_test.dart` | Scheduling, date clamping, EMI matching and calendar projection |
| `personal_accounts_test.dart`, `personal_accounts_screen_test.dart` | Balance/transfer calculations, service validation, owner isolation and account UI |
| `personal_finance_features_test.dart`, `personal_finance_features_screen_test.dart` | Monthly comparisons, savings atomic/history guards, merchant rules, owner isolation, navigation and forms |

Last implementation verification recorded 100 passing tests for the full suite and a successful debug APK build. `flutter test --dart-define=CAPTURE_PREVIEW=true` also captures fixture previews under ignored `build/previews/`. These tests do not verify physical SMS delivery/background execution or deployed production rules. See [DEPLOYMENT.md](DEPLOYMENT.md).

---

## Layer Summary

| Layer | Purpose |
|-------|---------|
| Config | Theme, routing, constants and development flags |
| Models | Stored data structures and derived finance calculations |
| Services | Firebase/native operations and business rules |
| Providers | Reactive state and selected-month projections |
| Screens | Feature entry points, forms and detail views |
| Widgets | Shared design system, finance tiles, sheets and pickers |
| Android | SMS receiver, queues, background execution and platform configuration |
| Tests | Parser, model, service, ownership and widget verification |
| Docs | Four guides in `docs/`, supplemented by root feature/schema guides |

---

*End of Document*
