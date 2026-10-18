"""Unit tests for Portal categories and banner fallbacks, using tiny hand-made tables.

Run from the repo root:  python -m unittest discover backend
"""

import unittest

from game_data import PLACEHOLDER, GameData


def activity(name, image, original=None, playlist=()):
    return {
        "displayProperties": {"name": name},
        "originalDisplayProperties": {"name": original or name},
        "pgcrImage": image,
        "playlistItems": [{"activityHash": h} for h in playlist],
    }


ACTIVITIES = {
    "1": activity("Quickplay: Master", PLACEHOLDER),
    "2": activity("Quickplay", "/img/solo_ops_playlist1.jpg"),
    "3": activity("Gambit: Matchmade", PLACEHOLDER, original="Gambit", playlist=[4]),
    "4": activity("Emerald Coast", "/img/gambit_badlands.jpg"),
    "5": activity("Battleground: Behemoth", PLACEHOLDER),
    "6": activity("Battleground: Oracle", "/img/oracle.jpg"),
}

# Top-level "Solo Ops" (100) -> child node (101) -> activity set (200) -> activities 1 and 2.
GRAPH = {
    "100": {"displayProperties": {"name": "Solo Ops"}, "selfAndAllDescendantHashes": [100, 101]},
    "101": {"displayProperties": {"name": "Solo Ops"}, "parentHash": 100, "relatedActivitySetHashes": [200]},
}
SETS = {"200": {"activityHashes": [1, 2]}}


class Banners(unittest.TestCase):
    data = GameData(ACTIVITIES, GRAPH, SETS)

    def test_keeps_its_own_real_banner(self):
        self.assertEqual(self.data.banner(6), "/img/oracle.jpg")

    def test_placeholder_borrows_from_another_version(self):
        self.assertEqual(self.data.banner(1), "/img/solo_ops_playlist1.jpg")  # "Quickplay: Master" -> "Quickplay"

    def test_playlist_borrows_its_first_map(self):
        self.assertEqual(self.data.banner(3), "/img/gambit_badlands.jpg")

    def test_never_borrows_from_a_different_activity(self):
        # "Behemoth" isn't a variant word, so it must not take Battleground: Oracle's art.
        self.assertIsNone(self.data.banner(5))


class PortalCategories(unittest.TestCase):
    data = GameData(ACTIVITIES, GRAPH, SETS)

    def test_activity_under_a_category(self):
        self.assertEqual(self.data.portal_category(1), "Solo Ops")

    def test_activity_outside_the_portal(self):
        self.assertIsNone(self.data.portal_category(3))


if __name__ == "__main__":
    unittest.main()
