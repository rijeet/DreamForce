import 'package:dream_force/features/timer/domain/focus_session.dart';
import 'package:material_ui/material_ui.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({required this.session, required this.onDelete, super.key});
  final FocusSession session;
  final VoidCallback onDelete;
  String _time(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (_, _) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            session.activity.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            session.phaseName,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          Center(
            child: SizedBox(
              width: 230,
              height: 230,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: session.progress.clamp(0, 1),
                    strokeWidth: 14,
                  ),
                  Text(
                    _time(session.remainingSeconds),
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (session.status == SessionStatus.completed)
            Text(
              'Great work. Your session is complete.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            )
          else if (session.status == SessionStatus.cancelled)
            const Text(
              'Session deleted. Elapsed time remains in history.',
              textAlign: TextAlign.center,
            )
          else ...[
            FilledButton.icon(
              onPressed: session.togglePause,
              icon: Icon(
                session.status == SessionStatus.running
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
              label: Text(
                session.status == SessionStatus.running ? 'Pause' : 'Resume',
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final accepted = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete session?'),
                    content: const Text(
                      'This cancels the current session. Elapsed time is kept in history.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Keep session'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (accepted ?? false) onDelete();
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete session'),
            ),
          ],
        ],
      ),
    ),
  );
}
