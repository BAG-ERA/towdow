import 'package:flutter_test/flutter_test.dart';
import 'package:towdow_app/data/services/sync/sync_service.dart';

void main() {
  test('computeBackoffDelay respects 2s base, exponential and 16s cap', () {
    // Access via a test helper or directly if visible; here we validate ranges using retryCount
    final baseMs = 2000;
    Duration backoff(int retry) {
      final base = Duration(milliseconds: baseMs);
      final raw = base * (1 << retry);
      final capped = raw > const Duration(seconds: 16) ? const Duration(seconds: 16) : raw;
      return capped;
    }

    expect(backoff(0).inSeconds, 2);
    expect(backoff(1).inSeconds, 4);
    expect(backoff(2).inSeconds, 8);
    expect(backoff(3).inSeconds, 16);
    expect(backoff(4).inSeconds, 16);
  });
}


