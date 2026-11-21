import 'package:dream_force/features/activities/domain/activity_draft.dart';
import 'package:material_ui/material_ui.dart';

IconData planActivityIcon(String? key) => switch (key) {
  'study' => Icons.menu_book_outlined,
  'coding' => Icons.code,
  'exercise' => Icons.directions_run_outlined,
  'reading' => Icons.auto_stories_outlined,
  'focus' => Icons.bolt_outlined,
  _ => Icons.task_alt_outlined,
};

class PlanOccurrenceCard extends StatelessWidget {
  const PlanOccurrenceCard({
    required this.occurrence,
    required this.busy,
    required this.onStart,
    required this.onSkip,
    super.key,
  });

  final Map<String, dynamic> occurrence;
  final bool busy;
  final Future<void> Function(ActivityDraft activity) onStart;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final state = occurrence['displayState'] as String? ?? 'scheduled';
    final duration = (occurrence['plannedMinutes'] as num?)?.toInt() ?? 25;
    final time = occurrence['localStartTime'] as String?;
    final item = ActivityDraft.seconds(
      name: occurrence['name'] as String? ?? 'Activity',
      icon: planActivityIcon(occurrence['iconKey'] as String?),
      iconKey: occurrence['iconKey'] as String? ?? 'focus',
      category: occurrence['category'] as String?,
      templateId: occurrence['templateId'] as String?,
      plannedSeconds: duration * 60,
    );
    final timeLabel = time == null || time.length < 5
        ? 'Any time'
        : time.substring(0, 5);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              planActivityIcon(occurrence['iconKey'] as String?),
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$timeLabel · $duration min${state == 'skipped'
                        ? ' · Skipped'
                        : state == 'completed'
                        ? ' · Completed'
                        : state == 'started'
                        ? ' · In progress'
                        : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (state == 'scheduled' || state == 'unstarted') ...[
              TextButton(
                onPressed: busy
                    ? null
                    : () {
                        onStart(item);
                      },
                child: const Text('Start'),
              ),
              if (state != 'unstarted')
                TextButton(onPressed: onSkip, child: const Text('Skip')),
            ] else if (state == 'started')
              const Icon(Icons.play_circle_outline),
          ],
        ),
      ),
    );
  }
}
