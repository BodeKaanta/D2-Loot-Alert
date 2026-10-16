# CLAUDE.md

Read this whole file before doing anything in this repo. It is the shared memory between chat sessions.

**Keep it current.** When you make a decision, learn something about the API, finish a phase or change the plan, update the matching section on your working branch as part of that task. Add decisions to the [decision log](#decision-log) with the date.

---

## Working rules (non-negotiable)

1. **Never write code on `main`.** All work happens on a task branch. Before editing any file, run `git branch --show-current`. If it says `main`, stop and switch to (or create) the branch for the current task.
2. **Bode reviews all code before it is committed.** This is a learning project. The loop for every change is:
   1. Write the change.
   2. Show Bode the new or changed code and explain how it works. While Bode is still learning Kotlin, go into some detail on syntax and concepts, relating them to Java.
   3. Answer any questions and fix any logic issues Bode spots.
   4. Wait for explicit approval.
   5. Commit, then push.

   Never commit or push anything Bode hasn't seen. This covers code, build files, manifests, CI workflows and docs.
3. **Never merge pull requests.** No `gh pr merge`, no merging into `main` locally and no pushing to `main`. You may commit and push to working branches and open PRs. Bode always has the final say on merges.
4. **Every feature or problem gets a task on the kanban board,** assigned to Bode (`BodeKaanta`) with a size of S, M or L. Use **one branch per task.** See [Task workflow](#task-workflow).
5. **Never commit secrets.** The Bungie API key lives in `local.properties` (Android) or an environment variable or gitignored file (scripts). Check the diff for keys before every commit.
6. **No force-pushes, history rewriting on pushed branches or skipped hooks** (`--no-verify`).
7. **Ask before adding a dependency.** Say what it does and why it's needed.
8. **Prefer clear over clever.** Readable code with comments where the *why* isn't obvious. Bode should be able to explain every line in an interview.

## About the developer

- Bode is a senior computer science student.
- Comfortable in Java, Python, C and C++, with some Flutter/Dart: coursework without AI, plus one larger project using AI as a tool.
- **New to Kotlin** and wants to learn it to grow their portfolio. Teach as you go: point out Kotlin idioms (null safety, data classes, coroutines, extension functions) and how they compare to Java.
- **Who writes the code:** Claude writes it and explains it. After roughly 5–10 coding commits, start sometimes giving Bode pseudocode to fill in, for small, self-contained pieces only.
- **Keep it quick and easy.** Bode is also shipping a separate large app to both app stores, so this project should stay low-effort. Choose the simplest approach that works, don't over-engineer, and keep tasks small.
- **Device:** Pixel 9 Pro XL on the latest Android. Android Studio is installed on Bode's Windows PC.
  - This is the only device the app will ever run on, so `minSdk` can be recent. Pick it when the Android project is created.
- Offer recommendations, but leave design decisions to Bode.

## Task workflow

- **Repo:** `BodeKaanta/D2-Loot-Alert`
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
5. Work through the review loop in rule 2. Commit in small, focused steps with an imperative summary line ("Add Bungie profile client").
6. Push and open a PR with `gh pr create`.
   - The body covers what changed, why, and how it was tested.
   - Include `Closes #<issue>` so the issue closes when Bode merges.
7. Bode reviews and merges. Never merge yourself.

**Branch naming:** `task_<issue#>_<short_snake_case_description>`, e.g. `task_2_phase0_api_spike`. `getting_started` (issue #1) predates this convention.

---

## Project overview

Personal-use Android app (sideloaded APK, never published to a store).

- **Bonus focus alerts:** the user picks weapons they want and gets a phone notification on the day a weapon is an activity's **bonus focus** drop.
- **Featured raid alerts:** the user picks raids and dungeons and gets notified in the week they are **featured** (farmable).

Single user, no server, no accounts. The README holds the public-facing scope.

## Destiny 2 domain notes

- **Resets:** daily reset is **17:00 UTC** and weekly reset is **Tuesday 17:00 UTC**, both fixed in UTC regardless of daylight saving time. Trials of Osiris runs from Friday reset to Tuesday reset.
- **Bonus focus:** each activity features one boosted item per day, changing at daily reset.
  - In-game, the activity preview shows the specific weapon or armor icon.
  - A separate "Bonus Drop" appears as a generic green engram. That is a different thing.
- **Bonus focus can depend on class.** For armor it does: on 2026-10-16, d2portal.com showed a hunter cloak for one activity and warlock robes for another. Check **every character.** Weapons are probably the same across characters (unverified).
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

- The docs warn that 204 data "can be unfortunately problematic and relatively unreliable." Parse defensively: everything nullable, and never crash on missing fields.
- `DestinyActivityDefinition.rewards` holds tooltip-style rewards, often placeholder items rather than real drops. It may or may not be usable as a loot pool.
- **Manifest:** the full manifest is large. Plan to look up individual hashes via the single-definition endpoint and cache them in Room. Revisit if the Browse screen needs bulk data.
- **Polling:** one profile request every few hours is far below any rate limit.

## Architecture (planned)

- **Platform:** native Android, no backend.
- **Scheduling:** a WorkManager periodic job runs every few hours.
  - It computes the **reset ID**, the timestamp of the most recent 17:00 UTC reset. If that reset was already processed, the job does nothing.
  - This is sturdier than trying to fire at exactly 17:00, because Android delays background work under Doze.
- **Pipeline:**
  1. Fetch the profile (200 + 204).
  2. For each character, collect each activity's `visibleRewards`.
  3. Look up names, using the cache first.
  4. Store the daily snapshot.
  5. Match it against watches.
  6. Post a notification, at most once per watch per reset.
- **Watch types:**
  - `ItemInActivity`: a weapon in one specific activity
  - `ItemAnywhere`: a weapon in any activity
  - `FeaturedRaidOrDungeon`
- **Storage (Room tables):**
  - watches
  - daily snapshots
  - observed reward history (builds the loot pool over time)
  - definition cache
  - notification log (for deduplication)
- **Screens:**
  - Today: all current bonus focuses
  - Browse: activity → loot pool → watch toggle
  - Raids & Dungeons: featured toggles
  - Settings: Bungie name, "check now", and a battery-optimization exemption prompt
- **Android specifics:**
  - The `POST_NOTIFICATIONS` runtime permission is required on Android 13 and later.
  - Ask the user to exempt the app from battery optimization.
- **Secrets:** the API key goes in `local.properties` (gitignored), exposed through `BuildConfig`.

## Roadmap

| Phase | Goal | Status |
|---|---|---|
| 0. API spike | Script pulls Bode's live profile (200, 204), dumps the JSON, resolves names | Not started |
| 1. Core logic | Kotlin data layer: API client, definition cache, snapshot, watch matching, unit tests | Not started |
| 2. Bare app | Compose Today screen, WorkManager job, notifications, settings | Not started |
| 3. Watchlist UI | Browse activities and loot pools, watch weapons, raid and dungeon picker | Not started |
| 4. Extras | Rotation history and loot pool building, forecasting, notification deep links | Not started |

**Phase 0 must answer these questions:**

- How does the bonus focus appear in `visibleRewards`? Which `uiStyle` values show up?
- Are Gambit, each Crucible mode and Trials separate activities with their own rewards?
- Does any API data list an activity's full loot pool, or must we build it from observed history?
- How are featured raids and dungeons detected? Candidates: `isFocusedActivity`, public milestones, or the rewards on raid activities. If none work, fall back to a known rotation cycle anchored to a known date.
- Are weapon bonus focuses the same on every character?
- Is component 204 readable without OAuth for Bode's profile?

Phase 0 script language is not decided yet. Python is fastest since Bode knows it; Kotlin would double as practice for the app. Keep the API key out of the script and out of git.

## Current status

- **Issue #1** (branch `getting_started`): README and CLAUDE.md. In review.
- **Next:** break Phases 0–4 down into tasks together with Bode, then start the Phase 0 API spike.

## Decision log

- **2026-10-16:** Build a native Android app (Kotlin + Jetpack Compose) rather than a server plus push service. Single user, wants a real app UI, and wants to learn Kotlin.
- **2026-10-16:** No OAuth. Use an API key plus a public Bungie.net progression setting.
- **2026-10-16:** Personal use only. Sideloaded APK, no store release, Android only.
- **2026-10-16:** Poll every few hours with deduplication by reset ID, instead of scheduling exactly at reset.
- **2026-10-16:** Review happens before commit: Claude shows and explains the code, then commits and pushes after Bode approves.
- **2026-10-16:** Branch names follow `task_<issue#>_<description>`.
- **2026-10-16:** The board's Size field was trimmed to S/M/L, and the board was renamed "D2 Loot Alert Task Board".
