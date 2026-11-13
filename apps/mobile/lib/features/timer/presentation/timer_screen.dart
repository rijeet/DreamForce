import 'package:dream_force/features/timer/domain/focus_session.dart';
import 'package:material_ui/material_ui.dart';

class TimerScreen extends StatelessWidget {
  const TimerScreen({required this.session, required this.onDelete, super.key});
  final FocusSession session;
  final VoidCallback onDelete;

  String _time(int seconds) {
    if (seconds >= 3600) {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      final remainder = seconds % 60;
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
    }
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  String _duration(int seconds) {
    if (seconds >= 3600) {
      final hours = seconds ~/ 3600;
      final minutes = (seconds % 3600) ~/ 60;
      return minutes == 0 ? '$hours hr' : '$hours hr $minutes min';
    }
    if (seconds >= 60) return '${seconds ~/ 60} min';
    return '$seconds sec';
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (_, _) {
      final next = session.nextPhase;
      final phase = session.phaseName.toUpperCase();
      final phaseColor = session.phaseName == 'Rest'
          ? Theme.of(context).colorScheme.secondary
          : Theme.of(context).colorScheme.primary;
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        children: [
          Text(
            '${session.activity.name} session',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          const Text('Stay with the current block.'),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              Chip(
                backgroundColor: phaseColor.withValues(alpha: 0.12),
                label: Text('$phase · CYCLE ${session.currentCycle}'),
              ),
              Chip(
                label: Text('${session.currentCycle} of ${session.cycleCount}'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 270,
            child: Center(
              child: SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: session.progress.clamp(0, 1),
                        strokeWidth: 9,
                        backgroundColor: Theme.of(context).colorScheme.primary
                            .withValues(alpha: 0.12),
                        color: phaseColor,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _time(session.remainingSeconds),
                          style: Theme.of(context).textTheme.displayMedium,
                        ),
                        Text(
                          session.status == SessionStatus.paused
                              ? 'Paused · ${session.phaseName.toLowerCase()} time left'
                              : '${session.phaseName} time left',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              '${session.activity.name} · ${_duration(session.activity.plannedSeconds)} plan',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 16),
          if (next != null)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Next: ${next.name} ${next.name == 'Rest' ? 'break' : 'block'} · ${_duration(next.seconds)}',
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              try {
                await session.togglePause();
              } catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not sync timer action: $error'),
                    ),
                  );
                }
              }
            },
            child: Text(
              session.status == SessionStatus.running
                  ? 'Pause session'
                  : 'Resume session',
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
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
                      child: const Text('Delete session'),
                    ),
                  ],
                ),
              );
              if (accepted ?? false) onDelete();
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete session'),
          ),
          const SizedBox(height: 4),
          Text(
            'Your timer continues if you leave this screen. Lock-screen controls depend on device settings.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );
    },
  );
}
