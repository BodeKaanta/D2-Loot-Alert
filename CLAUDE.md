# CLAUDE.md

Read this whole file before doing anything in this repo. It is the shared memory between chat sessions.

**Keep it current.** When you make a decision, learn something about the API, finish a phase or change the plan, update the matching section on your working branch as part of that task. Add decisions to the [decision log](#decision-log) with the date.

---

## Working rules (non-negotiable)

1. **Never write code on `main`.** All work happens on a task branch. Before editing any file, run `git branch --show-current`. If it says `main`, stop and switch to (or create) the branch for the current task.
2. **Bode reviews all code before it is committed.** The loop for every change is:
   1. Write the change.
   2. Show Bode the new or changed code and explain how it works. Go into more detail on the parts that are new to Bode: the Firebase backend, Cloud Functions, push notification setup, and Flutter or Dart patterns beyond the basics.
   3. Answer any questions and fix any logic issues Bode spots.
   4. Wait for explicit approval.
   5. Commit, then push.

   Never commit or push anything Bode hasn't seen. This covers code, build files, manifests, CI workflows and docs.
3. **Never merge pull requests.** No `gh pr merge`, no merging into `main` locally and no pushing to `main`. You may commit and push to working branches and open PRs. Bode always has the final say on merges.
4. **Every feature or problem gets a task on the kanban board,** assigned to Bode (`BodeKaanta`) with a size of S, M or L. Use **one branch per task.** See [Task workflow](#task-workflow).
5. **Never commit secrets. The repo is public.**
   - The Bungie API key lives in a gitignored `.env` file locally and in Cloud Secret Manager for the backend.
   - Never commit Firebase service-account keys (JSON files containing `private_key`). The backend doesn't need one; Cloud Functions use the project's own credentials.
   - The Firebase client config files (`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`) aren't secrets, but decide in #8 whether to commit them.
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
  - For Bode (Mountain time), that's 11 AM during daylight saving time and 10 AM after the clocks change on Nov 1, 2026.
  - Daily reset changes the bonus focuses and vendor stock. Weekly reset changes the featured raids and dungeons.
- **Bonus focus:** each activity features one boosted item per day, changing at daily reset.
  - In-game, the activity preview shows the specific weapon or armor icon.
  - A separate "Bonus Drop" appears as a generic green engram. That is a different thing.
- **Bonus focus is class-specific only for armor.** Confirmed in Phase 0 on 2026-10-17:
  - All 18 weapon focuses were identical on Bode's Warlock, Hunter and Titan, so **one profile serves everyone.**
  - The 6 armor focuses were each class's version of the same set, e.g. Eutechnology Robes, Vest and Plate.
  - Armor bonus focus is out of scope for now.
- **One activity often has several entries with the same focus:** "Customize" and "Matchmade", or "Normal" and "Master". Group them so a weapon gets one alert, not several.
- **Crucible: one mode has the focus at a time** (Bode, confirmed by the data). Sparrow Racing League has its own separate focus.
  - Before the 2026-10-17 reset, Competitive had The Helmsman, and Trials, though live, showed no rewards at all.
  - After that reset, Competitive had nothing and Trials had Autumn Wind, a general Crucible weapon rather than a Trials-only one.
- **Gambit** had Last Man Standing both before and after the 2026-10-17 reset. It's unclear whether it sometimes repeats or rotates more slowly; the history from #6 will show.
- **Featured raids and dungeons:** currently 2 raids and 2 dungeons per week. For the week of 2026-10-13 these were Vow of the Disciple and Last Wish, plus Vesper's Host and Prophecy. See [Phase 0 findings](#phase-0-findings) for how to detect them.
- **Bungie keeps reorganizing the activity UI.** The Director was replaced by the Portal in The Edge of Fate (July 2025), and Wikipedia reports the Director returning in June 2026.
  - **Don't hardcode playlists or categories.** Model the data generically: activity → today's visible rewards.
- **Example: Gambit's pool** includes Spare Rations, Gnawing Hunger and Bug-Out Bag (Bode's example).
- **Cross-check sites:**
  - https://www.d2portal.com/today shows per-activity focus rewards and needs no login. On 2026-10-17 it matched our Phase 0 data exactly. It groups activities as Solo Ops, Fireteam Ops and Pinnacle Ops, and doesn't list Gambit or Crucible.
  - https://kyberscorner.com/this-week-in-destiny-2/ lists weekly featured raids and dungeons.

## Bungie API notes

- **Base URL:** `https://www.bungie.net/Platform`. Every request sends the header `X-API-Key: <key>`.
- **API key:** register an app at https://www.bungie.net/en/Application with OAuth client type "Not applicable". We don't use OAuth.
- **Only the backend talks to Bungie.** The phone app never holds the API key.
- **Spec:** https://github.com/Bungie-net/api (`openapi.json`).
  - Version 2.21.9, last commit 2025-12-02 ("Update for Renegades").
  - Portal activity fields were added in October 2025.
- **Privacy:** CharacterActivities (component 204) can be read **without OAuth**. Confirmed 2026-10-17 with Bode's "Show my progression" turned on.
  - Quirk: the response still labels the component `privacy: 2` (Private) while returning the data. Check whether `data` is present instead of trusting the label.

### Endpoints we expect to use (all API-key only)

| Purpose | Request |
|---|---|
| Bungie name → membership | `POST /Destiny2/SearchDestinyPlayerByBungieName/-1/` with body `{"displayName": "...", "displayNameCode": 1234}` |
| Characters + activities | `GET /Destiny2/{membershipType}/Profile/{destinyMembershipId}/?components=200,204` |
| Manifest index | `GET /Destiny2/Manifest/` |
| Single definition lookup | `GET /Destiny2/Manifest/{entityType}/{hash}/`, e.g. `DestinyInventoryItemDefinition`, `DestinyActivityDefinition` |
| Weekly public milestones | `GET /Destiny2/Milestones/` |
| Public vendors (Xûr only) | `GET /Destiny2/Vendors/?components=400,402` |

### Vendors (tested 2026-10-17)

- **The public vendors endpoint returns only Xûr.** Every other vendor (Banshee and so on) can differ per character, so reading them needs OAuth as Bode. That's planned as a later task.
- **Xûr publicly shows exotic armor names only,** e.g. Omnioculus and Peacekeepers. He shows up while he's in the game (Friday to Tuesday reset).
  - No stats: the item stat components come back empty even when requested.
  - No exotic weapons: those sit behind his "Strange Gear Offers" sub-vendor, which the public endpoint doesn't return.

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

### Phase 0 findings

Verified on 2026-10-17 against d2portal.com and Kyber's Corner. Raw data is in `phase0/output/` after a run.

- **Bonus focus:** the `visibleRewards[].rewardItems[]` entries with `uiStyle == "daily_grind_guaranteed"`.
- **Other `uiStyle` values:**
  - `"extra_engram"` is the generic "Ops Bonus Drop" green engram.
  - `""` marks generic previews such as "Powerful Gear", "Raid Gear" and "Deepsight Weapon".
- **Same on every character?** Yes for weapons. Armor is each class's version of the same set.
- **Loot pool: `DestinyActivityDefinition.rewards` lists the full pool.**
  - It includes weapons, armor and engram placeholders. Filter to weapons with `itemType == 3`.
  - It's static game data, so the Browse screen can show complete pools from day one.
  - Example: Gambit's pool includes Spare Rations, Gnawing Hunger, Bug-Out Bag and Last Man Standing.
  - Control and Competitive share the same Crucible pool.
- **Activity category:** look up `activityTypeHash` in `DestinyActivityTypeDefinition`.

  | Type | Hash |
  |---|---|
  | Raid | `2043403989` |
  | Dungeon | `608898761` |
  | The Crucible | `4088006058` |
  | Gambit | `248695599` |
  | Solo Ops | `3851289711` |
  | Vanguard Op | `1996806804` and `2009300208` |

  - The two "Vanguard Op" types are Fireteam Ops and Pinnacle Ops; which is which isn't settled yet.
  - `directActivityModeType` is missing on newer activities such as Vesper's Host and The Desert Perpetual, so don't rely on it.
- **Featured raids and dungeons:** activities whose type is Raid or Dungeon **and** whose `challenges` list isn't empty.
  - This matched Kyber's Corner exactly: Vow of the Disciple, Last Wish, Prophecy and Vesper's Host.
  - The newest raid (The Desert Perpetual) and dungeon (Equilibrium) also have a challenge every week, because they're always available.
  - Backup for raids only: public milestones list every raid, but only the featured ones have `challengeObjectiveHashes`. Dungeons aren't in milestones.
- **`isFocusedActivity`** marks the Portal's featured carousel, **not** the bonus focus. Sparrow Racing League and the Warden of Nothing GM have a bonus focus but the flag is false.
- **Scale:** each character has 180–230 available activities, about 130 of which show rewards. 24 had a bonus focus on 2026-10-17.

Other notes:

- The docs warn that 204 data "can be unfortunately problematic and relatively unreliable." Parse defensively: treat every field as optional, and never crash on missing fields.
- **Name lookups:** the full manifest is large, so look up individual hashes with the single-definition endpoint.
  - The first Phase 0 run made about 300 lookups and took about 85 seconds; the cache makes reruns fast.
  - The backend should cache definitions too, in Firestore or a downloaded activity table. Decide in #6.
- **Item icons** are relative paths. Prefix them with `https://www.bungie.net`.
- **Rate limits:** a few requests per day are far below any limit.

## Architecture (planned)

```
shortly after daily reset (17:00 UTC)
  scheduled Cloud Function (Python) ── Bungie API (Bode's profile)
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
| `backend/` | Cloud Functions source, Python (#6, #7). `main.py` is the scheduled function, `rotation.py` the logic, `bungie.py` the API client (from Phase 0). |
| `firebase.json`, `.firebaserc` | Firebase CLI config: functions source and runtime, rules file, default project `d2-loot-alert` |
| `firestore.rules` | Firestore security rules, deployed with `firebase deploy --only firestore:rules` |
| `app/` | Flutter app (#8 onward) |

### Firebase project

- **Project:** "d2 loot alert", in Bode's **personal** Google account, separate from the other app. **Project ID: `d2-loot-alert`**.
- **Set up in #5:**
  - Firestore database (Standard edition, production mode) with the rules from `firestore.rules`
  - FCM API (V1) enabled
  - Admin SDK service-account key and GitHub secrets: made for the GitHub Actions plan, **now unused**. Delete them; Cloud Functions use the project's own credentials.
- **Plan: Blaze (pay-as-you-go), chosen in #6.** Cloud Functions need it. Bode doesn't want to be billed, so keep usage far inside the free allowances:

  | Service | Our use | Free allowance |
  |---|---|---|
  | Cloud Functions (Cloud Run) | 3 short runs a day | 2M requests, 180k vCPU-seconds, 360k GiB-seconds a month |
  | Cloud Scheduler | 1 job (one cron with 3 times) | 3 jobs per billing account |
  | Secret Manager | 2 secrets | 6 active secret versions, 10k accesses a month |
  | Firestore | a handful of writes per run; app reads | 50k reads, 20k writes a day |
  | Artifact Registry | build images from deploys | 0.5 GB storage, kept low by a cleanup policy |
  | FCM | pushes | free |

  - **Budget alert at $1.** It emails; it doesn't cap spending.
  - **Run `firebase functions:artifacts:setpolicy` once** after the first deploy, so old build images get deleted.
  - **Don't add** Firestore-triggered functions that write to Firestore (they can loop), or anything that runs constantly.
  - **Worst realistic case** is someone hammering the public Firestore reads past 50k a day. That costs pennies per 100k reads, and the budget alert would flag it. App Check can lock reads to the real app later if needed.
  - **Free trial:** if Google attached its $300 / 90-day free trial to the billing account, the account must be upgraded to a full (paid) account before the trial ends, or Google stops the project.
- **CLI account:** Bode's Firebase CLI defaults to the other app's Google account. In this repo, use the personal account, added with `firebase login:add` and selected with `firebase login:use <email>`.
- **App ID** for both Android and iOS: `com.id0.d2lootalert`. It's permanent once the app is in App Store Connect.

### Backend

- **A scheduled Cloud Function** (2nd gen, Python 3.11 to match Bode's local Python), `daily_rotation` in `backend/main.py`, region us-central1 (the default).
  - **Don't pass `timezone=`** to `on_schedule`. It needs a time-zone database that Windows lacks, which breaks `firebase deploy` from Bode's PC. The CLI already defaults 2nd-gen schedules to UTC (`DEFAULT_TIME_ZONE_V2` in firebase-tools).
  - **Schedule:** cron `7 17,18,21 * * *` in UTC. That's 17:07, a few minutes after reset, plus backups at 18:07 and 21:07. The backups cover Bungie API outages around reset and late arrivals like Trials. Tuesday's reset is also a daily reset, so the same schedule covers the weekly check.
  - **Timeout** 540 s, **memory** 512 MB. A normal run takes seconds; rebuilding loot pools after a game update takes about 2–3 minutes.
  - **Logs:** Firebase console → Functions → `daily_rotation` → Logs, or Google Cloud Logging.
  - **Test without waiting for reset:** Google Cloud console → Cloud Scheduler → the function's job → **Force run**.
- **Secrets** (Cloud Secret Manager, set with `firebase functions:secrets:set <NAME>`):
  - `BUNGIE_API_KEY`
  - `BUNGIE_NAME`
- **Writes Firestore** (and, in #7, sends FCM) with the Firebase Admin SDK, using the function's built-in credentials. The Admin SDK bypasses security rules.
- **Dependencies** (`backend/requirements.txt`, pinned): `firebase-functions` and `firebase-admin`. `rotation.py` and `bungie.py` use only the standard library, so the dry run needs nothing installed.
- **Local test:** with `BUNGIE_API_KEY` and `BUNGIE_NAME` set, run `python backend/rotation.py --dry-run`. It writes to `backend/output/` (gitignored) instead of Firestore.
  - Use plain `python`, not `python -I`, so `rotation.py` can import `bungie.py`.
  - From Git Bash, load the env vars with `set -a; source <(tr -d '\r' < phase0/.env); set +a`.
- **Deploy** (from the repo root):
  1. One time: `python -m venv backend/venv` then `backend/venv/Scripts/pip install -r backend/requirements.txt`. The CLI reads the functions from this venv.
  2. `firebase deploy --only functions`
- **Idempotent:** each run for the same reset overwrites the same documents. **Reset ID** is the date of the most recent 17:00 UTC reset, e.g. `2026-10-17`.
- **Firestore layout** (finalized in #6):

  | Path | Holds |
  |---|---|
  | `rotation/current` | `resetId`, `updatedAt`, `activities[]`, `featured[]` |
  | `history/{resetId}` | a copy of each reset's last snapshot |
  | `lootPools/{id}` | one activity group's weapons, from its definitions' `rewards`. Rebuilt only when the manifest version changes. |
  | `meta/state` | `manifestVersion`, `lastResetId`, `lastRunAt` |

  - An **activity group** has an `id` (e.g. `gambit-gambit`), `name`, `category`, `image`, `activityHashes[]` and `weapons[]`.
    - The `id` is the slug of category + base name, so the Today screen's entries link to their loot pool by the same `id`.
  - A **weapon** has `itemHash`, `name`, `type` and `icon` (a full URL).
  - A **featured** entry has `id`, `name`, `kind` (`raid` or `dungeon`), `image` and `activityHashes[]`.
  - The always-available newest raid (The Desert Perpetual, including its Epic version) and dungeon (Equilibrium) also show up as featured.

- **Security rules** (`firestore.rules`): anyone can read, nobody can write. The backend writes through the Admin SDK, which ignores rules.

### Push notifications

- FCM **topics**, so the server never stores user data:
  - `weapon_<itemHash>`
  - `raid_<activityHash>` (dungeons use this too)
- **One message per weapon per reset,** naming every activity where it's the focus, e.g. "Spare Rations is today's bonus drop in Gambit." Variants like Customize and Matchmade share a focus, so group them first.
- **iOS** needs an APNs auth key (.p8) uploaded to Firebase, plus the Push Notifications capability in Xcode. Done in #8, along with registering the apps through `flutterfire configure`.
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
| #3 | Update README and CLAUDE.md for iOS and the new architecture | S | Done |
| #4 | Phase 0: Bungie API test script (Python) | M | Done |
| #5 | Firebase project setup | S | Done |
| #6 | Backend: daily rotation job (Cloud Function) | M | In progress |
| #7 | Backend: push notifications for bonus drops and featured raids | S | Backlog |
| #8 | Flutter app setup and Today screen | M | Backlog |
| #9 | Watch screens: browse loot pools and raids, toggle alerts | M | Backlog |
| #10 | Release: Android APK and iOS TestFlight | M | Backlog |
| later | Privacy policy + App Store release, if the friend keeps using it | — | Not created |
| #13 | Xûr alerts: exotic armor he's selling (names only, no login), after #7 | S | Backlog |
| later | Vendor weapon alerts (Banshee etc.): needs OAuth as Bode, with a stored refresh token | — | Not created |
| later | Extras: forecasting, armor bonus focus | — | Not created |

All Phase 0 questions are answered; see [Phase 0 findings](#phase-0-findings).

**Still open (minor):**

- Does Gambit's focus sometimes repeat across resets?
- Which "Vanguard Op" type is Fireteam Ops and which is Pinnacle Ops?

Watch these in the daily snapshots once #6 runs.

## Current status

- **#6** (branch `task_6_daily_rotation_job`): the Cloud Function is written, and a dry run against live data passed. Waiting on Bode to upgrade to Blaze and add the personal account to the Firebase CLI, then set secrets, deploy and verify one run.
- **Next:** #7, push notifications.
- **Phase 0 script:** run `python phase0/api_test.py` from the repo root. It needs `phase0/.env`, which holds the API key and Bungie name and is gitignored.

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
- **2026-10-17:** Phase 0 **confirmed one profile serves everyone** for weapon bonus focus.
- **2026-10-17:** **Loot pools come from `DestinyActivityDefinition.rewards`,** not from building up history.
- **2026-10-17:** **Featured raids and dungeons** = Raid or Dungeon activities with a non-empty `challenges` list. This replaces the idea of a hardcoded rotation cycle.
- **2026-10-17:** ~~Firebase scheduled Cloud Function on the Blaze plan.~~ Superseded the same day: Bode wants to stay on the free Spark plan, which has no Cloud Functions.
- **2026-10-17:** ~~**The backend runs in GitHub Actions** (scheduled Python job) and writes to Firebase on the Spark plan with a service-account key.~~ Superseded on 2026-10-17.
- **2026-10-17:** **Back to a scheduled Cloud Function on the Blaze plan.**
  - GitHub's terms say Actions shouldn't be used "as part of a serverless application" and limit use to developing and testing software.
  - GitHub staff disabled the popular keep-alive action's repo, so working around the 60-day pause isn't safe either.
  - Bode accepted Blaze on the condition that bills stay very unlikely. See the free-allowance table under Firebase project.
- **2026-10-17:** Python 3.11 runtime, matching Bode's local Python. Bungie API key and name stored in Cloud Secret Manager.
- **2026-10-17:** Loot pools cover every available activity with weapons in its `rewards` (74 on 2026-10-17). They're rebuilt only when the manifest version changes.
- **2026-10-17:** App ID `com.id0.d2lootalert`. The Firebase project lives in Bode's personal Google account.
- **2026-10-17:** Vendor weapon alerts are a later task (they need OAuth). Xûr's exotic armor alerts are task #13, after #7.
- **2026-10-17:** Backend schedule: one run shortly after reset plus two backup runs, with alerts sent only once per reset.
- **2026-10-17:** App registration and the APNs key moved from #5 to #8, where `flutterfire configure` handles registration.
