import 'package:dream_force/features/timer/domain/focus_session.dart';
import 'package:dream_force/features/timer/presentation/timer_screen.dart';
import 'package:dream_force/features/timer/presentation/session_complete_screen.dart';
import 'package:material_ui/material_ui.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({
    required this.onChooseActivity,
    required this.session,
    required this.onDeleteSession,
    super.key,
  });
  final VoidCallback onChooseActivity;
  final FocusSession? session;
  final VoidCallback onDeleteSession;

  @override
  Widget build(BuildContext context) => session == null
      ? _buildContent(context)
      : AnimatedBuilder(
          animation: session!,
          builder: (context, _) => _buildContent(context),
        );

  Widget _buildContent(BuildContext context) {
    if (session?.status == SessionStatus.completed) {
      return SessionCompleteScreen(
        session: session!,
        onDone: onDeleteSession,
        onStartAnother: onChooseActivity,
      );
    }
    if (session != null && session!.status != SessionStatus.cancelled) {
      return TimerScreen(session: session!, onDelete: onDeleteSession);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                'assets/images/logo.jpg',
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                semanticLabel: 'Dream Force logo',
              ),
            ),
            const SizedBox(width: 12),
            Text('Today', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
        const SizedBox(height: 4),
        const Text('A steady day, one block at a time.'),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready to focus?',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose an activity and Dream Force will calculate focus and rest automatically.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onChooseActivity,
                  icon: const Icon(Icons.add),
                  label: const Text('Choose activity'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text("Today's plan", style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Card(
          child: ListTile(
            leading: Icon(Icons.event_note_outlined),
            title: Text('No activities planned'),
            subtitle: Text('Build your week from the Plan tab.'),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Close your day with a reflection'),
                SizedBox(height: 4),
                Text('You can review today even if no activity is complete.'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
