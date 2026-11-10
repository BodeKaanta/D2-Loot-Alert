---
title: Privacy policy
permalink: /privacy/
---

# Privacy policy

**D2 Loot Alert** · Last updated: November 10, 2026

D2 Loot Alert is a free, unofficial fan app for Destiny 2, made by Bode Kaanta. It
tells you when a weapon you want is a bonus focus drop, when a raid or dungeon you
want is featured that week, and when Xûr is selling an exotic you want.

**The short version:** the app has no accounts, collects no personal information, and
has no ads, analytics or tracking. The list of things you watch stays on your device.
To deliver notifications, the app uses Google's Firebase Cloud Messaging, described
below.

## What the app does not collect

- No account, login, name, email address or Bungie account.
- No location, contacts, photos or other personal data.
- No analytics, advertising or tracking of any kind, and nothing is sold or shared
  for advertising.
- No crash reporting service.

## What stays on your device

- **Your watch list** (the weapons, raids, dungeons and exotic armor you tap the bell
  on) is saved only on your device. It is never uploaded to us. Deleting the app
  deletes it.
- **Your notification permission** is managed by your phone's settings.

## Notifications

To send you alerts, the app uses **Firebase Cloud Messaging**, a Google service, which
delivers them through Apple's push notification service on iPhone and iPad, and
through Google's on Android.

- When you allow notifications, your device gets a **push token**: a random identifier
  that lets notifications reach this copy of the app. Firebase also gives the app a
  random **installation ID**. Neither one contains your name or any account
  information.
- When you watch something, your device **subscribes to a topic** for it, for example
  "weapon_fair-judgment". Firebase stores which topics your push token is subscribed
  to, so it can deliver the right alerts. When you unwatch something, the
  subscription is removed.
- Once a day, our server sends one message to each topic, for example "Fair Judgment
  is a bonus drop today". Firebase delivers it to every device subscribed to that
  topic. **We never see which devices are subscribed, or who you are.**

## Game data and images

- **Today's rotation** (bonus focus weapons, featured raids and dungeons, Xûr's stock)
  is read from a Google Cloud Firestore database. It's the same public information
  for everyone, and the app sends nothing about you to read it.
- **Weapon icons and activity art** are downloaded directly from Bungie's servers
  (bungie.net). That data comes from the official Bungie.net API, which only our
  server talks to.

## Service providers

Like any internet service, the companies below receive your device's IP address and
basic technical information (such as the device type and operating system version)
when the app connects to them. They process it under their own privacy policies:

- **Google (Firebase)**, for notifications and the rotation data:
  [Privacy and security in Firebase](https://firebase.google.com/support/privacy)
- **Apple**, which delivers notifications on iPhone and iPad:
  [Apple Privacy Policy](https://www.apple.com/legal/privacy/)
- **Bungie**, which serves the images:
  [Bungie Privacy Policy](https://www.bungie.net/7/en/Legal/PrivacyPolicy)

## How long data is kept

- Your watch list stays on your device until you delete the app.
- A topic subscription lasts until you unwatch the item. If you delete the app, its
  push token stops working, and Firebase removes push tokens that haven't been used
  for a long time.

## Children

The app is not directed at children under 13, and it does not knowingly collect
personal information from anyone.

## Changes to this policy

If the app starts handling data differently, this page will be updated, along with the
date at the top.

## Contact

Questions about this policy:

- Email: [d2lootalert@gmail.com](mailto:d2lootalert@gmail.com)
- Or open an issue on [GitHub](https://github.com/BodeKaanta/D2-Loot-Alert/issues)

D2 Loot Alert is an unofficial fan app, not affiliated with or endorsed by Bungie.
Destiny is a trademark of Bungie, Inc.
