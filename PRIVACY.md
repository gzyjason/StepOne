# Privacy Policy for StepOne

**Effective date:** August 12, 2026

This policy explains what information StepOne ("the app", "we", "us") collects, how it is used, and the choices you have. It's written to match what the app actually does — not a generic template — so if the app's behavior changes, this document should be updated alongside it.

## Who this policy covers

StepOne is published by MorSo and built and maintained by a single independent developer, Ziye Gao ("we", "us"). This policy applies to anyone who downloads or uses the StepOne iOS app.

StepOne is also open-source software: its full source code is public at [github.com/gzyjason/StepOne](https://github.com/gzyjason/StepOne) under the MIT License. That means the data practices described below aren't just a promise — you, or anyone, can read the code that runs on your device and verify them directly. Being a one-person project also means there's no separate support department; the contact address below reaches the developer.

## Information we collect

### Account information

When you register or sign in, we collect what's needed to create and secure your account:

- **Email and password**, if you register directly. Your password is never seen or stored by us in readable form — it is handled entirely by Firebase Authentication (a Google service), which stores only a securely hashed version.
- **Name and email**, if you sign in with **Sign in with Apple**. If you choose Apple's "Hide My Email" option, we receive the private relay address Apple generates instead of your real one.
- **Name and email**, if you sign in with **Google Sign-In**, as provided by your Google account.

This information is stored by Firebase Authentication on our behalf. We do not operate our own separate database of accounts.

### Trip progress

If you're signed in, StepOne keeps your chosen Trip categories, which Trips you've completed or discarded, and your distance/milestone progress in sync with our servers — specifically, in a Cloud Firestore document tied to your account, holding only those fields. That's what lets your progress follow you to a new device or survive a reinstall. Nobody but your signed-in account can read or write that document — it's enforced by server-side rules, not just app behavior. If you're not signed in, this data stays on your device only.

### Notification schedule

If you turn on reminders, the times you choose are scheduled directly with iOS (`UNUserNotificationCenter`) as local, on-device notifications. These do not go through a push notification server, and we never see or collect them.

### Information we do **not** collect

StepOne does not use analytics, advertising, or crash-reporting SDKs, does not access your location, camera, photo library, or contacts, and does not use advertising identifiers (IDFA) or any other cross-app tracking. We do not sell your information, and we don't have any to sell beyond the account details above.

## How we use your information

- To create, secure, and let you sign in to your account.
- To personalize the greeting and content shown in the app (e.g., using your name).
- To communicate with you about your account — for example, email verification and password-related emails, sent automatically by Firebase Authentication.

## Third-party services

StepOne relies on the following third parties to provide sign-in, authentication, and Trip progress storage. Each has its own privacy policy governing how it handles your data:

- **Firebase Authentication** (Google) — [https://firebase.google.com/support/privacy](https://firebase.google.com/support/privacy)
- **Cloud Firestore** (Google), for the Trip progress described above — [https://firebase.google.com/support/privacy](https://firebase.google.com/support/privacy)
- **Sign in with Apple** — [https://www.apple.com/legal/privacy/](https://www.apple.com/legal/privacy/)
- **Google Sign-In** — [https://policies.google.com/privacy](https://policies.google.com/privacy)

## Data retention and deletion

Your account information, and your synced Trip progress, are retained for as long as your account exists. You can permanently delete your account at any time from **Settings → Account → Delete Account** inside the app, which removes both your account from Firebase Authentication and your Trip progress document from Cloud Firestore. Data that lives only on your device — because you were never signed in, or signed out — is removed automatically when you sign out, delete your account, or uninstall the app.

To request deletion any other way, contact us at **support@morso.one**.

## Your rights

Depending on where you live, you may have rights to access, correct, or delete your personal information, or to object to or restrict how it's used. You can exercise most of these directly in the app (updating your name or email, or deleting your account in Settings), or by contacting us at **support@morso.one**.

## Children's privacy

StepOne is not directed at children under 13 (or the minimum age required by your country's law), and we do not knowingly collect information from children under that age. If you believe a child has created an account, contact us at **support@morso.one** and we will delete it.

## International data transfers

Firebase Authentication and Cloud Firestore store data on Google Cloud infrastructure, which may process and store information outside your country of residence. StepOne's Firestore data is currently hosted in the United States (`nam5`).

## Changes to this policy

We may update this policy as the app changes. If we make material changes, we'll update the effective date above.

## Contact us

Questions about this policy or your data can be sent to **support@morso.one**.
