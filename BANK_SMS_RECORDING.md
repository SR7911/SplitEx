# Bank SMS recording

Android only. Enable **Settings → Bank SMS Recording → Capture new bank SMS**.
The review inbox is also available directly from **Personal → SMS Review Inbox**.
The app shows a disclosure before requesting `RECEIVE_SMS`. It does not request
`READ_SMS` or `SEND_SMS`, scan the inbox, or send messages.

New senders require review. After recording or linking a verified alert, select
**Trust this sender for future clear expenses** to enable automatic recording for
that sender. Credits, absent payees/references/account endings, potential linked
payments, and bank transfers require review. Unsupported formats are ignored;
this is message-based bookkeeping, not bank-side payment verification.

While recording a reviewed expense, **Use this category for future payments**
saves an exact merchant + bank-sender rule. Rules suggest the category during
review and apply it to future automatic expenses without changing existing entries
or bypassing review safeguards. Manage rules in the SMS settings screen.

- Parsed accepted payments use the existing personal transaction collection.
- Raw messages and review items stay in the app-private `splitex_bank_sms`
  preferences, excluded from Android cloud and device-transfer backups.
- Signing out or switching users clears this device's captured/review SMS data.
- Disabling capture clears unprocessed SMS; existing review items can be dismissed.
- Durable import receipts prevent duplicate writes after retries, edits, or deletion.
- A same-amount transaction near the payment date goes to Review. Link the original
  EMI/settlement/manual entry instead of creating a second expense.
- Reviewed alerts can also create or link own-account transfers. A transfer does
  not count as spending or income. See [personal finance additions](PERSONAL_FINANCE_FEATURES.md)
  for accounts, account matching and the payment calendar.
- The background Android job requires connectivity. Android battery restrictions,
  force-stop, and device behavior can delay/prevent background delivery. The app
  also processes its captured queue on resume. No history scan fills missed SMS.
- Capture and review queues are bounded. If full, open the app to process or
  dismiss items; the settings screen reports a full capture queue.

## Before using against the live Firebase project

Deploy the owner-only `bank_sms_receipts` rules from the updated `firestore.rules`:

```sh
firebase deploy --only firestore:rules
```

The repository's `.firebaserc` selects the project. No rules are deployed by the
build. Until deployed, imports remain pending and existing financial data is not
modified by this feature.

## Release and device checks

Google Play SMS permission use requires a reviewed exception and an accurate
privacy policy / permissions declaration. Budgeting apps can apply under
[SMS-based money management](https://support.google.com/googleplay/android-developer/answer/10208820).
Do not publish the added permission without completing the applicable review.

The background entrypoint uses the same App Check debug provider already used by
`main.dart`. Configure both entrypoints for your production App Check setup before
a production release.

On a test Android device, verify: disclosure cancelled; permission denied/granted;
a multipart financial alert; untrusted sender review; approved sender automatic
debit; duplicate delivery; credit/refund review; existing EMI linking; capture off;
sign-out/account switch; revoked permission; offline retry; and app-closed job
execution. Automated parser/storage/widget tests do not establish SMS delivery or
background execution on a physical device.
