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

  test('countdown text', () {
    expect(formatCountdown(const Duration(hours: 14, minutes: 3)), '14H 03M');
    expect(formatCountdown(const Duration(minutes: 9)), '0H 09M');
  });
}
