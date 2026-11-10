import 'package:d2lootalert/widgets/retrying_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// flutter_test answers every HTTP request with "400 Bad Request", so every
// download in these tests fails, which is the case they need (#43).

/// Which attempt the widget is on: its inner Image's key.
int attempt(WidgetTester tester) => (tester.widget<Image>(find.byType(Image)).key! as ValueKey<int>).value;

/// Lets the current download fail and the widget react to it.
Future<void> letItFail(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

/// Fails the first download, then each retry after its delay (2, 4, 8, 16, 32 s).
Future<void> useUpAllRetries(WidgetTester tester) async {
  await letItFail(tester);
  for (var i = 0; i < RetryingNetworkImage.maxRetries; i++) {
    await tester.pump(Duration(seconds: 2 << i));
    await letItFail(tester);
  }
}

void main() {
  testWidgets('a failed image is retried after 2, 4, 8, 16 and 32 seconds', (tester) async {
    await tester.pumpWidget(const RetryingNetworkImage('https://example.com/banner.jpg'));
    await letItFail(tester);
    expect(attempt(tester), 0);

    // Just before its delay, nothing happens; at the delay, it retries.
    for (var i = 0; i < RetryingNetworkImage.maxRetries; i++) {
      final delay = Duration(seconds: 2 << i);
      await tester.pump(delay - const Duration(milliseconds: 100));
      expect(attempt(tester), i, reason: 'too early for retry ${i + 1}');
      await tester.pump(const Duration(milliseconds: 100));
      await letItFail(tester);
      expect(attempt(tester), i + 1, reason: 'retry ${i + 1} after ${delay.inSeconds} s');
    }
  });

  testWidgets('after the last retry it waits instead of trying forever', (tester) async {
    await tester.pumpWidget(const RetryingNetworkImage('https://example.com/banner.jpg'));
    await useUpAllRetries(tester);
    await tester.pump(const Duration(minutes: 10));
    await letItFail(tester);
    expect(attempt(tester), RetryingNetworkImage.maxRetries);
  });

  testWidgets('coming back to the app tries again, even after giving up', (tester) async {
    await tester.pumpWidget(const RetryingNetworkImage('https://example.com/banner.jpg'));
    await useUpAllRetries(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await letItFail(tester);
    expect(attempt(tester), RetryingNetworkImage.maxRetries + 1);
  });

  testWidgets('a new URL starts over with all its retries', (tester) async {
    await tester.pumpWidget(const RetryingNetworkImage('https://example.com/old.jpg'));
    await useUpAllRetries(tester);

    await tester.pumpWidget(const RetryingNetworkImage('https://example.com/new.jpg'));
    await letItFail(tester);
    expect(attempt(tester), 0);
    await tester.pump(const Duration(seconds: 2));
    await letItFail(tester);
    expect(attempt(tester), 1);
  });
}
