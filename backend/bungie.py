"""Minimal Bungie.net API client for the backend (adapted from phase0/api_test.py).

Only uses the Python standard library. See CLAUDE.md > "Bungie API notes" for
the endpoints and data shapes.
"""

import json
import urllib.error
import urllib.request

BUNGIE_URL = "https://www.bungie.net"
BASE_URL = BUNGIE_URL + "/Platform"


class BungieError(RuntimeError):
    """The API returned an error, e.g. during maintenance around reset."""


class Bungie:
    def __init__(self, api_key):
        self.api_key = api_key
        self._definitions = {}  # cache for this run: (entity type, hash) -> definition
        self._manifest = None  # manifest index, fetched once per run

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
                raise BungieError(f"{path} failed: HTTP {err.code}") from None

        # Every response is wrapped: {"Response": ..., "ErrorCode": 1, "ErrorStatus": "Success", ...}
        if payload.get("ErrorCode") != 1:
            raise BungieError(f"{path} failed: {payload.get('ErrorStatus')}: {payload.get('Message')}")
        return payload["Response"]

    def definition(self, entity_type, hash_id):
        """One manifest definition (name, icon, type...), or {} if Bungie doesn't know the hash."""
        key = (entity_type, hash_id)
        if key not in self._definitions:
            try:
                self._definitions[key] = self.request(f"/Destiny2/Manifest/{entity_type}/{hash_id}/")
            except BungieError:
                return {}  # don't cache failures; they may be temporary
        return self._definitions[key]

    def item(self, hash_id):
        return self.definition("DestinyInventoryItemDefinition", hash_id)

    def activity_type(self, hash_id):
        return self.definition("DestinyActivityTypeDefinition", hash_id)

    def manifest(self):
        """The manifest index: the game data's version and where each definition table lives."""
        if self._manifest is None:
            self._manifest = self.request("/Destiny2/Manifest/")
        return self._manifest

    def manifest_version(self):
        """Changes whenever Bungie updates the game data (e.g. a new season or patch)."""
        return self.manifest()["version"]

    def definition_table(self, name):
        """A whole definition table, e.g. every DestinyActivityDefinition, keyed by hash string.

        Fine for activity tables (~11 MB); item definitions are far bigger, so
        those stay single lookups through item().
        """
        path = self.manifest()["jsonWorldComponentContentPaths"]["en"][name]
        with urllib.request.urlopen(BUNGIE_URL + path, timeout=60) as resp:
            return json.load(resp)

    def character_activities(self, bungie_name):
        """Profile component 204: every character's available activities and their rewards."""
        display_name, code = bungie_name.rsplit("#", 1)
        memberships = self.request(
            "/Destiny2/SearchDestinyPlayerByBungieName/-1/",
            {"displayName": display_name, "displayNameCode": int(code)},
        )
        if not memberships:
            raise BungieError(f"No Destiny account found for {bungie_name}")
        member = _active_membership(memberships)

        profile = self.request(
            f"/Destiny2/{member['membershipType']}/Profile/{member['membershipId']}/?components=204"
        )
        # Bungie labels this component "private" even when it returns the data,
        # so check for the data itself (see CLAUDE.md > Bungie API notes > Privacy).
        if "data" not in profile.get("characterActivities", {}):
            raise BungieError("Character activities are hidden; check the Bungie.net privacy settings")
        return profile


def _active_membership(memberships):
    """Cross Save lists every linked platform; the active one matches crossSaveOverride."""
    for m in memberships:
        if m.get("crossSaveOverride") in (0, m["membershipType"]):
            return m
    return memberships[0]
