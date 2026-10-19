"""Daily rotation (issue #6): today's bonus focus weapons and this week's featured
raids and dungeons, saved to Firestore for the app, plus push alerts (#7).

main.py runs this on a schedule. To test locally without touching Firestore or
sending anything (saves the results to backend/output/, which is gitignored):

    python backend/rotation.py --dry-run [--skip-pools]

with BUNGIE_API_KEY and BUNGIE_NAME set as environment variables.

How the data is identified is documented in CLAUDE.md > "Phase 0 findings".
"""

import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import alerts
from bungie import Bungie
from game_data import GameData, base_name

BONUS_FOCUS = "daily_grind_guaranteed"  # uiStyle of a bonus focus reward
WEAPON = 3                              # DestinyItemType.Weapon
RAID = 2043403989                       # DestinyActivityTypeDefinition hashes
DUNGEON = 608898761
WEEKLY_REWARD = 3649567221              # the "Weekly Reward" preview item: loot only once a week
RESET_HOUR_UTC = 17
BUNGIE_URL = "https://www.bungie.net"   # icons and images are paths relative to this

# The order the app lists categories in: the game's own Portal list, then Gambit.
# Anything else (e.g. an activity outside the Portal) comes after, alphabetically.
CATEGORY_ORDER = ["Solo Ops", "Fireteam Ops", "Arena Ops", "Pinnacle Ops", "Crucible Ops", "Gambit Ops"]

# Bump when the shape or IDs of lootPools documents change, to force a rebuild
# even if Bungie's game data hasn't changed. 2 = in-game Portal categories (#8),
# 3 = weapon ids (#26).
POOLS_SCHEMA = 3


def reset_id(now):
    """The date of the most recent daily reset (17:00 UTC), e.g. '2026-10-17'.

    Anything before 17:00 UTC still belongs to the previous day's reset.
    """
    return (now - timedelta(hours=RESET_HOUR_UTC)).date().isoformat()


def week_id(now):
    """The date of the most recent weekly reset (Tuesday 17:00 UTC), e.g. '2026-10-13'."""
    reset_day = (now - timedelta(hours=RESET_HOUR_UTC)).date()
    days_since_tuesday = (reset_day.weekday() - 1) % 7  # weekday(): Monday = 0, Tuesday = 1
    return (reset_day - timedelta(days=days_since_tuesday)).isoformat()


def slug(text):
    """A Firestore-safe document ID, e.g. 'Solo Ops The Salt Mines' -> 'solo-ops-the-salt-mines'."""
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def image_url(path):
    return BUNGIE_URL + path if path else None


def unique_activity_hashes(profile):
    """Every activity available on any character. Weapon focus is the same on each."""
    hashes = []
    for character in profile["characterActivities"]["data"].values():
        for activity in character.get("availableActivities", []):
            if activity["activityHash"] not in hashes:
                hashes.append(activity["activityHash"])
    return hashes


def category_name(api, data, activity_hash, definition):
    """The in-game Portal category ('Solo Ops', 'Gambit Ops'...).

    Outside the Portal, falls back to Bungie's activity type name.
    """
    portal = data.portal_category(activity_hash)
    if portal:
        return portal
    type_hash = definition.get("activityTypeHash")
    name = api.activity_type(type_hash).get("displayProperties", {}).get("name") if type_hash else None
    return name or "Other"


def category_rank(category):
    return CATEGORY_ORDER.index(category) if category in CATEGORY_ORDER else len(CATEGORY_ORDER)


def weapon_info(api, item_hash):
    """What the app needs to show a weapon, or None if the item isn't a weapon.

    The id comes from the name, not the hash: one weapon can have several item
    hashes (e.g. Warden of Nothing's GM versions, #26), and any of them can be
    the bonus focus. Watches and alert topics use the id, so they cover all of them.
    """
    item = api.item(item_hash)
    if item.get("itemType") != WEAPON:
        return None
    name = item["displayProperties"]["name"]
    return {
        "id": slug(name) or str(item_hash),  # the hash only if the name has no letters or digits to slug
        "itemHash": item_hash,
        "name": name,
        "type": item.get("itemTypeDisplayName", ""),
        "icon": image_url(item["displayProperties"].get("icon")),
    }


def activity_group(groups, api, data, definition, activity_hash):
    """Find or create the group this activity variant belongs to.

    Variants like "Customize"/"Matchmade" share a base name and category, so the
    app sees them as one activity.
    """
    category = category_name(api, data, activity_hash, definition)
    name = base_name(definition)
    group = groups.setdefault(slug(f"{category} {name}"), {
        "id": slug(f"{category} {name}"),
        "name": name,
        "category": category,
        "image": image_url(data.banner(activity_hash)),
        "activityHashes": [],
        "weapons": [],
    })
    if activity_hash not in group["activityHashes"]:
        group["activityHashes"].append(activity_hash)
    return group


def is_farmable(activity):
    """True if the activity previews real loot, not only the once-a-week "Weekly Reward" item.

    Rotator-featured raids show "Raid Gear" and dungeons show "Powerful Gear". The
    newest raid and dungeon also have a weekly challenge every week, but preview
    only "Weekly Reward", so this keeps them off the featured list.
    """
    for mapping in activity.get("visibleRewards", []):
        for reward in mapping.get("rewardItems", []):
            if reward.get("itemQuantity", {}).get("itemHash") not in (None, WEEKLY_REWARD):
                return True
    return False


def add_weapon(group, weapon):
    """Adds the weapon unless the group already has it, in any version (same id)."""
    if weapon and all(w["id"] != weapon["id"] for w in group["weapons"]):
        group["weapons"].append(weapon)


def build_snapshot(api, data, profile, now):
    """Today's bonus focus weapons per activity, plus this week's featured raids and dungeons."""
    activities = {}
    featured = {}
    for character in profile["characterActivities"]["data"].values():
        for activity in character.get("availableActivities", []):
            focus_hashes = []
            for mapping in activity.get("visibleRewards", []):
                for reward in mapping.get("rewardItems", []):
                    item_hash = reward.get("itemQuantity", {}).get("itemHash")
                    if reward.get("uiStyle") == BONUS_FOCUS and item_hash:
                        focus_hashes.append(item_hash)
            has_challenge = bool(activity.get("challenges"))
            if not focus_hashes and not has_challenge:
                continue  # most activities; skipping them saves a lot of lookups

            activity_hash = activity["activityHash"]
            definition = data.activity(activity_hash)

            # A raid or dungeon with a weekly challenge and farmable loot is in this
            # week's rotation (the newest raid/dungeon have a challenge but no farmable loot).
            type_hash = definition.get("activityTypeHash")
            if has_challenge and type_hash in (RAID, DUNGEON) and is_farmable(activity):
                name = base_name(definition)
                entry = featured.setdefault(slug(name), {
                    "id": slug(name),
                    "name": name,
                    "kind": "raid" if type_hash == RAID else "dungeon",
                    "image": image_url(data.banner(activity_hash)),
                    "activityHashes": [],
                })
                if activity_hash not in entry["activityHashes"]:
                    entry["activityHashes"].append(activity_hash)

            # Armor focus differs per class and is out of scope, so keep weapons only.
            weapons = [w for w in (weapon_info(api, h) for h in focus_hashes) if w]
            if weapons:
                group = activity_group(activities, api, data, definition, activity_hash)
                for weapon in weapons:
                    add_weapon(group, weapon)

    return {
        "resetId": reset_id(now),
        "updatedAt": now.isoformat(),
        "activities": sorted(activities.values(),
                             key=lambda a: (category_rank(a["category"]), a["category"], a["name"])),
        "featured": sorted(featured.values(), key=lambda f: (f["kind"], f["name"])),
        "raidsAndDungeons": build_raid_catalog(data, profile),  # everything the app can watch
    }


def build_raid_catalog(data, profile):
    """Every raid and dungeon that can rotate into the featured list, for the app's watch toggles.

    Grouped by base name like the featured list, so the IDs (and alert topics)
    match. Left out:
    - raid-typed extras the game files under other Portal categories (Pantheon)
    - anything that only previews the once-a-week reward (the newest raid and
      dungeon), since those are never farmable "featured" picks
    """
    catalog = {}
    for character in profile["characterActivities"]["data"].values():
        for activity in character.get("availableActivities", []):
            activity_hash = activity["activityHash"]
            definition = data.activity(activity_hash)
            type_hash = definition.get("activityTypeHash")
            if type_hash not in (RAID, DUNGEON) or not is_farmable(activity):
                continue
            if data.portal_category(activity_hash) not in (None, "Raids", "Dungeons"):
                continue
            name = base_name(definition)
            catalog.setdefault(slug(name), {
                "id": slug(name),
                "name": name,
                "kind": "raid" if type_hash == RAID else "dungeon",
                "image": image_url(data.banner(activity_hash)),
            })
    return sorted(catalog.values(), key=lambda r: (r["kind"], r["name"]))


def build_loot_pools(api, data, profile):
    """Every activity's weapon pool, from the reward lists in Bungie's game data.

    Slow (a few hundred item lookups), so run() only calls it when the game data changes.
    """
    pools = {}
    for activity_hash in unique_activity_hashes(profile):
        definition = data.activity(activity_hash)
        weapons = []
        for reward_group in definition.get("rewards", []):
            for reward in reward_group.get("rewardItems", []):
                weapons.append(weapon_info(api, reward["itemHash"]))
        weapons = [w for w in weapons if w]
        if not weapons:
            continue
        pool = activity_group(pools, api, data, definition, activity_hash)
        for weapon in weapons:
            add_weapon(pool, weapon)
    for pool in pools.values():
        pool["weapons"].sort(key=lambda w: w["name"])
    return pools


def new_alerts(snapshot, state, now):
    """The alerts not already sent this reset (weapons) or this week (raids and dungeons).

    Returns (alerts to send, weapon topics already sent, raid topics already sent).
    """
    sent_weapons = set(state.get("sentWeaponTopics", [])) if state.get("sentResetId") == snapshot["resetId"] else set()
    sent_raids = set(state.get("sentRaidTopics", [])) if state.get("sentWeekId") == week_id(now) else set()
    to_send = ([a for a in alerts.weapon_alerts(snapshot) if a["topic"] not in sent_weapons]
               + [a for a in alerts.raid_alerts(snapshot) if a["topic"] not in sent_raids])
    return to_send, sent_weapons, sent_raids


def save_loot_pools(db, pools):
    """Write every pool, and delete pools left over from older IDs (e.g. old category names)."""
    batch = db.batch()
    for pool_id, pool in pools.items():
        batch.set(db.document(f"lootPools/{pool_id}"), pool)
    for old in db.collection("lootPools").list_documents():
        if old.id not in pools:
            batch.delete(old)
    batch.commit()


def run(api_key, bungie_name, db):
    """One scheduled run: fetch today's rotation, save it to Firestore and send new alerts.

    Every run for the same reset overwrites the same documents and skips alerts
    that were already sent, so the backup runs are always safe.
    """
    now = datetime.now(timezone.utc)
    api = Bungie(api_key)
    profile = api.character_activities(bungie_name)
    data = GameData.download(api)
    snapshot = build_snapshot(api, data, profile, now)
    print(f"Reset {snapshot['resetId']}: {len(snapshot['activities'])} activities with a weapon focus, "
          f"{len(snapshot['featured'])} featured raids/dungeons")

    db.document("rotation/current").set(snapshot)
    db.document(f"history/{snapshot['resetId']}").set(snapshot)

    # Loot pools only change when Bungie updates the game data (manifest) or we
    # change their format, and rebuilding them takes a few hundred item lookups,
    # so skip it otherwise.
    state_ref = db.document("meta/state")
    state = state_ref.get().to_dict() or {}
    manifest_version = api.manifest_version()
    if state.get("manifestVersion") != manifest_version or state.get("poolsSchema") != POOLS_SCHEMA:
        pools = build_loot_pools(api, data, profile)
        save_loot_pools(db, pools)
        print(f"Rebuilt {len(pools)} loot pools for manifest {manifest_version}")

    to_send, sent_weapons, sent_raids = new_alerts(snapshot, state, now)
    accepted = alerts.send(to_send)
    print(f"Sent {len(accepted)} of {len(to_send)} new alerts")

    state_ref.set({
        "manifestVersion": manifest_version,
        "poolsSchema": POOLS_SCHEMA,
        "lastResetId": snapshot["resetId"],
        "lastRunAt": now.isoformat(),
        # What has been alerted, so backup runs only send what's new.
        "sentResetId": snapshot["resetId"],
        "sentWeaponTopics": sorted(sent_weapons | {t for t in accepted if t.startswith("weapon_")}),
        "sentWeekId": week_id(now),
        "sentRaidTopics": sorted(sent_raids | {t for t in accepted if t.startswith("raid_")}),
    }, merge=True)


def dry_run():
    """Local test: build the same data as run() and save it to backend/output/."""
    sys.stdout.reconfigure(encoding="utf-8")  # names can include characters Windows can't print by default
    now = datetime.now(timezone.utc)
    api = Bungie(os.environ["BUNGIE_API_KEY"])
    profile = api.character_activities(os.environ["BUNGIE_NAME"])
    data = GameData.download(api)
    snapshot = build_snapshot(api, data, profile, now)
    print(f"Reset {snapshot['resetId']}")
    for a in snapshot["activities"]:
        image = (a["image"] or "(no banner)").rsplit("/", 1)[-1]
        print(f"  {a['category']:13} {a['name']:24} {', '.join(w['name'] for w in a['weapons']):26} {image}")
    print("Featured: " + ", ".join(f"{f['name']} ({f['kind']})" for f in snapshot["featured"]))
    print("Watchable raids/dungeons: " + ", ".join(r["name"] for r in snapshot["raidsAndDungeons"]))

    to_send, _, _ = new_alerts(snapshot, {}, now)  # empty state: as if nothing was sent yet
    print(f"Alerts that would be sent ({len(to_send)}):")
    for alert in to_send:
        print(f"  [{alert['topic']}] {alert['title']}" + (f" / {alert['body']}" if alert["body"] else ""))

    out = Path(__file__).parent / "output"
    out.mkdir(exist_ok=True)
    (out / "snapshot.json").write_text(json.dumps(snapshot, indent=2, ensure_ascii=False), encoding="utf-8")
    (out / "alerts.json").write_text(json.dumps(to_send, indent=2, ensure_ascii=False), encoding="utf-8")

    if "--skip-pools" not in sys.argv:
        print("Building loot pools (takes a few minutes)...")
        pools = build_loot_pools(api, data, profile)
        print(f"{len(pools)} loot pools")
        (out / "loot_pools.json").write_text(json.dumps(pools, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Saved to {out}")


if __name__ == "__main__":
    if "--dry-run" not in sys.argv:
        sys.exit("Usage: python backend/rotation.py --dry-run [--skip-pools]")
    dry_run()
