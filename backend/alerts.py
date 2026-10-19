"""Push alerts (issue #7): one FCM topic message per bonus focus weapon (daily)
and per featured raid or dungeon (weekly).

Phones subscribe to a topic when the user watches something (weapon_<id>,
raid_<id>), so the backend never stores who is watching what. rotation.run()
decides which alerts are new; this module only builds and sends them.
"""


def weapon_topic(weapon_id):
    return f"weapon_{weapon_id}"  # the name slug, shared by every version of the weapon (#26)


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
    """One alert per weapon, naming every activity where it's the bonus focus today.

    Grouped by weapon id, so a GM version in one activity and the regular version
    in another make one alert that names both activities.
    """
    labels = activity_labels(snapshot["activities"])
    banners = {a["id"]: a.get("image") for a in snapshot["activities"]}
    by_weapon = {}  # weapon id -> (weapon, [activity ids])
    for activity in snapshot["activities"]:
        for weapon in activity["weapons"]:
            by_weapon.setdefault(weapon["id"], (weapon, []))[1].append(activity["id"])

    alerts = []
    for weapon_id, (weapon, activity_ids) in by_weapon.items():
        alerts.append({
            "topic": weapon_topic(weapon_id),
            "title": f"{weapon['name']} is a bonus drop today",
            "body": f"Bonus focus in {join_names([labels[i] for i in activity_ids])}",
            "image": weapon["icon"],
            # Shown when the alert is expanded (#30): the first focus activity's banner
            # that exists, else the weapon's own screenshot (e.g. Typhon Imperator has
            # no banner). The body still names every activity.
            "banner": next((banners[i] for i in activity_ids if banners[i]), weapon.get("screenshot")),
            # The app uses these to open the right screen (#9).
            "data": {"kind": "weapon", "weaponId": weapon_id, "activityIds": ",".join(activity_ids)},
        })
    return alerts


def raid_alerts(snapshot):
    """One title-only alert per featured raid or dungeon. Players know it lasts until Tuesday.

    Expanded, it shows the raid's banner (#30).
    """
    return [{
        "topic": raid_topic(raid["id"]),
        "title": f"{raid['name']} is featured this week",
        "body": None,
        "image": None,
        "banner": raid.get("image"),
        "data": {"kind": raid["kind"], "id": raid["id"]},
    } for raid in snapshot["featured"]]


def fcm_data(alert):
    """The alert's FCM data: what the app needs to open the right tab, plus what
    it needs to draw the notification on Android (#30).

    FCM data values must be strings, so empty ones (no body, no banner) are left out.
    """
    fields = {**alert["data"], "title": alert["title"], "body": alert["body"],
              "icon": alert["image"], "banner": alert["banner"]}
    return {key: str(value) for key, value in fields.items() if value is not None}


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
            # No `notification` part: that makes it a data message on Android, so the
            # app draws it, with the banner when expanded (#30). iPhones get the
            # visible alert from the `apns` part below.
            data=fcm_data(alert),
            # High priority so FCM delivers right away, even to a phone in Doze (#28).
            # Otherwise it holds alerts until the phone wakes.
            android=messaging.AndroidConfig(priority="high"),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(aps=messaging.Aps(
                    alert=messaging.ApsAlert(title=alert["title"], body=alert["body"]),
                    # iOS only shows an image if the app has a Notification Service
                    # Extension (#17), and only runs it when mutable-content is set.
                    mutable_content=bool(image),
                )),
                fcm_options=messaging.APNSFCMOptions(image=image) if image else None,
            ),
        ))

    response = messaging.send_each(messages)
    accepted = set()
    for alert, result in zip(alerts, response.responses):
        if result.success:
            accepted.add(alert["topic"])
        else:
            print(f"FCM rejected {alert['topic']}: {result.exception}")
    return accepted
