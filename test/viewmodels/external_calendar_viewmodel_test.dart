import 'package:flutter_test/flutter_test.dart';
import 'package:towdow_app/presentation/viewmodels/external_calendar_viewmodel.dart';

void main() {
  test('ExternalCalendarState copyWith toggles flags', () {
    const s1 = ExternalCalendarState(isLoading: true);
    final s2 = s1.copyWith(isLoading: false, error: 'e');
    expect(s2.isLoading, false);
    expect(s2.error, 'e');
  });
}


