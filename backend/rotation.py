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

BONUS_FOCUS = "daily_grind_guaranteed"  # uiStyle of a bonus focus reward
WEAPON = 3                              # DestinyItemType.Weapon
RAID = 2043403989                       # DestinyActivityTypeDefinition hashes
DUNGEON = 608898761
RESET_HOUR_UTC = 17
BUNGIE_URL = "https://www.bungie.net"   # icons and images are paths relative to this


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


def base_name(definition):
    """'Gambit: Matchmade' and 'Gambit: Customize' share the base name 'Gambit'."""
    return (definition.get("originalDisplayProperties", {}).get("name")
            or definition.get("displayProperties", {}).get("name")
            or "Unknown")


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


def category_name(api, type_hash):
    """'Gambit', 'The Crucible', 'Solo Ops'... from the activity's type."""
    name = api.activity_type(type_hash).get("displayProperties", {}).get("name") if type_hash else None
    return name or "Other"


def weapon_info(api, item_hash):
    """What the app needs to show a weapon, or None if the item isn't a weapon."""
    item = api.item(item_hash)
    if item.get("itemType") != WEAPON:
        return None
    return {
        "itemHash": item_hash,
        "name": item["displayProperties"]["name"],
        "type": item.get("itemTypeDisplayName", ""),
        "icon": image_url(item["displayProperties"].get("icon")),
    }


def activity_group(groups, api, definition, activity_hash):
    """Find or create the group this activity variant belongs to.

    Variants like "Customize"/"Matchmade" share a base name and category, so the
    app sees them as one activity.
    """
    category = category_name(api, definition.get("activityTypeHash"))
    name = base_name(definition)
    group = groups.setdefault(slug(f"{category} {name}"), {
        "id": slug(f"{category} {name}"),
        "name": name,
        "category": category,
        "image": image_url(definition.get("pgcrImage")),
        "activityHashes": [],
        "weapons": [],
    })
    if activity_hash not in group["activityHashes"]:
        group["activityHashes"].append(activity_hash)
    return group


def add_weapon(group, weapon):
    if weapon and all(w["itemHash"] != weapon["itemHash"] for w in group["weapons"]):
        group["weapons"].append(weapon)


def build_snapshot(api, profile, now):
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
            definition = api.activity(activity_hash)

            # A raid or dungeon with a weekly challenge is featured this week.
            type_hash = definition.get("activityTypeHash")
            if has_challenge and type_hash in (RAID, DUNGEON):
                name = base_name(definition)
                entry = featured.setdefault(slug(name), {
                    "id": slug(name),
                    "name": name,
                    "kind": "raid" if type_hash == RAID else "dungeon",
                    "image": image_url(definition.get("pgcrImage")),
                    "activityHashes": [],
                })
                if activity_hash not in entry["activityHashes"]:
                    entry["activityHashes"].append(activity_hash)

            # Armor focus differs per class and is out of scope, so keep weapons only.
            weapons = [w for w in (weapon_info(api, h) for h in focus_hashes) if w]
            if weapons:
                group = activity_group(activities, api, definition, activity_hash)
                for weapon in weapons:
                    add_weapon(group, weapon)

    return {
        "resetId": reset_id(now),
        "updatedAt": now.isoformat(),
        "activities": sorted(activities.values(), key=lambda a: (a["category"], a["name"])),
        "featured": sorted(featured.values(), key=lambda f: (f["kind"], f["name"])),
    }


def build_loot_pools(api, profile):
    """Every activity's weapon pool, from the reward lists in Bungie's game data.

    Slow (a few hundred lookups), so run() only calls it when the game data changes.
    """
    pools = {}
    for activity_hash in unique_activity_hashes(profile):
        definition = api.activity(activity_hash)
        weapons = []
        for reward_group in definition.get("rewards", []):
            for reward in reward_group.get("rewardItems", []):
                weapons.append(weapon_info(api, reward["itemHash"]))
        weapons = [w for w in weapons if w]
        if not weapons:
            continue
        pool = activity_group(pools, api, definition, activity_hash)
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


def run(api_key, bungie_name, db):
    """One scheduled run: fetch today's rotation, save it to Firestore and send new alerts.

    Every run for the same reset overwrites the same documents and skips alerts
    that were already sent, so the backup runs are always safe.
    """
    now = datetime.now(timezone.utc)
    api = Bungie(api_key)
    profile = api.character_activities(bungie_name)
    snapshot = build_snapshot(api, profile, now)
    print(f"Reset {snapshot['resetId']}: {len(snapshot['activities'])} activities with a weapon focus, "
          f"{len(snapshot['featured'])} featured raids/dungeons")

    db.document("rotation/current").set(snapshot)
    db.document(f"history/{snapshot['resetId']}").set(snapshot)

    # Loot pools only change when Bungie updates the game data (manifest),
    # and rebuilding them takes a few hundred lookups, so skip it otherwise.
    state_ref = db.document("meta/state")
    state = state_ref.get().to_dict() or {}
    manifest_version = api.manifest_version()
    if state.get("manifestVersion") != manifest_version:
        pools = build_loot_pools(api, profile)
        batch = db.batch()
        for pool_id, pool in pools.items():
            batch.set(db.document(f"lootPools/{pool_id}"), pool)
        batch.commit()
        print(f"Rebuilt {len(pools)} loot pools for manifest {manifest_version}")

    to_send, sent_weapons, sent_raids = new_alerts(snapshot, state, now)
    accepted = alerts.send(to_send)
    print(f"Sent {len(accepted)} of {len(to_send)} new alerts")

    state_ref.set({
        "manifestVersion": manifest_version,
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
    snapshot = build_snapshot(api, profile, now)
    print(f"Reset {snapshot['resetId']}")
    for a in snapshot["activities"]:
        print(f"  {a['category']:14} {a['name']:28} {', '.join(w['name'] for w in a['weapons'])}")
    print("Featured: " + ", ".join(f"{f['name']} ({f['kind']})" for f in snapshot["featured"]))

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
        pools = build_loot_pools(api, profile)
        print(f"{len(pools)} loot pools")
        (out / "loot_pools.json").write_text(json.dumps(pools, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Saved to {out}")


if __name__ == "__main__":
    if "--dry-run" not in sys.argv:
        sys.exit("Usage: python backend/rotation.py --dry-run [--skip-pools]")
    dry_run()
