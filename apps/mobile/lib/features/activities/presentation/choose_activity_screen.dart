import 'package:dream_force/features/activities/domain/activity_draft.dart';
import 'package:material_ui/material_ui.dart';

class ChooseActivityScreen extends StatelessWidget {
  const ChooseActivityScreen({
    required this.activities,
    required this.onBack,
    required this.onCreateActivity,
    required this.onStart,
    super.key,
  });

  final List<ActivityDraft> activities;
  final VoidCallback onBack;
  final VoidCallback onCreateActivity;
  final ValueChanged<ActivityDraft> onStart;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              tooltip: 'Back to Today',
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Text(
              'Choose activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          children: [
            Text(
              'Start a focused session',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Choose a reusable activity or create a new one.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            for (final activity in activities)
              Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(child: Icon(activity.icon)),
                  title: Text(activity.name),
                  subtitle: Text(
                    '${activity.plannedMinutes} min · Automatic focus and rest',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => onStart(activity),
                ),
              ),
          ],
        ),
      ),
      SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onCreateActivity,
            icon: const Icon(Icons.add),
            label: const Text('Create activity'),
          ),
        ),
      ),
    ],
  );
}
