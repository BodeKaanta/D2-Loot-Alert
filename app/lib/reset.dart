/// Destiny's daily reset is 17:00 UTC every day, all year (no daylight saving).
DateTime nextDailyReset(DateTime now) {
  final utc = now.toUtc();
  final todaysReset = DateTime.utc(utc.year, utc.month, utc.day, 17);
  return utc.isBefore(todaysReset) ? todaysReset : todaysReset.add(const Duration(days: 1));
}

/// "14H 03M": Destiny-style countdown text.
String formatCountdown(Duration remaining) {
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
  return '${hours}H ${minutes}M';
}
