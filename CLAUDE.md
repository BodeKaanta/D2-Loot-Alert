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
- **In-game Portal category** (used since #8): the category the game itself shows, e.g. "Solo Ops", "Gambit Ops", "Raids". It comes from **`DestinyFireteamFinderActivityGraphDefinition`**, the tree the game builds its Portal screens from.
  - The **top-level nodes** (no `parentHash`, non-empty name) are the categories: Solo Ops, Fireteam Ops, Arena Ops, Pinnacle Ops, Crucible Ops, Gambit Ops, Raids, Dungeons, Campaign, Pantheon, World.
  - Each node lists `selfAndAllDescendantHashes`. Each descendant's `relatedActivitySetHashes` points into **`DestinyFireteamFinderActivitySetDefinition`**, whose `activityHashes` are the activities.
  - `DestinyGlobalConstantsDefinition.portalActivityGraphRootNodesWithIcons` lists the five main Portal roots in the game's order: Solo, Fireteam, Arena, Pinnacle ("Prestige" in its image name), Crucible. "Gambit Ops" isn't in that list, but it is a top-level node.
  - On 2026-10-17: The Coil and Midtown → Pinnacle Ops; Battleground: Oracle, HyperNet Current, The Devils' Lair, Warden of Nothing → Fireteam Ops; Astral Alignment and the "Vanguard Op" Quickplay → Arena Ops; Trials and Sparrow Racing → Crucible Ops; Gambit → Gambit Ops.
- **Bungie's internal activity type** is `activityTypeHash` in `DestinyActivityTypeDefinition`. The game doesn't show it ("Crawl", "Mission"…). Use it only as a fallback for activities outside the Portal tree, and to detect raids and dungeons.

  | Type | Hash |
  |---|---|
  | Raid | `2043403989` |
  | Dungeon | `608898761` |
  | The Crucible | `4088006058` |
  | Gambit | `248695599` |
  | Solo Ops | `3851289711` |
  | Vanguard Op | `1996806804` and `2009300208` |

  - The two "Vanguard Op" types turned out to be Arena Ops and Pinnacle Ops in the game; the Portal tree above settles it.
  - `directActivityModeType` is missing on newer activities such as Vesper's Host and The Desert Perpetual, so don't rely on it.
- **Featured (rotator, farmable) raids and dungeons:** activities whose type is Raid or Dungeon, whose `challenges` list isn't empty, **and** whose `visibleRewards` preview real loot (`rotation.is_farmable`).
  - This matches Kyber's Corner exactly: Vow of the Disciple, Last Wish, Prophecy and Vesper's Host.
  - **The newest raid (The Desert Perpetual, + Epic) and dungeon (Equilibrium) have a weekly challenge every week too, but they are NOT farmable.** They preview only the "Weekly Reward" item (`3649567221`), meaning loot once a week. Bode spotted this on 2026-10-17, and the reward check excludes them.
  - The previews seen on 2026-10-17:

    | Raid / dungeon | Preview items |
    |---|---|
    | Rotator raids | "Raid Gear" (`3808930384`/`3808930390`) + a guaranteed "Deepsight Weapon" (`2782701438`) |
    | Other raids | "Deepsight Weapon (Chance)" |
    | Rotator dungeons | "Powerful Gear" (`735813784`/`3220608786`) |
  - Backup for raids only: public milestones list every raid, but only the featured ones have `challengeObjectiveHashes`. Dungeons aren't in milestones.
- **`isFocusedActivity`** marks the Portal's featured carousel, **not** the bonus focus. Sparrow Racing League and the Warden of Nothing GM have a bonus focus but the flag is false.
- **Scale:** each character has 180–230 available activities, about 130 of which show rewards. 24 had a bonus focus on 2026-10-17.

Other notes:

- The docs warn that 204 data "can be unfortunately problematic and relatively unreliable." Parse defensively: treat every field as optional, and never crash on missing fields.
- **Banners (`pgcrImage`):** many activities use Bungie's literal placeholder, `/img/theme/destiny/bgs/pgcrs/placeholder.jpg`. On 2026-10-17 that was 707 of 4,069 activity definitions, including Gambit, The Coil and Quickplay. Real art usually sits on *another version* of the same activity, so the backend falls back (`game_data.py`):
  1. its own image, if it isn't the placeholder
  2. the most common real image among definitions with the same name, stripping known variant words after a colon one at a time ("Quickplay: Master" → "Quickplay")
  3. for a playlist, its first map's image (Gambit → `gambit_badlands.jpg`)
  4. none (the app shows a plain dark banner)

  Bungie's image folders can't be listed; only images referenced by definitions are usable (502 distinct banners). The in-game Gambit card art isn't in the public data.
- **Definition lookups:**
  - **Activity tables are downloaded whole** from the manifest's `jsonWorldComponentContentPaths.en`. `DestinyActivityDefinition` is about 11 MB and downloads in under a second; the two Fireteam Finder tables are small.
  - **Items stay single lookups** through the entity endpoint, because the item table is far bigger.
  - A full run with a loot-pool rebuild takes about 80 seconds, down from about 160.
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
| `backend/` | Cloud Functions source, Python (#6, #7, #8). `main.py` is the scheduled function, `rotation.py` the logic, `alerts.py` the pushes, `game_data.py` the Portal categories and banner fallbacks from whole tables, `bungie.py` the API client (from Phase 0). |
| `firebase.json`, `.firebaserc` | Firebase CLI config: functions source and runtime, rules file, default project `d2-loot-alert` |
| `firestore.rules` | Firestore security rules, deployed with `firebase deploy --only firestore:rules` |
| `app/` | Flutter app (#8 onward) |

### Firebase project

- **Project:** "d2 loot alert", in Bode's **personal** Google account, separate from the other app. **Project ID: `d2-loot-alert`**.
- **Set up in #5:**
  - Firestore database (Standard edition, production mode) with the rules from `firestore.rules`
  - FCM API (V1) enabled
  - The rules paste in #5 never actually got published; the console still had the deny-all default. Since #6 the rules are deployed from the repo with `firebase deploy --only firestore:rules`. A change takes about a minute to apply.
  - Admin SDK service-account key and GitHub secrets: made for the GitHub Actions plan and **removed on 2026-10-17**. The GitHub secrets and Bode's key file were deleted, and the key itself is revoked under IAM & Admin → Service Accounts → `firebase-adminsdk-fbsvc` → Keys.
    - **Never delete the service accounts themselves.** `firebase-adminsdk-fbsvc` is Firebase's, `…-compute@developer` is what the function runs as, and `…@appspot` is a Google default.
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
  - **Test without waiting for reset:** Google Cloud console → Cloud Scheduler → job `firebase-schedule-daily_rotation-us-central1` → ⋮ → **Force run**. (`gcloud` isn't installed on Bode's PC.)
  - **Check results without credentials:** Firestore allows public reads, so `GET https://firestore.googleapis.com/v1/projects/d2-loot-alert/databases/(default)/documents/rotation/current` works. `meta/state` is written last, so if it has a fresh `lastRunAt`, the whole run succeeded.
  - **The function's URL is private.** Unauthenticated calls get 403; only Cloud Scheduler can invoke it. Keep it that way. Never make the invoker public, or strangers could trigger runs.
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
- **Deploy gotchas** (all from the first deploy on 2026-10-17):
  - **"Failed to list functions" right after Firebase enables the Cloud Functions API** is a propagation delay. Wait a minute or two and retry.
  - **`firebase functions:secrets:set` can leave a secret with no value.** Check with `firebase functions:secrets:get <NAME>`, which should list an ENABLED version. To set one from `.env` without the prompt: `grep '^NAME=' phase0/.env | cut -d= -f2- | tr -d '\r\n' | firebase functions:secrets:set NAME --data-file -`.
  - **The first deploy configured the Artifact Registry cleanup policy** (delete images older than 1 day) by itself, so `functions:artifacts:setpolicy` wasn't needed.
  - **When Claude deploys,** use `--non-interactive --force` because its shell can't answer prompts. `--force` only bypasses prompts here; there are no other functions it could delete.
- **Idempotent:** each run for the same reset overwrites the same documents. **Reset ID** is the date of the most recent 17:00 UTC reset, e.g. `2026-10-17`.
- **Firestore layout** (finalized in #6):

  | Path | Holds |
  |---|---|
  | `rotation/current` | `resetId`, `updatedAt`, `activities[]`, `featured[]`, `raidsAndDungeons[]` (every farmable-capable raid and dungeon, same entry shape and IDs as `featured`; Pantheon and the newest raid and dungeon are left out) |
  | `history/{resetId}` | a copy of each reset's last snapshot |
  | `lootPools/{id}` | one activity group's weapons, from its definitions' `rewards`. Rebuilt only when the manifest version or `POOLS_SCHEMA` (in `rotation.py`) changes; a rebuild also deletes pools whose IDs no longer exist. |
  | `meta/state` | `manifestVersion`, `poolsSchema`, `lastResetId`, `lastRunAt`, plus alert tracking (`sentResetId`, `sentWeaponTopics`, `sentWeekId`, `sentRaidTopics`) |

  - An **activity group** has an `id` (e.g. `gambit-ops-gambit`), `name`, `category` (the in-game Portal category), `image` (a real banner when one exists), `activityHashes[]` and `weapons[]`.
    - The `id` is the slug of category + base name, so the Today screen's entries link to their loot pool by the same `id`.
    - `activities[]` is sorted in the game's Portal order (`CATEGORY_ORDER`: Solo, Fireteam, Arena, Pinnacle, Crucible, Gambit Ops), then anything else alphabetically, then by name. The app keeps that order.
    - **Bump `POOLS_SCHEMA`** whenever group IDs or the pool shape change. 2 = Portal categories (#8).
  - A **weapon** has `itemHash`, `name`, `type` and `icon` (a full URL).
  - A **featured** entry has `id`, `name`, `kind` (`raid` or `dungeon`), `image` and `activityHashes[]`.
  - Only rotator-featured, farmable raids and dungeons appear (see Phase 0 findings). The newest raid and dungeon don't.

- **Security rules** (`firestore.rules`): anyone can read, nobody can write. The backend writes through the Admin SDK, which ignores rules.

### Push notifications

- Built in #7: `backend/alerts.py` builds and sends the alerts, and `rotation.new_alerts()` decides which are new.
- FCM **topics**, so the server never stores user data. The app subscribes when the user watches something:
  - `weapon_<itemHash>`
  - `raid_<id>`, where `id` is the featured entry's name slug, e.g. `raid_vow-of-the-disciple`. Dungeons use it too. Slugs are used because one raid has several activity hashes (Standard, Master).
- **Weapon alert (daily):** one per weapon per reset, naming every activity where it's the focus.
  - **Title:** "Spare Rations is a bonus drop today"
  - **Body:** "Bonus focus in Gambit". Bode wants the body so people learn which activity a weapon comes from.
  - The category is added only when two categories share an activity name, e.g. "Quickplay (Solo Ops) and Quickplay (Vanguard Op)".
  - **Image:** the weapon icon.
- **Raid/dungeon alert (weekly):** **title only**, e.g. "Vow of the Disciple is featured this week". Bode: players already know the weekly rotation lasts until Tuesday.
  - Only the farmable, rotator-featured ones are alerted. The newest raid and dungeon never are, because they're never "featured" in the farmable sense. (This replaced the earlier plan to alert them every Tuesday.)
- **Data payload** (strings only), for tap-to-open in #9:
  - weapons: `kind=weapon`, `itemHash`, `activityIds` (comma-separated group ids)
  - raids: `kind=raid|dungeon`, `id`
- **Never twice:** `meta/state` stores `sentResetId` + `sentWeaponTopics` and `sentWeekId` + `sentRaidTopics`.
  - **Week ID** is the date of the most recent Tuesday 17:00 UTC reset.
  - A run only sends topics that aren't recorded yet for the current reset or week. Only topics FCM accepted get recorded, so failures retry on the next backup run.
- **Images on iOS** need a Notification Service Extension in the app (#8). The backend already sets `mutable-content` and `fcm_options.image` on APNs. Android shows the image with no extra work.
- **iOS** also needs an APNs auth key (.p8) uploaded to Firebase, plus the Push Notifications capability in Xcode. Done in #8, along with registering the apps through `flutterfire configure`.
- **Tests:** run `python -m unittest discover backend` from the repo root (19 tests, standard library only). They cover the reset and week math, alert wording, deduplication, the farmable check, the raid catalog, banner fallbacks and Portal categories, the last two on tiny hand-made tables. Test files are excluded from deploys in `firebase.json`.
- **Local check of FCM messages:** `rotation.py --dry-run --skip-pools` writes `backend/output/alerts.json`.
- **Watch types are simplified** to "weapon, in any activity" plus "raid or dungeon." A weapon's alert fires wherever it's the bonus focus, and the message says where.

### App (Flutter)

Lives in `app/` (Flutter 3.44, Dart 3.12). The package name is `d2lootalert`, and the app ID is `com.id0.d2lootalert` on both platforms. The display name is "D2 Loot Alert".

- **Packages:** `firebase_core` ^5, `cloud_firestore` ^7, `firebase_messaging` ^17, `shared_preferences` ^2.5 (added in #9 for the watch list).
  - `getToken()` is deprecated in `firebase_messaging` 17 (replaced by `register()`/`onRegistered`). We don't need tokens, only topics.
  - **Pinned: `shared_preferences_android` 2.4.28** (`dependency_overrides` in `pubspec.yaml`, #21).
    - 2.5.0 (released 2026-10-17) switched to a "Pigeon JNI" bridge that release-build code shrinking (R8) breaks. The app hung on the splash screen with `NoSuchMethodError ... SharedPreferencesApiRegistrar.getAll`, while debug builds worked.
    - **Remove the pin** once a fixed version is out and a release build starts cleanly.
  - **Always try a release build** (`flutter run --release`) before shipping. Some bugs, like this one, only show up there.
  - To read the app's own crash log on the Pixel: `adb -s <device> logcat -d --pid=$(adb -s <device> shell pidof com.id0.d2lootalert)`.
- **Code layout** (`app/lib/`):

  | File | What it does |
  |---|---|
  | `main.dart` | Firebase init, Inter license, loads the `WatchStore` before the first frame. `MaterialApp.builder` wraps the navigator in `WatchScope`, so pushed screens can reach it too. |
  | `theme.dart` | `AppColors`, `AppText`, `buildTheme()` |
  | `models.dart` | Defensive parsing of the Firestore docs; `groupByCategory()`; `buildCategoryLoot()`; `portalCategories` |
  | `reset.dart` | Next daily reset and countdown text |
  | `push.dart` | Permission, topic subscribe and unsubscribe, `weaponTopic()` / `raidTopic()` (must match `backend/alerts.py`) |
  | `watch_store.dart` | The watch list (see Watching below), plus `WatchScope` |
  | `screens/` | `home_screen` (tabs and push taps), `today_screen`, `loot_screen`, `category_screen`, `raids_screen`, `about_screen` |
  | `widgets/` | Section header, banner image, activity card with `WeaponRow`/`WeaponBell`/`ItemTile`, featured grid and card with `RaidBell`, reset countdown, `WatchBell`, `AppTabBar`, `PageHeader` |

- **Tabs** (bottom, `AppTabBar`, **three equal thirds** so LOOT sits in the middle, as Bode asked): **TODAY / LOOT / RAIDS & DUNGEONS**. "RAIDS &" / "DUNGEONS" is stacked on two lines (Bode: it crowded the screen edge; stacking also keeps one text size on narrower iPhones). Every tab has the same two-line label area, so the underlines line up. The last name matches the game's wording (Bode). `IndexedStack` keeps each tab's scroll position.
- **Today:** a live listener on `rotation/current` (`snapshots()`), so it updates itself when the backend writes. Pull-to-refresh forces a server read.
  - **Layout, like the game's Portal:** "BONUS FOCUS" with one section per Portal category (SOLO OPS, FIRETEAM OPS… GAMBIT OPS) via `groupByCategory()`, cards showing only the activity name. Every weapon row has a watch bell.
  - Then "FEATURED THIS WEEK" with RAIDS and DUNGEONS, **kept at the bottom** (Bode, 2026-10-17): daily content changes more often, and the RAIDS & DUNGEONS tab shows the featured ones first anyway.
- **Loot:** WATCHING (every watched weapon, with its bell), then one banner card per Portal category with its weapon count. A card opens `CategoryScreen`: the category's whole pool, each weapon with a bell.
  - `buildCategoryLoot()` merges the `lootPools` docs per category. The main pool is the weapon list most activities share. Weapons outside it are labeled "<activity> only" (e.g. Trials of Osiris, Sparrow Racing League, Warden of Nothing), which also covers Iron Banner or Trials-specific focus later.
  - **Only the Portal categories are shown** (`portalCategories`, kept in sync with `CATEGORY_ORDER` in `rotation.py`). That hides the one-off Campaign, Story and World quest weapons (Bode).
- **Raids & Dungeons:** FEATURED THIS WEEK (grid with bells), then ALL RAIDS and ALL DUNGEONS as slim banner rows with bells. These come from `rotation/current.raidsAndDungeons`; featured ones are labeled in gold.
- **Watching** (`WatchStore`, a `ChangeNotifier` read through `WatchScope.of(context)`):
  - **Watching = subscribing to the FCM topic** (`weapon_<itemHash>`, `raid_<id>`). FCM can't list a phone's topics, so the list is also saved locally with `shared_preferences` (key `watches`, JSON).
  - **Taps are instant (#20).** A tap changes the list, every bell, and the confirmation message on the same frame, and saves without waiting.
    - The FCM subscribe or unsubscribe runs **in the background**, queued per topic, so fast repeated taps resolve in tap order.
    - **If it fails,** the change is undone (unless a later tap already reversed it) and a message goes out on `WatchStore.failures`. `main.dart` shows those through a global `ScaffoldMessenger` key, on whatever screen is open.
  - **The first watch asks for notification permission.** That's the only time a tap waits; once granted, it isn't asked again in that session. If it's denied, nothing is watched.
  - **Firebase calls are injected,** so `test/watch_store_test.dart` runs with fakes, including a "slow network" gate to prove the bell updates before the network answers.
  - **A reinstall starts with an empty list** (a new install gets new FCM registrations anyway).
- **Tapping a push** (`HomeScreen`): `getInitialMessage()` (app was closed) and `onMessageOpenedApp` (app was in the background) switch the tab by the alert's `kind`: `weapon` → Today, `raid`/`dungeon` → Raids & Dungeons.
  - With the app in the foreground, Android doesn't display FCM notification messages. That's fine, since the screens already update live.
- **Performance (#20):**
  - **Judge smoothness in a release build** (`flutter run --release`). Debug builds scroll noticeably worse and aren't representative.
  - **Banners decode at their on-screen size** (`cacheWidth` in `BannerImage`, from `LayoutBuilder`) instead of Bungie's ~1920 px originals. `BoxFit.cover` on the taller grid cells is accounted for.
  - **No disk image cache.** Release scrolling was already smooth, so it wasn't worth a new package.
- **Tests:** `flutter test` (14 tests: models, category loot, reset math, watch store) and `flutter analyze`, both clean as of #20.

### Design system (agreed with Bode in #8)

- **Look:** close to Bungie's own in-game and website style. Dark, and **not stock Material**.
- **Colors** (`AppColors`):
  - background `#0B0E11`, cards `#151A1F`
  - 1 px borders at 15% white (item tiles at 30%)
  - text `#E9E7E2`, secondary text `#8B939C`
  - exotic gold `#CEAE33`: **the one bright accent.** It's used for the 4×20 bar in front of each section header, a *watched* bell, the active tab's underline, and the "FEATURED THIS WEEK" label on raid rows. Keep it rare so it stays a landmark.
- **Type:** **Inter** (SIL OFL 1.1, bundled in `app/assets/fonts/` with `Inter-OFL.txt`, which must stay).
  - Headers are uppercase with wide letter spacing (`AppText.appTitle`, `groupTitle`, `sectionHeader`, `cardTitle`, `label`). Widgets call `.toUpperCase()` themselves.
  - **Hierarchy,** largest first:
    1. `groupTitle` 20 ("BONUS FOCUS", "FEATURED THIS WEEK")
    2. `appTitle` 18
    3. `sectionHeader` 16, bold off-white with the gold bar (categories, RAIDS, DUNGEONS)
    4. `cardTitle` 14 (activity names on banners)

    Section headers must stay bigger than card titles: Bode scans by them while scrolling fast (2026-10-17).
  - Destiny's own font, reportedly Neue Haas Grotesk, is commercial, so we don't use it.
- **Shapes:** square corners everywhere, no ripple (`NoSplash`), thin 1 px borders. Weapon icons sit in square tiles like Destiny's inventory.
- **Art rules:**
  - **No AI-generated art, ever.**
  - **Images only from the Bungie API:** weapon icons and activity `pgcrImage` banners, shown dimmed under a gradient. **No bungie.net concept art** for now; it's Bungie-owned, and Apple flags third-party IP.
  - **Bungie images only as *content*:** an item's icon, an activity's banner. **Never Bungie UI graphics or branding**, e.g. the Portal category emblems in `portalActivityGraphRootNodesWithIcons` or the Gambit snake shield. Category names are fine as plain text.
  - **The line** (agreed with Bode on 2026-10-17): looking *inspired by* Destiny is fine, since style, colors and layout aren't protected. Copying their graphics, logos, font or screens, implying it's official, or making money is not.
  - **Credits** live on the About screen: "Destiny imagery © Bungie, Inc." plus the not-affiliated disclaimer and the Inter credit.
  - **The app icon** will be made by Bode's artist friend (the iOS tester). No Bungie or Destiny logos. Specs: 1024×1024 PNG with no transparency, plus optional Android foreground and background layers. Credit him on the About screen if he wants; Bode will ask.
- **Known data quirks:**
  - Bungie's placeholder banner is replaced by real art where any exists (see Bungie API notes > Banners).
  - The Arena Ops and Solo Ops Quickplays share the same "Quickplay" banner, since the fallback works by name.
  - Midtown's banner comes from its Crucible map art.

### App setup on a new machine (including Bode's Mac)

The Firebase client config files are **gitignored** (`app/lib/firebase_options.dart`, `app/android/app/google-services.json`, `app/ios/Runner/GoogleService-Info.plist`). They aren't secret, but Bode chose to keep them out of the public repo's history. Committing and deleting them later wouldn't remove them from history. Each machine regenerates them:

1. Install Flutter, Node, and the Firebase CLI (`npm install -g firebase-tools`).
2. Log in with the **personal** Google account: `firebase login`. If the CLI already uses the other app's account, run `firebase login:add`, then `firebase login:use <personal email>` in the repo.
3. Install the FlutterFire CLI: `dart pub global activate flutterfire_cli`.
4. In `app/`, run:
   ```
   flutterfire configure --project=d2-loot-alert --platforms=android,ios --android-package-name=com.id0.d2lootalert --ios-bundle-id=com.id0.d2lootalert --yes
   ```
   It reuses the apps registered in #8, so nothing new gets created in Firebase.
   - Copying the files from the PC works too.
5. **Mac / iOS extras** (#17):
   - Install Xcode and CocoaPods. Flutter runs `pod install` on the first iOS build.
   - Set the signing team in Xcode (Runner target → Signing & Capabilities).
   - The push key, capabilities and Notification Service Extension are all in #17.

### Running and testing the app on Bode's PC

- **Pixel:** run from Android Studio, or `flutter run` with the phone connected.
- **Emulator** (`Medium_Phone_API_36.1`): it only has about 450 MB free, so the 150 MB all-CPU debug APK won't install. Build just its CPU type instead: `flutter build apk --debug --target-platform android-x64 --split-per-abi`, then `adb install -r build/app/outputs/flutter-apk/app-x86_64-debug.apk`.
  - The emulator also has Bode's `hand_speed_calculator` app. **Don't uninstall it or wipe the emulator.**
- **From Git Bash,** set `MSYS_NO_PATHCONV=1` before `adb shell` commands with `/` paths, or Git Bash rewrites them. adb is at `C:/Users/bodek/AppData/Local/Android/sdk/platform-tools/adb.exe`.
- **Push test** (debug builds only):
  1. In the app, open About → **Enable notifications**. It asks permission and subscribes to topic `test`.
  2. Put the app in the background.
  3. In the Firebase console → **Messaging** → new campaign → Firebase Notification messages, set the target to **Topic** `test`, and send.

## Roadmap

| # | Task | Size | Status |
|---|---|---|---|
| #3 | Update README and CLAUDE.md for iOS and the new architecture | S | Done |
| #4 | Phase 0: Bungie API test script (Python) | M | Done |
| #5 | Firebase project setup | S | Done |
| #6 | Backend: daily rotation job (Cloud Function) | M | Done |
| #7 | Backend: push notifications for bonus drops and featured raids | S | Done |
| #8 | Flutter app setup and Today screen (Android/PC) | M | In progress |
| #17 | iOS setup: push key, notification image extension, iPad testing (Mac) | M | Backlog |
| #9 | Watch screens: browse loot pools and raids, toggle alerts | M | In progress |
| #10 | Release: Android APK and iOS TestFlight | M | Backlog |
| later | Privacy policy + App Store release, if the friend keeps using it | — | Not created |
| #13 | Xûr alerts: exotic armor he's selling (names only, no login), after #7 | S | Backlog |
| later | Vendor weapon alerts (Banshee etc.): needs OAuth as Bode, with a stored refresh token | — | Not created |
| later | Extras: forecasting, armor bonus focus | — | Not created |

All Phase 0 questions are answered; see [Phase 0 findings](#phase-0-findings).

**Still open (minor):**

- Does Gambit's focus sometimes repeat across resets?

Watch these in the daily snapshots once #6 runs.

## Current status

- **Backend (#6, #7):** deployed and merged. It runs daily at 17:07 UTC plus backups, and sends alerts. A forced run on 2026-10-17 sent all 20 alerts and FCM accepted them.
- **#8:** merged (PR #18). App with Portal categories, real banners, farmable-only featured list; a real push was received on Bode's Pixel.
- **#9** (branch `task_9_watch_screens`): tabs, LOOT, category pools, RAIDS & DUNGEONS, watch bells, watch list, push-tap handling, and the backend `raidsAndDungeons` list.
  - Verified on the emulator: watching Gnawing Hunger asked for permission, subscribed, showed the gold bell and listed it under WATCHING.
  - **Remaining:** Bode's review, commit, a backend redeploy plus Force run (so the ALL RAIDS / ALL DUNGEONS lists fill), then the PR. A real weapon alert arrives at the next reset where a watched weapon is a bonus focus.
- **Next:** #13 (Xûr), #17 (iOS on the Mac), #10 (release).
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
- **2026-10-17:** **App art policy:** only Bungie API images, credited to Bungie on an About screen. No bungie.net concept art for now, no AI-generated art ever. The app icon comes from Bode's artist friend.
- **2026-10-17:** **Font: Inter** (free, OFL) instead of Destiny's commercial font. The look follows Bungie's dark in-game style; the Today screen layout was approved from a mockup.
- **2026-10-17:** **Firebase client config files are gitignored;** each machine runs `flutterfire configure`.
- **2026-10-17:** **In-game Portal categories** (from the Fireteam Finder tree) replace Bungie's internal activity types. The Today screen groups cards under category headers like the game. This was done inside #8, since it's part of getting the Today screen right.
- **2026-10-17:** **Real banners replace Bungie's placeholder** via the name and playlist fallbacks. The backend downloads whole activity tables instead of making single lookups.
- **2026-10-17:** **Bungie images appear only as content** (icons, banners), never UI graphics or emblems. The app's style stays "inspired by", not copied.
- **2026-10-17:** **"Featured" means farmable (the weekly rotator).** The newest raid and dungeon are excluded via the "Weekly Reward"-only preview check, and get no weekly pushes. This supersedes the earlier "alert the always-available ones every Tuesday".
- **2026-10-17:** Featured cards show only the name; the RAIDS / DUNGEONS header already says the kind.
- **2026-10-17:** **Featured raids stay at the bottom of Today;** the RAIDS & DUNGEONS tab shows them first.
- **2026-10-17:** **Tabs: TODAY / LOOT / RAIDS & DUNGEONS** (the last matches the game's wording).
- **2026-10-17:** **LOOT browses by Portal category, not by activity.** Special-pool weapons are labeled "<activity> only". Campaign, Story and World quest weapons are hidden.
- **2026-10-17:** **The watch list is stored locally** with `shared_preferences` (FCM can't list a phone's topics). Watching = a topic subscription; the first watch asks for notification permission.
- **2026-10-17:** **Every weapon row on Today gets a watch bell too,** so a weapon can be watched right where it's spotted.
- **2026-10-17:** #8 split by platform. The iOS-only work (push key, image extension, iPad testing) is #17, done on the Mac.
- **2026-10-17:** The push test uses a `test` topic, the same path as real alerts. `getToken()` is deprecated in firebase_messaging 17, and we don't need device tokens.
- **2026-10-17:** App ID `com.id0.d2lootalert`. The Firebase project lives in Bode's personal Google account.
- **2026-10-17:** Vendor weapon alerts are a later task (they need OAuth). Xûr's exotic armor alerts are task #13, after #7.
- **2026-10-17:** Backend schedule: one run shortly after reset plus two backup runs, with alerts sent only once per reset.
- **2026-10-17:** App registration and the APNs key moved from #5 to #8, where `flutterfire configure` handles registration.
