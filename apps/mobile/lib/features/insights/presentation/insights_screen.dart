import 'package:dream_force/core/platform/device_settings.dart';
import 'package:material_ui/material_ui.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with WidgetsBindingObserver {
  ScreenTimeSummary? _screenTime;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadScreenTime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadScreenTime();
  }

  Future<void> _loadScreenTime() async {
    try {
      final data = await DeviceSettings.getTodayScreenTime();
      if (mounted) {
        setState(() {
          _screenTime = data;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not read screen time from Android.';
        });
      }
    }
  }

  Future<void> _openUsageAccessSettings() async {
    await DeviceSettings.openUsageAccessSettings();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Insights', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 4),
      const Text('Your focused work, one day at a time.'),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Activity', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Complete your first focus session to see this week’s activity.',
              ),
              const SizedBox(height: 12),
              const LinearProgressIndicator(value: 0),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Screen time',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text('Today · on this device'),
              const SizedBox(height: 12),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_error != null)
                Text(_error!)
              else if (!(_screenTime?.hasPermission ?? false)) ...[
                const Text(
                  'Allow Usage Access to see today’s screen time. This data stays on your device.',
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _openUsageAccessSettings,
                  child: const Text('Set up Usage Access'),
                ),
              ] else ...[
                Text(
                  _formatDuration(_screenTime!.total),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                if (_screenTime!.apps.isEmpty)
                  const Text('No screen time recorded yet today.')
                else
                  for (final app in _screenTime!.apps)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(app.packageName),
                      trailing: Text(_formatDuration(app.duration)),
                    ),
                TextButton.icon(
                  onPressed: _loadScreenTime,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ],
          ),
        ),
      ),
    ],
  );

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) return '$minutes min';
    return '$hours hr ${minutes.toString().padLeft(2, '0')} min';
  }
}
