# UI implementation guidance

- Before UI changes, inspect the current screen, nearby recently updated screens,
  and `lib/shared/ui/design_system/`. The user wants additions to blend with the
  current app UI; treat these files as the reference rather than older screenshots.
- Reuse `appCardDecoration`, `AppSectionHeader`, `AppFinanceTile`, `AppSpacing`,
  `AppRadius`, `AppTextStyles`, and `AppColors` where applicable. Reference screens:
  Personal dashboard `widgets/personal_tools_section.dart`, Personal Budgets,
  Bank SMS Settings, and Settings. Paths are under `lib/modules/`.
- Use theme surfaces, subtle outlines/shadows, restrained accent tints, compact
  rounded icon containers, and existing Gilmer typography. Respect light, dark,
  deep-dark, and user-selected palettes. Keep text flexible at narrow widths.
- Preserve the restored Personal hero: Remaining Balance/Overspent By, Income and
  Spent chips, savings badge, and spending progress. Change its design or financial
  meaning only when the user requests it.
- Keep projections read-only and reuse existing financial policies/providers.
  Display loading/failure states honestly; missing data must not imply all clear.
- Needs attention follows the dashboard's selected month. Keep live SMS inbox
  alerts on the current month; historical cards use that month's payments/budgets.
- Shared-expense net spending is the original payment minus cash repayments of
  its linked split debts. Keep full payment/account cash movement intact; write-offs
  and non-cash tallies must not look like repayments. Use the display transaction
  provider for UI/reporting so settlement status and totals stay reactive.
- Keep strict two-decimal validation on new-entry/write paths. Stored or calculated
  amounts may have extra precision: preserve ordinary read-side arithmetic and use
  `roundedMoneyCents` for paise-based shared-expense projections, never `moneyCents`.
- Follow the module-first architecture documented in `docs/DEVELOPMENT_HANDOFF.md`.
  Domain code stays independent of Flutter, Riverpod, and persistence.
