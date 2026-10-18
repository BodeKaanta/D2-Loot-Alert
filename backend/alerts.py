"""Push alerts (issue #7): one FCM topic message per bonus focus weapon (daily)
and per featured raid or dungeon (weekly).

Phones subscribe to a topic when the user watches something (weapon_<itemHash>,
raid_<id>), so the backend never stores who is watching what. rotation.run()
decides which alerts are new; this module only builds and sends them.
"""


def weapon_topic(item_hash):
    return f"weapon_{item_hash}"


def raid_topic(raid_id):
    return f"raid_{raid_id}"  # dungeons too


def join_names(names):
    """['A'] -> 'A', ['A', 'B'] -> 'A and B', ['A', 'B', 'C'] -> 'A, B and C'."""
    if len(names) <= 1:
        return "".join(names)
    return ", ".join(names[:-1]) + " and " + names[-1]


def activity_labels(activities):
    """Each activity's name, plus its category when two categories share that name.

    e.g. 'Gambit', but 'Quickplay (Solo Ops)' vs 'Quickplay (Vanguard Op)'.
    """
    categories_by_name = {}
    for a in activities:
        categories_by_name.setdefault(a["name"], set()).add(a["category"])
    return {
        a["id"]: f"{a['name']} ({a['category']})" if len(categories_by_name[a["name"]]) > 1 else a["name"]
        for a in activities
    }


def weapon_alerts(snapshot):
    """One alert per weapon, naming every activity where it's the bonus focus today."""
    labels = activity_labels(snapshot["activities"])
    by_weapon = {}  # itemHash -> (weapon, [activity ids])
    for activity in snapshot["activities"]:
        for weapon in activity["weapons"]:
            by_weapon.setdefault(weapon["itemHash"], (weapon, []))[1].append(activity["id"])

    alerts = []
    for item_hash, (weapon, activity_ids) in by_weapon.items():
        alerts.append({
            "topic": weapon_topic(item_hash),
            "title": f"{weapon['name']} is a bonus drop today",
            "body": f"Bonus focus in {join_names([labels[i] for i in activity_ids])}",
            "image": weapon["icon"],
            # FCM data values must be strings. The app uses these to open the right screen (#9).
            "data": {"kind": "weapon", "itemHash": str(item_hash), "activityIds": ",".join(activity_ids)},
        })
    return alerts


def raid_alerts(snapshot):
    """One title-only alert per featured raid or dungeon. Players know it lasts until Tuesday."""
    return [{
        "topic": raid_topic(raid["id"]),
        "title": f"{raid['name']} is featured this week",
        "body": None,
        "image": None,
        "data": {"kind": raid["kind"], "id": raid["id"]},
    } for raid in snapshot["featured"]]


def send(alerts):
    """Send alerts through FCM. Returns the topics FCM accepted.

    Rejected ones aren't returned, so they aren't recorded as sent and the next
    backup run tries them again.
    """
    if not alerts:
        return set()
    # Imported here so `rotation.py --dry-run` works without firebase-admin installed.
    from firebase_admin import messaging

    messages = []
    for alert in alerts:
        image = alert["image"]
        messages.append(messaging.Message(
            topic=alert["topic"],
            notification=messaging.Notification(title=alert["title"], body=alert["body"], image=image),
            data=alert["data"],
            # iOS only shows an image if the app has a Notification Service Extension (#8),
            # and only runs that extension when mutable-content is set.
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(aps=messaging.Aps(mutable_content=True)),
                fcm_options=messaging.APNSFCMOptions(image=image),
            ) if image else None,
        ))

    response = messaging.send_each(messages)
    accepted = set()
    for alert, result in zip(alerts, response.responses):
        if result.success:
            accepted.add(alert["topic"])
        else:
            print(f"FCM rejected {alert['topic']}: {result.exception}")
    return accepted
