"""Whole-table lookups from Bungie's game data (issue #8):

- which in-game Portal category an activity sits under ("Solo Ops", "Gambit Ops"...)
- a real banner when an activity's own is Bungie's placeholder image

Three definition tables (~12 MB together) are downloaded once per run. That's
faster than looking up hundreds of activities one at a time, and the banner
search needs every activity anyway.
"""

from collections import Counter, defaultdict

PLACEHOLDER = "/img/theme/destiny/bgs/pgcrs/placeholder.jpg"

# Words Bungie puts after a colon for versions of one activity, e.g.
# "Quickplay: Master". Stripped one at a time when looking for real art, so
# "Quickplay: Master" can borrow "Quickplay"'s banner. Only these words are
# stripped, so "Battleground: Behemoth" never borrows another Battleground's art.
VARIANT_WORDS = {"Matchmade", "Customize", "Normal", "Master", "Standard",
                 "Legend", "Expert", "Grandmaster", "Hero", "Adept"}


def base_name(definition):
    """'Gambit: Matchmade' and 'Gambit: Customize' share the base name 'Gambit'."""
    return (definition.get("originalDisplayProperties", {}).get("name")
            or definition.get("displayProperties", {}).get("name")
            or "Unknown")


class GameData:
    def __init__(self, activities, finder_graph, finder_sets):
        self.activities = activities  # hash (as a string) -> DestinyActivityDefinition
        self._category_of = _portal_categories(finder_graph, finder_sets)
        self._banner_by_name = _real_banners_by_name(activities)

    @classmethod
    def download(cls, api):
        return cls(
            api.definition_table("DestinyActivityDefinition"),
            # The game builds its Portal screens from the Fireteam Finder tree.
            api.definition_table("DestinyFireteamFinderActivityGraphDefinition"),
            api.definition_table("DestinyFireteamFinderActivitySetDefinition"),
        )

    def activity(self, activity_hash):
        return self.activities.get(str(activity_hash), {})

    def portal_category(self, activity_hash):
        """'Solo Ops', 'Gambit Ops'... as the game shows it, or None if it isn't in the Portal."""
        return self._category_of.get(activity_hash)

    def banner(self, activity_hash):
        """The activity's banner path, with Bungie's placeholder swapped for real art when any exists."""
        definition = self.activity(activity_hash)
        own = definition.get("pgcrImage")
        if own and own != PLACEHOLDER:
            return own

        # Another version of the same activity: "Quickplay: Master" -> "Quickplay".
        name = base_name(definition)
        while True:
            if name in self._banner_by_name:
                return self._banner_by_name[name]
            shorter, colon, last_word = name.rpartition(": ")
            if not colon or last_word not in VARIANT_WORDS:
                break
            name = shorter

        # A playlist (like Gambit) borrows the art of the first map it lists.
        for item in definition.get("playlistItems", []):
            image = self.activity(item["activityHash"]).get("pgcrImage")
            if image and image != PLACEHOLDER:
                return image
        return None


def _portal_categories(graph, sets):
    """activityHash -> the name of the top-level Portal category it sits under."""
    category_of = {}
    for node in graph.values():
        name = node.get("displayProperties", {}).get("name")
        if node.get("parentHash") or not name:
            continue  # only named top-level nodes are categories
        for node_hash in node.get("selfAndAllDescendantHashes", []):
            for set_hash in graph.get(str(node_hash), {}).get("relatedActivitySetHashes", []):
                for activity_hash in sets.get(str(set_hash), {}).get("activityHashes", []):
                    category_of.setdefault(activity_hash, name)
    return category_of


def _real_banners_by_name(activities):
    """The most common real banner for each activity name, across every version Bungie defines."""
    counts = defaultdict(Counter)
    for definition in activities.values():
        image = definition.get("pgcrImage")
        if not image or image == PLACEHOLDER:
            continue
        names = {definition.get("displayProperties", {}).get("name"),
                 definition.get("originalDisplayProperties", {}).get("name")}
        for name in names - {None, ""}:
            counts[name][image] += 1
    # Ties go to the alphabetically first path, so the pick doesn't change between runs.
    return {name: min(c, key=lambda image: (-c[image], image)) for name, c in counts.items()}
