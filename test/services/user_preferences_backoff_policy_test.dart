import 'package:flutter_test/flutter_test.dart';

Duration computeBackoff(int retryCount) {
  const base = Duration(seconds: 2);
  final raw = base * (1 << retryCount);
  return raw > const Duration(seconds: 16) ? const Duration(seconds: 16) : raw;
}

void main() {
  test('backoff policy matches 2s base, doubling and 16s cap', () {
    expect(computeBackoff(0), const Duration(seconds: 2));
    expect(computeBackoff(1), const Duration(seconds: 4));
    expect(computeBackoff(2), const Duration(seconds: 8));
    expect(computeBackoff(3), const Duration(seconds: 16));
    expect(computeBackoff(4), const Duration(seconds: 16));
  });
}


