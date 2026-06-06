# split_ex

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Future Requirements

### Core Features
- Create/join groups (trips, roommates, etc.)
- Add expenses with description, amount, date
- Split bills equally, by percentage, by exact amounts, or by shares
- Track who owes whom
- Settle up / record payments

### Nice-to-Have Features
- Recurring expenses (rent, subscriptions)
- Receipt scanning (OCR)
- Multi-currency support with conversion
- Expense categories & tags
- Activity feed / expense history
- Push notifications for new expenses or reminders
- Export reports (PDF/CSV)
- Offline support with sync

### Social Features
- Invite friends via link/contact
- In-app chat per group
- Nudge/remind to pay

### Analytics
- Monthly spending summary
- Category-wise breakdown
- Balance trends over time

### Settings & Account

#### Priority 1 (Must-have)
- Edit Profile (name, photo)
- Change Password
- Delete Account
- Theme toggle (Light/Dark/System)
- Default Currency selection
- Notification preferences (push, email, SMS)
- Export Data (CSV/PDF)
- Terms of Service & Privacy Policy
- Log Out
- App Version display

#### Priority 2 (Should-have)
- Phone auth (OTP)
- Biometric lock (Face ID / Fingerprint)
- Help Center / FAQs
- Contact Support / Report a Bug
- Open Source Licenses
- Email verification
- Re-authentication for sensitive operations
- Anonymous sign-in


### Known issues
- Image upload issue
- Settlement issue - UPI apps showing error during payment(GPAY, Phonepay, Paytm)
- 1 - 1 Expense should be like, a person paying for another person, i.e, one person owing the entered anount totally to paid person - Done
- Clicking settle up in homepage, moving to expense tab of room page instead of settlement tab
- Settlement tab showing same data even changing months
- Pending settlements are showing in activity log and recent activity
- Home page selecting other month, current month recent activity showing