"""Phase 0: Bungie API test script (issue #4).

Pulls live data from the Bungie API to answer the Phase 0 questions in
CLAUDE.md before anything else gets built:
  - How does an activity's bonus focus show up in its visibleRewards?
  - Is it the same on every character?
  - How can this week's featured raids and dungeons be detected?

Setup (one time):
  Copy phase0/.env.example to phase0/.env and fill in your API key and
  Bungie name. .env is gitignored, so the key never reaches GitHub.

Run from the repo root:
  python phase0/api_test.py

Only the Python standard library is used, so there's nothing to install.
Everything is saved to phase0/output/ (also gitignored):
  report.txt               the readable report that gets printed
  profile.json             raw characters + activities response
  milestones.json          raw public milestones response
  definitions_cache.json   names looked up so far, so reruns are fast
"""

import json
import sys
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

BASE_URL = "https://www.bungie.net/Platform"
HERE = Path(__file__).parent
OUTPUT_DIR = HERE / "output"
CACHE_FILE = OUTPUT_DIR / "definitions_cache.json"

CLASS_NAMES = {0: "Titan", 1: "Hunter", 2: "Warlock"}
MODE_NAMES = {4: "RAID", 82: "DUNGEON"}  # DestinyActivityModeType values from the API spec
PRIVATE = 2  # ComponentPrivacySetting.Private


class Bungie:
    """Minimal Bungie API client: sends the API key and unwraps responses."""

    def __init__(self, api_key):
        self.api_key = api_key
        self.cache = json.loads(CACHE_FILE.read_text(encoding="utf-8")) if CACHE_FILE.exists() else {}

    def request(self, path, body=None):
        # Passing a body makes urllib send a POST instead of a GET.
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(
            BASE_URL + path,
            data=data,
            headers={"X-API-Key": self.api_key, "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                payload = json.load(resp)
        except urllib.error.HTTPError as err:
            try:
                payload = json.load(err)  # Bungie usually explains failures in a JSON body
            except ValueError:
                raise RuntimeError(f"{path} failed: HTTP {err.code}") from None

        # Every response is wrapped: {"Response": ..., "ErrorCode": 1, "ErrorStatus": "Success", ...}
        if payload.get("ErrorCode") != 1:
            raise RuntimeError(f"{path} failed: {payload.get('ErrorStatus')}: {payload.get('Message')}")
        return payload["Response"]

    def definition(self, entity_type, hash_id):
        """Look up one manifest definition (name, icon, type...), cached between runs."""
        key = f"{entity_type}/{hash_id}"
        if key not in self.cache:
            try:
                self.cache[key] = self.request(f"/Destiny2/Manifest/{entity_type}/{hash_id}/")
            except RuntimeError:
                return {}  # don't cache failures; they may be temporary
        return self.cache[key]

    def activity(self, hash_id):
        return self.definition("DestinyActivityDefinition", hash_id)

    def item(self, hash_id):
        return self.definition("DestinyInventoryItemDefinition", hash_id)

    def save_cache(self):
        CACHE_FILE.write_text(json.dumps(self.cache), encoding="utf-8")


def name(definition):
    return definition.get("displayProperties", {}).get("name") or "(no name)"


def load_env():
    env_file = HERE / ".env"
    if not env_file.exists():
        sys.exit("Missing phase0/.env. Copy phase0/.env.example to phase0/.env and fill it in.")
    env = {}
    for line in env_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            env[key.strip()] = value.strip()
    return env


def pick_membership(memberships):
    """Cross Save lists every linked platform; the active one matches crossSaveOverride."""
    if not memberships:
        sys.exit("No Destiny account found for that Bungie name.")
    for m in memberships:
        if m.get("crossSaveOverride") in (0, m["membershipType"]):
            return m
    return memberships[0]


def save_json(filename, data):
    (OUTPUT_DIR / filename).write_text(json.dumps(data, indent=2), encoding="utf-8")


def main():
    # Item names can include characters the Windows console can't print by default.
    sys.stdout.reconfigure(encoding="utf-8")
    OUTPUT_DIR.mkdir(exist_ok=True)
    env = load_env()
    api = Bungie(env["BUNGIE_API_KEY"])

    lines = []

    def report(text=""):
        """Print a line and keep it for report.txt."""
        print(text)
        lines.append(text)

    report(f"Run at {datetime.now(timezone.utc):%Y-%m-%d %H:%M} UTC (daily reset is 17:00 UTC)")

    # 1. Bungie name -> Destiny account
    display_name, code = env["BUNGIE_NAME"].rsplit("#", 1)
    member = pick_membership(api.request(
        "/Destiny2/SearchDestinyPlayerByBungieName/-1/",
        {"displayName": display_name, "displayNameCode": int(code)},
    ))
    report(f"Account: membershipType={member['membershipType']} membershipId={member['membershipId']}")

    # 2. Characters (component 200) and their available activities (component 204)
    profile = api.request(
        f"/Destiny2/{member['membershipType']}/Profile/{member['membershipId']}/?components=200,204"
    )
    save_json("profile.json", profile)
    activities = profile.get("characterActivities", {})
    if "data" not in activities:
        sys.exit("Bungie is hiding your character activities. Check your privacy settings on "
                 "bungie.net (the option about showing your progression), then rerun.")

    class_of = {cid: CLASS_NAMES.get(c["classType"], "?") for cid, c in profile["characters"]["data"].items()}
    report("Characters: " + ", ".join(class_of.values()))
    if activities.get("privacy") == PRIVATE:
        # Seen 2026-10-17: the component is labeled private even with "Show my progression"
        # turned on, but the data still comes back. Trust the data, not the label.
        report("Note: Bungie labels character activities as private but returned them anyway.")

    # 3. Gather every activity that shows rewards, per character:
    #    rewards[activityHash][characterId] = [(itemHash, uiStyle), ...]
    rewards = defaultdict(dict)
    focused = set()
    total = 0
    for cid, char_data in activities["data"].items():
        for act in char_data.get("availableActivities", []):
            total += 1
            if act.get("isFocusedActivity"):
                focused.add(act["activityHash"])
            items = []
            for mapping in act.get("visibleRewards", []):
                for reward in mapping.get("rewardItems", []):
                    item_hash = reward.get("itemQuantity", {}).get("itemHash")
                    if item_hash:
                        items.append((item_hash, reward.get("uiStyle", "")))
            if items:
                rewards[act["activityHash"]][cid] = items

    report(f"{total} available activities across characters, {len(rewards)} show rewards, "
           f"{len(focused)} marked isFocusedActivity")
    report("Looking up names (slow on the first run, cached after that)...")

    # 4. Activities and their rewards, flagging anything that differs between characters
    report("\n=== Activities with visible rewards ===")
    for act_hash in sorted(rewards, key=lambda h: name(api.activity(h))):
        definition = api.activity(act_hash)
        tags = [MODE_NAMES.get(definition.get("directActivityModeType"), "")]
        if act_hash in focused:
            tags.append("FOCUSED")
        report(f"\n{name(definition)}  [{act_hash}] {' '.join(tags).strip()}")

        per_char = rewards[act_hash]
        shown = next(iter(per_char.values()))
        for item_hash, ui_style in shown:
            item = api.item(item_hash)
            report(f"    {name(item):35} {item.get('itemTypeDisplayName', ''):22} uiStyle={ui_style!r}")
        for cid, items in per_char.items():
            if set(items) != set(shown):
                others = ", ".join(name(api.item(h)) for h, _ in items)
                report(f"    !! {class_of[cid]} sees different rewards: {others}")
        missing = [cls for cid, cls in class_of.items() if cid not in per_char]
        if missing:
            report(f"    (no rewards shown on: {', '.join(missing)})")

    # 5. Which uiStyle values exist? One of them probably marks the bonus focus.
    report("\n=== uiStyle values ===")
    counts = Counter()
    examples = defaultdict(set)
    for per_char in rewards.values():
        for items in per_char.values():
            for item_hash, ui_style in items:
                counts[ui_style] += 1
                examples[ui_style].add(name(api.item(item_hash)))
    for ui_style, count in counts.most_common():
        report(f"  {ui_style!r}: {count} rewards, e.g. {', '.join(sorted(examples[ui_style])[:6])}")

    # 6. Public milestones: one candidate source for this week's featured raids and dungeons
    milestones = api.request("/Destiny2/Milestones/")
    save_json("milestones.json", milestones)
    report("\n=== Public milestones ===")
    for ms_hash, milestone in milestones.items():
        act_names = []
        for act in milestone.get("activities", []):
            definition = api.activity(act["activityHash"])
            mode = MODE_NAMES.get(definition.get("directActivityModeType"), "")
            act_names.append(f"{name(definition)} {mode}".strip())
        ms_name = name(api.definition("DestinyMilestoneDefinition", ms_hash))
        report(f"  {ms_name} [{ms_hash}]: {', '.join(act_names) or '(no activities)'}")

    api.save_cache()
    (OUTPUT_DIR / "report.txt").write_text("\n".join(lines), encoding="utf-8")
    print(f"\nSaved the report and raw JSON to {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
