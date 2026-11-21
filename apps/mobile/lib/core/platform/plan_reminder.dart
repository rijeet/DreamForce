class PlanReminder {
  const PlanReminder({required this.id, required this.title, required this.at});

  final String id;
  final String title;
  final DateTime at;
}

/// Future planned items that have a clock time today.
List<PlanReminder> remindersForToday(
  List<Map<String, dynamic>> occurrences,
  DateTime now,
) {
  final reminders = <PlanReminder>[];
  for (final occurrence in occurrences) {
    final state = occurrence['displayState'] as String? ?? 'scheduled';
    if (state != 'scheduled' && state != 'unstarted') continue;
    final id = occurrence['id'] as String?;
    final time = occurrence['localStartTime'] as String?;
    if (id == null || id.isEmpty || time == null || time.length < 5) continue;
    final hour = int.tryParse(time.substring(0, 2));
    final minute = int.tryParse(time.substring(3, 5));
    if (hour == null || minute == null || hour > 23 || minute > 59) continue;
    final at = DateTime(now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) continue;
    final name = (occurrence['name'] as String?)?.trim();
    reminders.add(
      PlanReminder(
        id: id,
        title: name == null || name.isEmpty ? 'Planned activity' : name,
        at: at,
      ),
    );
  }
  return reminders;
}
