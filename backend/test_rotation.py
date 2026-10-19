"""Unit tests for the parts that are easy to get subtly wrong: reset math and alert deduplication.

Run from the repo root:  python -m unittest discover backend
Uses only the standard library and a hand-made snapshot, so no network or Firebase.
"""

import unittest
from datetime import datetime, timezone

import alerts
import rotation
from game_data import GameData


def utc(*args):
    return datetime(*args, tzinfo=timezone.utc)


def weapon(item_hash, name):
    return {"id": rotation.slug(name), "itemHash": item_hash, "name": name, "type": "Hand Cannon",
            "icon": f"https://example/{item_hash}.png"}


SNAPSHOT = {
    "resetId": "2026-10-17",
    "activities": [
        {"id": "gambit-gambit", "name": "Gambit", "category": "Gambit", "weapons": [weapon(1, "Spare Rations")]},
        {"id": "solo-ops-quickplay", "name": "Quickplay", "category": "Solo Ops", "weapons": [weapon(2, "Perfect Pitch")]},
        {"id": "vanguard-op-quickplay", "name": "Quickplay", "category": "Vanguard Op", "weapons": [weapon(2, "Perfect Pitch")]},
    ],
    "featured": [{"id": "last-wish", "name": "Last Wish", "kind": "raid"}],
}


class ResetIds(unittest.TestCase):
    def test_daily_reset_is_17_utc(self):
        self.assertEqual(rotation.reset_id(utc(2026, 10, 17, 16, 59)), "2026-10-16")
        self.assertEqual(rotation.reset_id(utc(2026, 10, 17, 17, 0)), "2026-10-17")

    def test_weekly_reset_is_tuesday_17_utc(self):
        self.assertEqual(rotation.week_id(utc(2026, 10, 17, 23, 0)), "2026-10-13")  # Saturday
        self.assertEqual(rotation.week_id(utc(2026, 10, 20, 16, 59)), "2026-10-13")  # Tuesday, just before reset
        self.assertEqual(rotation.week_id(utc(2026, 10, 20, 17, 0)), "2026-10-20")  # Tuesday reset


class Alerts(unittest.TestCase):
    def test_one_alert_per_weapon_listing_every_activity(self):
        by_topic = {a["topic"]: a for a in alerts.weapon_alerts(SNAPSHOT)}
        self.assertEqual(set(by_topic), {"weapon_spare-rations", "weapon_perfect-pitch"})
        self.assertEqual(by_topic["weapon_spare-rations"]["body"], "Bonus focus in Gambit")
        # Same name in two categories, so the category is added to tell them apart.
        self.assertEqual(by_topic["weapon_perfect-pitch"]["body"],
                         "Bonus focus in Quickplay (Solo Ops) and Quickplay (Vanguard Op)")

    def test_two_versions_of_a_weapon_make_one_alert_naming_both_activities(self):
        # The GM version (Warden of Nothing) and the regular one (Midtown) have different hashes (#26).
        snapshot = {"activities": [
            {"id": "fireteam-ops-warden-of-nothing", "name": "Warden of Nothing", "category": "Fireteam Ops",
             "weapons": [weapon(149110926, "Whatchamacallit")]},
            {"id": "pinnacle-ops-midtown", "name": "Midtown", "category": "Pinnacle Ops",
             "weapons": [weapon(357669417, "Whatchamacallit")]},
        ]}
        [alert] = alerts.weapon_alerts(snapshot)
        self.assertEqual(alert["topic"], "weapon_whatchamacallit")
        self.assertEqual(alert["body"], "Bonus focus in Warden of Nothing and Midtown")

    def test_alert_data_has_what_android_draws(self):
        snapshot = {"activities": [
            {"id": "solo-ops-quickplay", "name": "Quickplay", "category": "Solo Ops", "image": None,
             "weapons": [weapon(1, "Ecliptic Distaff")]},
            {"id": "solo-ops-quickplay-master", "name": "Quickplay: Master", "category": "Solo Ops",
             "image": "https://example/quickplay.jpg", "weapons": [weapon(1, "Ecliptic Distaff")]},
        ]}
        [alert] = alerts.weapon_alerts(snapshot)
        self.assertEqual(alerts.fcm_data(alert), {
            "kind": "weapon", "weaponId": "ecliptic-distaff",
            "activityIds": "solo-ops-quickplay,solo-ops-quickplay-master",
            "title": "Ecliptic Distaff is a bonus drop today",
            "body": "Bonus focus in Quickplay and Quickplay: Master",
            "icon": "https://example/1.png",
            "banner": "https://example/quickplay.jpg",  # the first activity has no banner, so the next one's
        })

    def test_without_an_activity_banner_the_weapon_screenshot_is_used(self):
        reckless = {**weapon(3085559077, "Reckless Endangerment"), "screenshot": "https://example/reckless.jpg"}
        snapshot = {"activities": [{"id": "solo-ops-typhon-imperator", "name": "Typhon Imperator",
                                    "category": "Solo Ops", "image": None, "weapons": [reckless]}]}
        [alert] = alerts.weapon_alerts(snapshot)
        self.assertEqual(alert["banner"], "https://example/reckless.jpg")

    def test_raid_alert_data_has_its_banner_and_no_empty_fields(self):
        snapshot = {"featured": [{"id": "last-wish", "name": "Last Wish", "kind": "raid",
                                  "image": "https://example/last-wish.jpg"}]}
        [alert] = alerts.raid_alerts(snapshot)
        self.assertEqual(alerts.fcm_data(alert), {
            "kind": "raid", "id": "last-wish", "title": "Last Wish is featured this week",
            "banner": "https://example/last-wish.jpg",  # no body or icon: left out, not "None"
        })

    def test_raid_alerts_are_title_only(self):
        [alert] = alerts.raid_alerts(SNAPSHOT)
        self.assertEqual((alert["topic"], alert["title"], alert["body"]),
                         ("raid_last-wish", "Last Wish is featured this week", None))

    def test_join_names(self):
        self.assertEqual(alerts.join_names(["A", "B", "C"]), "A, B and C")


def previews(*item_hashes):
    """A live activity whose preview rewards are these items."""
    return {"visibleRewards": [{"rewardItems": [{"itemQuantity": {"itemHash": h}} for h in item_hashes]}]}


class FakeItems:
    """Stands in for the Bungie API: item lookups, plus the public vendors response for Xûr."""
    def __init__(self, items, vendors=None):
        self.items = items
        self.vendors = vendors

    def item(self, item_hash):
        return self.items.get(item_hash, {})

    def request(self, path):
        return self.vendors


def exotic_armor(name, class_type, slot):
    """An exotic armor item definition, as Bungie returns it."""
    return {"itemType": rotation.ARMOR, "classType": class_type, "itemTypeDisplayName": slot,
            "inventory": {"tierType": rotation.EXOTIC},
            "displayProperties": {"name": name, "icon": f"/{name}.jpg"}, "screenshot": f"/{name}-shot.jpg"}


OMNIOCULUS = {"id": "omnioculus", "name": "Omnioculus", "class": "Hunter", "slot": "Chest Armor",
              "icon": "https://x/omni.jpg", "screenshot": "https://x/omni-shot.jpg"}


class Xur(unittest.TestCase):
    def test_stock_is_only_his_exotic_armor_in_class_order(self):
        items = {
            1: exotic_armor("Omnioculus", 1, "Chest Armor"),
            2: exotic_armor("Peacekeepers", 0, "Leg Armor"),
            3: {"itemType": 8, "inventory": {"tierType": rotation.EXOTIC},  # an engram: not armor
                "displayProperties": {"name": "Exotic Engram"}},
        }
        vendors = {"vendors": {"data": {str(rotation.XUR): {"enabled": True}}},
                   "sales": {"data": {str(rotation.XUR): {"saleItems": {
                       "1": {"itemHash": 1}, "2": {"itemHash": 2}, "3": {"itemHash": 3}}}}}}
        stock = rotation.xur_stock(FakeItems(items, vendors))
        self.assertEqual([(a["name"], a["class"], a["slot"]) for a in stock],
                         [("Peacekeepers", "Titan", "Leg Armor"), ("Omnioculus", "Hunter", "Chest Armor")])
        self.assertEqual(stock[1]["screenshot"], "https://www.bungie.net/Omnioculus-shot.jpg")

    def test_nothing_when_he_is_not_in_the_game(self):
        self.assertEqual(rotation.xur_stock(FakeItems({}, {"vendors": {"data": {}}, "sales": {"data": {}}})), [])

    def test_catalog_finds_collectibles_in_every_node_below_armor(self):
        nodes = {str(rotation.EXOTIC_ARMOR_NODE): {"children": {"presentationNodes": [{"presentationNodeHash": 10}]}},
                 "10": {"children": {"collectibles": [{"collectibleHash": 100}, {"collectibleHash": 101}]}}}
        self.assertEqual(rotation.collectibles_under(nodes, rotation.EXOTIC_ARMOR_NODE), [100, 101])

    def test_class_banners_use_the_chosen_exotic_else_the_first_chest_piece(self):
        def piece(name, cls, slot):
            return {"name": name, "class": cls, "slot": slot, "screenshot": f"https://x/{name}.jpg"}
        armor = [piece("Actium War Rig", "Titan", "Chest Armor"), piece("Heart of Inmost Light", "Titan", "Chest Armor"),
                 piece("Gwisin Vest", "Hunter", "Chest Armor")]  # The Sixth Coyote missing: fall back
        self.assertEqual(rotation.class_images(armor), {"Titan": "https://x/Heart of Inmost Light.jpg",
                                                        "Hunter": "https://x/Gwisin Vest.jpg"})

    def test_alert_names_the_class_and_slot(self):
        [alert] = alerts.xur_alerts({"xur": [OMNIOCULUS]})
        self.assertEqual((alert["topic"], alert["title"], alert["body"], alert["banner"]),
                         ("xur_omnioculus", "Xûr is selling Omnioculus", "Hunter chest armor", "https://x/omni-shot.jpg"))
        self.assertEqual(alerts.armor_description({"class": "Titan", "slot": "Titan Mark"}), "Titan Mark")

    def test_alerts_go_out_once_per_visit(self):
        snapshot = {"resetId": "2026-10-19", "activities": [], "featured": [], "xur": [OMNIOCULUS]}
        monday = utc(2026, 10, 19, 18, 7)  # his visit started Friday 2026-10-16, in the week of 2026-10-13

        def topics(state):
            to_send, _, _, _ = rotation.new_alerts(snapshot, state, monday)
            return {a["topic"] for a in to_send}
        self.assertEqual(topics({"sentWeekId": "2026-10-13", "sentXurTopics": ["xur_omnioculus"]}), set())
        self.assertEqual(topics({"sentWeekId": "2026-10-06", "sentXurTopics": ["xur_omnioculus"]}), {"xur_omnioculus"})


class WeaponIds(unittest.TestCase):
    def test_versions_share_an_id_and_are_listed_once(self):
        def adored(icon):
            return {"itemType": rotation.WEAPON, "itemTypeDisplayName": "Sniper Rifle",
                    "displayProperties": {"name": "Adored", "icon": icon}, "screenshot": "/adored.jpg"}
        api = FakeItems({891765152: adored("/gm.jpg"), 1405095983: adored("/regular.jpg")})
        gm, regular = rotation.weapon_info(api, 891765152), rotation.weapon_info(api, 1405095983)
        self.assertEqual((gm["id"], regular["id"]), ("adored", "adored"))

        group = {"weapons": []}
        rotation.add_weapon(group, gm)
        rotation.add_weapon(group, regular)
        self.assertEqual([w["itemHash"] for w in group["weapons"]], [891765152])  # the first version seen

    def test_ids_are_name_slugs(self):
        self.assertEqual(rotation.slug("D.F.A."), "d-f-a")
        self.assertEqual(rotation.slug("Salvager's Salvo"), "salvager-s-salvo")


class Farmable(unittest.TestCase):
    def test_rotator_raid_with_raid_gear_is_farmable(self):
        self.assertTrue(rotation.is_farmable(previews(3808930384, 2782701438)))  # Raid Gear, Deepsight Weapon

    def test_weekly_reward_alongside_real_loot_still_counts(self):
        self.assertTrue(rotation.is_farmable(previews(3808930384, rotation.WEEKLY_REWARD)))  # Vow: Master

    def test_newest_raid_with_only_weekly_reward_is_not(self):
        self.assertFalse(rotation.is_farmable(previews(rotation.WEEKLY_REWARD)))  # The Desert Perpetual

    def test_no_previews_is_not(self):
        self.assertFalse(rotation.is_farmable({}))


class RaidCatalog(unittest.TestCase):
    def test_farmable_raids_once_each_without_the_newest_or_pantheon(self):
        def raid(name, original):
            return {"displayProperties": {"name": name}, "originalDisplayProperties": {"name": original},
                    "activityTypeHash": rotation.RAID, "pgcrImage": "/img/x.jpg"}
        activities = {
            "1": raid("Vow of the Disciple: Standard", "Vow of the Disciple"),
            "2": raid("Vow of the Disciple: Master", "Vow of the Disciple"),
            "3": raid("The Desert Perpetual: Standard", "The Desert Perpetual"),
            "4": raid("Pantheon: Morgeth", "Pantheon: Morgeth"),
        }
        graph = {"9": {"displayProperties": {"name": "Pantheon"}, "selfAndAllDescendantHashes": [9],
                       "relatedActivitySetHashes": [8]}}
        data = GameData(activities, graph, {"8": {"activityHashes": [4]}})
        raid_gear = 3808930384
        profile = {"characterActivities": {"data": {"c1": {"availableActivities": [
            {"activityHash": 1, **previews(raid_gear)},
            {"activityHash": 2, **previews(raid_gear, rotation.WEEKLY_REWARD)},
            {"activityHash": 3, **previews(rotation.WEEKLY_REWARD)},  # newest raid: never farmable
            {"activityHash": 4, **previews(raid_gear)},  # Pantheon: another Portal category
        ]}}}}

        catalog = rotation.build_raid_catalog(data, profile)

        self.assertEqual([(r["id"], r["kind"]) for r in catalog], [("vow-of-the-disciple", "raid")])


class NewAlerts(unittest.TestCase):
    now = utc(2026, 10, 17, 21, 7)  # a backup run on the same reset and week

    def topics(self, state):
        to_send, _, _, _ = rotation.new_alerts(SNAPSHOT, state, self.now)
        return {a["topic"] for a in to_send}

    def test_first_run_sends_everything(self):
        self.assertEqual(self.topics({}), {"weapon_spare-rations", "weapon_perfect-pitch", "raid_last-wish"})

    def test_backup_run_only_sends_what_is_new(self):
        state = {"sentResetId": "2026-10-17", "sentWeaponTopics": ["weapon_spare-rations"],
                 "sentWeekId": "2026-10-13", "sentRaidTopics": ["raid_last-wish"]}
        self.assertEqual(self.topics(state), {"weapon_perfect-pitch"})

    def test_new_reset_and_week_send_again(self):
        state = {"sentResetId": "2026-10-16", "sentWeaponTopics": ["weapon_spare-rations", "weapon_perfect-pitch"],
                 "sentWeekId": "2026-10-06", "sentRaidTopics": ["raid_last-wish"]}
        self.assertEqual(self.topics(state), {"weapon_spare-rations", "weapon_perfect-pitch", "raid_last-wish"})


if __name__ == "__main__":
    unittest.main()
