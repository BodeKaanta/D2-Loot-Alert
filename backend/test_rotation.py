"""Unit tests for the parts that are easy to get subtly wrong: reset math and alert deduplication.

Run from the repo root:  python -m unittest discover backend
Uses only the standard library and a hand-made snapshot, so no network or Firebase.
"""

import unittest
from datetime import datetime, timezone

import alerts
import rotation


def utc(*args):
    return datetime(*args, tzinfo=timezone.utc)


def weapon(item_hash, name):
    return {"itemHash": item_hash, "name": name, "type": "Hand Cannon", "icon": f"https://example/{item_hash}.png"}


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
        self.assertEqual(set(by_topic), {"weapon_1", "weapon_2"})
        self.assertEqual(by_topic["weapon_1"]["body"], "Bonus focus in Gambit")
        # Same name in two categories, so the category is added to tell them apart.
        self.assertEqual(by_topic["weapon_2"]["body"], "Bonus focus in Quickplay (Solo Ops) and Quickplay (Vanguard Op)")

    def test_raid_alerts_are_title_only(self):
        [alert] = alerts.raid_alerts(SNAPSHOT)
        self.assertEqual((alert["topic"], alert["title"], alert["body"]),
                         ("raid_last-wish", "Last Wish is featured this week", None))

    def test_join_names(self):
        self.assertEqual(alerts.join_names(["A", "B", "C"]), "A, B and C")


class NewAlerts(unittest.TestCase):
    now = utc(2026, 10, 17, 21, 7)  # a backup run on the same reset and week

    def topics(self, state):
        to_send, _, _ = rotation.new_alerts(SNAPSHOT, state, self.now)
        return {a["topic"] for a in to_send}

    def test_first_run_sends_everything(self):
        self.assertEqual(self.topics({}), {"weapon_1", "weapon_2", "raid_last-wish"})

    def test_backup_run_only_sends_what_is_new(self):
        state = {"sentResetId": "2026-10-17", "sentWeaponTopics": ["weapon_1"],
                 "sentWeekId": "2026-10-13", "sentRaidTopics": ["raid_last-wish"]}
        self.assertEqual(self.topics(state), {"weapon_2"})

    def test_new_reset_and_week_send_again(self):
        state = {"sentResetId": "2026-10-16", "sentWeaponTopics": ["weapon_1", "weapon_2"],
                 "sentWeekId": "2026-10-06", "sentRaidTopics": ["raid_last-wish"]}
        self.assertEqual(self.topics(state), {"weapon_1", "weapon_2", "raid_last-wish"})


if __name__ == "__main__":
    unittest.main()
