import 'package:dream_force/core/platform/plan_reminder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 21, 9, 30);

  test('schedules a later planned activity at its start time', () {
    final reminders = remindersForToday([
      {
        'id': 'study',
        'name': 'Study',
        'displayState': 'scheduled',
        'localStartTime': '18:15:00',
      },
    ], now);

    expect(reminders, hasLength(1));
    expect(reminders.single.title, 'Study');
    expect(reminders.single.at, DateTime(2026, 11, 21, 18, 15));
  });

  test('skips past times, any-time items, and items already started', () {
    final reminders = remindersForToday([
      {
        'id': 'past',
        'name': 'Coding',
        'displayState': 'scheduled',
        'localStartTime': '08:00:00',
      },
      {
        'id': 'open',
        'name': 'Reading',
        'displayState': 'scheduled',
        'localStartTime': null,
      },
      {
        'id': 'done',
        'name': 'Exercise',
        'displayState': 'started',
        'localStartTime': '20:00:00',
      },
    ], now);

    expect(reminders, isEmpty);
  });
}
