# Personal finance additions

## Shared expense repayments and SMS entry

- Original shared payments now show their participants, allocated shares, live
  Pending/Partially settled/Settled/Closed status and net spending in Transactions,
  transaction details and dashboard recent transactions. Search also matches share
  participants. The full original payment remains visible and editable under the
  existing settlement-history restrictions.
- Shared transaction tiles show the current net amount prominently as **Your
  spend**, with **Paid** underneath for the original payment. For a 100 payment
  with a 45 share, this changes from 100 to 80 after 20 is repaid, then to 55 after
  the remaining 25 is repaid. The participant and repayment details stay visible.
- Cash repayments of linked split debts reduce the original expense's net
  spending. Paying 100 with your share 55 and another person's share 45 starts at
  100 spent; receiving 20 reduces it to 80, and receiving all 45 reduces it to 55.
  Write-offs and non-cash tallies do not count as returned money. A later-month
  reimbursement updates the original purchase month's net cost, while cash/account
  movement stays in the actual payment month. Ordinary lent/borrowed principal
  remains outside purchase spending.
- Dashboard totals, category budgets, weekly/report charts, Monthly Money Review,
  Needs attention budget checks and launcher widget snapshots use this joined
  state. Joins reuse existing transaction/debt streams rather than querying each
  tile. Existing settled shares work without rewriting stored expenses.
- SMS review can create split expenses directly using the existing equal/manual
  editor, or record a person-involved lent/borrowed payment. Account, repayment
  date and notes are available. Split debts, original payment and import receipt
  are committed atomically; repeated SMS delivery cannot add duplicate shares.
- Transaction controls use white theme surfaces in light mode and retain dark
  surfaces in dark mode. The header's offline pulse stops while online.

## Needs attention

- The Personal dashboard shows this card directly below its existing balance
  hero. It follows the shared card, section header and finance tile styles.
- Alerts follow the month selected on the dashboard. The current month shows
  payments scheduled from today through the following six days and the live bank
  message inbox. Historical months show unrecorded outgoing payments scheduled
  within that month and hide live inbox alerts. Budget checks always use the
  selected month, which is labeled on the card.
- Payment checks reuse Payment Calendar projections, including the next month
  when needed. Incoming money and recorded entries are excluded. These are
  scheduled entries, not bank-verified unpaid bills; older overdue entries remain
  available in Payment Calendar.
- Rows open the calendar on the earliest applicable date, the SMS inbox, or budgets
  for the selected month. Opening the card or a destination does not record payments.
- Budget checks reuse purchase-spending rules and compare integer paise. Debt
  principal and repayments remain excluded. Loading and failed checks stay visible
  and do not produce an all-clear message; SMS waits for its first status load.
- The calendar day refreshes at midnight. UI conventions for future work are in
  `AGENTS.md`.

## Monthly review, savings goals and merchant categories

- **Personal → Monthly Money Review** sits alongside Accounts & Wallets and Payment
  Calendar. It opens the month selected on the Personal dashboard and has its own
  month navigation. Current-month comparisons use the same elapsed dates in the
  previous month (clamped for short months); completed months compare full months.
- The review covers recorded income/expense totals, category changes, category
  budget overruns and uncategorized expenses. Tap an uncategorized expense to edit
  its original record. Totals follow the existing Personal dashboard, including
  lending/borrowing and settlement entries. Account transfers and goal progress
  are excluded. The debt section explicitly shows **current** balances across all
  months, rather than implying a historical month-end balance.
- **Personal → Savings Goals** supports goals with target amounts, optional target
  dates and optional account labels. Record dated contributions and withdrawals,
  inspect/delete history entries, edit a target, or archive/restore a goal.
  Progress is a separate planning record: it does not reserve money, transfer
  funds, or create expenses/income. Account labels do not allocate a bank balance.
- Goal progress uses integer paise and atomic updates. Entry IDs protect retries;
  withdrawals and history deletions cannot leave negative saved amounts.
- In SMS review, **Use this category for future payments** saves a merchant rule
  together with the new expense and import receipt. Exact merchant + bank-sender
  matches suggest categories in review and categorize future automatic expenses.
  Sender prefixes/case/spacing are normalized. Rules never grant sender trust or
  bypass credit, transfer or duplicate review. Existing entries keep their categories.
- Manage, pause or delete rules in **Settings → Bank SMS Recording → Merchant
  Category Rules**. Rule changes affect subsequent entries only.

Deploy the updated `firestore.rules` for `merchant_category_rules` and
`personal_savings_goals` (including its `entries` subcollection) before live use:
`firebase deploy --only firestore:rules`. App builds do not deploy rules. The new
collections need no additional composite indexes.

Personal now has **Accounts & Wallets**, **Payment Calendar**, and an Android
**SMS Review Inbox**. The existing transaction, budget and debt dashboards remain
the entry points for recording and reporting spending.

## Accounts and transfers

- Create cash, bank and credit card accounts. An optional four-digit account
  ending helps match bank SMS; never enter a full account number.
- The opening balance is the balance **before all assigned transactions**. For a
  credit card, enter the amount owed; the stored balance is negative. A card
  repayment transfers money from a bank account to the card and reduces that debt.
- Balances derive from opening balances, assigned personal income/expenses, and
  transfers. Editing, deleting or reassigning an entry recalculates its effect.
- Existing entries stay unassigned. Add or edit personal transactions/debts to
  assign an account. Loan, recurring and settlement expenses can be assigned by
  editing their resulting personal transaction; no account is assumed for them.
- Transfers have their own collection. They do not affect personal spending,
  income, categories or budget totals. Transfer history supports edits/deletion.
- Archive an account to stop new assignments/transfers while preserving history
  and its tracked balance. Restore it before making another transfer.
- Tracked balances are bookkeeping totals; they are not live bank balances.

## SMS inbox

- Personal shows the review count and messages awaiting processing. Open the inbox
  to inspect, edit, approve, link or dismiss a message. SMS settings remain separate.
- Reviewed payments can be assigned an account, or recorded as a transfer between
  two accounts. Similar existing transfers appear alongside expense/income matches.
- Debit and credit alerts for the same transfer can both link the existing
  transfer. Each alert has its own import receipt without adding another transfer.
- Automatic clear expenses match an account only when exactly one active non-cash
  account has the SMS ending. Missing or ambiguous matches stay unassigned.
- Account ending matching never grants trust to a sender or bypasses review.
- See [BANK_SMS_RECORDING.md](BANK_SMS_RECORDING.md) for consent, Android delivery
  limits and release requirements.

## Calendar

- A full Monday-first month grid supports arrows, horizontal swipes, a date jump,
  and Today. Payment dots identify EMIs, recurring entries and debts; compact daily
  amounts show unrecorded payments. Tap a day for its agenda or show the whole month.
- Filters and monthly pay/receive totals use the same displayed events. Overdue
  status means a scheduled date is past without a recorded entry.
- EMI logs are matched once within the existing 15-day matching window. Closed
  loans have no future unrecorded installments. Loan-linked recurring schedules
  appear once as EMIs.
- Recurring dates follow the current schedule and its last run. Recorded means
  generated by the recurring processor, not independently verified as paid.
  Monthly days clamp to the end of shorter months; weekly dates use a seven-day
  anchor. Forecasts are not an immutable historical statement after schedule edits.
- Add an optional **Repayment date** when creating/editing a debt. Only dated debts
  appear; partial debts show the remaining amount. Settled/written-off debts are
  marked closed rather than becoming overdue.
- Opening or browsing the calendar never records expenses or marks payments paid.
  Open an event to access its existing loan, recurring or debt details.

## Firebase setup and verification

Deploy the updated owner-only rules for `personal_accounts`, `personal_transfers`
and `bank_sms_receipts` before using these features with the live project:

```sh
firebase deploy --only firestore:rules
```

No rules deployment is performed by an app build. No additional composite index
is required for the new account/transfer queries. Existing transaction/debt queries
retain their existing index requirements.

Tests cover signed account arithmetic, transfers and duplicate alerts, private
collection rules, short months/leap years, weekly scheduling, loan deduplication,
partial debts, month navigation and narrow light/dark calendar layouts.

For optional local calendar previews from fixture data:

```sh
flutter test --dart-define=CAPTURE_PREVIEW=true test/payment_calendar_test.dart
```

Images are written to `build/previews/`. Test actual bank SMS and background
execution on an Android device before release.
