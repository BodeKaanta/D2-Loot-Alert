/// Destiny's daily reset is 17:00 UTC every day, all year (no daylight saving).
DateTime nextDailyReset(DateTime now) {
  final utc = now.toUtc();
  final todaysReset = DateTime.utc(utc.year, utc.month, utc.day, 17);
  return utc.isBefore(todaysReset) ? todaysReset : todaysReset.add(const Duration(days: 1));
}

/// The date of the latest daily reset, e.g. "2026-10-17". It's what the backend
/// saves as the rotation's resetId (reset_id() in backend/rotation.py).
String currentResetId(DateTime now) =>
    nextDailyReset(now).subtract(const Duration(days: 1)).toIso8601String().substring(0, 10);

/// True when a rotation saved for [resetId] is from before the latest reset:
/// every day from reset until the backend's run a few minutes later, or longer
/// if Bungie's servers are down. Dates written this way compare correctly as text.
bool isOutOfDate(String resetId, DateTime now) => resetId.compareTo(currentResetId(now)) < 0;

/// "14H 03M": Destiny-style countdown text.
String formatCountdown(Duration remaining) {
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '${hours}H ${minutes}M';
}
