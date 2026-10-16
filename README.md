# D2 Loot Alert

An Android app that tells you when the Destiny 2 loot you're chasing is easy to farm.

> **Status:** Planning. No app code yet. See the [roadmap](#roadmap).

## The problem

Destiny 2 rotates its rewards on a schedule:

- **Daily:** at every daily reset, each activity (Gambit, Crucible modes like Control or Trials of Osiris, Vanguard and other Portal activities) features a **bonus focus** drop. That's one item from the activity's loot pool with a much better chance to drop. Spare Rations might be Gambit's bonus focus one day and Bug-Out Bag the next.
- **Weekly:** at every weekly reset, a set of older raids and dungeons becomes **featured**, which makes their loot farmable for that week.

If you can't play every day, you either check the game daily or miss the window for the weapon you want.

## What it does

The app is planned to:

- **Browse activities and their loot pools**, then pick the weapons you care about.
- **Watch a weapon,** in one specific activity or in any activity, and get a phone notification on the day it's the bonus focus.
- **Watch raids and dungeons** and get a notification in the week they're featured.
- **Show a Today screen** with every activity's current bonus focus at a glance.
- **Keep a rotation history** of every bonus focus it has seen, which fills in loot pools over time and may allow forecasting ("likely back in 3 days").

## How it works

```
 every few hours (Android WorkManager)
        │
        ▼
 Bungie.net API ── your characters' available activities
        │          and each one's currently visible rewards
        ▼
 look up item and activity names (Destiny manifest, cached)
        │
        ▼
 save today's snapshot ──► compare against your watchlist
                                    │
                                    ▼
                          local notification on a match
                          (once per watch per reset)
```

Everything runs on the phone. There is no server and no login. The app reads public data from the [Bungie.net API](https://github.com/Bungie-net/api), which needs only an API key and a Bungie.net profile with progression set to public.

## Tech stack (planned)

| Area | Choice |
|---|---|
| Language | Kotlin |
| UI | Jetpack Compose |
| Background work | WorkManager |
| Storage | Room (SQLite) |
| Networking | Retrofit + OkHttp or Ktor (decided in Phase 1) |
| JSON | kotlinx.serialization |
| Data source | Bungie.net Platform API |

## Scope

**In scope**
- One user: me
- Android only, installed by sideloading an APK
- Daily bonus focus alerts for any activity the API exposes
- Weekly featured raid and dungeon alerts

**Out of scope**
- Google Play or App Store release
- iOS
- Multiple users, accounts or a backend server
- Bungie login (OAuth), inventory management and vendor tracking

## Roadmap

| Phase | Goal | Status |
|---|---|---|
| 0. API spike | Script that pulls live data and confirms how bonus focus and featured raids appear in the API | Not started |
| 1. Core logic | Fetch, resolve names, snapshot and watchlist matching, unit-tested | Not started |
| 2. Bare app | Today screen, background check, notifications | Not started |
| 3. Watchlist UI | Browse loot pools, watch weapons, pick raids and dungeons | Not started |
| 4. Extras | Rotation history, forecasting, notification deep links | Not started |

Work is tracked on the [project board](https://github.com/users/BodeKaanta/projects/6).

## Building

Coming in Phase 2. You'll need Android Studio and your own Bungie API key from [bungie.net/en/Application](https://www.bungie.net/en/Application). The key goes in `local.properties`, which is never committed.

## Disclaimer

This is a personal project, not affiliated with or endorsed by Bungie. Destiny 2 is a trademark of Bungie, Inc.
