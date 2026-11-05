# Room lifecycle and ledger audit

Date: 2026-11-05

## Findings and resulting behavior

| Area | Previous problem | Result |
| --- | --- | --- |
| Departures | Active membership was the only list used to build settlement pairs and names. Departed users disappeared from those views. | `memberIds` controls active membership; durable `participantIds` preserves historical access. Monthly views also derive identities from recorded participants. |
| Bills | Balances and detailed debts divided historical bills among today's members, ignoring the stored bill split. | Calculations use each bill's saved `splitAmong`. Membership changes cannot reallocate old bills. |
| Legacy bills | Older documents can lack participant snapshots. | `legacyBillMemberIds` freezes the pre-change member list before the next join or departure. See the legacy limitations below. |
| Ownership | No transfer flow; departure writes could remove the only admin. | Only the current admin can transfer to another active member. A non-last admin must transfer before leaving. |
| Final departure | No durable room closure lifecycle. | The last departure archives the room. The historical admin can restore it and rejoin. |
| Archive | No archive state or write protection. | Archive retains every subcollection, freezes expenses and settlements, and remains accessible. Restore reopens it. Outstanding balances remain recorded. |
| Payments | Confirmed payments did not reduce balances or pair totals. | Only confirmed payments reduce debt; pending payments reserve the pair against a duplicate payment; cancelled payments do not reduce debt. |
| Payment month | Payment date implicitly selected the debt month. | New payments store `ledgerMonth`, allowing November payment of October expenses. Legacy payments retain payment-month fallback. |
| Counterparties | Simplified debts could direct a payment between people without the original pair debt. | Payment flows and receipts use direct pair balances. The standalone net simplifier remains available for reporting. |
| Payment transitions | Either party could broadly update settlement fields. | The recipient confirms, the payer cancels, and the amount/participants remain immutable during a status transition. Repeated transitions fail. |
| Race conditions | Stale membership and balance checks were separate from writes. | Ledger mutations read the room in a Firestore transaction, enforce its current state, advance `ledgerVersion`, and commit the activity with the mutation. Payment projections fail safely if the version changes. |
| Member removal | Updating another user's profile backlink was rejected by the original profile rules. UI did not await the write. | A narrowly scoped rule permits only the paired admin unlink. Membership actions await completion and report failures. |
| Screen state | Detail/add/edit screens used a manually selected room snapshot that could belong to another room or predate a transfer. | Room-sensitive actions use the live stream for their route's room ID. |
| History discovery | Departed rooms disappeared from the user's room query; the home tab exposed only the first room. | Queries include historical participation; active rooms sort first; the home selector exposes former and archived rooms. |
| Editing | Merely editing an equal-split expense could replace its participants with today's members; whole-rupee initialization dropped paise. | Ordinary edits retain the original split and initialize amounts with two decimals. Historical participants remain valid for corrections. |
| Dynamic selection | Deselecting one roommate also removed the payer, and an admin editing another person's expense was treated as its payer. | Selection retains the actual payer while other roommates remain selected. Removing the last roommate clears the selection for validation. |
| First room | The empty room tab offered creation without an entry to join an existing room. | Both Create Room and Join Room are reachable from the empty state. |
| Async failures | Swipe deletion used unawaited writes and could appear successful when rejected. | Deletion awaits persistence, preserves the item on failure, and reports the error. Bill edits/deletions use the appropriate activity types. |
| Names | Fresh participant-list objects created new profile-provider keys every build. | Profile requests normalize IDs into a stable value key. Missing profiles still leave their ledger IDs visible. |
| Loading/errors | Some missing streams appeared as zero balances or an empty settled state. | The room home balance and settlement views expose loading/error states. Receipt generation awaits its inputs. |
| Receipts | Former participants were omitted and pair details ignored payments. | Exports include recorded participants, payment history, and balances after confirmed payments. Average spending is labelled as an average rather than each person's actual share. |
| Account deletion | Deleting an account could orphan an admin or leave an unreachable member in future splits. | The app requires leaving active memberships first; the normal leave/transfer/archive workflow preserves shared records. |

## Persisted invariants

- `memberIds`: current occupants, at most 10. New entries can select these people.
- `participantIds`: retained historical access, including former members. Departures never remove IDs from this list.
- `adminId`: exactly one responsible admin; for an empty archived room this retains its historical owner.
- `isArchived`: read-only closure. Admin restoration resumes operations. An explicit archive may retain unresolved balances; archive is not a settlement or debt write-off.
- `legacyBillMemberIds`: stable fallback for old bills without `splitAmong`. New bill creation requires a participant snapshot.
- `ledgerVersion`: advances for membership and ledger mutations. Rules require ledger writes to carry the paired version change.
- `settlements.ledgerMonth`: the expense month affected by a new payment. Confirmation time does not move a payment to another expense month.

A former participant may read retained room history and settle existing debts while the room is open. They cannot create, edit, or delete room expenses. Archive also freezes payment creation, confirmation, and cancellation; restore the room to finish settlement.

Room document lookup remains authenticated-readable to support the existing invite-code flow. Ledger subcollections require historical participation. The rules prohibit room hard deletion and historical activity/payment deletion. Developer bulk-clear tools must not be used as room closure; archive is the closure mechanism.

## Legacy recovery and limits

In Room Settings, the active admin can use **Recover former members**. This reads existing expenses, bills, payments and activity records and restores their recorded user IDs to `participantIds`. It does not reactivate people, rewrite amounts, remove records, or invent a missing bill split. This makes rooms removed from older members' room lists discoverable again.

Existing expense documents already contain explicit split participants, so they can usually retain their original accounting. An old bill with no participant snapshot cannot prove who lived in the room on its original date. The fallback preserves the membership known before the next change; previously lost occupancy data requires manual review. Documents already physically deleted cannot be recreated from membership fields. A legacy payment without `ledgerMonth` also cannot reveal which earlier month it was intended to settle.

## Verification and release

- Full Flutter suite: **286 tests passed** after the accounting, lifecycle and split corrections. After the final empty-room join action, the complete focused room suite passed **52 tests**, including **10 authenticated Firestore emulator tests**. Targeted analysis completed with **zero errors and zero warnings**; style-level info notices remain. `git diff --check` passed.
- Repository lifecycle regressions cover joins, departures, removal, transfer, archival/restoration, legacy recovery, participant snapshots, account-deletion guard, monetary validation, pending/confirmed/cancelled payments, and historical-month payments.
- Widget/provider regressions cover former-member debts, archived history, confirmed and pending payments, loading/error behavior, stable profile keys, and monthly accounting.
- `room_security_rules_test.dart` runs against the real Firestore emulator when `ROOM_FIRESTORE_EMULATOR` is set. It uses an isolated `demo-splitex-room-audit` project and synthetic local identities. It never uses production credentials.
- Test and analysis logs from this audit are under `.dart_tool/room-audit-*.log` (ignored build artifacts).

Start an official Firestore emulator with `firestore.rules`, then run:

```powershell
$env:ROOM_FIRESTORE_EMULATOR = '127.0.0.1:8787'
flutter test --no-pub --concurrency=1 test/modules/room
```

Deploy the matching Firestore rules together with a compatible app rollout. The new rules require versioned atomic writes; older app clients do not supply these writes. No live rules or app deployment is performed by this local audit. Physical-device checks should cover two accounts, admin transfer while the other device is open, a departure followed by a new join, an earlier-month payment, and archive/restore with pending payments.
