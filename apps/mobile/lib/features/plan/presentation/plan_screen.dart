import 'dart:async';
import 'dart:convert';

import 'package:dream_force/core/platform/plan_reminder.dart';
import 'package:dream_force/core/platform/session_media.dart';
import 'package:dream_force/features/activities/domain/activity_draft.dart';
import 'package:dream_force/features/auth/data/dream_force_auth_api.dart';
import 'package:dream_force/features/plan/presentation/plan_occurrence_card.dart';
import 'package:material_ui/material_ui.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    required this.onReview,
    required this.onStartActivity,
    this.active = true,
    this.refreshToken = 0,
    super.key,
  });

  final ValueChanged<String> onReview;
  final Future<void> Function(ActivityDraft activity, String occurrenceId)
  onStartActivity;
  final bool active;
  final int refreshToken;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _api = const DreamForceAuthApi();
  late DateTime _selectedDate;
  String _timezone = 'Asia/Dhaka';
  Map<String, dynamic>? _plan;
  List<Map<String, dynamic>> _entries = [];
  List<Map<String, dynamic>> _activities = [];
  List<Map<String, dynamic>> _occurrences = [];
  bool _loading = false;
  bool _refreshing = false;
  bool _saving = false;
  bool _editing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    if (widget.active) {
      _loading = true;
      unawaited(_load(initial: true));
    }
  }

  @override
  void didUpdateWidget(PlanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final becameActive = widget.active && !oldWidget.active;
    final refresh = widget.refreshToken != oldWidget.refreshToken;
    if (!becameActive && !refresh) return;
    if (_plan == null) {
      _loading = true;
    } else {
      _refreshing = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load(initial: true));
    });
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  bool _isToday(DateTime value) {
    final now = DateTime.now();
    return value.year == now.year &&
        value.month == now.month &&
        value.day == now.day;
  }

  IconData _icon(String? key) => switch (key) {
    'study' => Icons.menu_book_outlined,
    'coding' => Icons.code,
    'exercise' => Icons.directions_run_outlined,
    'reading' => Icons.auto_stories_outlined,
    'focus' => Icons.bolt_outlined,
    _ => Icons.task_alt_outlined,
  };

  Future<void> _load({bool background = false, bool initial = false}) async {
    if (!initial && mounted) {
      setState(() {
        if (background && _plan != null) {
          _refreshing = true;
        } else {
          _loading = true;
        }
        _error = null;
      });
    }
    try {
      await _loadOccurrences();
      _error = null;
    } catch (error) {
      _error = error is AuthApiException
          ? error.message
          : 'Could not load your weekly plan.';
    }
    if (mounted) {
      setState(() {
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _loadOccurrences() async {
    final response = await _api.request(
      'GET',
      '/v1/plans/current?localDate=${_date(_selectedDate)}',
    );
    var body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['plan'] == null) {
      await _api.request(
        'POST',
        '/v1/plans',
        body: {
          'name': 'My weekly plan',
          'timezone': 'Asia/Dhaka',
          'entries': <Object>[],
        },
      );
      final again = await _api.request(
        'GET',
        '/v1/plans/current?localDate=${_date(_selectedDate)}',
      );
      body = jsonDecode(again.body) as Map<String, dynamic>;
    }
    final plan = body['plan'];
    if (plan is! Map<String, dynamic>) {
      throw const AuthApiException('Could not load your weekly plan.');
    }
    _plan = plan;
    _timezone = plan['timezone'] as String? ?? 'Asia/Dhaka';
    _entries = (plan['entries'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
    _activities = (body['templates'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
    _occurrences = (body['occurrences'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(Map<String, dynamic>.from)
        .toList();
    if (_isToday(_selectedDate)) {
      unawaited(
        SessionMedia.schedulePlanReminders(
          remindersForToday(_occurrences, DateTime.now()),
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _dayEntries =>
      _entries
          .where(
            (entry) =>
                (entry['weekday'] as num?)?.toInt() == _selectedDate.weekday,
          )
          .toList()
        ..sort(
          (a, b) => ((a['position'] as num?)?.toInt() ?? 0).compareTo(
            (b['position'] as num?)?.toInt() ?? 0,
          ),
        );

  Future<void> _selectDay(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _refreshing = true;
      _error = null;
    });
    try {
      await _loadOccurrences();
    } catch (error) {
      _error = error is AuthApiException
          ? error.message
          : 'Could not load this day.';
    }
    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _saveEntries(List<Map<String, dynamic>> entries) async {
    final plan = _plan;
    if (plan == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response = await _api.request(
        'PUT',
        '/v1/plans/${plan['id']}',
        body: {
          'name': plan['name'],
          'timezone': _timezone,
          'version': plan['version'],
          'entries': entries,
        },
      );
      final updated = jsonDecode(response.body) as Map<String, dynamic>;
      _plan = updated;
      _entries = (updated['entries'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList();
      await _loadOccurrences();
    } catch (error) {
      _error = error is AuthApiException
          ? error.message
          : 'Could not save your weekly plan.';
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _addActivity() async {
    if (_activities.isEmpty) {
      setState(
        () => _error =
            'Create a reusable activity before adding it to your plan.',
      );
      return;
    }
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Choose an activity',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            for (final activity in _activities)
              ListTile(
                leading: CircleAvatar(
                  child: Icon(_icon(activity['iconKey'] as String?)),
                ),
                title: Text(activity['name'] as String? ?? 'Activity'),
                subtitle: Text('${activity['plannedMinutes'] ?? 25} min'),
                onTap: () => Navigator.pop(context, activity),
              ),
          ],
        ),
      ),
    );
    if (selected == null || _plan == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    final entries = List<Map<String, dynamic>>.from(_entries);
    final sameDay = entries
        .where(
          (entry) =>
              (entry['weekday'] as num?)?.toInt() == _selectedDate.weekday,
        )
        .length;
    entries.add({
      'templateId': selected['id'],
      'weekday': _selectedDate.weekday,
      'position': sameDay,
      'localStartTime': time == null
          ? null
          : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00',
      'plannedMinutesOverride': null,
    });
    await _saveEntries(entries);
  }

  Future<void> _editEntry(Map<String, dynamic> entry) async {
    final timeValue = entry['localStartTime'] as String?;
    final parts = timeValue?.split(':') ?? const [];
    TimeOfDay? selectedTime = parts.length >= 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 9,
            minute: int.tryParse(parts[1]) ?? 0,
          )
        : null;
    final durationController = TextEditingController(
      text:
          '${entry['plannedMinutesOverride'] ?? _activityFor(entry['templateId'])?['plannedMinutes'] ?? 25}',
    );
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            entry['name'] as String? ??
                _activityFor(entry['templateId'])?['name'] as String? ??
                'Edit activity',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duration in minutes',
                  helperText: '1–480 minutes',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime:
                        selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedTime = picked);
                  }
                },
                icon: const Icon(Icons.schedule),
                label: Text(
                  selectedTime == null
                      ? 'Set start time'
                      : selectedTime!.format(context),
                ),
              ),
              if (selectedTime != null)
                TextButton(
                  onPressed: () => setDialogState(() => selectedTime = null),
                  child: const Text('Clear start time'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final minutes = int.tryParse(durationController.text.trim());
                if (minutes == null || minutes < 1 || minutes > 480) return;
                Navigator.pop(context, {
                  'minutes': minutes,
                  'time': selectedTime == null
                      ? null
                      : '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}:00',
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    durationController.dispose();
    if (result == null) return;
    final entries = List<Map<String, dynamic>>.from(_entries);
    final index = entries.indexWhere(
      (item) =>
          item['templateId'] == entry['templateId'] &&
          item['weekday'] == entry['weekday'] &&
          item['position'] == entry['position'],
    );
    if (index < 0) return;
    entries[index] = {
      ...entries[index],
      'plannedMinutesOverride': result['minutes'],
      'localStartTime': result['time'],
    };
    await _saveEntries(entries);
  }

  Map<String, dynamic>? _activityFor(Object? id) {
    for (final activity in _activities) {
      if (activity['id'] == id) return activity;
    }
    return null;
  }

  Future<void> _removeEntry(Map<String, dynamic> entry) async {
    final entries = List<Map<String, dynamic>>.from(_entries)
      ..removeWhere(
        (item) =>
            item['templateId'] == entry['templateId'] &&
            item['weekday'] == entry['weekday'] &&
            item['position'] == entry['position'],
      );
    await _saveEntries(_reposition(entries, _selectedDate.weekday));
  }

  List<Map<String, dynamic>> _reposition(
    List<Map<String, dynamic>> entries,
    int weekday,
  ) {
    final day =
        entries
            .where((entry) => (entry['weekday'] as num?)?.toInt() == weekday)
            .toList()
          ..sort(
            (a, b) => ((a['position'] as num?)?.toInt() ?? 0).compareTo(
              (b['position'] as num?)?.toInt() ?? 0,
            ),
          );
    final others = entries
        .where((entry) => (entry['weekday'] as num?)?.toInt() != weekday)
        .toList();
    return [
      ...others,
      for (var i = 0; i < day.length; i++) {...day[i], 'position': i},
    ];
  }

  Future<void> _moveEntry(Map<String, dynamic> entry, int delta) async {
    final day = _dayEntries;
    final index = day.indexWhere(
      (item) =>
          item['templateId'] == entry['templateId'] &&
          item['position'] == entry['position'],
    );
    final target = index + delta;
    if (index < 0 || target < 0 || target >= day.length) return;
    final reordered = List<Map<String, dynamic>>.from(day);
    final item = reordered.removeAt(index);
    reordered.insert(target, item);
    final others = _entries
        .where(
          (item) => (item['weekday'] as num?)?.toInt() != _selectedDate.weekday,
        )
        .toList();
    await _saveEntries([
      ...others,
      for (var i = 0; i < reordered.length; i++)
        {...reordered[i], 'position': i},
    ]);
  }

  Future<void> _copyDay() async {
    final destinations = [
      for (var day = 1; day <= 7; day++)
        if (day != _selectedDate.weekday) day,
    ];
    var targetDay = destinations.first;
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Copy this day'),
          content: DropdownButtonFormField<int>(
            initialValue: targetDay,
            items: [
              for (final day in destinations)
                DropdownMenuItem(value: day, child: Text(_weekdayName(day))),
            ],
            onChanged: (value) {
              if (value != null) setDialogState(() => targetDay = value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, targetDay),
              child: const Text('Copy'),
            ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    final copies = [
      for (final entry in _dayEntries) {...entry, 'weekday': selected},
    ];
    final entries = List<Map<String, dynamic>>.from(_entries)
      ..removeWhere((entry) => (entry['weekday'] as num?)?.toInt() == selected);
    await _saveEntries(_reposition([...entries, ...copies], selected));
  }

  Future<void> _skip(Map<String, dynamic> occurrence) async {
    try {
      await _api.request(
        'PATCH',
        '/v1/plan-occurrences/${occurrence['id']}',
        body: {'state': 'skipped'},
      );
      await _loadOccurrences();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AuthApiException
              ? error.message
              : 'Could not skip this activity.',
        );
      }
    }
  }

  Future<void> _start(
    Map<String, dynamic> occurrence,
    ActivityDraft activity,
  ) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onStartActivity(activity, occurrence['id'] as String);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AuthApiException
              ? error.message
              : 'Could not start this planned activity.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _weekdayName(int weekday) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][weekday - 1];

  String _weekLabel() {
    final start = _selectedDate.subtract(
      Duration(days: _selectedDate.weekday - 1),
    );
    const months = [
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
    ];
    return 'Week of ${months[start.month - 1]} ${start.day} · ${_timezone.replaceAll('_', ' ')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _plan == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final todayEntries = _dayEntries;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _editing ? 'Edit weekly plan' : 'Your weekly plan',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() => _editing = !_editing),
              child: Text(_editing ? 'Done' : 'Edit'),
            ),
          ],
        ),
        Text(_weekLabel()),
        if (_refreshing) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 72,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 7,
            itemBuilder: (context, index) {
              final monday = _selectedDate.subtract(
                Duration(days: _selectedDate.weekday - 1),
              );
              final day = monday.add(Duration(days: index));
              final selected = _date(day) == _date(_selectedDate);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _selectDay(day),
                  child: Container(
                    width: 42,
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _weekdayName(day.weekday).substring(0, 1),
                          style: TextStyle(
                            color: selected ? Colors.white : null,
                          ),
                        ),
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Text(
                '${_weekdayName(_selectedDate.weekday)} · ${_editing ? todayEntries.length : _occurrences.length} activities',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (!_editing)
              TextButton(
                onPressed: () => widget.onReview(_date(_selectedDate)),
                child: const Text('Review'),
              ),
          ],
        ),
        if (_editing)
          for (final entry in todayEntries) _editEntryTile(context, entry)
        else if (_occurrences.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Nothing planned for this day yet. Add an activity to build your week.',
              ),
            ),
          )
        else
          for (final occurrence in _occurrences)
            _occurrenceTile(context, occurrence),
        if (_error != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _saving ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_editing) ...[
          FilledButton(
            onPressed: _saving ? null : _addActivity,
            child: const Text('Add activity'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _saving || todayEntries.isEmpty ? null : _copyDay,
            child: const Text('Copy this day'),
          ),
          const SizedBox(height: 8),
          if (_saving) const LinearProgressIndicator(),
        ] else ...[
          OutlinedButton(
            onPressed: () => widget.onReview(_date(_selectedDate)),
            child: const Text('Review this day'),
          ),
        ],
      ],
    );
  }

  Widget _editEntryTile(BuildContext context, Map<String, dynamic> entry) {
    final activity = _activityFor(entry['templateId']);
    final name = activity?['name'] as String? ?? 'Activity';
    final iconKey = activity?['iconKey'] as String?;
    final minutes =
        entry['plannedMinutesOverride'] ?? activity?['plannedMinutes'] ?? 25;
    final time = entry['localStartTime'] as String?;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          _icon(iconKey),
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${time == null ? 'Any time' : time.substring(0, 5)} · $minutes min',
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: 'Move up',
              onPressed: (entry['position'] as num?)?.toInt() == 0
                  ? null
                  : () => _moveEntry(entry, -1),
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: 'Move down',
              onPressed:
                  (entry['position'] as num?)?.toInt() == _dayEntries.length - 1
                  ? null
                  : () => _moveEntry(entry, 1),
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton(
              tooltip: 'Edit activity',
              onPressed: () => _editEntry(entry),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Remove activity',
              onPressed: () => _removeEntry(entry),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _occurrenceTile(
    BuildContext context,
    Map<String, dynamic> occurrence,
  ) {
    final activity = _activityFor(occurrence['templateId']);
    final enriched = {
      ...occurrence,
      'category': occurrence['category'] ?? activity?['category'],
    };
    return PlanOccurrenceCard(
      occurrence: enriched,
      busy: _saving,
      onStart: (activity) => _start(occurrence, activity),
      onSkip: () {
        unawaited(_skip(occurrence));
      },
    );
  }
}
