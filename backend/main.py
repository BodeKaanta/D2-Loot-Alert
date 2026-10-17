"""Cloud Functions entry point (issue #6). Deploy with: firebase deploy --only functions

The work happens in rotation.py; this file only wires it to a schedule and
Firebase. The Bungie API key and Bungie name are Cloud Secret Manager secrets,
set once with `firebase functions:secrets:set <NAME>`.
"""

from firebase_admin import firestore, initialize_app
from firebase_functions import options, scheduler_fn
from firebase_functions.params import SecretParam

import rotation

BUNGIE_API_KEY = SecretParam("BUNGIE_API_KEY")
BUNGIE_NAME = SecretParam("BUNGIE_NAME")

initialize_app()  # inside Cloud Functions, credentials come from the project automatically


@scheduler_fn.on_schedule(
    # 17:07 UTC, a few minutes after daily reset, plus backup runs at 18:07 and 21:07
    # in case the first one hits Bungie downtime or something shows up late.
    # Times are UTC: the Firebase CLI's default for 2nd-gen schedules. (Passing
    # timezone= explicitly breaks deploys from Windows, which has no tz database.)
    schedule="7 17,18,21 * * *",
    secrets=[BUNGIE_API_KEY, BUNGIE_NAME],
    timeout_sec=540,  # rebuilding loot pools after a game update takes a few minutes
    memory=options.MemoryOption.MB_512,
)
def daily_rotation(event: scheduler_fn.ScheduledEvent) -> None:
    rotation.run(BUNGIE_API_KEY.value, BUNGIE_NAME.value, firestore.client())
