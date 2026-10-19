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
    """Stands in for the Bungie API's item lookups."""
    def __init__(self, items):
        self.items = items

    def item(self, item_hash):
        return self.items[item_hash]


class WeaponIds(unittest.TestCase):
    def test_versions_share_an_id_and_are_listed_once(self):
        def adored(icon):
            return {"itemType": rotation.WEAPON, "itemTypeDisplayName": "Sniper Rifle",
                    "displayProperties": {"name": "Adored", "icon": icon}}
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
        to_send, _, _ = rotation.new_alerts(SNAPSHOT, state, self.now)
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
