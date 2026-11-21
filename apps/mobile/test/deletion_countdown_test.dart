import 'package:dream_force/features/profile/domain/deletion_countdown.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final due = DateTime(2026, 12, 21, 8, 0);

  test('shows days and the clock that remains', () {
    expect(
      deletionCountdown(due, DateTime(2026, 11, 21, 8, 0)),
      '30d 00:00:00',
    );
    expect(
      deletionCountdown(due, DateTime(2026, 12, 20, 3, 5, 9)),
      '1d 04:54:51',
    );
  });

  test('stays at zero after the deadline', () {
    expect(
      deletionCountdown(due, DateTime(2026, 12, 21, 8, 0, 1)),
      '0d 00:00:00',
    );
  });
}
