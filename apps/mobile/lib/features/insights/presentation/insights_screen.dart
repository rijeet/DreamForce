import 'dart:async';
import 'dart:convert';

import 'package:dream_force/core/platform/device_settings.dart';
import 'package:dream_force/core/platform/app_info_service.dart';
import 'package:dream_force/features/auth/data/dream_force_auth_api.dart';
import 'package:dream_force/features/insights/presentation/insight_heatmap.dart';
import 'package:material_ui/material_ui.dart';

enum _Period { day, week, month, year }

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen>
    with WidgetsBindingObserver {
  final _api = const DreamForceAuthApi();
  var _screen = 0;
  var _period = _Period.week;
  var _heatmapYear = DateTime.now().year;
  var _heatmapEarliestYear = 2019;
  String _selectedHeatmapDate = _localDate(DateTime.now());
  var _loading = true;
  String? _error;
  Map<String, dynamic>? _activity;
  ScreenTimeSummary? _screenTime;
  ScreenTimeSummary? _localScreenTime;
  bool _screenTimeSyncEnabled = false;
  bool _syncingScreenTime = false;
  Map<String, int> _activityHeatmap = const {};
  Map<String, int> _screenTimeHeatmap = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _screen == 1) _loadScreenTime();
  }

  Future<void> _load() async =>
      _screen == 0 ? _loadActivity() : _loadScreenTime();

  Future<void> _loadActivity() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = Uri(
        queryParameters: {
          'period': _period.name,
          if (_period == _Period.year) 'year': '$_heatmapYear',
        },
      ).query;
      final response = await _api.request(
        'GET',
        '/v1/insights/activity?$query',
      );
      final value = jsonDecode(response.body) as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _activity = value;
          _loading = false;
        });
      }
      unawaited(_loadActivityHeatmap());
      unawaited(_loadScreenTimeHeatmap());
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _readableError(error);
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadActivityHeatmap() async {
    try {
      final response = await _api.request(
        'GET',
        '/v1/insights/activity?period=year&year=$_heatmapYear',
      );
      final value = jsonDecode(response.body) as Map<String, dynamic>;
      final days = (value['days'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _heatmapEarliestYear = value['earliestYear'] as int? ?? 2019;
          _activityHeatmap = {
            for (final day in days)
              day['date'] as String: day['focusSeconds'] as int? ?? 0,
          };
        });
      }
    } catch (_) {
      // The selected-period card reports API errors; heatmap failure stays local.
    }
  }

  Future<void> _loadScreenTimeHeatmap() async {
    try {
      final profile = jsonDecode(
        (await _api.request('GET', '/v1/me')).body,
      ) as Map<String, dynamic>;
      final enabled = profile['screenTimeSyncEnabled'] as bool? ?? false;
      final timezone = profile['timezone'] as String? ?? 'UTC';
      if (mounted) setState(() => _screenTimeSyncEnabled = enabled);
      if (!enabled) {
        final localSummary = await DeviceSettings.getScreenTime('year');
        final local = _localScreenTimeDays(localSummary, _heatmapYear);
        if (mounted) setState(() => _screenTimeHeatmap = local);
        return;
      }
      final query = Uri(
        queryParameters: {
          'period': 'year',
          'year': '$_heatmapYear',
          'timezone': timezone,
        },
      ).query;
      final response = await _api.request('GET', '/v1/me/screen-time?$query');
      final value = jsonDecode(response.body) as Map<String, dynamic>;
      final days = (value['days'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>();
      if (mounted) {
        setState(() {
          _screenTimeHeatmap = {
            for (final day in days)
              day['date'] as String: day['usageSeconds'] as int? ?? 0,
          };
        });
      }
    } catch (_) {
      // Do not hide activity or local screen-time insights if cloud sync is down.
    }
  }

  Map<String, int> _localScreenTimeDays(ScreenTimeSummary? summary, int year) =>
      {
        for (final day in summary?.dailyUsage ?? const <ScreenTimeDay>[])
          if (day.localDate.startsWith('$year-'))
            day.localDate: day.apps.fold<int>(
              0,
              (total, app) => total + app.usageSeconds,
            ),
      };

  Future<void> _setHeatmapYear(int year) async {
    if (year == _heatmapYear) return;
    setState(() {
      _heatmapYear = year;
      _selectedHeatmapDate = _localDate(DateTime(year, 1, 1));
    });
    if (_screen == 0 && _period == _Period.year) {
      await _loadActivity();
    } else if (_screen == 1 && _period == _Period.year) {
      await _loadScreenTime();
    } else {
      await Future.wait([_loadActivityHeatmap(), _loadScreenTimeHeatmap()]);
    }
  }

  Widget _heatmapCard() {
    final keys = <String>{..._activityHeatmap.keys, ..._screenTimeHeatmap.keys};
    final days = keys
        .map(
          (date) => InsightHeatmapDay(
            localDate: date,
            activitySeconds: _activityHeatmap[date] ?? 0,
            screenTimeSeconds: _screenTimeHeatmap[date] ?? 0,
          ),
        )
        .toList(growable: false);
    return InsightHeatmap(
      days: days,
      year: _heatmapYear,
      earliestYear: _heatmapEarliestYear,
      onYearChanged: _setHeatmapYear,
      selectedDate: _selectedHeatmapDate,
      onDaySelected: (date) => setState(() => _selectedHeatmapDate = date),
    );
  }

  Widget _selectedDayCard(BuildContext context) {
    final selectedDate = DateTime.tryParse(_selectedHeatmapDate);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selected day',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                Text(
                  selectedDate == null
                      ? _selectedHeatmapDate
                      : '${_monthName(selectedDate.month)} ${selectedDate.day}, ${selectedDate.year}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            _selectedDayValue(
              context,
              'Dream Force activity',
              _activityHeatmap[_selectedHeatmapDate] ?? 0,
              Colors.green.shade700,
            ),
            const SizedBox(height: 8),
            _selectedDayValue(
              context,
              'Android screen time',
              _screenTimeHeatmap[_selectedHeatmapDate] ?? 0,
              Colors.red.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedDayValue(
    BuildContext context,
    String label,
    int seconds,
    Color color,
  ) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(label)),
      Text(
        _formatSeconds(seconds),
        style: Theme.of(context).textTheme.titleSmall,
      ),
    ],
  );

  static String _localDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _loadScreenTime() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final localData = await DeviceSettings.getScreenTime(_period.name);
      if (mounted) {
        setState(() {
          _screenTime = localData;
          _localScreenTime = localData;
          _screenTimeHeatmap = _localScreenTimeDays(localData, _heatmapYear);
          _loading = false;
        });
      }
      unawaited(_loadActivityHeatmap());

      try {
        final profile = jsonDecode(
          (await _api.request('GET', '/v1/me')).body,
        ) as Map<String, dynamic>;
        final syncEnabled = profile['screenTimeSyncEnabled'] as bool? ?? false;
        if (mounted) setState(() => _screenTimeSyncEnabled = syncEnabled);
        if (!syncEnabled) {
          if (_period == _Period.year && _heatmapYear != DateTime.now().year) {
            if (mounted) {
              setState(() {
                _screenTime = const ScreenTimeSummary(
                  hasPermission: true,
                  total: Duration.zero,
                  apps: [],
                );
              });
            }
          }
          return;
        }

        final rows = localData.hasPermission
            ? [
                for (final day in localData.dailyUsage)
                  for (final app in day.apps)
                    if (app.usageSeconds > 0)
                      {
                        'localDate': day.localDate,
                        'timezoneId': localData.timezoneId,
                        'packageName': app.packageName,
                        'appLabel': app.appLabel,
                        'usageSeconds': app.usageSeconds,
                      },
              ]
            : <Map<String, Object>>[];
        if (rows.isNotEmpty) {
          if (mounted) setState(() => _syncingScreenTime = true);
          for (var offset = 0; offset < rows.length; offset += 5000) {
            await _api.request(
              'PUT',
              '/v1/me/screen-time',
              body: {
                'queriedAt': localData.queriedAt,
                'rows': rows.skip(offset).take(5000).toList(growable: false),
              },
            );
          }
        }
        final query = Uri(
          queryParameters: {
            'period': _period.name,
            'timezone': localData.timezoneId,
            if (_period == _Period.year) 'year': '$_heatmapYear',
          },
        ).query;
        final response = await _api.request('GET', '/v1/me/screen-time?$query');
        final remote = jsonDecode(response.body) as Map<String, dynamic>;
        final remoteApps = (remote['apps'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(
              (app) => ScreenTimeApp(
                packageName: app['packageName'] as String? ?? 'unknown.app',
                appLabel:
                    app['appLabel'] as String? ??
                    app['packageName'] as String? ??
                    'Unknown app',
                duration: Duration(seconds: app['usageSeconds'] as int? ?? 0),
              ),
            )
            .toList(growable: false);
        if (mounted) {
          setState(() {
            _screenTime = ScreenTimeSummary(
              hasPermission: true,
              total: Duration(
                seconds: remote['totalUsageSeconds'] as int? ?? 0,
              ),
              apps: remoteApps,
              timezoneId: localData.timezoneId,
              queriedAt: remote['updatedAt'] as String?,
            );
            _error = null;
            if (_period == _Period.year) {
              _screenTimeHeatmap = {
                for (final day
                    in (remote['days'] as List<dynamic>? ?? const [])
                        .whereType<Map<String, dynamic>>())
                  day['date'] as String: day['usageSeconds'] as int? ?? 0,
              };
            }
          });
        }
        if (_period != _Period.year) unawaited(_loadScreenTimeHeatmap());
      } catch (error) {
        if (mounted) setState(() => _error = _readableError(error));
      } finally {
        if (mounted) setState(() => _syncingScreenTime = false);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Could not read screen time from Android: $error';
          _loading = false;
        });
      }
    }
  }

  Future<void> _setScreenTimeSync(bool enabled) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          enabled ? 'Sync screen time?' : 'Turn off screen-time sync?',
        ),
        content: Text(
          enabled
              ? 'Daily app names, usage totals, local dates, and your time zone will be uploaded to your private account for Screen time Insights. No raw event timeline is uploaded. You can turn this off later.'
              : 'This stops future uploads and deletes the screen-time records already stored in your account. Android Usage Access remains a separate device permission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(enabled ? 'I consent' : 'Turn off and delete'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await _api.request(
        'PATCH',
        '/v1/me',
        body: {
          'settings': {
            'screenTimeSyncEnabled': enabled,
            if (enabled)
              'screenTimeConsentVersion':
                  DreamForceAuthApi.screenTimeConsentVersion,
          },
        },
      );
      if (mounted) {
        setState(() {
          _screenTimeSyncEnabled = enabled;
          _error = null;
          if (!enabled) _screenTime = _localScreenTime;
        });
      }
      if (enabled) {
        await _loadScreenTime();
      } else {
        unawaited(_loadScreenTimeHeatmap());
      }
    } catch (error) {
      if (mounted) setState(() => _error = _readableError(error));
    }
  }

  String _readableError(Object error) => error is AuthApiException
      ? error.message
      : 'Could not load activity insights. Check your connection and try again.';

  Future<void> _setScreen(int value) async {
    setState(() {
      _screen = value;
    });
    await _load();
  }

  Future<void> _setPeriod(_Period period) async {
    setState(() {
      _period = period;
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      Text(
        _screen == 0 ? 'Insights' : 'Time insights',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 4),
      Text(
        _screen == 0
            ? 'Your focused work, one day at a time.'
            : 'All-app screen time · Android only',
      ),
      const SizedBox(height: 18),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(
            value: 0,
            label: Text('Activity'),
            icon: Icon(Icons.bolt_outlined),
          ),
          ButtonSegment(
            value: 1,
            label: Text('Screen time'),
            icon: Icon(Icons.pie_chart_outline),
          ),
        ],
        selected: {_screen},
        onSelectionChanged: (selection) => _setScreen(selection.first),
      ),
      const SizedBox(height: 12),
      SegmentedButton<_Period>(
        segments: const [
          ButtonSegment(value: _Period.day, label: Text('Day')),
          ButtonSegment(value: _Period.week, label: Text('Week')),
          ButtonSegment(value: _Period.month, label: Text('Month')),
          ButtonSegment(value: _Period.year, label: Text('Year')),
        ],
        selected: {_period},
        onSelectionChanged: (selection) => _setPeriod(selection.first),
      ),
      const SizedBox(height: 16),
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_error != null && !(_screen == 1 && _screenTime != null))
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ),
        )
      else if (_screen == 0)
        _activityContent(context)
      else
        _screenTimeContent(context),
    ],
  );

  Widget _activityContent(BuildContext context) {
    final data = _activity ?? const <String, dynamic>{};
    final seconds = data['totalFocusSeconds'] as int? ?? 0;
    final sessions = data['completedSessions'] as int? ?? 0;
    final days = (data['days'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final color = Theme.of(context).colorScheme.primary;
    final maxSeconds = days.fold<int>(
      1,
      (max, row) => (row['focusSeconds'] as int? ?? 0) > max
          ? row['focusSeconds'] as int
          : max,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Focused time',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatSeconds(seconds),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        '$sessions completed ${sessions == 1 ? 'session' : 'sessions'}',
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.timer_outlined, size: 32),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_period != _Period.year)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Focus activity',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(_periodLabel),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (days.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(
                        child: Text(
                          'Complete a focus session to see your activity.',
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 142,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: days.map((row) {
                          final value = row['focusSeconds'] as int? ?? 0;
                          final height = value == 0
                              ? 4.0
                              : (value / maxSeconds * 94)
                                    .clamp(8, 94)
                                    .toDouble();
                          final date = DateTime.tryParse(
                            row['date'] as String? ?? '',
                          );
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (value > 0)
                                    Text(
                                      _compactDuration(value),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                      maxLines: 1,
                                    ),
                                  const SizedBox(height: 5),
                                  Container(
                                    height: height,
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    _dateLabel(date),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        _activityCategoryMix(context, data),
        const SizedBox(height: 12),
        _heatmapCard(),
        const SizedBox(height: 12),
        _selectedDayCard(context),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.public),
            title: const Text('Local time zone'),
            subtitle: Text(data['timezone'] as String? ?? 'UTC'),
          ),
        ),
      ],
    );
  }

  Widget _activityCategoryMix(BuildContext context, Map<String, dynamic> data) {
    final categories = (data['categories'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final values = [
      for (final category in categories) category['focusSeconds'] as int? ?? 0,
    ];
    final total = values.fold<int>(0, (sum, value) => sum + value);
    final categoryColors = [
      for (final category in categories)
        _activityColor(category['name'] as String? ?? 'Uncategorized'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Activity mix',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _selectedRangeLabel,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (total == 0 || categories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(
                      child: Text(
                        'Complete a focus session to see your activity mix.',
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      SizedBox(
                        width: 126,
                        height: 126,
                        child: CustomPaint(
                          painter: _DonutPainter(
                            values: values,
                            colors: categoryColors,
                            total: total,
                            centerLabel: _compactDuration(total),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < categories.length && index < 5;
                              index++
                            )
                              _categoryLegend(
                                context,
                                categories[index],
                                categoryColors[index],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Activity by category',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              _selectedRangeLabel,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (categories.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No completed activity for this period.'),
            ),
          )
        else
          for (var index = 0; index < categories.length; index++)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: categoryColors[index],
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(
                  categories[index]['name'] as String? ?? 'Uncategorized',
                ),
                subtitle: Text(
                  '${categories[index]['completedSessions'] ?? 0} completed ${((categories[index]['completedSessions'] as int? ?? 0) == 1) ? 'session' : 'sessions'}',
                ),
                trailing: Text(
                  _formatSeconds(
                    categories[index]['focusSeconds'] as int? ?? 0,
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
      ],
    );
  }

  Widget _categoryLegend(
    BuildContext context,
    Map<String, dynamic> category,
    Color color,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            category['name'] as String? ?? 'Uncategorized',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Text(
          _compactDuration(category['focusSeconds'] as int? ?? 0),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );

  List<Color> get _activityColors => [
    Colors.teal,
    Colors.blue,
    Colors.orange,
    Colors.deepPurple,
    Colors.red,
    Colors.indigo,
    Colors.green,
    Colors.brown,
  ];

  Color _activityColor(String name) {
    final normalized = name.trim().toLowerCase();
    final known = <String, Color>{
      'study': Colors.teal,
      'coding': Colors.blue,
      'exercise': Colors.orange,
      'reading': Colors.deepPurple,
      'uncategorized': Colors.blueGrey,
    };
    final knownColor = known[normalized];
    if (knownColor != null) return knownColor;
    final stableIndex =
        normalized.runes.fold<int>(0, (sum, rune) => sum + rune) %
        _activityColors.length;
    return _activityColors[stableIndex];
  }

  Widget _screenTimeContent(BuildContext context) {
    final summary = _screenTime;
    if (summary == null ||
        (!summary.hasPermission &&
            !_screenTimeSyncEnabled &&
            summary.total == Duration.zero &&
            _screenTimeHeatmap.isEmpty)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _screenTimeSyncCard(),
          if (_error != null) _syncErrorCard(),
          _heatmapCard(),
          const SizedBox(height: 12),
          _selectedDayCard(context),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Android needs Usage Access permission to read app totals. Cloud sync starts only when you enable sync and grant this Android permission.',
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: DeviceSettings.openUsageAccessSettings,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Set up Usage Access'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    final colors = _activityColors;
    final total = summary.total.inMilliseconds;
    final apps = summary.apps;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _screenTimeSyncCard(),
        if (_error != null) _syncErrorCard(),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App screen time · ${_periodLabel.toLowerCase()}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDuration(summary.total),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(
                  _screenTimeSyncEnabled
                      ? 'Synced to your account · ${_updatedLabel(summary.queriedAt)}'
                      : 'On this device only · Android Usage Access',
                ),
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
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Screen time mix',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(_periodLabel),
                  ],
                ),
                const SizedBox(height: 12),
                if (total == 0 || apps.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(
                      child: Text('No screen time recorded for this period.'),
                    ),
                  )
                else
                  Row(
                    children: [
                      SizedBox(
                        width: 126,
                        height: 126,
                        child: CustomPaint(
                          painter: _DonutPainter(
                            values: [
                              for (final app in apps)
                                app.duration.inMilliseconds,
                            ],
                            colors: colors,
                            total: total,
                            centerLabel: _compactDuration(total ~/ 1000),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < apps.length && index < 6;
                              index++
                            )
                              _legend(apps[index], colors[index], total),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _heatmapCard(),
        const SizedBox(height: 12),
        _selectedDayCard(context),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'All apps by screen time',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(_periodLabel),
          ],
        ),
        const SizedBox(height: 8),
        if (apps.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Nothing to show yet.'),
            ),
          )
        else
          SizedBox(
            height: (apps.length * 84.0).clamp(84.0, 420.0),
            child: ListView.builder(
              itemCount: apps.length,
              itemBuilder: (context, index) =>
                  _appTile(apps[index], colors[index % colors.length], total),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _loadScreenTime,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ),
      ],
    );
  }

  Widget _screenTimeSyncCard() => Card(
    child: SwitchListTile(
      value: _screenTimeSyncEnabled,
      onChanged: _syncingScreenTime ? null : _setScreenTimeSync,
      title: Text(
        _screenTimeSyncEnabled
            ? 'Screen-time sync is on'
            : 'Sync screen time to your account',
      ),
      subtitle: Text(
        _screenTimeSyncEnabled
            ? 'Daily app totals are stored in your private account. Turning this off deletes synced records.'
            : 'Optional: upload daily app names and totals for cross-device Screen time Insights. No event timeline is uploaded.',
      ),
      secondary: _syncingScreenTime
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.cloud_sync_outlined),
    ),
  );

  Widget _syncErrorCard() => Card(
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        'Screen-time cloud sync failed. The Android summary remains available on this device. $_error',
      ),
    ),
  );

  String _updatedLabel(String? value) {
    if (value == null) return 'not synced yet';
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return 'not synced yet';
    return 'updated ${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _legend(ScreenTimeApp app, Color color, int total) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            app.appLabel ?? app.packageName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Text(
          _compactDuration(app.duration.inSeconds),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );

  Widget _appTile(ScreenTimeApp app, Color color, int total) {
    final fraction = total == 0
        ? 0.0
        : (app.duration.inMilliseconds / total).clamp(0, 1).toDouble();
    final percent = (fraction * 100).toStringAsFixed(1);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            FutureBuilder<AppInfo>(
              future: AppInfoService.getAppInfo(
                app.packageName,
                fallbackLabel: app.appLabel,
              ),
              builder: (context, snapshot) {
                final info = snapshot.data;
                final iconBytes = info?.iconBytes;
                if (iconBytes != null) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      iconBytes,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stack) =>
                          _appIconFallback(app, color, info?.label),
                    ),
                  );
                }
                return _appIconFallback(app, color, info?.label);
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FutureBuilder<AppInfo>(
                    future: AppInfoService.getAppInfo(
                      app.packageName,
                      fallbackLabel: app.appLabel,
                    ),
                    builder: (context, snapshot) => Text(
                      snapshot.data?.label ?? app.appLabel ?? app.packageName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${_formatDuration(app.duration)} · $percent% of observed',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(value: fraction, color: color),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _appIconFallback(
    ScreenTimeApp app,
    Color color,
    String? resolvedLabel,
  ) {
    final label = (resolvedLabel ?? app.appLabel ?? app.packageName).trim();
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: .14),
      foregroundColor: color,
      child: Text(label.isEmpty ? '?' : label.substring(0, 1).toUpperCase()),
    );
  }

  String get _periodLabel => switch (_period) {
    _Period.day => 'Today',
    _Period.week => 'This week',
    _Period.month => 'This month',
    _Period.year => '$_heatmapYear',
  };
  String get _selectedRangeLabel =>
      _period == _Period.year ? '$_heatmapYear' : _periodLabel;
  String _dateLabel(DateTime? date) {
    if (date == null) return '';
    if (_period == _Period.year) return _monthName(date.month);
    if (_period == _Period.month) return '${date.day}';
    return const [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ][date.weekday - 1];
  }

  String _monthName(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
  String _formatSeconds(int value) => _formatDuration(Duration(seconds: value));
  String _compactDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    if (duration.inHours > 0) return '${duration.inHours}h';
    if (duration.inMinutes > 0) return '${duration.inMinutes}m';
    return '${duration.inSeconds}s';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) return '$hours h ${minutes.toString().padLeft(2, '0')} min';
    return '${duration.inMinutes} min';
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.values,
    required this.colors,
    required this.total,
    required this.centerLabel,
  });
  final List<int> values;
  final List<Color> colors;
  final int total;
  final String centerLabel;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(
      center: center,
      radius: size.shortestSide * .43,
    );
    final background = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 17;
    canvas.drawCircle(center, size.shortestSide * .43, background);
    var start = -3.141592653589793 / 2;
    for (var index = 0; index < values.length; index++) {
      final sweep = values[index] / total * 6.283185307179586;
      final paint = Paint()
        ..color = colors[index % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 17
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
    final textPainter = TextPainter(
      text: TextSpan(
        text: centerLabel,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * .7);
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.total != total;
}
