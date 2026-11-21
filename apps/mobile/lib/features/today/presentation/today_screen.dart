import 'dart:async';
import 'dart:convert';

import 'package:dream_force/core/platform/plan_reminder.dart';
import 'package:dream_force/core/platform/session_media.dart';
import 'package:dream_force/features/activities/domain/activity_draft.dart';
import 'package:dream_force/features/auth/data/dream_force_auth_api.dart';
import 'package:dream_force/features/plan/presentation/plan_occurrence_card.dart';
import 'package:dream_force/features/timer/domain/focus_session.dart';
import 'package:dream_force/features/timer/presentation/session_complete_screen.dart';
import 'package:dream_force/features/timer/presentation/timer_screen.dart';
import 'package:material_ui/material_ui.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({
    required this.onChooseActivity,
    required this.onStartActivity,
    required this.session,
    required this.onDeleteSession,
    required this.onReviewToday,
    this.active = true,
    this.refreshToken = 0,
    super.key,
  });

  final VoidCallback onChooseActivity;
  final Future<void> Function(ActivityDraft activity, String occurrenceId)
  onStartActivity;
  final FocusSession? session;
  final VoidCallback onDeleteSession;
  final VoidCallback onReviewToday;
  final bool active;
  final int refreshToken;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final _api = const DreamForceAuthApi();
  List<Map<String, dynamic>>? _occurrences;
  var _loading = false;
  var _refreshing = false;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _loading = true;
      unawaited(_load(initial: true));
    }
  }

  @override
  void didUpdateWidget(TodayScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final becameActive = widget.active && !oldWidget.active;
    final refresh = widget.refreshToken != oldWidget.refreshToken;
    if (!becameActive && !refresh) return;
    if (_occurrences == null) {
      _loading = true;
    } else {
      _refreshing = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_load(initial: true));
    });
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _load({bool background = false, bool initial = false}) async {
    if (!initial && mounted) {
      setState(() {
        if (background && _occurrences != null) {
          _refreshing = true;
        } else {
          _loading = true;
        }
        _error = null;
      });
    }
    try {
      final response = await _api.request(
        'GET',
        '/v1/plans/current?localDate=${_today()}',
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final occurrences = (body['occurrences'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Map<String, dynamic>.from)
          .toList();
      unawaited(
        SessionMedia.schedulePlanReminders(
          remindersForToday(occurrences, DateTime.now()),
        ),
      );
      if (mounted) {
        setState(() {
          _occurrences = occurrences;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is AuthApiException
              ? error.message
              : 'Could not load today’s plan.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _skip(Map<String, dynamic> occurrence) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.request(
        'PATCH',
        '/v1/plan-occurrences/${occurrence['id']}',
        body: {'state': 'skipped'},
      );
      await _load(background: true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is AuthApiException
              ? error.message
              : 'Could not skip this activity.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _start(
    Map<String, dynamic> occurrence,
    ActivityDraft activity,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onStartActivity(activity, occurrence['id'] as String);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is AuthApiException
              ? error.message
              : 'Could not start this planned activity.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    if (session == null) return _buildContent(context);
    return AnimatedBuilder(
      animation: session,
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final session = widget.session;
    if (session?.status == SessionStatus.completed) {
      return SessionCompleteScreen(
        session: session!,
        onDone: widget.onDeleteSession,
        onStartAnother: widget.onChooseActivity,
      );
    }
    if (session != null && session.status != SessionStatus.cancelled) {
      return TimerScreen(session: session, onDelete: widget.onDeleteSession);
    }
    final occurrences = _occurrences;
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
                  onPressed: widget.onChooseActivity,
                  icon: const Icon(Icons.add),
                  label: const Text('Choose activity'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text("Today's plan", style: Theme.of(context).textTheme.titleLarge),
        if (_refreshing) ...[
          const SizedBox(height: 8),
          const LinearProgressIndicator(),
        ],
        const SizedBox(height: 8),
        if (_loading && occurrences == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (occurrences != null && occurrences.isNotEmpty)
          for (final occurrence in occurrences)
            PlanOccurrenceCard(
              occurrence: occurrence,
              busy: _busy,
              onStart: (activity) => _start(occurrence, activity),
              onSkip: () {
                unawaited(_skip(occurrence));
              },
            )
        else if (_error == null)
          const Card(
            child: ListTile(
              leading: Icon(Icons.event_note_outlined),
              title: Text('No activities planned'),
              subtitle: Text('Build your week from the Plan tab.'),
            ),
          ),
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
              onPressed: _busy ? null : () => _load(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Close your day with a reflection'),
                const SizedBox(height: 4),
                const Text(
                  'You can review today even if no activity is complete.',
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.onReviewToday,
                  child: const Text('Review today'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
