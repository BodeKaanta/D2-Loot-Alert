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
from bungie import Bungie, BungieError
from game_data import GameData, base_name

BONUS_FOCUS = "daily_grind_guaranteed"  # uiStyle of a bonus focus reward
WEAPON = 3                              # DestinyItemType.Weapon
RAID = 2043403989                       # DestinyActivityTypeDefinition hashes
DUNGEON = 608898761
WEEKLY_REWARD = 3649567221              # the "Weekly Reward" preview item: loot only once a week
RESET_HOUR_UTC = 17
BUNGIE_URL = "https://www.bungie.net"   # icons and images are paths relative to this

# Xûr (#13)
XUR = 2190858386                        # DestinyVendorDefinition hash
ARMOR = 2                               # DestinyItemType.Armor
EXOTIC = 6                              # TierType.Exotic
EXOTIC_ARMOR_NODE = 1789205056          # Collections > Exotic > Armor (Titan, Hunter, Warlock below it)
CLASS_NAMES = {0: "Titan", 1: "Hunter", 2: "Warlock"}  # DestinyClass, in the game's order
# Bungie has no class art we may use, so each class card on the Xûr screen shows
# one well-known exotic's screenshot (Bode's picks, 2026-10-19). Bump POOLS_SCHEMA
# after changing these, or the catalog keeps the old images until a game update.
# Where each picture sits in its card is set in the app (_classImageAlignment in xur_screen.dart).
CLASS_BANNER_ARMOR = {"Titan": "Heart of Inmost Light", "Hunter": "The Sixth Coyote", "Warlock": "Wings of Sacred Dawn"}

# The order the app lists categories in: the game's own Portal list, then Gambit.
# Anything else (e.g. an activity outside the Portal) comes after, alphabetically.
CATEGORY_ORDER = ["Solo Ops", "Fireteam Ops", "Arena Ops", "Pinnacle Ops", "Crucible Ops", "Gambit Ops"]

# Bump when the shape or IDs of lootPools documents (or the exotic armor catalog)
# change, to force a rebuild even if Bungie's game data hasn't changed.
# 2 = in-game Portal categories (#8), 3 = weapon ids (#26), 4 = exotic armor catalog (#13),
# 5 = catalog banners (#13), 6 and 7 = new Warlock card pictures (#13).
POOLS_SCHEMA = 7


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
        # A 16:9 render of the weapon. The expanded alert shows it when the
        # activity has no banner of its own (#30).
        "screenshot": image_url(item.get("screenshot")),
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


def armor_info(api, item_hash):
    """What the app and alerts need for an exotic armor piece, or None if the item isn't one."""
    item = api.item(item_hash)
    if item.get("itemType") != ARMOR or item.get("inventory", {}).get("tierType") != EXOTIC:
        return None
    name = item["displayProperties"]["name"]
    return {
        "id": slug(name) or str(item_hash),  # by name, like weapons (#26)
        "itemHash": item_hash,
        "name": name,
        "class": CLASS_NAMES.get(item.get("classType"), ""),
        "slot": item.get("itemTypeDisplayName", ""),  # e.g. "Chest Armor"
        "icon": image_url(item["displayProperties"].get("icon")),
        "screenshot": image_url(item.get("screenshot")),  # the expanded alert's picture
    }


def by_class(armor):
    """Sort key: the game's class order (Titan, Hunter, Warlock), then name."""
    order = list(CLASS_NAMES.values())
    return (order.index(armor["class"]) if armor["class"] in order else len(order), armor["name"])


def xur_stock(api):
    """The exotic armor Xûr is selling, or [] when he isn't in the game (Friday to Tuesday reset).

    The public vendors endpoint shows names only: no stats, and no exotic weapons
    (those are behind his "Strange Gear Offers", which needs a Bungie login). The
    rest of his stock (engrams, materials...) is filtered out by armor_info().
    """
    try:
        response = api.request("/Destiny2/Vendors/?components=400,402")
    except BungieError as err:
        print(f"Couldn't read Xûr's stock: {err}")  # weapon and raid alerts still go out
        return []
    vendor = response.get("vendors", {}).get("data", {}).get(str(XUR), {})
    if not vendor.get("enabled", True):
        return []
    sales = response.get("sales", {}).get("data", {}).get(str(XUR), {}).get("saleItems", {})
    stock = {}
    for sale in sales.values():
        armor = armor_info(api, sale.get("itemHash"))
        if armor:
            stock.setdefault(armor["id"], armor)
    return sorted(stock.values(), key=by_class)


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
        "xur": xur_stock(api),  # the exotic armor he's selling; [] when he's not in the game
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


def collectibles_under(nodes, node_hash):
    """Every collectible hash in a Collections node and the nodes below it."""
    children = nodes.get(str(node_hash), {}).get("children", {})
    found = [c["collectibleHash"] for c in children.get("collectibles", [])]
    for child in children.get("presentationNodes", []):
        found += collectibles_under(nodes, child["presentationNodeHash"])
    return found


def build_exotic_armor_catalog(api):
    """Every exotic armor piece, for the app's Xûr screen, where people pick what to watch.

    The list comes from the game's Collections (Exotic > Armor > Titan, Hunter,
    Warlock): 141 pieces on 2026-10-19. One item lookup each, so run() only
    rebuilds it along with the loot pools.

    Returns {"armor": [...], "xurImage": ..., "classImages": {class: ...}}, the
    catalog/exoticArmor document.
    """
    nodes = api.definition_table("DestinyPresentationNodeDefinition")
    collectibles = api.definition_table("DestinyCollectibleDefinition")
    catalog = {}
    for collectible_hash in collectibles_under(nodes, EXOTIC_ARMOR_NODE):
        item_hash = collectibles.get(str(collectible_hash), {}).get("itemHash")
        armor = armor_info(api, item_hash) if item_hash else None
        if armor:
            catalog.setdefault(armor["id"], armor)
    armor = sorted(catalog.values(), key=by_class)

    # The XÛR card on LOOT: the image of Xûr at his spot in the Tower.
    locations = api.definition("DestinyVendorDefinition", XUR).get("locations", [])
    xur_image = image_url(locations[0].get("backgroundImagePath")) if locations else None
    return {"armor": [{k: v for k, v in a.items() if k != "screenshot"} for a in armor],  # alerts look it up fresh
            "xurImage": xur_image,
            "classImages": class_images(armor)}


def class_images(armor):
    """Each class card's banner: CLASS_BANNER_ARMOR's screenshot, else the class's first chest piece."""
    images = {}
    for cls, name in CLASS_BANNER_ARMOR.items():
        mine = [a for a in armor if a["class"] == cls and a["screenshot"]]
        pick = (next((a for a in mine if a["name"] == name), None)
                or next((a for a in mine if a["slot"] == "Chest Armor"), None))
        if pick:
            images[cls] = pick["screenshot"]
    return images


def new_alerts(snapshot, state, now):
    """The alerts not already sent this reset (weapons) or this week (raids, dungeons and Xûr).

    Returns (alerts to send, weapon topics already sent, raid topics already sent,
    Xûr topics already sent).
    """
    this_week = state.get("sentWeekId") == week_id(now)
    sent_weapons = set(state.get("sentWeaponTopics", [])) if state.get("sentResetId") == snapshot["resetId"] else set()
    sent_raids = set(state.get("sentRaidTopics", [])) if this_week else set()
    # Xûr arrives Friday and leaves at the Tuesday reset, so one visit is one week.
    sent_xur = set(state.get("sentXurTopics", [])) if this_week else set()
    to_send = ([a for a in alerts.weapon_alerts(snapshot) if a["topic"] not in sent_weapons]
               + [a for a in alerts.raid_alerts(snapshot) if a["topic"] not in sent_raids]
               + [a for a in alerts.xur_alerts(snapshot) if a["topic"] not in sent_xur])
    return to_send, sent_weapons, sent_raids, sent_xur


def save_loot_pools(db, pools):
    """Write every pool, and delete pools left over from older IDs (e.g. old category names)."""
    batch = db.batch()
    for pool_id, pool in pools.items():
        batch.set(db.document(f"lootPools/{pool_id}"), pool)
    for old in db.collection("lootPools").list_documents():
        if old.id not in pools:
            batch.delete(old)
    batch.commit()


def save_exotic_armor_catalog(db, catalog):
    """One document for the whole list (141 small entries, far under Firestore's 1 MB limit).

    An empty list means the Collections node moved in a game update, so the old
    list is kept rather than wiped.
    """
    if not catalog["armor"]:
        print("Exotic armor catalog came back empty; keeping the old one (check EXOTIC_ARMOR_NODE)")
        return
    db.document("catalog/exoticArmor").set(catalog)


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
          f"{len(snapshot['featured'])} featured raids/dungeons, {len(snapshot['xur'])} Xûr exotic armor")

    db.document("rotation/current").set(snapshot)
    db.document(f"history/{snapshot['resetId']}").set(snapshot)

    # Loot pools and the exotic armor catalog only change when Bungie updates the
    # game data (manifest) or we change their format, and rebuilding them takes a
    # few hundred item lookups, so skip it otherwise.
    state_ref = db.document("meta/state")
    state = state_ref.get().to_dict() or {}
    manifest_version = api.manifest_version()
    if state.get("manifestVersion") != manifest_version or state.get("poolsSchema") != POOLS_SCHEMA:
        pools = build_loot_pools(api, data, profile)
        save_loot_pools(db, pools)
        catalog = build_exotic_armor_catalog(api)
        save_exotic_armor_catalog(db, catalog)
        print(f"Rebuilt {len(pools)} loot pools and {len(catalog['armor'])} exotic armor for manifest {manifest_version}")

    to_send, sent_weapons, sent_raids, sent_xur = new_alerts(snapshot, state, now)
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
        "sentXurTopics": sorted(sent_xur | {t for t in accepted if t.startswith("xur_")}),
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
    print("Xûr is selling: " + (", ".join(f"{a['name']} ({a['class']} {a['slot']})" for a in snapshot["xur"])
                                or "nothing (not in the game)"))

    to_send, _, _, _ = new_alerts(snapshot, {}, now)  # empty state: as if nothing was sent yet
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
        catalog = build_exotic_armor_catalog(api)
        print(f"{len(catalog['armor'])} exotic armor in the catalog; banners: {catalog['classImages']}, Xûr: {catalog['xurImage']}")
        (out / "exotic_armor.json").write_text(json.dumps(catalog, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Saved to {out}")


if __name__ == "__main__":
    if "--dry-run" not in sys.argv:
        sys.exit("Usage: python backend/rotation.py --dry-run [--skip-pools]")
    dry_run()
