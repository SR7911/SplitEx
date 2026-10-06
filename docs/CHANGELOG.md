# SplitEx — Changelog

---

## SPLITEX011
- Loan & EMI Manager — clarity, auto-expense sync, and card improvements
- **`emiStartDate` field added to `LoanModel`** — user can now set the exact first EMI date separately from the loan start date; defaults to `startDate + 1 month` if not set (`effectiveEmiStart` getter)
- **Fixed `endDate` computation** — was off by one month; now derived from `effectiveEmiStart` instead of `startDate`
- **Fixed `_nthEmiDate`** in `LoanService` — EMI schedule now aligns with `effectiveEmiStart`, so amortization and missed-EMI detection are accurate
- **Auto personal expense dedup guard** — `_addPersonalExpenseForPayment` now checks for an existing `loanSourceId` + same-day entry before inserting, preventing duplicate expense records when EMI is logged
- Each auto-logged personal expense is tagged with `loanSourceId: loanId` for traceability and dedup
- **New `loanEmiProgressProvider`** — exposes `LoanEmiProgress(paidCount, totalCount, nextDueDate)` per loan; `paidCount` counts only EMI-type payments; `nextDueDate` is the next upcoming due date after the last paid EMI
- **Loan list card footer updated** — replaced "Due day X" chip with `X/Y EMIs` paid count chip; replaced static tenure/end-date chip with `Next: DD MMM` upcoming EMI date chip for active loans
- **Loan detail hero card updated** — subtitle now shows `EMI ₹XXXX · 3/24 paid · Next: 05 Jul` instead of just `EMI ₹XXXX · Due day 5`
- **Add Loan sheet — First EMI Date picker** — two separate date pickers: "Loan Start" and "First EMI Date"; first EMI shows auto-calculated date as hint with "Tap to override" label; clear (×) button resets to auto; changing loan start resets first EMI to auto

## SPLITEX010
- Added weekly expense analysis to personal reports sheet (`personal_reports_screen.dart`)
  - New `_WeeklyAnalysisSection` widget between Spending Breakdown and Daily Spending sections
  - 4 fixed week buckets: W1 (1–7), W2 (8–14), W3 (15–21), W4 (22–end of month)
  - Horizontal progress bars per week — highest week in red, lowest in green, others in primary color
  - Up/down arrow indicators vs. weekly average; per-week transaction count + income sub-text
  - Insight line: "Week X spent Y% more than Week Z"
  - Average weekly spend chip in section header
- Category chips and breakdown bars in reports sheet are now tappable — navigate to filtered transaction list
  - Category donut chips show chevron icon and push `/personal/transactions/category`
  - Spending breakdown bar rows also tappable with same navigation
  - Passes `{monthKey, category}` as route extra
- Added new route `/personal/transactions/category` in `router.dart`
- `PersonalTransactionsScreen` accepts optional `initialCategory` param — pre-applies category filter and shows category name in app bar title
- Added `_WeeklyExpenseSummaryCard` to personal expense tab (`personal_expense_tab.dart`)
  - Inserted after Quick Actions row, hidden when no expense data exists
  - 4 vertical bar columns (W1–W4) with compact amount labels
  - Current week highlighted with primary color + dot indicator; highest week shown in red
  - Trend insight: "This week is X% more/less than last week" (current month only, when prior week has data)

## SPLITEX009
- Complete Debt & Settlements revamp — new dedicated Debt Dashboard and Monthly Debt List screens
- New `debt_dashboard_screen.dart` — hero card (net balance, lent, borrowed, active count), quick actions, 6-month grouped bar chart, lent vs borrowed donut chart, most debted people (consolidated net per person), top lent/borrowed debts, recent debts
- New `debt_list_screen.dart` — month navigation with `AppMonthSelector`, month hero card (lent/borrowed/net/count), search by person name or description, filter sheet (type/status/amount range), active filter chips with clear, separate lent/borrowed sections
- New `add_debt_sheet.dart` — dedicated debt entry sheet with animated lent/borrowed toggle, person name autocomplete from existing debt history, category + date picker, balance impact hint
- Person name suggestions derived from existing debt transaction `personName` fields — no extra Firestore collection
- `personalDebtsByMonthProvider` — filters all debts to a specific `yyyy-MM` month
- `debtPersonSuggestionsProvider` — derives unique sorted person names from all debt transactions
- Fixed `personalDebtBalancesProvider` to use `remainingAmount` instead of `amount` — partial settlements now correctly reflected in net balances
- Balance logic preserved: lent → `type: expense` (deducts balance); borrowed → `type: income` (adds balance); lent settlement → auto-creates income entry; borrowed settlement → no auto-transaction
- Navigation updated: `/personal/debt-dashboard` (new dashboard), `/personal/debt-list` (new monthly list), `/personal/debts` (existing settle screen unchanged)
- Personal tab quick actions and debts summary section now navigate to `/personal/debt-dashboard`

## SPLITEX008
- Added Group Expenses module — create/join groups with invite codes, track shared expenses across any group type
- Added Project Expense Tracker module — personal project budgets with category breakdown and status tracking
- Group features: equal/select split, simplified debt view (Settle Up tab), admin archive/restore, member leave
- Project features: budget progress bar, category breakdown bars, status management (active/completed/paused)
- Universal project categories: Materials, Labor, Services, Equipment, Transport, Food & Catering, Decoration, Venue, Clothing & Attire, Electronics, Furniture, Utilities, Fees & Permits, Marketing, Miscellaneous
- Home screen tabs expanded from 2 to 4 (scrollable): Room, Personal, Groups, Projects
- Added 7 new routes: `/groups`, `/groups/create`, `/groups/join`, `/groups/:groupId`, `/projects`, `/projects/create`, `/projects/:projectId`
- Firestore structure: groups at root `groups/{groupId}/expenses/{expenseId}`, projects under `users/{uid}/projects/{projectId}/expenses/{expenseId}`
- GroupBalanceService reuses existing `BalanceService.simplifyDebts()` for consistent debt simplification
- No image/file upload in new modules — Firestore only

## SPLITEX007
- Added personal peer-to-peer debt tracking (Lent/Borrowed) to personal expense section
- Add Transaction sheet now has "Involves someone else?" toggle with Lent/Borrowed switcher and person name field
- New Debts & Settlements screen (/personal/debts) with separate Lent/Borrowed sections
- Settled debts shown as disabled (greyed out, strikethrough) instead of removed
- Contextual settle buttons: "Settled?" for lent, "Settle Up" for borrowed
- All Transactions screen now groups transactions day-wise with daily totals
- Added FAB to All Transactions screen for quick expense entry
- Reports bottom sheet now includes Daily Spending bar chart (weekday vs weekend color-coded)
- Budget category dropdown now merges hardcoded categories with categories from actual spending
- Fixed splash screen always showing on app launch (was being skipped for returning users)
- Router redirect no longer overrides splash — splash handles its own navigation timing

## SPLITEX006
- Added Developer only access to DB & Storage in Home Screen Drawer
- Add notification trigger to remind users to settle up
- Refine settlement screen UI with debtor/creditor views
- Implement payment request screen to view, manage, request, and pay settlements
- Add consolidated settlement card showing net position and breakdown
- Add reminder button for creditors using Firestore notifications
- Improve settlement history with cancel/confirm actions and status badges

## SPLITEX005
- Email password sign up error — Fixed
- Adding water in bill not reflecting total — Fixed
- Delete function not available for bills — Fixed
- Activity log not showing for bills — Fixed
- Adding dynamic expense reflects 1-to-1 function — Fixed
- Change month, recent activity shows same data — Fixed
- Fresh login steps multiple splash shows — Fixed

## SPLITEX004
- Multiple splash screen occurrences during login/signup/profile setup flow
- Fix: Use `ref.read` instead of `ref.watch` in `routerProvider` so GoRouter instance isn't recreated on auth state changes
