Final Task: Complete Room Expense UI/UX Redesign

The Room Expense List screen is NOT considered redesigned.

Although a previous implementation may have introduced some newer components, the actual Room Expense List UI still contains the legacy/old design, including the outdated hero card, buttons, quick actions, cards, list tiles, Recent Activities, and overall screen layout.

I need a complete visual and layout migration of the Room Expense List screen.

Critical scope
MUST redesign

The entire Room Expense List screen and all of its UI components must be updated to match the modern design language already established by:

Personal Expense

Group Expense

Project Expense

MUST NOT modify

room_detail_screen.dart

Leave room_detail_screen.dart completely as-is.

Do not change:

Its UI

Its layout

Its styling

Its widgets

Its navigation

Its functionality

Its business logic

Its behavior

room_detail_screen.dart is explicitly out of scope and should remain exactly as it currently works.

1. Source of truth

Use the Personal Expense, Group Expense, and Project Expense screens as the visual and layout reference.

The goal is not to copy one screen literally.

The goal is to establish:

One cohesive design system + different expense contexts.

Room Expense should feel like the natural fourth screen in the same application.

The result should look like:

Personal Expense  → Modern UI
Group Expense     → Modern UI
Project Expense   → Modern UI
Room Expense      → Modern UI


NOT:

Personal Expense  → Modern UI
Group Expense     → Modern UI
Project Expense   → Modern UI
Room Expense      → Legacy UI

2. Do NOT trust the previous redesign

Ignore any previous claim such as:

"room_list_screen.dart already contains the full redesign."

That is not sufficient.

The current rendered Room Expense screen visibly still uses the old design.

Therefore, treat the Room Expense List screen as a legacy screen requiring a full migration.

Do not determine completion merely by checking whether the source code contains names such as:

NewCard

ModernCard

DesignSystemCard

NewListTile

ModernHero

etc.

Component names do not prove that the actual UI matches the other tabs.

The objective is actual visual consistency and improved screen composition.

3. Redesign the ENTIRE Room Expense List screen

Do not merely modify colors, radius, or padding on the existing Room screen.

Re-evaluate and redesign the entire screen structure.

The overall composition should be brought into the same design pattern as the other three tabs.

Evaluate:

Page structure

Top-level spacing

Hero placement

Summary placement

Quick-action placement

Section ordering

Card grouping

Expense list placement

Recent Activities placement

Tile/grid placement

Information hierarchy

Content density

Vertical rhythm

Empty space

CTA placement

The final screen should feel intentionally designed rather than being the old Room screen with a few updated widgets.

4. Components that MUST be migrated

Audit the entire Room Expense List screen from top to bottom.

Every applicable component must be compared with its equivalent in the updated tabs.

Hero Card

The existing Room Expense hero card is outdated.

Replace/rework it to follow the modern hero-card pattern used by the other tabs.

Match the established:

Layout

Proportions

Padding

Typography

Amount/value hierarchy

Icon/avatar treatment

Background

Radius

Shadow/elevation

Supporting information

CTA/action placement

Responsive behavior

Keep the content Room-specific.

Quick Actions

The existing Room Expense quick actions are outdated.

Redesign them to match the modern Quick Actions pattern used by the other tabs.

Check:

Layout

Button/tile dimensions

Icon treatment

Icon containers

Typography

Radius

Colors

Spacing

Primary/secondary hierarchy

Interaction states

Do not retain the old Room-specific quick-action styling.

Buttons

All outdated Room Expense buttons must be migrated.

Match the modern button system used by the other tabs:

Height

Radius

Typography

Icon

Icon placement

Padding

Colors

Border

Elevation

Interaction states

Do not leave old button variants on the Room Expense List screen.

Summary / Statistics Cards

If Room Expense has summary or statistics cards, redesign them using the modern card patterns established by the other tabs.

Match:

Card structure

Padding

Radius

Typography

Value hierarchy

Icon treatment

Background

Border

Shadow

Spacing

Expense Cards

Replace any legacy Room Expense cards with the modern expense-card pattern.

The information can remain Room-specific, but the visual design must belong to the same design system as Personal, Group, and Project Expense.

List Tiles

The existing Room Expense list tiles are outdated.

Fully migrate them to the modern list-tile design.

Match:

Row structure

Height

Padding

Leading icon/avatar

Icon container

Title

Subtitle

Metadata

Amount/value

Trailing content/action

Alignment

Typography

Divider treatment

Background

Radius

Spacing

Do not simply change the colors of the old list tile.

5. Recent Activities MUST be redesigned

The existing Recent Activities section is also legacy UI.

It must be completely migrated.

Update:

Section header

Section layout

Activity card/container

Activity row

Avatar/icon

Activity title

Supporting text

Amount/value

Timestamp

Trailing content

Dividers

Padding

Row spacing

Typography

Radius

Background

Shadows

The resulting Recent Activities section should visually match the Recent Activities pattern used by the other updated tabs.

6. Other Room Expense widgets

Audit and update every other applicable legacy widget on the Room Expense List screen, including:

Section headers

Filters

Chips

Tabs

Stat tiles

Information tiles

Empty states

Loading states

Error states

CTA areas

Icon buttons

Floating actions

Member/user rows

Room summary elements

Expense summaries

Supporting information

Dividers

Background containers

Any other visible legacy component

If a component visually belongs to the old UI generation, migrate it.

7. Redesign the screen layout, not just the widgets

This is extremely important.

The Room Expense screen currently has an older overall composition.

Do not preserve that composition simply because the existing functionality works.

Use the other three updated tabs as references for:

What should appear above the fold

How the hero is positioned

How actions are grouped

How summary information is surfaced

How cards are grouped

Where the main list begins

Where Recent Activities appears

How sections are separated

How much spacing exists between sections

How information is prioritized

The Room Expense screen should have a modern, intentional layout comparable to the other three tabs.

8. Do not make every tab identical

Do NOT blindly copy the Personal Expense layout.

Room Expense has its own information and requirements.

Use:

Same design language + appropriate Room-specific information architecture.

For example:

Personal Expense
Hero
↓
Quick Actions
↓
Summary
↓
Expenses
↓
Recent Activities


Room Expense might become:

Room Summary / Hero
↓
Room Quick Actions
↓
Room Statistics
↓
Room Expenses
↓
Recent Room Activities


The exact arrangement should be determined from the existing Room Expense data and the layout patterns used by the other updated tabs.

9. Reuse the established design system

Where practical, reuse/refactor the same components already being used by:

Personal Expense

Group Expense

Project Expense

Avoid creating another independent Room-specific design system.

If an appropriate shared component already exists, use it.

If the existing shared component does not support the Room use case, extend it appropriately rather than duplicating an entire component unnecessarily.

The objective is:

Shared Design System
│
├── Personal Expense
├── Group Expense
├── Project Expense
└── Room Expense


Not:

Personal UI
Group UI
Project UI
Old Room UI

10. Preserve Room Expense functionality

This is primarily a UI/UX redesign and layout migration.

Do not unnecessarily change:

APIs

Data models

Business logic

State management

Navigation behavior

Expense calculations

Room functionality

Existing actions

Preserve existing functionality while modernizing the presentation.

11. Important: Do not modify Room Detail

Again, this is a hard boundary:

room_detail_screen.dart MUST remain unchanged.

Do not redesign it.

Do not refactor its UI.

Do not change its layout.

Do not change its behavior.

Do not change its functionality.

Do not change its styling.

The task applies to the Room Expense List screen and its associated list-screen UI components only.

If a shared component is also used by room_detail_screen.dart, be careful not to unintentionally alter the detail screen.

If necessary, isolate the new List-screen styling rather than breaking the existing Detail screen.

12. Inspect child components

Do not inspect only room_list_screen.dart.

Trace the complete widget tree used by the Room Expense List screen.

Find:

Room-specific cards

Room-specific list tiles

Room-specific buttons

Room-specific quick actions

Room-specific activity widgets

Room-specific hero components

Shared components

Legacy style constants

Hardcoded styling

Duplicate components

Old design variants

If a child component is responsible for the old appearance, update or replace it.

13. Before/after validation

After implementation, compare all four screens:

Personal Expense
Group Expense
Project Expense
Room Expense


Check them side-by-side.

The Room Expense screen should have comparable:

Visual polish

Layout quality

Information hierarchy

Card treatment

Hero treatment

Button treatment

Quick-action treatment

List treatment

Recent Activities treatment

Typography

Spacing

Iconography

Content density

Overall visual rhythm

14. Final acceptance criteria

The task is NOT complete if:

Room still has the old hero card.

Room still has old buttons.

Room still has old quick actions.

Room still has old cards.

Room still has old list tiles.

Room still has old Recent Activities.

Room still has old typography.

Room still has old spacing.

Room still has the old overall screen composition.

Any major Room Expense section visibly belongs to the legacy UI.

The Room screen looks noticeably different in design quality from the other three tabs.

The task IS complete when:

Room Expense has been fully visually migrated.

The overall Room screen layout has been recomposed where necessary.

Hero uses the modern design.

Quick Actions use the modern design.

Buttons use the modern design.

Cards use the modern design.

List tiles use the modern design.

Recent Activities uses the modern design.

Section hierarchy and spacing match the design philosophy of the other tabs.

Room-specific information remains intact.

Existing Room Expense functionality remains intact.

The screen feels like a natural fourth tab alongside Personal, Group, and Project Expense.

room_detail_screen.dart remains unchanged.

Final instruction

Do not tell me that the Room Expense screen is already redesigned simply because the source code contains newer components.

Verify and improve the actual implementation.

Redesign/recompose the entire Room Expense List screen and migrate every legacy UI element to the established modern design system used by Personal, Group, and Project Expense.

The only screen that must remain untouched is room_detail_screen.dart.

After completing the work, report:

The overall Room Expense layout changes.

The components migrated from legacy to modern UI.

Any shared components/styles reused.

Confirmation that room_detail_screen.dart was not modified.

Any remaining intentional differences between Room Expense and the other tabs.