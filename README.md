# D2 Loot Alert

An Android and iOS app that tells you when the Destiny 2 loot you're chasing is easy to farm.

> **Status:** Early development. No app code yet. See the [roadmap](#roadmap).

## The problem

Destiny 2 rotates its rewards on a schedule:

- **Daily:** at every daily reset, each activity (Gambit, Crucible modes like Control or Trials of Osiris, Vanguard and other Portal activities) features a **bonus focus** drop. That's one item from the activity's loot pool with a much better chance to drop. Spare Rations might be Gambit's bonus focus one day and Bug-Out Bag the next.
- **Weekly:** at every weekly reset, a set of older raids and dungeons becomes **featured**, which makes their loot farmable for that week.

If you can't play every day, you either check the game daily or miss the window for the weapon you want.

## What it does

The app is planned to:

- **Browse activities and their loot pools**, then pick the weapons you care about.
- **Watch a weapon** and get a push notification on the day it's a bonus focus drop, naming the activity.
- **Watch raids and dungeons** and get a notification in the week they're featured.
- **Show a Today screen** with every activity's current bonus focus and this week's featured raids and dungeons.
- **Keep a rotation history** of every bonus focus seen.

## How it works

```
 once a day, shortly after reset
   scheduled cloud function ──► Bungie.net API
        │                       (today's activities and their visible rewards)
        ├──► saves today's rotation to a database
        └──► sends a push notification to everyone watching
             each bonus-focus weapon or featured raid

 the app
   ├── reads today's rotation for the Today screen
   ├── watching an item subscribes the phone to that item's alerts
   └── receives the pushes
```

- **No accounts and no login.** Watching an item subscribes the phone to a push topic, so the server never stores who is watching what.
- **No API key on the phone.** Only the backend talks to the [Bungie.net API](https://github.com/Bungie-net/api).
- **Why a server at all:** iOS doesn't let apps reliably run on a schedule, so the checks happen in the cloud and arrive as pushes on both platforms.

## Tech stack

| Area | Choice |
|---|---|
| App | Flutter (Android + iOS), with a custom design |
| Backend | Cloud Functions for Firebase (Python), on a schedule |
| Database | Cloud Firestore |
| Notifications | Firebase Cloud Messaging (topics) |
| Data source | Bungie.net Platform API |

## Scope

**In scope**
- A small group of users: me and a friend
- Android, installed by sideloading an APK
- iOS through TestFlight, moving to the App Store if it sticks
- Daily bonus focus alerts for weapons
- Weekly featured raid and dungeon alerts

**Out of scope (for now)**
- Google Play release
- User accounts or Bungie login (OAuth)
- Armor bonus focus, inventory management and vendor tracking

## Roadmap

| Task | Goal | Status |
|---|---|---|
| Phase 0: API test | Script that pulls live data and confirms how bonus focus and featured raids appear in the API | Done |
| Firebase setup | Project on the free plan, database, backend secrets | Done |
| Daily rotation job | Scheduled function that saves each day's rotation | Done |
| Push notifications | Alerts for bonus focus weapons and featured raids | Not started |
| Xûr alerts | Alerts when Xûr sells an exotic armor piece you want | Not started |
| App: Today screen | Flutter app with a custom look, showing today's rotation | Not started |
| App: watch screens | Browse loot pools and raids, toggle alerts | Not started |
| Release | Android APK and iOS TestFlight | Not started |

Work is tracked on the [project board](https://github.com/users/BodeKaanta/projects/6).

## Building

Coming soon. You'll need Flutter, a Firebase project and your own Bungie API key from [bungie.net/en/Application](https://www.bungie.net/en/Application). The key is stored in Cloud Secret Manager and never committed.

## Disclaimer

This is a personal project, not affiliated with or endorsed by Bungie. Destiny 2 is a trademark of Bungie, Inc.
