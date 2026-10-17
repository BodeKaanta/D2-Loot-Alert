# CLAUDE.md

Read this whole file before doing anything in this repo. It is the shared memory between chat sessions.

**Keep it current.** When you make a decision, learn something about the API, finish a phase or change the plan, update the matching section on your working branch as part of that task. Add decisions to the [decision log](#decision-log) with the date.

---

## Working rules (non-negotiable)

1. **Never write code on `main`.** All work happens on a task branch. Before editing any file, run `git branch --show-current`. If it says `main`, stop and switch to (or create) the branch for the current task.
2. **Bode reviews all code before it is committed.** The loop for every change is:
   1. Write the change.
   2. Show Bode the new or changed code and explain how it works. Go into more detail on the parts that are new to Bode: the Firebase backend, Python Cloud Functions, push notification setup, and Flutter or Dart patterns beyond the basics.
   3. Answer any questions and fix any logic issues Bode spots.
   4. Wait for explicit approval.
   5. Commit, then push.

   Never commit or push anything Bode hasn't seen. This covers code, build files, manifests, CI workflows and docs.
3. **Never merge pull requests.** No `gh pr merge`, no merging into `main` locally and no pushing to `main`. You may commit and push to working branches and open PRs. Bode always has the final say on merges.
4. **Every feature or problem gets a task on the kanban board,** assigned to Bode (`BodeKaanta`) with a size of S, M or L. Use **one branch per task.** See [Task workflow](#task-workflow).
5. **Never commit secrets. The repo is public.**
   - The Bungie API key lives in a gitignored `.env` file locally and in a Firebase Functions secret in the cloud.
   - Never commit Firebase service-account keys (JSON files containing `private_key`).
   - The Firebase client config files (`google-services.json`, `GoogleService-Info.plist`) aren't secrets, but decide in #5 whether to commit them.
   - Check the diff for keys before every commit.
6. **No force-pushes, history rewriting on pushed branches or skipped hooks** (`--no-verify`).
7. **Ask before adding a dependency.** Say what it does and why it's needed.
8. **Prefer clear over clever.** Readable code with comments where the *why* isn't obvious. Bode should be able to explain every line in an interview.

## About the developer

- Bode is a senior computer science student.
- Comfortable in Java, Python, C and C++.
- **Has shipped a large Flutter + Firebase app to both app stores,** so the Flutter basics and the store processes are familiar.
- **Firebase:** has set it up before but wants **step-by-step reminders.** Give exact console clicks and CLI commands rather than assuming Bode remembers them.
- **Who writes the code:** Claude writes it and explains it. After roughly 5–10 coding commits, start sometimes giving Bode pseudocode to fill in, for small, self-contained pieces only.
- **Keep it quick.** Bode is also shipping that other app, so this project should stay low-effort. Choose the simplest approach that works, don't over-engineer, and keep tasks small.
- **Devices:**
  - Bode: Pixel 9 Pro XL on the latest Android. Android Studio is installed on Bode's Windows PC.
  - iOS: Bode has a Mac (for Xcode builds and TestFlight uploads) and an iPad for testing.
  - Bode's friend uses an iPhone.
- **Design:** the app must **not look like a stock Flutter app.** Use a custom theme, typography and components. Agree on the look with Bode in #8.
- Offer recommendations, but leave design decisions to Bode.

## Task workflow

- **Repo:** `BodeKaanta/D2-Loot-Alert` (public)
- **Board:** "D2 Loot Alert Task Board", GitHub Project #6, linked to the repo: https://github.com/users/BodeKaanta/projects/6
- **Board fields:**
  - `Status`: Backlog / In Progress / Done
  - `Size`: S / M / L
  - `Priority`: P0 / P1 / P2
- **New tasks:** before creating tasks, explain what each one is and why it's needed, and agree on the breakdown with Bode. Don't bulk-create a backlog without discussing it first.
- **Size guide:**
  - S: an hour or two
  - M: about one evening
  - L: several sessions. Consider splitting it.

**Steps for each task:**

1. Create the issue:
   ```sh
   gh issue create --repo BodeKaanta/D2-Loot-Alert --assignee BodeKaanta \
     --title "..." --body "..." [--label enhancement|bug|documentation]
   ```
2. Add it to the board:
   ```sh
   gh project item-add 6 --owner BodeKaanta --url <issue-url> --format json
   ```
   The output's `id` is the item ID.
   - The board also auto-adds new issues from this repo. If `item-add` says "Content already exists", find the item ID with `gh project item-list 6 --owner BodeKaanta --format json`.
3. Set Size and Status:
   ```sh
   gh project item-edit --project-id <project-id> --id <item-id> \
     --field-id <field-id> --single-select-option-id <option-id>
   ```
   Look up the IDs with `gh project field-list 6 --owner BodeKaanta --format json`. At last check the project ID was `PVT_kwHOBJc_rc4BnTqZ`.
4. Branch from an up-to-date `main`:
   ```sh
   git checkout main && git pull && git checkout -b <branch>
   ```
   Then move the task to **In Progress**.
5. Work through the review loop in rule 2. Commit in small, focused steps with an imperative summary line ("Add Bungie profile fetch").
6. Push and open a PR with `gh pr create`.
   - The body covers what changed, why, and how it was tested.
   - Include `Closes #<issue>` so the issue closes when Bode merges.
7. Bode reviews and merges. Never merge yourself.

**Branch naming:** `task_<issue#>_<short_snake_case_description>`, e.g. `task_4_phase0_api_test`. `getting_started` (issue #1) predates this convention.

**Numbering:** GitHub numbers issues and PRs from the same counter, so a PR takes the next number too.

---

## Project overview

A small Android + iOS app for Bode and a friend:

- **Bonus focus alerts:** the user picks weapons they want and gets a push notification on the day a weapon is an activity's **bonus focus** drop.
- **Featured raid alerts:** the user picks raids and dungeons and gets notified in the week they are **featured** (farmable).

**Distribution:**
- **Android:** Bode sideloads a signed APK.
- **iOS:** TestFlight first, for Bode's friend.
  - TestFlight builds expire after 90 days.
  - If the friend keeps using the app, move to an App Store release so nobody has to reinstall every 90 days. That needs a privacy policy; Claude helps write it.

No user accounts and no login. The README holds the public-facing scope.

## Destiny 2 domain notes

- **Resets:** daily reset is **17:00 UTC** and weekly reset is **Tuesday 17:00 UTC**, both fixed in UTC regardless of daylight saving time. Trials of Osiris runs from Friday reset to Tuesday reset.
- **Bonus focus:** each activity features one boosted item per day, changing at daily reset.
  - In-game, the activity preview shows the specific weapon or armor icon.
  - A separate "Bonus Drop" appears as a generic green engram. That is a different thing.
- **Bonus focus can depend on class.** For armor it does: on 2026-10-16, d2portal.com showed a hunter cloak for one activity and warlock robes for another.
  - **Weapons are assumed to be the same for everyone.** The backend checks one profile (Bode's) and the result serves every user, so this must be confirmed in Phase 0 (#4).
  - Armor bonus focus is out of scope for now.
- **Featured raids and dungeons:** currently 2 raids and 2 dungeons per week. For the week of 2026-10-13 these were Vow of the Disciple and Last Wish, plus Vesper's Host and Prophecy.
- **Bungie keeps reorganizing the activity UI.** The Director was replaced by the Portal in The Edge of Fate (July 2025), and Wikipedia reports the Director returning in June 2026.
  - **Don't hardcode playlists or categories.** Model the data generically: activity → today's visible rewards.
- **Example: Gambit's pool** includes Spare Rations, Gnawing Hunger and Bug-Out Bag (Bode's example).
- **Cross-check sites:**
  - https://www.d2portal.com/today shows per-activity focus rewards and needs no login. It probably uses the same API data we plan to use.
  - https://kyberscorner.com/this-week-in-destiny-2/ lists weekly featured raids and dungeons.

## Bungie API notes

- **Base URL:** `https://www.bungie.net/Platform`. Every request sends the header `X-API-Key: <key>`.
- **API key:** register an app at https://www.bungie.net/en/Application with OAuth client type "Not applicable". We don't use OAuth.
- **Only the backend talks to Bungie.** The phone app never holds the API key.
- **Spec:** https://github.com/Bungie-net/api (`openapi.json`).
  - Version 2.21.9, last commit 2025-12-02 ("Update for Renegades").
  - Portal activity fields were added in October 2025.
- **Privacy:** CharacterActivities (component 204) can be read **without OAuth** if the profile's progression is set to public. Bode believes theirs already is; confirm in Phase 0.

### Endpoints we expect to use (all API-key only)

| Purpose | Request |
|---|---|
| Bungie name → membership | `POST /Destiny2/SearchDestinyPlayerByBungieName/-1/` with body `{"displayName": "...", "displayNameCode": 1234}` |
| Characters + activities | `GET /Destiny2/{membershipType}/Profile/{destinyMembershipId}/?components=200,204` |
| Manifest index | `GET /Destiny2/Manifest/` |
| Single definition lookup | `GET /Destiny2/Manifest/{entityType}/{hash}/`, e.g. `DestinyInventoryItemDefinition`, `DestinyActivityDefinition` |
| Weekly public milestones | `GET /Destiny2/Milestones/` |
| Public vendors (probably unused) | `GET /Destiny2/Vendors/` |

### Key data shapes

- **`DestinyCharacterActivitiesComponent`** (component 204), per character:
  - `availableActivities[]` (each a `DestinyActivity`)
  - `availableActivityInteractables[]`
  - `difficultyTierCollections`, `selectableSkullCollections`
- **`DestinyActivity`** (live state for one activity):
  - `activityHash`, `modifierHashes[]`, `difficultyTier`, `challenges`
  - `isFocusedActivity`: the docs say "in the featured carousel of the Portal."
  - **`visibleRewards[]`**: a list of `DestinyActivityRewardMapping`, "a filtered list of reward mappings with only the currently visible reward items." Each mapping has:
    - `displayBehavior`: enum `DestinyActivityRewardDisplayMode` (Aggregate=0, PickFirst=1, Count=2)
    - `rewardItems[]`: each has `itemQuantity { itemHash, quantity }` and `uiStyle` (string)

**Main hypothesis (UNVERIFIED):** the bonus focus is an entry in `visibleRewards`, told apart by its `uiStyle` string. Phase 0 confirms this.

Other notes:

- The docs warn that 204 data "can be unfortunately problematic and relatively unreliable." Parse defensively: treat every field as optional, and never crash on missing fields.
- `DestinyActivityDefinition.rewards` holds tooltip-style rewards, often placeholder items rather than real drops. It may or may not be usable as a loot pool.
- **Name lookups:** the full manifest is large. Look up individual hashes with the single-definition endpoint; a day's run needs only a few dozen.
- **Item icons** are relative paths. Prefix them with `https://www.bungie.net`.
- **Rate limits:** a few requests per day are far below any limit.

## Architecture (planned)

```
once a day, shortly after reset (17:00 UTC)
  Firebase scheduled function (Python) ── Bungie API (Bode's profile)
     ├─ writes today's bonus drops + featured raids to Firestore
     └─ sends FCM pushes to topics: weapon_<itemHash>, raid_<activityHash>

Flutter app (Android + iOS)
  ├─ reads today's data from Firestore
  ├─ watching something = subscribing the phone to its FCM topic
  └─ receives pushes; no background work, no Bungie key, no login
```

**Why a server:** iOS doesn't let apps run on a schedule (background refresh is opportunistic and may never run), so on-device polling can't deliver reliable alerts. A server push works the same on both platforms.

### Repo layout

| Folder | Contents |
|---|---|
| `phase0/` | Bungie API test script (#4) |
| `backend/` | Firebase Cloud Functions, Python (#6, #7). Its Bungie code comes from the Phase 0 script. |
| `app/` | Flutter app (#8 onward) |

### Backend

- Cloud Functions for Firebase (2nd gen), Python runtime, as a scheduled function.
  - Scheduled functions need the **Blaze** (pay-as-you-go) plan. Set a budget alert. Expected usage is within the free tier.
- The Bungie API key is stored as a Functions secret.
- **Reset ID:** the timestamp of the most recent 17:00 UTC reset. Stored in Firestore so each reset is processed and notified **once**, even if the function runs more than once.
- **Firestore layout** (draft, finalize in #6):

  | Path | Holds |
  |---|---|
  | `rotation/current` | today's activities with their bonus focus items (name, icon, hash), plus this week's featured raids and dungeons |
  | `history/{resetId}` | a copy of each day's snapshot |
  | `lootPools/{activityHash}` | every item seen as that activity's bonus focus, which builds the loot pool over time |
  | `meta/state` | last processed daily and weekly reset IDs |

- **Security rules:** apps can read; only the backend (Admin SDK) can write.

### Push notifications

- FCM **topics**, so the server never stores user data:
  - `weapon_<itemHash>`
  - `raid_<activityHash>` (dungeons use this too)
- The message names the activity, e.g. "Spare Rations is today's bonus drop in Gambit."
- **iOS** needs an APNs auth key (.p8) uploaded to Firebase, plus the Push Notifications capability in Xcode.
- **Watch types are simplified** to "weapon, in any activity" plus "raid or dungeon." A weapon's alert fires wherever it's the bonus focus, and the message says where.

### App (Flutter)

- **Packages:** `firebase_core`, `firebase_messaging`, `cloud_firestore`, plus a small local store for the watch list (e.g. `shared_preferences`).
- **Screens:**
  - Today: every activity's bonus focus and the featured raids and dungeons
  - Browse: activity → loot pool → watch toggle
  - Raids & Dungeons: watch toggles
- **Custom look:** not stock Material. Decide the direction in #8.

## Roadmap

| # | Task | Size | Status |
|---|---|---|---|
| #3 | Update README and CLAUDE.md for iOS and the new architecture | S | In progress |
| #4 | Phase 0: Bungie API test script (Python) | M | Backlog |
| #5 | Firebase project setup | S | Backlog |
| #6 | Backend: daily rotation job | M | Backlog |
| #7 | Backend: push notifications for bonus drops and featured raids | S | Backlog |
| #8 | Flutter app setup and Today screen | M | Backlog |
| #9 | Watch screens: browse loot pools and raids, toggle alerts | M | Backlog |
| #10 | Release: Android APK and iOS TestFlight | M | Backlog |
| later | Privacy policy + App Store release, if the friend keeps using it | — | Not created |
| later | Extras: forecasting, armor bonus focus | — | Not created |

**Phase 0 (#4) must answer these questions:**

- How does the bonus focus appear in `visibleRewards`? Which `uiStyle` values show up?
- Are Gambit, each Crucible mode and Trials separate activities with their own rewards?
- **Is the weapon bonus focus the same on every character?** The one-profile backend depends on this.
- Does any API data list an activity's full loot pool, or must we build it from observed history?
- How are featured raids and dungeons detected? Candidates: `isFocusedActivity`, public milestones, or the rewards on raid activities. If none work, fall back to a known rotation cycle anchored to a known date.
- Is component 204 readable without OAuth for Bode's profile?

## Current status

- **#3** (branch `task_3_update_docs_for_ios`): this docs update. In review.
- **Next:** #4, the Phase 0 API test script.
  - Bode needs a Bungie API key (bungie.net/en/Application) and their Bungie name with its number (`Name#1234`).

## Decision log

- **2026-10-16:** ~~Build a native Android app (Kotlin + Jetpack Compose) rather than a server plus push service.~~ Superseded on 2026-10-17.
- **2026-10-16:** No OAuth. Use an API key plus a public Bungie.net progression setting.
- **2026-10-16:** ~~Personal use only. Sideloaded APK, no store release, Android only.~~ Superseded on 2026-10-17.
- **2026-10-16:** ~~Poll every few hours on the device with deduplication by reset ID.~~ Superseded on 2026-10-17; the backend uses reset IDs instead.
- **2026-10-16:** Review happens before commit: Claude shows and explains the code, then commits and pushes after Bode approves.
- **2026-10-16:** Branch names follow `task_<issue#>_<description>`.
- **2026-10-16:** The board's Size field was trimmed to S/M/L, and the board was renamed "D2 Loot Alert Task Board".
- **2026-10-17:** **Support iOS** for Bode's friend: TestFlight first, App Store later if it sticks.
- **2026-10-17:** **Flutter** for the app instead of Kotlin. Speed matters more than learning Kotlin, and Bode already knows Flutter. The design must not look stock.
- **2026-10-17:** **Firebase backend:** a scheduled Python function, Firestore and FCM topic pushes. iOS can't run reliable scheduled background work, so alerts have to come from a server.
- **2026-10-17:** **One profile serves everyone.** The backend checks Bode's profile only; weapon bonus focus is assumed to be the same for all players, pending Phase 0.
- **2026-10-17:** **FCM topics instead of user records.** No accounts, and no per-user data on the server.
- **2026-10-17:** Watch types simplified to "weapon, in any activity" plus "raid or dungeon."
- **2026-10-17:** The Phase 0 script is in **Python**, so its code can carry over to the Python backend.
