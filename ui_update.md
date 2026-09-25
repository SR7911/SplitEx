Objective

Redesign the remaining 3 expense tabs so they follow the same UI design language and visual quality as the Personal Expense tab.

Tabs

Reference tab: Personal Expense

Tab 2: Group Expense List

Tab 3: Project Expense List

Tab 4: Room Expense List

The Personal Expense tab is the single source of truth for the visual design. Do not create a completely new design for the other tabs.

The widgets/components may represent different data, but their visual treatment, hierarchy, spacing, typography, card styling, list patterns, tiles, and overall composition should feel like they belong to the same product and design system.

1. Analyze the Personal Expense tab first

Before modifying the other 3 tabs, inspect the Personal Expense screen and identify its design patterns:

Overall page structure and content hierarchy

Hero card design

Hero card proportions, padding, radius, colors, shadows, and typography

Quick-action card design

Quick-action placement and grouping

Standard card styling

List-view card styling

List tile styling

Tile spacing and alignment

Section headers

Typography hierarchy

Icon size, container shape, and placement

Primary/secondary text treatment

Amount/currency presentation

Color usage

Background colors

Border radius

Shadows/elevation

Internal component padding

Spacing between widgets

Spacing between sections

Empty states

Loading states

CTA/button styling

Responsive behavior

Scroll behavior

Visual density

Treat these observations as the existing design system for the application.

Do not arbitrarily invent new visual styles.

2. Apply the same design language to the other tabs

Redesign:

Group Expense List

Use the same visual patterns from Personal Expense, but adapt the content to group-expense information.

For example:

Use a hero/summary area if the information architecture supports it.

Use quick actions where they are useful.

Present groups using the same card/list/tile visual language as Personal Expense.

Surface important group-level information prominently.

Keep secondary information visually subordinate.

Use the same spacing, typography, icon treatment, colors, radius, shadows, and card proportions as the Personal Expense tab.

Project Expense List

Apply the same approach:

Reuse the Personal Expense visual hierarchy.

Create an appropriate summary/hero area where useful.

Use quick actions where relevant.

Use the same card and list patterns.

Adapt the information displayed for projects rather than blindly copying Personal Expense content.

Make project-specific information easy to scan.

Room Expense List

Apply the same design language:

Use the same overall visual hierarchy.

Use a suitable hero/summary component if appropriate.

Use quick actions where they provide value.

Use the same card/list/tile styling.

Adapt the content to room-related expenses.

Maintain consistent visual density and spacing.

3. Important: Do NOT simply reuse the existing widgets

The existing tabs already have cards, text styles, list views, and tiles, but they currently look visually different from the Personal Expense tab.

Do not consider the task complete simply because the same component types are being used.

Instead, compare the actual visual implementation.

For example:

❌ Existing:

Card → generic card styling
List → generic list styling
Tile → generic tile styling


Desired:

Personal Expense
↓
Extract visual design patterns
↓
Create/standardize reusable design components
↓
Apply those components to
↓
Group Expense
Project Expense
Room Expense


The goal is visual consistency, not merely component-type consistency.

4. Create a shared design language

Where practical, extract reusable components/styles from the Personal Expense implementation rather than duplicating styles across screens.

Consider creating shared components such as:

ExpenseQuickActions

ExpenseSectionHeader

ExpenseListCard

ExpenseListTile

ExpenseInfoTile

ExpenseStatTile

ExpenseEmptyState

Shared spacing constants

Shared typography styles

Shared colors

Shared corner-radius values

Shared elevation/shadow styles

Use the project's existing architecture and conventions rather than introducing unnecessary abstractions.

If equivalent reusable components already exist, improve/standardize them instead of creating duplicates.

5. Preserve information architecture

Do NOT blindly copy the Personal Expense screen layout.

The visual design should be consistent, while the content hierarchy should be appropriate for each expense type.

Think of it as:

Same design system + different information architecture.

For example:

Personal Expense
Hero
↓
Quick Actions
↓
Summary
↓
Expense List
↓
Tiles / Additional Information


could become:

Group Expense
Group Summary / Hero
↓
Group Quick Actions
↓
Group Statistics
↓
Groups / Expenses
↓
Additional Information


and:

Project Expense
Project Summary / Hero
↓
Project Actions
↓
Project Statistics
↓
Project Expense List
↓
Additional Information


The exact arrangement should be determined by the importance and relationships of the information.

6. Improve widget placement

Do not preserve the current placement just because the widgets already exist.

Re-evaluate the layout of each tab.

Use these principles:

Most important information should appear first.

Primary actions should be easy to discover.

Related information should be grouped together.

Avoid large areas of empty space.

Avoid excessive widget fragmentation.

Avoid putting too many unrelated cards next to each other.

Maintain consistent vertical rhythm.

Use visual hierarchy to guide scanning.

Use the Personal Expense tab's spacing and composition as the reference.

Make the screen feel intentional rather than like a collection of independent widgets.

7. Visual consistency requirements

The following should feel consistent across all 4 tabs:

Typography

Use the same:

Font family

Heading hierarchy

Font weights

Font sizes

Line heights

Primary/secondary text colors

Amount/value typography

Cards

Use consistent:

Border radius

Background

Border treatment

Shadow/elevation

Internal padding

Header/body/footer structure

Lists

Use consistent:

Row height

Avatar/icon treatment

Leading/trailing element positioning

Divider behavior

Text hierarchy

Amount alignment

Spacing

Tiles

Use consistent:

Dimensions

Radius

Icon treatment

Label/value hierarchy

Padding

Grid/list spacing

Actions

Use consistent:

Button styles

Icon buttons

Quick-action treatment

CTA hierarchy

Touch targets

8. Do not change functionality unnecessarily

This is primarily a UI/UX consistency and visual enhancement task.

Preserve:

Existing functionality

Existing data

Existing navigation

Existing business logic

Existing API behavior

Existing state management

Only modify functionality if it is required to support the improved UI.

9. Responsive behavior

The resulting screens should remain visually consistent across supported screen sizes.

Do not simply scale everything.

Maintain:

Appropriate content width

Consistent spacing

Card proportions

Grid/list behavior

Readable typography

Proper touch targets

Good information density

10. Implementation workflow

Follow this process:

Step 1 — Inspect

Analyze the Personal Expense tab and identify its reusable visual patterns.

Step 2 — Compare

Compare Personal Expense against:

Group Expense

Project Expense

Room Expense

Identify why the latter 3 feel visually inconsistent.

Step 3 — Standardize

Extract or improve shared UI components/styles based on the Personal Expense design.

Step 4 — Redesign

Recompose the remaining 3 screens using those shared patterns.

Step 5 — Validate

Compare all 4 tabs side-by-side.

Ask:

If I switch between these four tabs, do they look like four screens from the same design system?

They should.

Most important instruction

Do not redesign the Personal Expense tab. Treat it as the established visual reference.

The task is to bring:

Group Expense + Project Expense + Room Expense

up to the same level of:

visual hierarchy

polish

spacing

component styling

information density

card treatment

typography

widget composition

usability

as the Personal Expense tab.

The final result should feel like:

One cohesive expense-management design system with four different data contexts, rather than four independently designed screens.