# Clean architecture migration status

## Baseline — 2026-10-26

- Branch: `refactor/clean-architecture`
- Starting commit: `b56da02`
- Toolchain: Flutter 3.41.9, Dart 3.11.5
- Android debug baseline: passed
- Analyzer baseline: 533 existing diagnostics; no cleanup was included in the pilot
- Test baseline: 111 passed, 3 failed in `personal_finance_features_screen_test.dart`
  - monthly review did not find the expected uncategorized entry
  - savings-goal screen had a 44-pixel horizontal overflow
  - SMS review test produced multiple widget-lifecycle exceptions

The baseline failures are outside the accounts/transfers pilot. They remain visible so a migration is not credited with failures that existed before it.

## Personal accounts/transfers pilot

Status: implemented and verified.

Implemented boundaries:

- Pure account, transfer and minimal transaction entities
- Pure account validation and balance calculation
- Abstract account repository contract
- Account and transfer write use cases
- Explicit Firestore mappers and repository implementation
- Firestore transaction retains active-account checks and schema compatibility
- Riverpod dependency declarations and app composition overrides
- Account presentation state/controller uses domain contracts
- Compatibility exports remain for SMS and other Personal callers pending their stages
- Architecture test rejects Flutter, Riverpod and Firebase imports in Personal domain

Verification:

- 20 focused domain/architecture/repository/screen tests passed
- Complete suite after migration: 114 passed, the same 3 baseline failures remained
- Android debug build passed
- Analyzer introduced no errors in the migrated module; repository-wide legacy diagnostics remain tracked from baseline

## Follow-up: Personal transaction boundary

Status: first transaction boundary implemented; full transaction repository and presentation migration remain open.

- Moved the account screen and picker into `modules/personal/presentation/accounts/`; old paths now re-export them for existing routes and callers.
- Added a Firestore mapper for the shared Personal transaction fields. Account balances and the legacy transaction model now decode through the same mapper, with legacy settlement history preserved by the compatibility model.
- Extracted new-transaction amount and due-date validation into a pure domain policy; the existing write path invokes it.
- Added mapper/schema and domain validation tests. Focused architecture, account-screen and payment-calendar tests passed (19 tests). Targeted analysis found no errors; existing style diagnostics remain. Android debug APK built successfully.

After Personal transaction workflows, migrate Group, Room, Project/Track, Settings and Notifications in the staged order in the migration plan. Keep compatibility exports until all callers move and validate platform/Firebase behavior on an emulator or device.

## Personal transaction creation

Status: creation path migrated; reads, edits, deletion and debt settlement remain on the legacy service.

- Added a pure transaction repository contract and `CreatePersonalTransaction` use case.
- Added the Firestore repository and app-level Riverpod binding. It preserves the existing transaction document fields, usage counting and active-account check.
- The add-transaction and add-debt sheets now call the use case through a presentation provider.
- Fake Firestore tests cover stored fields, active/missing accounts and invalid amounts. The focused Personal/architecture regression run passed 26 tests, targeted analysis had no errors, and the Android debug APK built.

## Personal transaction edit and delete

Status: detail-sheet edit and delete commands migrated; legacy persistence operations still back the Firestore adapter during transition.

- Added a pure edit value and domain edit/delete use cases. The detail sheet no longer creates Firestore update maps or calls the legacy service directly.
- The Firestore adapter translates the edit into the existing update schema and delegates to the existing transaction-safe persistence logic, preserving active-account and debt-settlement restrictions.
- Repository tests cover typed edits, account reassignment, rejected unknown accounts and deletion. Thirty focused tests passed, targeted analysis had no errors, and the Android debug APK built.

The monthly list read is recorded below. Debt history and the remaining transaction consumers still require migration.

## Personal monthly transaction read

Status: monthly transaction list read migrated; other monthly consumers and all debt reads still use the legacy provider.

- Added a pure monthly stream to the transaction repository contract and a Firestore implementation with the existing month filter and descending date order.
- Added a presentation provider that resolves the user ID through Personal's dependency boundary.
- Moved the monthly transaction list screen into `modules/personal/presentation/transactions/screens/` and switched it to pure transactions. The old screen path re-exports it for routes and callers.
- Fake Firestore tests cover month filtering, sort order and old-document defaults. Thirty-nine focused tests passed, targeted analysis had no errors, and the Android debug APK built.

## Personal debt read and settlement history

Status: the all-time debt screen reads domain transactions; other debt dashboards and settlement writes still use the legacy provider/service.

- Added a typed `DebtSettlement` domain value, decoded from historical `partialSettlements` documents. Invalid historical date text remains nullable so the debt screen can display the rest of the entry.
- Added a debt stream to the repository with the existing debt-type filter and date order, plus a contract-based presentation provider.
- Moved the all-time Personal debt screen into `modules/personal/presentation/debts/screens/`. Its tiles and settlement history use pure transaction values; its old path re-exports the screen and shared widgets for existing callers.
- The legacy transaction model still retains the raw map list for unmigrated callers and preserves typed history when those objects are constructed directly.
- Debt screen, mapper, repository, account and architecture tests passed (34 focused tests). Targeted analysis had no errors, and the Android debug APK built.

## Personal debt settlement command

Status: the all-time debt screen sends full, partial and write-off actions through a domain command; the Firestore adapter still delegates to the legacy atomic settlement implementation.

- Added a pure settlement command and use case, plus a repository operation. The debt sheet no longer calls the legacy service directly.
- Fake Firestore tests cover partial and full repayments, settlement history, repayment transaction creation and write-off without a repayment. Debt screen and architecture tests passed (19 focused tests). Targeted analysis had no errors; the Android debug APK built. The full suite had 125 passing tests and the same three baseline failures in `personal_finance_features_screen_test.dart`.

The atomic settlement implementation is now owned by the Firestore repository, as recorded below. Other debt dashboards and transaction consumers still need migration.

## Personal transaction persistence ownership

Status: edit, delete and atomic settlement persistence now live in the Firestore transaction repository. The old service methods remain as compatibility entry points and delegate to that repository.

- Moved account reassignment and debt edit checks into the repository's Firestore transaction. Typed edit commands and legacy map updates use the same implementation.
- Moved repayment/write-off atomic writes, history changes, repayment document creation and usage tracking into the repository. Typed settlement commands and legacy service calls use the same implementation.
- Removed the repository's dependency on `PersonalExpenseService`. Budget and recurring operations still reside in that legacy service.
- Repository, account, debt screen and architecture tests passed (34 focused tests); a separate compatibility test passed for the old settlement entry point. Targeted analysis had no errors and the Android debug APK built.

## Personal debt list and dashboard

Status: the monthly debt list and dashboard now consume domain debt transactions. All three principal debt screens are under Personal presentation; existing route imports use compatibility exports.

- Added a domain-backed monthly debt filter provider that derives from the shared debt stream.
- Migrated the list and dashboard widgets, including shared `DebtInsights`, to `PersonalTransaction` values.
- Debt screen and repository tests passed (19 focused tests). Targeted analysis had no errors and the Android debug APK built.

## Personal monthly summaries, reports and widget feed

Status: the Personal dashboard, reports sheet and running home-screen widget use the domain monthly transaction stream. Budgets, recurring entries and monthly money review still use legacy providers.

- Added pure monthly income/expense and category-spending calculations, with Riverpod providers based on the domain monthly stream.
- Moved the expense tab and reports sheet into Personal presentation folders; old paths remain compatibility exports.
- Updated the home-screen widget snapshot to accept domain transactions and its sync service to watch the domain stream. The payload shape and user/month filtering remain unchanged.
- Summary, widget-parity, finance and architecture tests passed (25 focused tests). Android debug APK built. The full suite had 127 passing tests and the same three baseline failures in `personal_finance_features_screen_test.dart`.
- Targeted analysis found no errors. The migrated large screens still report pre-existing style/deprecation notices, including two unused declarations in the expense tab.

## Personal monthly money review

Status: the review now combines domain transaction and debt streams with the existing budget stream. Budget models and persistence remain legacy.

- Changed review inputs and uncategorized entries to pure `PersonalTransaction` values. Its current-versus-previous calendar logic and debt totals remain the same.
- Moved the review provider and screen into Personal's reports presentation folders; old paths remain compatibility exports.
- Finance calculation tests passed. The screen test file still has the same three recorded baseline failures; targeted analysis found no errors, and the Android debug APK built.

## Personal category budgets

Status: budget reads and writes use a Personal domain contract and Firestore repository. Recurring entries, loans and SMS remain planned.

- Added a pure budget value, repository contract and save use case. The Firestore adapter preserves the existing `personal_budgets` fields and category/month upsert behavior.
- The budget screen, expense dashboard and monthly money review consume the domain budget stream; the budget screen writes through the new use case/repository. Its old route path remains a compatibility export.
- The legacy `CategoryBudget` now extends the pure value and the old service's budget write methods delegate to the repository for remaining callers.
- Fake Firestore tests cover month filtering, upsert, deletion, invalid amounts and the legacy document shape. Focused budget, finance and architecture tests passed (19 tests). Android debug APK built. The full suite had 130 passing tests and the same three baseline failures in `personal_finance_features_screen_test.dart`.
- Targeted analysis found no errors. Two pre-existing unused declarations and style notices remain in the large expense tab.

## Personal recurring entries and payment calendar reader

Status: recurring reads, edits, activation, deletion and app-open transaction creation run through Personal domain contracts and Firestore adapters. The payment calendar reads the same domain recurring stream.

- Added pure recurring values, edit changes, a due-date policy, repository and processor contracts. The Firestore mapper and repository preserve the `personal_recurring` document shape, edit history, ordering and usage tracking.
- Moved the recurring screen under Personal presentation and switched the expense dashboard and payment calendar to its domain stream. The old recurring screen path remains a route compatibility export; the unused legacy recurring provider was removed.
- The app-open processor now receives its Firestore and transaction repository dependencies from app composition. It uses the existing catch-up schedule and creates transactions through the Personal transaction use case.
- Focused recurring, calendar and architecture tests passed (18 tests). The full suite had 135 passing tests and the same three baseline failures in `personal_finance_features_screen_test.dart`. Targeted analysis found no errors, and the Android debug APK built.
- Legacy recurring methods and model remain in `PersonalExpenseService` for compatibility. Their removal belongs with the remaining legacy Personal service cleanup; loan-linked recurring deletion still uses the loan service.

## Personal loan and payment calendar reads

Status: the payment calendar consumes pure Personal loan and payment values through a domain repository contract. Loan list/detail screens and all loan writes still use `LoanService` and the legacy models.

- Added pure loan and payment entities, including existing EMI calculation and first-due-date behavior, plus a read repository contract.
- Added Firestore mappers and streams for `users/{uid}/loans` and each loan's `payments` subcollection. They preserve ordering, document IDs, historical defaults and usage tracking.
- Wired the repository in app composition and changed only the payment calendar's loan/payment read path. Its recurring read remains on the Personal domain provider; debt and loan commands remain in their existing paths.
- Repository tests cover ordering, IDs, historical defaults, user isolation and EMI calculation parity with `LoanModel`. Calendar and architecture tests passed (15 focused tests). Targeted analysis found no errors, and the Android debug APK built. The full suite had 137 passing tests and the same three baseline failures in `personal_finance_features_screen_test.dart`.

## Personal regular EMI command

Status: the loan detail screen records regular EMI payments through a Personal domain use case and Firestore loan repository. Missed EMI, partial payment and foreclosure commands still use `LoanService`.

- Added a loan lookup, paired EMI write and settlement operation to the domain repository contract. The use case retains the existing interest/principal calculation and settlement threshold.
- The Firestore repository writes the payment and matching Personal expense in one transaction using stable IDs (`emi_yyyy-MM-dd` and `loan_{loanId}_emi_yyyy-MM-dd`). It preserves the `loanSourceId`, expense schema, payment schema, and existing duplicate-date behavior.
- A final EMI updates the loan status and deactivates its linked recurring entry, matching the existing post-write sequence.
- Fake Firestore tests cover the paired documents, retry deduplication, calculated interest and final-payment closure. Focused loan, calendar and architecture tests passed (17 tests). Targeted analysis found no errors, and the Android debug APK built. The full suite had 139 passing tests and the same three baseline failures in `personal_finance_features_screen_test.dart`.

## Personal missed EMI detection and recording

Status: the loan list's due check and the add-loan confirmation use a pure missed-date policy and the Personal loan repository. Confirmed backdated EMIs use the same paired Firestore write as regular EMIs. Partial payment and foreclosure remain in `LoanService`.

- Extracted the existing due-date schedule, month-end clamp, 15-day payment match and active-loan check into a pure policy.
- The backdated command re-reads loan/payments, intersects the requested dates with dates still unpaid, removes duplicate requests, processes dates in order and updates the running principal. It retains the existing settlement threshold and linked-recurring closure.
- Tests cover month-end dates, matching EMI versus partial payments, stale/duplicate requests, stable paired document IDs and multi-month principal reduction through settlement. Focused loan, calendar and architecture tests passed (20 tests); targeted analysis found no errors, and the Android debug APK built. The full suite had 142 passing tests and the same three baseline failures in `personal_finance_features_screen_test.dart`.
- The old `LoanService` missed-EMI methods remain as compatibility code until the remaining loan service cleanup. They are no longer called by the loan list or add-loan flow.

## Personal partial loan payment

Status: the loan detail screen records partial payments through a Personal domain use case and Firestore loan repository. Foreclosure remains in `LoanService`.

- Moved the existing interest cap, principal reduction, settlement threshold and remaining-tenure EMI calculation into a domain command.
- The Firestore repository appends each partial payment and creates at most one loan-linked Personal expense for the same loan/day. It writes `loanSourceId` on the expense being created, retains the existing schema and recalculates the linked recurring amount after counting EMI payments only.
- Final partial payment updates the loan to settled and deactivates its linked recurring entry. These steps retain the existing order; they are still separate writes.
- Fake Firestore tests cover the payment split, same-day expense deduplication, recurring amount parity with `LoanModel`, and final settlement. Focused loan, calendar and architecture tests passed (22 tests); targeted analysis found no errors, and the Android debug APK built. The full suite had 144 passing tests and the same three baseline failures in `personal_finance_features_screen_test.dart`.
- The old `LoanService.logPartialPayment` remains as compatibility code pending loan service cleanup.

## Personal loan foreclosure

Status: both the loan detail and loan list foreclosure actions use a Personal domain use case and Firestore loan repository. Loan creation/edit/deletion, schedules and reports still use `LoanService` and legacy models.

- Moved the existing remaining-principal-plus-one-month-interest payoff calculation into a domain command.
- The repository appends a foreclosure payment, creates at most one linked Personal expense per loan/day, marks the loan foreclosed and deactivates its linked recurring entry. It retains the existing write order and stored fields.
- Fake Firestore tests cover the payoff split, expense schema, status, recurring deactivation and same-day behavior (two payment logs, one expense). Focused loan, calendar and architecture tests passed (24 tests); targeted analysis found no errors, and the Android debug APK built. The full suite had 146 passing tests and the same three baseline failures in `personal_finance_features_screen_test.dart`.
- `LoanService.forecloseLoan` remains as compatibility code until loan service cleanup.

## Personal loan create, edit and delete

Status: the add/edit loan sheet and both loan delete actions use Personal domain commands and the Firestore loan repository. The separate linked-recurring delete action uses the Personal recurring repository. Loan list/detail/report reads and schedule calculations still use `LoanService` and legacy loan models.

- Added typed loan edit changes and create/update/delete commands. The Firestore mapper writes the existing loan document shape, including a server timestamp on creation and conditional optional fields.
- Edit retains the old write order: update the loan, then update a linked recurring entry's amount and optional due day. The recurring amount is calculated with the loan's existing custom EMI, even when the edit clears that override; this preserves current behavior pending a separate financial-policy fix.
- Delete removes payment subdocuments and then the loan document. It leaves linked recurring and Personal expense records unless the user invokes their separate action.
- Fake Firestore tests cover create schema, update/recurring behavior, custom EMI clearing and deletion boundaries. Focused loan, calendar and architecture tests passed (27 tests); targeted analysis found no errors, and the Android debug APK built. The full suite had 149 passing tests and the same three baseline failures in `personal_finance_features_screen_test.dart`.

## Personal loan detail projections

Status: the loan detail screen's remaining balance and amortization tab use pure Personal loan/payment projections. The loan list and reports still read legacy loan models and calculations; the detail's payment-history widgets and EMI progress still use legacy providers.

- Added a pure amortization entry and domain policy for latest-payment balance and the existing amortization schedule, including its due-date clamp and payment ordering.
- Added contract-backed presentation providers and switched the detail's balance and schedule consumers. The unused legacy schedule provider was removed; `LoanService.buildSchedule` remains for the list/report charts.
- Domain tests cover latest-payment balance, recorded EMI marking and applying partial-payment balance before a later due date. Focused loan, calendar and architecture tests passed (30 tests); targeted analysis found no errors, and the Android debug APK built. The full suite had 152 passing tests and the same three baseline failures in `personal_finance_features_screen_test.dart`.

## Personal loan progress, summary and list chart

Status: loan list/detail/reports and the Personal dashboard use domain-backed remaining balance, EMI progress, loan summary and amortization projections. Their main loan/payment streams still use legacy models, so screen-model migration and service cleanup remain.

- Added pure EMI progress and aggregate loan summary values and policies. They preserve EMI-only paid counts, the existing next-due-date selection, active-loan filtering and latest-payment balance rule.
- Switched the loan list, detail, reports and Personal dashboard to contract-backed providers. The loan list chart now uses the pure amortization policy instead of creating `LoanService` inside its widget.
- Removed the unused legacy computed providers; `loan_provider.dart` retains only the loan/payment streams still needed by legacy screen widgets.
- Domain tests cover EMI progress, next due date and active-loan summary. Focused loan, calendar and architecture tests passed (32 tests); targeted analysis found no errors, and the Android debug APK built. The full suite had 154 passing tests and the same three baseline failures in `personal_finance_features_screen_test.dart`.

## Personal loan screen read adapters and legacy service removal

Status: all active loan/payment reads use the Personal repository streams. Loan list/detail/report widgets still receive temporary `LoanModel` and `LoanPaymentModel` values through a presentation adapter; direct pure widget migration remains.

- Added a presentation-only adapter from pure Personal loan/payment values to the legacy widget types. It preserves loan fields, derived EMI/end-date calculations and payment fields.
- Replaced the old loan `StreamProvider`s with `AsyncValue` views of the Personal streams, so the loan screens share the repository-backed data source and retain their existing loading/error UI.
- Removed `LoanService`; a reference search found no remaining callers in `lib` or `test`. The old `LoanModel` remains for unmigrated widget signatures and form previews.
- Adapter-parity and provider-wiring tests passed with loan, calendar and architecture tests (35 focused tests). Targeted analysis found no errors, and the Android debug APK built. The full suite had 157 passing tests and the same three baseline failures in `personal_finance_features_screen_test.dart`.

## Personal loan add/edit form values

Status: the add/edit loan sheet receives a pure `PersonalLoan` and calculates its EMI preview through the domain function. The loan detail screen passes its repository value directly to the form while its remaining widgets still use the temporary display adapter.

- Removed the form's dependency on `LoanModel`, `LoanType` and `LoanStatus`. Existing values, charges, loan type selection and create/edit commands retain their behavior.
- Existing loan repository, domain and adapter tests passed (22 tests). Targeted analysis found no errors; its informational style notices remain.

## Personal loan screen values

Status: the loan list, detail and reports now receive pure `PersonalLoan` and `PersonalLoanPayment` values from the Personal providers. The temporary view adapter and its legacy provider have no app callers and were removed.

- Switched loan status helpers, cards, charts, history rows and report sheets to domain values. The domain loan now exposes the same end date, charge total and net disbursal calculations used by those widgets.
- Extended the existing repository read test to check those calculated values against the legacy model. No new test file was created.
- Loan screen and domain analysis found no errors. The full suite had 154 passing tests and the same three baseline failures in `personal_finance_features_screen_test.dart`.
- `LoanModel` remains only as a parity fixture in existing tests; it has no app callers. Its removal belongs with final legacy fixture cleanup.

## Legacy loan model cleanup

Status: the obsolete `lib/models/loan_model.dart` has been removed. A reference search found no remaining `LoanModel`, `LoanPaymentModel` or legacy loan provider imports in `lib` or `test`.

- Replaced the existing repository test's legacy model fixture with the stored Firestore document fields and fixed expected EMI, date and charge values. Removed an unused calendar test import. No new test file was created.
- Updated the current file and app reference docs. The changelog retains its historical mention of the old model.
- The existing loan, domain and calendar tests passed (31 tests). Broad Personal analysis found no errors; it reported two existing dashboard unused-code warnings and informational style notices. `git diff --check` passed.

## Personal screen compatibility exports

Status: ten one-line screen exports under `lib/screens/personal` were removed after switching their router, screen and test imports to the canonical Personal presentation paths. The active implementations and routes remain the same.

- Removed the old exports for accounts, budgets, debts, debt dashboard, debt list, recurring, dashboard tab, reports, transactions and monthly review. The remaining files in `lib/screens/personal` contain active UI or forms.
- Updated the current file reference document. The migration plan retains its original starting-path inventory.
- Debt and account screen tests passed (13 tests). Targeted route and screen analysis found no errors; existing unused-code and style warnings remain. A reference search and `git diff --check` passed.

## Personal account and review provider compatibility cleanup

Status: the old account and monthly-review provider export files, plus the `PersonalAccountService` alias, were removed. Callers now import the module providers and account repository directly.

- Account screen tests override `personalAccountRepositoryProvider` with `FirestorePersonalAccountRepository`; account repository tests instantiate that repository directly.
- Monthly review screen and feature tests import the module provider. Current file-reference documentation now points to the module paths; the migration plan keeps its original starting-path inventory.
- Existing account tests passed (17 tests). Targeted analysis found no errors and one existing style notice. A reference search found no old service or provider callers.

## Personal expense service dead-path cleanup

Status: `PersonalExpenseService` remains the source for legacy transaction, budget and debt read providers and a few test-only writes. Methods with no callers were removed, along with the unused legacy recurring model types.

- Removed unused transaction deletion, full debt settlement, debt close and budget deletion service wrappers. Removed the old recurring read/create/edit/toggle/delete API; active recurring flows already use the Personal repository.
- Removed `RecurringTransaction`, `RecurringEditSnapshot` and `RecurringFrequency` from the legacy transaction model. Current recurring values live under Personal domain.
- Existing account, transaction, budget, recurring and calendar tests passed (40 tests). Targeted analysis found no errors and two existing style notices. `git diff --check` passed. No new test file was created.

## Personal expense provider removal

Status: all active Personal debt reads now use `personalDebtTransactionsProvider` and the legacy `personal_expense_provider.dart` was removed. `PersonalExpenseService` has no app callers and remains only for existing test write entry points.

- Moved debt balance and person suggestion providers to Personal transaction presentation, preserving their calculations and sorting. Payment calendar reads and retry invalidation now use the pure debt stream.
- Payment calendar events carry `PersonalTransaction` debt values, which the transaction detail sheet already accepts. Removed the redundant legacy debt stream override from the screen test.
- Debt, calendar and account tests passed (38 tests). Targeted analysis found no errors; existing dashboard warnings and style notices remain. A reference search and `git diff --check` passed. No new test file was created.

## Personal expense service removal

Status: `lib/services/personal_expense_service.dart` has been removed. No `lib` or `test` code imports or constructs `PersonalExpenseService`.

- Account assignment and repayment-date tests now create through `CreatePersonalTransaction` and use the transaction repository's existing partial-field update boundary.
- The budget schema test writes through `FirestorePersonalBudgetRepository`. The borrowed partial-settlement test uses `SettlePersonalDebt` and still verifies the linked repayment expense.
- Existing account, budget and transaction tests passed (26 tests). Targeted analysis found no issues; a reference search and `git diff --check` passed. No new test file was created.

## Personal transaction form values

Status: both active Personal transaction creation forms now construct pure `PersonalTransaction` entities. `PersonalTransactionModel` and `CategoryBudget` have no app callers and remain only in test fixtures.

- The general add-transaction form and dedicated add-debt sheet still call `CreatePersonalTransaction`; their amount, date, account, debt direction and repayment fields are unchanged. The existing repository mapper continues to write the same Firestore fields.
- Debt screen, transaction repository and account tests passed (34 tests). Targeted analysis found no errors and existing style notices. A reference search and `git diff --check` passed. No new test file was created.

## Personal presentation consolidation

Status: eleven Personal-owned screen and widget implementations were moved into `lib/modules/personal/presentation` in this batch, their imports were updated, and the unused `lib/widgets/personal_account_picker.dart` export was removed. The four loan screens were missed in this inventory and moved in the following batch. The room dashboard remains outside Personal because it belongs to Room.

- Moved transaction and debt forms/details, debt widgets, Personal dashboard tools, payment calendar, savings goals, merchant rules, bank SMS settings, and Personal form/date-picker widgets. Router paths and screen behavior remain unchanged.
- Full Flutter suite: 154 passed and the same three baseline failures in `personal_finance_features_screen_test.dart`. Android debug APK built. Whole-`lib` analysis found zero errors and 37 existing warnings. `git diff --check` passed.
- Remaining Personal-owned source files outside `modules/personal` at that point: four loan screens, five models (`personal_account_model`, `personal_transaction_model`, `monthly_money_review`, `payment_calendar_model`, `savings_goal_model`), five services (`bank_sms_parser`, `bank_sms_repository`, `bank_sms_service`, `merchant_category_service`, `savings_goal_service`), and one provider (`payment_calendar_provider`). The account and transaction models have test callers only. Native Android SMS code remains in the platform directory by design. The Android expenses widget belongs to common Settings and is excluded from this Personal count.

Next batches: remove the two test-only model adapters and move calendar/review projections; extract savings; extract bank SMS and merchant rules; then run the Personal boundary audit and device checks.

## Personal loan screen consolidation

Status: the four active loan screens now live under `lib/modules/personal/presentation/loans/screens`. Their router and cross-screen imports use the new paths; route names and screen behavior are unchanged.

- Moved `add_loan_sheet`, `loan_detail_screen`, `loan_list_screen`, and `loan_reports_screen`. Corrected `FILE_EXPLANATION.md` and the previous inventory, which had overlooked `lib/screens/loans`.
- Android debug APK built successfully after the move. A reference search found no old loan screen imports, and `git diff --check` passed.
- Remaining known Personal-owned Dart sources outside `modules/personal`: five models, five services, and one provider (11 files). Continue with calendar/review projections, savings, bank SMS, and merchant rules.

## Personal source consolidation and boundary audit

Status: all known active Personal Dart sources now live under `lib/modules/personal`. The two files in `lib/models` with only test callers were removed from production: tests import the account domain values directly, and the legacy transaction adapter is a fixture under `test/support`.

- Moved the pure payment-calendar projection into Personal domain, the monthly review projection into Personal presentation, and the calendar provider beside its screen. Existing calendar/review tests passed (27 tests).
- Split savings into a pure domain entity and repository contract, a Firestore mapper and repository, and presentation providers. Existing savings data tests passed; the feature screen test file still has its three previously recorded layout failures.
- Moved the pure SMS parser, Firestore SMS and merchant repositories, Android SMS controller, and SMS providers into Personal. Existing parser, repository, and settings tests passed (38 tests).
- Updated production and test imports and the file guide. Savings and SMS repository construction now live in app composition. SMS domain contracts and a pure merchant rule remove direct data imports from Personal presentation. The Android background SMS entrypoint is in the composition library referenced by the native worker. Source and import boundary audit found no Personal-owned Dart source outside the module, no framework imports in its domain, and no data-layer imports in its presentation.
- Android debug APK built after the native entrypoint update. Full Flutter suite before the final SMS contract extraction: 154 passed, with the same three existing layout failures in `personal_finance_features_screen_test.dart`. After the extraction, 53 focused SMS and Personal data tests and the app smoke test passed. Dart analysis found no errors; existing warnings and style notices remain. `git diff --check` passed.

## Personal migration verification

Status: the three narrow-phone screen failures were reproduced and fixed. The review test now waits for its scroll to finish before tapping; Savings actions wrap on narrow screens; SMS review dropdowns fit the available width.

- The full Flutter suite passes: 157 tests, zero failures. The Android debug APK builds with the updated native SMS callback path.
- Installed the new debug APK over the existing app on the connected Android phone without clearing data. The app launched, its main activity became foreground, the UI hierarchy exposed the Personal tab, and recent error logs showed no startup crash. SMS permission remained granted.
- The user sent a real payment and confirmed that its SMS appeared in the review screen on the updated Android app. This verifies live SMS capture and review delivery. Automatic background processing and recording were not exercised by that check.

## Room source grouping

Status: Room-owned source is grouped under `lib/modules/room/{screens,models,providers,services,widgets}` before its Clean Architecture layer migration. This is a location and import migration; Room business and persistence boundaries have not been refactored yet.

- Moved 16 Room screen files across activity, analytics, bills, dashboard, expense, home tab, room, and settlement; four Room models, six providers, eight services, and the receipt picker widget. Updated all Dart imports and the file guide.
- Moved the cross-module `home_screen.dart` to `lib/app/presentation/home/`. Moved the settlement model and balance service to `lib/shared/` because both Room and Group use them. Shared auth, user profile, notification, and design-system code remains with its existing owners.
- Dart analysis found no errors. The full Flutter suite passed (157 tests), the Android debug APK built, and `git diff --check` passed. Room routes and behavior were preserved; no Room domain/data/presentation extraction was attempted in this grouping stage.
- Next Room architecture work: extract pure Room entities and financial rules, repository contracts and use cases, Firestore mappers/repositories, and presentation-only providers. Move shared session/member providers out of `room_provider.dart` and decouple the shared balance service from Room models when Group is migrated.

## Remaining feature and common source grouping

Status: the remaining legacy `lib/screens`, `lib/models`, `lib/providers`, and `lib/services` source files are grouped by owner. This is a file location and import change; Group, Project, and common capabilities have not undergone the Clean Architecture layer migration.

- Group screens, models, provider, and service now live under `lib/modules/group/`. Project/Track equivalents live under `lib/modules/project/`.
- Sign-in, registration, profile setup, user model, auth provider, and auth/user services live under `lib/app/auth/`. Splash and its app update check live under `lib/app/bootstrap/` because they control application startup, not a business module.
- Settings screens, theme and widget settings providers, widget snapshot/sync, and dot-matrix UI live under `lib/modules/settings/`. The notification preference screen remains Settings-owned. Notification feed, model, provider, FCM, local delivery, and notification helpers live under `lib/modules/notifications/`. Storage management UI/service live under `lib/modules/developer/`.
- Connectivity state and usage tracking remain under `lib/shared/` because multiple modules use them. Generic design-system and app-header widgets remain in `lib/widgets/`. The previously untracked finance preview test was updated to use the current Personal repository and screen paths so it remains runnable.
- Dart analysis found no errors. The full Flutter suite passed (158 tests, including the finance preview), the Android debug APK built, and `git diff --check` passed. Existing routes, service behavior, and Firestore schemas were not changed in this grouping stage.


## App, shared UI, and utility ownership grouping

Status: remaining generic configuration, utilities, and widgets were grouped by owner. This remains a location and import migration; behavior and module layer boundaries were not refactored.

- App routing lives in `lib/app/navigation/`. The root app name constant lives in `lib/app/constants.dart`; Room categories, icons, and limits live in `lib/modules/room/config/`. The Room split calculator lives in `lib/modules/room/utils/`. Developer flags live in `lib/modules/developer/config/`.
- Theme, design-system components, app header, and offline indicator live in `lib/shared/ui/` because they are used by multiple modules. Cross-module connectivity, usage tracking, settlement model, and balance service remain in `lib/shared/`. The balance service still imports Room models; decouple this during the Room/Group Clean Architecture migration.
- `lib/app/composition/personal_dependencies.dart` keeps the Android-invoked SMS background entrypoint, whose native callback references that library path. `lib/app.dart` and `lib/main.dart` remain Flutter entrypoints.
- No imports from the old `lib/config`, `lib/utils`, or `lib/widgets` locations remain. Dart analysis found no errors; existing warnings remain. The full Flutter suite passed (158 tests), the Android debug APK built, and `git diff --check` passed.

## Home shell and Room tab cleanup

The active Room dashboard widgets already live in `lib/modules/room/screens/home/room_tab.dart`. Removed the unused earlier Room widget copies and month state from `lib/app/presentation/home/home_screen.dart`. Moved the Room UPI entry check into `RoomTab`; the app home file now owns only tab selection, recurring startup, and the app drawer/navigation. The developer storage drawer item is shown only when a Room exists, matching its Room-scoped route.

The two changed Dart files analyze without errors or warnings. The full Flutter suite passed (158 tests), the Android debug APK built, and `git diff --check` passed.
