import 'package:dream_force/features/timer/domain/focus_session.dart';
import 'package:material_ui/material_ui.dart';

class SessionCompleteScreen extends StatelessWidget {
  const SessionCompleteScreen({
    required this.session,
    required this.onDone,
    required this.onStartAnother,
    super.key,
  });
  final FocusSession session;
  final VoidCallback onDone;
  final VoidCallback onStartAnother;

  @override
  Widget build(BuildContext context) {
    final total = session.activity.plannedSeconds;
    final focus = (total * 5 / 6).round();
    final rest = total - focus;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Session complete',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        const Text('Thanks for showing up for this block.'),
        const SizedBox(height: 20),
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${session.activity.name} finished',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                const Text('One focus block and one break.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Great job!',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'You have completed a focus period. A local notification appears when device settings allow it.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _summary(context, 'Focused', _minutes(focus)),
        const SizedBox(height: 10),
        _summary(context, 'Rested', _minutes(rest)),
        const SizedBox(height: 20),
        FilledButton(onPressed: onDone, child: const Text('Done')),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: onStartAnother,
          child: const Text('Start another activity'),
        ),
      ],
    );
  }

  String _minutes(int seconds) => '${(seconds / 60).round()} min';
  Widget _summary(BuildContext context, String label, String value) => Card(
    child: ListTile(
      title: Text(label, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(value),
      trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}
