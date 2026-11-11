# App Store listing (iOS, #10)

What gets pasted into App Store Connect, kept here so it's reviewed like code and the
next version starts from it. Limits are Apple's character counts.

## App Information

- **Name** (30): D2 Loot Alert
- **Subtitle** (30): Bonus drop and raid alerts
- **Category:** Reference (primary). No secondary.
- **Content rights:** "Yes, it contains, shows or accesses third-party content, and I have the
  necessary rights": the images and game data come from Bungie's official public API, used
  under its non-commercial terms.
- **Age rating:** 12+.
  - "Guns or Other Weapons" is **Frequent**, since the app shows weapon icons and names throughout. Apple's
    2025 questionnaire added that question.
  - Everything else is "None" / "No": no violence, web browser, user content, ads, gambling, contests or
    loot boxes.

## Version page

**Promotional text** (170, can be changed any time without a new build):

> Watch the weapons you're chasing and get a notification the day one is a bonus focus drop.
> Plus alerts for featured raids, dungeons and Xûr's exotic armor.

**Description** (4000):

> D2 Loot Alert tells you when the loot you want is easy to get.
>
> Pick the weapons you're after, and get a notification on the day one of them is an
> activity's bonus focus drop, with where to farm it. Pick raids and dungeons, and get a
> notification in the week they're featured. Pick exotic armor, and get a notification when
> Xûr is selling it.
>
> TODAY
> Every activity's bonus focus weapon, grouped like the game's Portal, plus this week's
> featured raids and dungeons and what Xûr is selling. Anything you watch that's available
> right now is pulled to the top, under READY TO FARM.
>
> LOOT
> Browse every weapon by activity category, and every exotic armor piece by class. Tap the
> bell on anything you want.
>
> RAIDS & DUNGEONS
> All raids and dungeons, with this week's featured ones first.
>
> NOTIFICATIONS
> Alerts arrive shortly after the daily reset, the weekly reset and Xûr's arrival. Each one
> says where to go.
>
> NO ACCOUNT NEEDED
> No sign-in, no ads, no tracking. Your watch list stays on your phone.
>
> D2 Loot Alert is an unofficial fan app, not affiliated with or endorsed by Bungie. Destiny is
> a trademark of Bungie, Inc. Game images and data come from the Bungie.net API.

**Keywords** (100, comma-separated, no spaces after commas). Apple's guideline 2.3.7 says not to
use other companies' trademarks here, so no "Destiny"; the name and description already say
what game it's for:

> bonus focus,loot,weapon,raid,dungeon,xur,exotic,armor,farm,drops,reset,rotation,guardian,alert

- **Support URL:** https://bodekaanta.github.io/D2-Loot-Alert/
- **Marketing URL:** (leave empty)
- **Privacy Policy URL** (App Privacy page): https://bodekaanta.github.io/D2-Loot-Alert/privacy/
- **Copyright:** 2026 Bode Kaanta (in General App Information, near the bottom of the version page)
- **Version:** 1.0.0

## App Privacy

- **Data collection:** Yes, one type:
  - **Identifiers → Device ID** (the push token and Firebase installation ID, used by FCM).
    - Used for: **App Functionality** only.
    - Linked to the user's identity: **No**.
    - Used for tracking: **No**.
- Everything else: not collected. This matches `docs/privacy.md`; update both together.

## App Review notes

> D2 Loot Alert is a free, unofficial companion app for the game Destiny 2. It has no
> accounts, no sign-in, no ads and no in-app purchases.
>
> How to try it: open the app and browse TODAY, LOOT and RAIDS & DUNGEONS. Tap the bell next to
> any weapon, raid, dungeon or exotic armor to watch it. The first tap asks for notification
> permission. Notifications are optional: everything can be browsed without them.
>
> Notifications are sent by our server shortly after the game's daily reset (17:00 UTC), and
> only for watched items that are available that day or week, so one can't be triggered on
> demand. The attached screen recording shows watching a weapon, then its notification
> arriving. Tapping a notification opens the app.
>
> Content: all game images and data come from Bungie's official public Bungie.net API
> (https://github.com/Bungie-net/api), used under its terms for non-commercial apps. The app
> is free, with no ads, purchases or donations. Bungie is credited on the About screen, and
> the app says it is not affiliated with Bungie.

- **Sign-in required:** No.
- **Attachment:** a screen recording of a real notification, made on the iPad (steps in CLAUDE.md > #10).
  The bonus focus changes at every reset, so a reviewer can't count on getting one.
  - **The notes may only claim what the video shows.** 1.0's recording didn't show tapping the
    notification, so the notes describe that as how the app works, not as part of the video.
  - **Upload it as an H.264 `.mp4` with a lowercase extension.** App Store Connect refused the iPad's own
    file, which was HEVC with an uppercase `.MP4` ("file type isn't supported"). Convert it with
    `avconvert --source <in> --preset PresetHighestQuality --output <out>.mp4`.
- **Contact:** Bode's name and phone, and `d2lootalert@gmail.com` (only Apple sees these).

## Screenshots

- **Required:** at least one for **iPhone with Dynamic Island (medium display)**, 1206 × 2622 (or
  1179 × 2556).
- **Optional:** the large display (Pro Max), 1320 × 2868. Apple scales screenshots for the other iPhones.
- **No alpha channel.** App Store Connect refuses PNGs with transparency, and the simulator's are RGBA.

For 1.0 (2026-11-11), the 1320 × 2868 captures from `app/tool/screenshots.sh` (iPhone 18 Pro Max
simulator) were redrawn without alpha at both sizes with a small CoreGraphics script. Making the
script do that itself is on the cleanup list (CLAUDE.md > Decision log, 2026-11-11 code review).

Upload in this order:

1. TODAY with READY TO FARM showing watched items
2. TODAY scrolled to the BONUS FOCUS categories
3. LOOT: WATCHING and the category cards
4. A category's weapon list with bells
5. RAIDS & DUNGEONS with the featured grid
