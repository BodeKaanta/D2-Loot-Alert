import 'package:d2lootalert/reset.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('next reset is today at 17:00 UTC before reset', () {
    expect(nextDailyReset(DateTime.utc(2026, 10, 17, 16, 59)), DateTime.utc(2026, 10, 17, 17));
  });

  test('next reset is tomorrow at 17:00 UTC from reset onward', () {
    expect(nextDailyReset(DateTime.utc(2026, 10, 17, 17)), DateTime.utc(2026, 10, 18, 17));
    expect(nextDailyReset(DateTime.utc(2026, 10, 31, 23, 30)), DateTime.utc(2026, 11, 1, 17));
  });

  test('current reset id is the date of the latest 17:00 UTC', () {
    expect(currentResetId(DateTime.utc(2026, 10, 17, 16, 59)), '2026-10-16');
    expect(currentResetId(DateTime.utc(2026, 10, 17, 17)), '2026-10-17');
    expect(currentResetId(DateTime.utc(2026, 11, 1, 3)), '2026-10-31');
  });

  test('a rotation is out of date from reset until the new one is saved', () {
    expect(isOutOfDate('2026-10-16', DateTime.utc(2026, 10, 17, 16, 59)), isFalse); // before reset
    expect(isOutOfDate('2026-10-16', DateTime.utc(2026, 10, 17, 17, 3)), isTrue); // reset, backend not run yet
    expect(isOutOfDate('2026-10-17', DateTime.utc(2026, 10, 17, 17, 8)), isFalse); // the new one is in
  });

  test('countdown text', () {
    expect(formatCountdown(const Duration(hours: 14, minutes: 3)), '14H 03M');
    expect(formatCountdown(const Duration(minutes: 9)), '0H 09M');
  });
}
