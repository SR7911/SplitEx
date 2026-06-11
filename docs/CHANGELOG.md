# SplitEx — Changelog

---

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
