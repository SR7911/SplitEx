# SplitEx development handoff

Updated 2026-11-01. This is a portable starting point for the next development session. It describes the code at branch `refactor/clean-architecture`, commit `1f4d28d`. The working tree was clean before this file was added. Check `git status --short` when resuming because the branch may have moved.

## Project direction

- Flutter app with four main business modules: `personal`, `group`, `room`, and `project` (Project/Track). Settings and Notifications are common capabilities. Auth, bootstrap, routing, and tab navigation belong to `app`; reusable UI and cross-module foundations belong to `shared`.
- The chosen Clean Architecture layout is module-first, then `domain/` (entities, repository contracts, use cases, pure policies), `data/` (models/codecs, data sources, repository implementations), and `presentation/` (screens, controllers/providers, widgets). Each module's `dependencies.dart` and `app/composition/` wire implementations.
- Preserve existing Firestore paths, Android integrations, routes, and financial behavior during architecture changes. `docs/CLEAN_ARCHITECTURE_MIGRATION.md` is the roadmap; `docs/CLEAN_ARCHITECTURE_STATUS.md` records earlier migration steps. Both contain historical snapshots, so verify statements against current code before using them as current-state documentation.
- The user prefers larger coherent changes over many tiny migration slices, but wants financial workflows and UI behavior checked carefully. Avoid adding low-value tests; test accounting, deduplication, and transactional boundaries.

## Current Personal finance behavior

- An expense can be split equally or by manual positive shares. The combined other-person shares cannot exceed the expense. The original expense carries the cash movement; linked lent-debt records represent receivables and must not duplicate that cash movement.
- Lent and borrowed balances for the same named person can be tallied without a cash transaction. Tally and write-off history entries do not move cash.
- A debt remains the primary record in Transactions and Debts. Debt status and a navigation action appear on its transaction detail. A settlement updates the debt's `partialSettlements`, `settledAmount`, and `isSettled`; new manual and SMS settlements do **not** create a separate repayment transaction. Old linked repayment documents with `debtSourceId` remain readable and count once for compatibility.
- New cash settlements carry `cashEntry: true` in debt history. Monthly cash movement includes these entries in their payment month, while purchase spending/budget totals exclude debt principal and repayment. An assigned account balance includes its settlement cash movement. Unassigned payments do not alter an account balance.
- The Personal dashboard's large amount represents net money movement. Purchase spending and budget figures remain separate. Do not silently change these meanings when editing dashboard calculations.

## SMS and RCS review workflow

- Android SMS capture, optional Google Messages notification access for future RCS payment alerts, and sharing an existing RCS message into SplitEx feed the local review flow. A cleared RCS notification cannot be recovered from old chat history by notification access. RCS candidates always require manual review.
- On SMS Review, the user can create a transaction, link an existing transaction/transfer, or apply the bank payment to existing debt. Existing debt creation through the Add Expense flow remains separate.
- Credit SMS payments can repay **lent** debts; debit SMS payments can repay **borrowed** debts. The review UI shows open matching-direction debts. The user selects debts for one person, then moves them up or down to set payment priority. The full SMS amount is allocated in that order: earlier debts close first, and the last funded debt may remain partially paid.
- Example: one ₹200 credit applied to a preferred ₹100 lent debt and then a ₹250 lent debt closes the first and applies ₹100 to the second, leaving ₹150. If selected balances are below the SMS amount, or a selected debt would receive ₹0, saving is disabled until the selection changes. The UI previews allocations and remaining balances.
- Allocation uses integer paise. The Firestore repository rechecks unique debt IDs, the exact SMS total, open balances, matching direction, same normalized person name, payment dates, and an active account if one was chosen. It updates all selected debt histories and writes one `bank_sms_receipts/{sms.transactionId}` receipt in a single Firestore transaction. The receipt prevents a repeated delivery from applying the payment again. No ordinary repayment transaction is created, and the raw message body is not uploaded by this path.
- A review message is removed from the device only after the repository returns recorded or duplicate. Failed validation or network writes leave it available for review. The person match is currently a normalized **name**, not a stable contact ID; the user must verify the SMS and selected person where names could be ambiguous.

## Key files for the latest work

| Responsibility | File |
| --- | --- |
| Review UI, selection order, preview | `lib/modules/personal/presentation/sms/screens/bank_sms_settings_screen.dart` |
| Review controller | `lib/modules/personal/presentation/sms/controllers/bank_sms_controller.dart` |
| Approval workflow and local review deletion | `lib/modules/personal/domain/use_cases/sms/approve_bank_sms_review.dart` |
| Pure priority allocation | `lib/modules/personal/domain/policies/sms/bank_sms_debt_allocation.dart` |
| Repository contract and allocation value | `lib/modules/personal/domain/repositories/bank_sms_repository.dart` |
| Atomic Firestore debt updates and SMS receipt | `lib/modules/personal/data/repositories/firestore_bank_sms_repository.dart` |
| Manual settlement persistence | `lib/modules/personal/data/repositories/firestore_personal_transaction_repository.dart` |
| Debt history decoding | `lib/modules/personal/data/models/personal_transaction_firestore_model.dart` |
| Account and monthly cash calculations | `lib/modules/personal/domain/policies/accounts/account_balance_calculator.dart`, `lib/modules/personal/domain/policies/transactions/monthly_transaction_summary.dart` |
| Focused regression tests | `test/bank_sms_repository_test.dart`, `test/bank_sms_settings_test.dart`, `test/modules/personal/data/transactions/firestore_personal_transaction_repository_test.dart`, `test/modules/personal/domain/transactions/monthly_transaction_summary_test.dart`, `test/personal_dashboard_cash_flow_test.dart` |

## Verification at handoff

- The latest focused Flutter run passed **40 tests** across SMS repository/review, personal transaction repository, monthly summary, and dashboard cash flow.
- Targeted Dart analysis of the latest SMS change reported **zero errors and zero warnings**; style-level `info` notices remain in some files.
- The complete Flutter suite, Android APK, and physical Android SMS/RCS flow were **not rerun after the latest multi-debt SMS change**. Earlier full-suite/build results in `CLEAN_ARCHITECTURE_STATUS.md` apply to earlier commits, not automatically to this snapshot.
- Before release, check on a physical Android device: incoming lent repayment, outgoing borrowed repayment, one SMS covering several debts, partial final debt, wrong person/direction, insufficient selected balance, repeated alert, account balance, dashboard cash movement, and whether a failed save keeps the review item. Test both captured SMS and shared/notification-derived RCS where available.

## Resume checklist

1. Run `git status --short` and read this file, `docs/CLEAN_ARCHITECTURE_MIGRATION.md`, and the latest relevant sections of `docs/CLEAN_ARCHITECTURE_STATUS.md`.
2. For debt/SMS changes, trace `bank_sms_settings_screen.dart` → `bank_sms_controller.dart` → `approve_bank_sms_review.dart` → `firestore_bank_sms_repository.dart`. Keep the Firestore receipt and all debt updates atomic, and preserve paise-exact allocation.
3. Run focused tests: `flutter test --concurrency=1 test/bank_sms_repository_test.dart test/bank_sms_settings_test.dart test/modules/personal/data/transactions/firestore_personal_transaction_repository_test.dart test/modules/personal/domain/transactions/monthly_transaction_summary_test.dart test/personal_dashboard_cash_flow_test.dart`.
4. When preparing a release or broad architecture change, run the full Flutter suite and Android debug build, then perform the physical-device scenarios above. Update this handoff with the actual new results rather than carrying forward old counts.

Current likely follow-up: perform the device and full-suite checks, then continue the broader Clean Architecture migration from the migration plan. Review the historical status document before treating its older linked-repayment wording as current behavior.
