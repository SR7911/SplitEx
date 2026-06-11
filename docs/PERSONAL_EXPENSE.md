# Personal Finance Tracker — Screen & Feature Reference

## Overview

A mobile-first personal finance tracker integrated into SplitEx, focused on:

* Fast transaction entry with debt tracking (Lent/Borrowed)
* Budget monitoring per category
* Day-wise expense grouping
* Monthly insights with daily spending bar charts
* Recurring transaction automation
* Peer-to-peer debt settlement

---

## Navigation

```text
Personal Tab (Bottom Nav)
├── Dashboard (main scrollable view)
├── Add Transaction (FAB → bottom sheet)
├── All Transactions (/personal/transactions)
├── Budgets (/personal/budgets)
├── Recurring (/personal/recurring)
├── Reports (bottom sheet)
└── Debts & Settlements (/personal/debts)
```

---

## 1. Dashboard (PersonalExpenseTab)

Main tab view with month navigation.

### Sections:
1. **Greeting Header** — User name + current month with "Current" badge
2. **Financial Status Card** — Remaining balance (income - expenses), color-coded gradient (green/red), animated amount, month prev/next navigation
3. **Income & Expense Pills** — Side-by-side monthly totals
4. **Budget Usage Card** — Expense-to-income ratio progress bar with status text
5. **Category Budgets** — Top 5 categories with spent vs budget progress bars
6. **Quick Actions** — "Add Transaction" + "Budgets" buttons
7. **Utilities Row** — Reports, All Transactions, Debts, Recurring (4 icon cards)
8. **Spending Pie Chart** — fl_chart donut with category legend chips
9. **Recent Transactions** — Last 5 with "View All" link
10. **Recurring Preview** — Up to 3 recurring items with "Manage" link
11. **FAB** — Floating button to add transaction

---

## 2. Add Transaction (Bottom Sheet)

### Fields:
- **Type Toggle** — Expense / Income (SegmentedButton)
- **Amount** — ₹ numeric field (validated > 0)
- **Title** — Text field with hint
- **Category** — Dropdown (19 categories: Food, Transport, Rent, Entertainment, Groceries, Shopping, Health, Loan, EMI, Insurance, Gifts, Fuel, Education, Bills, Salary, Home, Freelance, Investment, Other)
- **Date** — Date picker (defaults to today)
- **"Involves someone else?" Toggle** — Switch to enable debt tracking
  - **Debt Type** — "I Lent" / "I Borrowed" (SegmentedButton)
  - **Person's Name** — Text field (required when toggle is on)
- **Notes** — Optional text field
- **Save Button**

### Logic:
- When debt toggle is OFF → normal expense/income
- When ON with "I Lent" → records that the named person owes you
- When ON with "I Borrowed" → records that you owe the named person

---

## 3. All Transactions Screen (/personal/transactions)

### Features:
- **Search bar** — Filters by title
- **Filter chips** — All / Expenses / Income
- **Transaction count**
- **Day-wise grouped list** — Transactions grouped by date with:
  - Day header: "Today" or "Mon, 23 Jun"
  - Daily totals: expense in red (-₹500), income in green (+₹2000)
  - Transaction cards beneath each day header
- **FAB** — Add transaction directly from this screen
- **Tap transaction** → Opens detail/edit bottom sheet

---

## 4. Transaction Detail/Edit (Bottom Sheet)

### View Mode:
- Title, Amount (colored), Type, Category, Date
- Debt info (if applicable): Person name, "You Lent"/"You Borrowed", Settled status
- Notes
- Edit / Delete action buttons

### Edit Mode:
- Inline form (same fields as add) with Save/Cancel
- Delete with confirmation dialog

---

## 5. Manage Budgets (/personal/budgets)

### Features:
- List of category budgets with progress bars (spent/budget, color-coded)
- Delete button per budget
- FAB → Add Budget dialog:
  - Category dropdown (merges hardcoded categories + categories from actual spending)
  - Budget amount field

---

## 6. Recurring Transactions (/personal/recurring)

### Features:
- **Active section** — Currently running recurring items
- **Past section** — Expired recurring items (greyed out)
- Each card shows: title, category, frequency, day, end date, amount
- Tap → Detail sheet with Pause/Resume and Delete actions
- FAB → Add Recurring sheet:
  - Title, Amount, Category, Frequency (weekly/monthly), Day of month, End date (optional)

---

## 7. Reports (Bottom Sheet)

### Sections:
1. **Income/Expense summary pills**
2. **Category Distribution** — Pie chart with percentage labels
3. **Category Breakdown** — List with color dots, amounts, percentages
4. **Daily Spending Bar Chart** — One bar per day of month:
   - Color-coded: primary for weekdays, orange for weekends
   - Touch tooltip: day name + amount (e.g. "Mon, 23 → ₹500")
   - X-axis labels at every 5th day + first/last
   - Legend: Weekday vs Weekend

---

## 8. Debts & Settlements (/personal/debts)

### Summary:
- Two chips: "You Lent" (green, total owed to you) + "You Borrowed" (red, total you owe)

### Sections:
- **Money You Lent** — Green section header, list of lent transactions
- **Money You Borrowed** — Red section header, list of borrowed transactions

### Per Transaction Tile:
- Left colored border (green=lent, red=borrowed)
- Person initial avatar
- Person name, title, category, date
- Amount
- **Lent items** → Green "Settled?" button → confirms "Has [person] paid you back?"
- **Borrowed items** → Orange "Settle Up" button → confirms "Have you paid [person] back?"

### Settled Transactions:
- Remain visible but greyed out (50% opacity)
- Strikethrough on name and amount
- "Settled" badge
- Grey check icon instead of avatar
- No action button (grey check circle)
- Sorted to bottom of each section

---

## Data Model

### PersonalTransactionModel

| Field | Type | Description |
|-------|------|-------------|
| id | String | Document ID |
| title | String | Transaction description |
| amount | double | Amount in ₹ |
| type | TransactionType | `expense` or `income` |
| category | String | Category name |
| date | DateTime | Transaction date |
| notes | String? | Optional notes |
| userId | String | Owner UID |
| month | String | `yyyy-MM` for queries |
| createdAt | DateTime | Creation timestamp |
| debtType | DebtType? | `lent`, `borrowed`, or null |
| personName | String? | Person linked to debt |
| isSettled | bool | Whether debt is settled |

### CategoryBudget

| Field | Type |
|-------|------|
| id | String |
| category | String |
| budget | double |
| userId | String |
| month | String |

### RecurringTransaction

| Field | Type |
|-------|------|
| id | String |
| title | String |
| amount | double |
| category | String |
| type | TransactionType |
| frequency | RecurringFrequency |
| dayOfMonth | int |
| active | bool |
| userId | String |
| lastRunDate | DateTime? |
| endDate | DateTime? |

---

## Providers (Riverpod)

| Provider | Type | Description |
|----------|------|-------------|
| `personalTransactionsProvider(month)` | StreamProvider | Transactions for a month |
| `personalMonthlySummaryProvider(month)` | Provider | Computed income/expenses/remaining/budgetUsage |
| `personalCategorySpendingProvider(month)` | Provider | Map of spending per category |
| `personalBudgetsProvider(month)` | StreamProvider | Category budgets |
| `personalRecurringProvider` | StreamProvider | All recurring transactions |
| `personalDebtsProvider` | StreamProvider | All debt-tagged transactions |
| `personalDebtBalancesProvider` | Provider | Net balance per person (positive=owed to you) |

---

## Budget Indicators

| State | Color | Range |
|-------|-------|-------|
| Healthy | Green | 0% - 70% |
| Warning | Orange | 70% - 100% |
| Over Budget | Red | >100% |

---

## Navigation Flow

```text
Personal Tab
│
├── FAB → Add Transaction (bottom sheet)
│         └── Optional: Link person (Lent/Borrowed)
│
├── Utilities → All Transactions
│               └── Day-wise list + FAB
│               └── Tap → View/Edit Transaction
│
├── Utilities → Reports (bottom sheet)
│               └── Pie chart + Daily bar chart
│
├── Utilities → Debts & Settlements
│               └── Lent section + Borrowed section
│               └── Settle individual transactions
│
├── Utilities → Recurring
│               └── Active/Past + Add Recurring
│
├── Quick Action → Budgets
│                  └── List + Add Budget
│
└── Recent Transactions → View All
```
