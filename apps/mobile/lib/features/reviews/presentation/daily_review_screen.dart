import 'dart:convert';

import 'package:dream_force/core/platform/device_settings.dart';
import 'package:dream_force/features/auth/data/dream_force_auth_api.dart';
import 'package:material_ui/material_ui.dart';

class DailyReviewScreen extends StatefulWidget {
  const DailyReviewScreen({
    required this.localDate,
    required this.onDone,
    super.key,
  });

  final String localDate;
  final VoidCallback onDone;

  @override
  State<DailyReviewScreen> createState() => _DailyReviewScreenState();
}

class _DailyReviewScreenState extends State<DailyReviewScreen> {
  static const _suggestedReasons = [
    'Appointment',
    'Low energy',
    'Unexpected work',
    'Distractions',
    'Too many tasks',
    'Other',
  ];

  final _api = const DreamForceAuthApi();
  final _summary = TextEditingController();
  final _reflection = TextEditingController();
  final Set<String> _reasons = {};
  String? _mood;
  String _timezone = 'UTC';
  int? _version;
  int _plannedCount = 0;
  int _completedCount = 0;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _summary.dispose();
    _reflection.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _timezone = await DeviceSettings.getDeviceTimezone();
      final response = await _api.request(
        'GET',
        '/v1/daily-reviews/${widget.localDate}',
      );
      final review = jsonDecode(response.body);
      if (review is Map<String, dynamic>) {
        _version = (review['version'] as num?)?.toInt();
        _mood = review['mood'] as String?;
        _summary.text = review['summary'] as String? ?? '';
        _reflection.text = review['reflection'] as String? ?? '';
        _reasons
          ..clear()
          ..addAll(
            (review['reasonTags'] as List<dynamic>? ?? const [])
                .whereType<String>(),
          );
        _timezone = review['timezone'] as String? ?? _timezone;
      }
      try {
        final occurrencesResponse = await _api.request(
          'GET',
          '/v1/plan-occurrences?localDate=${widget.localDate}',
        );
        final occurrences = jsonDecode(occurrencesResponse.body);
        if (occurrences is List) {
          _plannedCount = occurrences.length;
          _completedCount = occurrences
              .whereType<Map<String, dynamic>>()
              .where((item) => item['displayState'] == 'completed')
              .length;
        }
      } catch (_) {
        // The review remains available even if plan progress cannot load.
      }
    } catch (error) {
      _error = error is AuthApiException
          ? error.message
          : 'Could not load this day’s review.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response = await _api.request(
        'PUT',
        '/v1/daily-reviews/${widget.localDate}',
        body: {
          'timezone': _timezone,
          'mood': _mood,
          'summary': _summary.text.trim().isEmpty ? null : _summary.text.trim(),
          'reflection': _reflection.text.trim().isEmpty
              ? null
              : _reflection.text.trim(),
          'reasonTags': _reasons.toList(growable: false),
          if (_version != null) 'version': _version,
        },
      );
      final saved = jsonDecode(response.body) as Map<String, dynamic>;
      _version = (saved['version'] as num?)?.toInt();
      if (mounted) widget.onDone();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AuthApiException
              ? error.message
              : 'Could not save this review.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this review?'),
        content: const Text(
          'This permanently deletes the reflection and selected reasons for this date.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep review'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await _api.request('DELETE', '/v1/daily-reviews/${widget.localDate}');
      if (mounted) widget.onDone();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is AuthApiException
              ? error.message
              : 'Could not delete this review.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _dateLabel {
    final date = DateTime.tryParse(widget.localDate);
    if (date == null) return widget.localDate;
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) => _loading
      ? const Center(child: CircularProgressIndicator())
      : ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: widget.onDone,
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Daily review',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                if (_version != null)
                  TextButton(
                    onPressed: _saving ? null : _delete,
                    child: const Text('Delete'),
                  ),
              ],
            ),
            Text('$_dateLabel · ${_timezone.replaceAll('_', ' ')}'),
            const SizedBox(height: 18),
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _plannedCount == 0
                          ? 'No activities planned today'
                          : '$_completedCount of $_plannedCount planned activities completed',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    const Text('There’s room to reflect on any kind of day.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'How did today feel?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final value in const [
                  ('positive', 'Positive'),
                  ('mixed', 'Mixed'),
                  ('difficult', 'Difficult'),
                ])
                  ChoiceChip(
                    label: Text(value.$2),
                    selected: _mood == value.$1,
                    onSelected: (_) => setState(
                      () => _mood = _mood == value.$1 ? null : value.$1,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _reflection,
              maxLength: 5000,
              minLines: 7,
              maxLines: 12,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What happened today?',
                hintText: 'Write freely about what went well, what got in the way, or what you need tomorrow.',
                helperText: 'Private to your account',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _summary,
              maxLength: 1000,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'What did you do? (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'What got in the way?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                for (final reason in _suggestedReasons)
                  FilterChip(
                    label: Text(reason),
                    selected: _reasons.contains(reason),
                    onSelected: (selected) => setState(
                      () => selected
                          ? _reasons.add(reason)
                          : _reasons.remove(reason),
                    ),
                  ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save review'),
            ),
          ],
        );
}
