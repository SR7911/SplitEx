# Personal Finance Tracker - Mobile UI Reference

## Overview

A mobile-first personal finance tracker focused on:

* Fast transaction entry
* Budget monitoring
* Expense categorization
* Monthly insights
* Recurring transaction automation
* Data export

---

# App Navigation

```text
Bottom Navigation
--------------------------------
🏠 Dashboard | 📋 Transactions
📊 Reports   
```

A floating **➕ Add Transaction** button remains accessible across all screens.

---

# 1. Dashboard Screen

## Purpose

Provide users with a quick overview of their financial status.

## Layout

```text
┌─────────────────────────┐
│ Good Morning, John 👋   │
│ June 2026               │
└─────────────────────────┘

┌─────────────────────────┐
│ Monthly Summary         │
│                         │
│ Income      ₹45,000     │
│ Expenses    ₹28,500     │
│ Remaining   ₹16,500     │
└─────────────────────────┘

Budget Usage
████████░░░░ 63%

₹28,500 / ₹45,000

----------------------------

Category Budgets

Food
██████████░░ 80%

Transport
█████░░░░░░ 50%

Entertainment
████████████ 110%

----------------------------

Recent Transactions

🍔 Food          ₹350
⛽ Transport     ₹200
💰 Salary      ₹25,000

                 [+]
```

## Components

* Monthly summary card
* Budget progress indicator
* Category spending overview
* Recent transactions
* Floating action button

---

# 2. Quick Add Transaction Screen

## Purpose

Enable fast transaction creation with minimal input.

## Layout

```text
Add Transaction

Amount
┌────────────────┐
│ ₹ 0.00         │
└────────────────┘

Type

(•) Expense
( ) Income

Category

[ Food ▼ ]

Date

[ Today ▼ ]

Notes

┌────────────────┐
│ Optional note  │
└────────────────┘

[ Save Transaction ]
```

## UX Guidelines

* Numeric keypad opens automatically
* Default date = current date
* Frequently used categories shown first
* One-tap save flow

---

# 3. Transactions Screen

## Purpose

Display historical income and expense records.

## Layout

```text
Transactions

🔍 Search

[ All ]
[ Expenses ]
[ Income ]

June 2026

12 Jun

🍔 Food
Dinner with friends
₹550

11 Jun

⛽ Transport
Uber Ride
₹230

10 Jun

💰 Salary
₹25,000
```

## Actions

```text
Swipe Left  → Delete
Swipe Right → Edit
```

## Features

* Search transactions
* Filter by type
* Chronological grouping
* Infinite scrolling

---

# 4. Calendar View

## Purpose

Provide date-based transaction navigation.

## Layout

```text
June 2026

Mo Tu We Th Fr Sa Su

    1  2  3  4  5
 6  7  8  9 10 11 12

● = transactions available

Selected Date

12 June

Food      ₹350
Transport ₹200
```

## Features

* Monthly calendar
* Daily transaction summary
* Quick date selection

---

# 5. Budget Management Screen

## Purpose

Configure overall and category budgets.

## Layout

```text
Monthly Budget

₹50,000

━━━━━━━━━━━━━━━

Category Budgets

Food
₹10,000

Transport
₹5,000

Rent
₹15,000

Entertainment
₹4,000

[ + Add Category Budget ]
```

## Features

* Global monthly budget
* Category-specific budgets
* Budget editing
* Budget progress monitoring

---

# 6. Categories Screen

## Purpose

Manage expense and income categories.

## Layout

```text
Categories

🍔 Food
⛽ Transport
🏠 Rent
🎬 Entertainment
🛒 Groceries

----------------

[ + New Category ]
```

## Features

* Create custom categories
* Edit categories
* Delete categories
* Category icons/colors

---

# 7. Recurring Transactions Screen

## Purpose

Automate recurring income and expenses.

## Layout

```text
Recurring Entries

☑ Rent
₹15,000
Every Month
1st Day

☑ Netflix
₹649
Monthly

☑ Gym Membership
₹1,500
Monthly

[ + Add Recurring ]
```

## Features

* Monthly recurring expenses
* Weekly recurring expenses
* Recurring income
* Enable/disable automation

---

# 8. Reports Screen

## Purpose

Provide spending insights and monthly breakdowns.

## Summary Section

```text
Total Income
₹45,000

Total Expenses
₹28,500
```

## Pie Chart

```text
Food           35%
Rent           40%
Transport      15%
Entertainment  10%
```

## Category Table

| Category      | Amount  | Percentage |
| ------------- | ------- | ---------- |
| Rent          | ₹12,000 | 40%        |
| Food          | ₹10,000 | 35%        |
| Transport     | ₹4,000  | 15%        |
| Entertainment | ₹2,500  | 10%        |

## Features

* Monthly spending analysis
* Category distribution chart
* Income vs expense trends
* Budget comparison

---

# 9. Export Screen

## Purpose

Allow users to download transaction history.

## Layout

```text
Export Data

Date Range

[ June 2026 ▼ ]

Format

(•) CSV
( ) PDF

[ Export ]
```

## Output Example

```text
finance_report_june_2026.csv
```

## Features

* CSV export
* PDF export
* Date-range filtering
* Share/download support

---

# Floating Action Button (FAB)

Visible on all major screens.

```text
       [+]
```

## Actions

* Add Expense
* Add Income

---

# Progress Bar States

## Healthy Spending

```text
██████░░░░░░
Green
0% - 70%
```

## Warning

```text
██████████░░
Orange
70% - 100%
```

## Over Budget

```text
████████████
Red
>100%
```

---

# Database Schema Reference

## Transaction

| Field    | Type             | Description        |
| -------- | ---------------- | ------------------ |
| id       | String / Integer | Unique identifier  |
| amount   | Decimal          | Transaction amount |
| type     | Enum             | Expense / Income   |
| category | String           | Category name      |
| date     | Timestamp        | Transaction date   |
| notes    | Text             | Optional notes     |

## Category

| Field  | Type    |
| ------ | ------- |
| id     | String  |
| name   | String  |
| icon   | String  |
| budget | Decimal |

## Recurring Transaction

| Field       | Type             |
| ----------- | ---------------- |
| id          | String           |
| amount      | Decimal          |
| category    | String           |
| frequency   | Monthly / Weekly |
| nextRunDate | Timestamp        |
| active      | Boolean          |

---

# Navigation Flow

```text
Dashboard
│
├── Add Transaction
│
├── Transactions
│   ├── Edit Transaction
│   └── Delete Transaction
│
├── Reports
│
├── Budgets
│
├── Categories
│
└── Settings
    ├── Export Data
    └── Recurring Transactions
```

---

# Recommended Design System

* Material 3 Design
* Bottom Navigation Bar
* Floating Action Button (FAB)
* Card-Based Layout
* Light & Dark Theme Support
* Responsive Mobile Layout
* Color-Coded Budget Indicators
* Simple Charts for Analytics

---

# MVP Screen List

1. Dashboard
2. Add Transaction
3. Transactions List
4. Budget Management
5. Categories
6. Reports
7. Recurring Transactions
8. Export Data
9. Settings

This screen set is sufficient for a complete MVP personal finance tracking application.
