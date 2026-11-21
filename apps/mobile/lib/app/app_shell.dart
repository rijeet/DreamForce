import 'dart:async';
import 'dart:convert';

import 'package:dream_force/features/activities/domain/activity_draft.dart';
import 'package:dream_force/features/auth/presentation/auth_gate.dart';
import 'package:dream_force/features/activities/presentation/choose_activity_screen.dart';
import 'package:dream_force/features/activities/presentation/create_activity_screen.dart';
import 'package:dream_force/features/insights/presentation/insights_screen.dart';
import 'package:dream_force/features/reviews/presentation/daily_review_screen.dart';
import 'package:dream_force/features/plan/presentation/plan_screen.dart';
import 'package:dream_force/features/profile/presentation/profile_screen.dart';
import 'package:dream_force/features/today/presentation/today_screen.dart';
import 'package:dream_force/features/timer/domain/focus_session.dart';
import 'package:dream_force/features/auth/data/dream_force_auth_api.dart';
import 'package:dream_force/core/platform/session_media.dart';
import 'package:dream_force/core/platform/session_notice.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:material_ui/material_ui.dart';

enum _ShellPage {
  today,
  plan,
  insights,
  profile,
  chooseActivity,
  createActivity,
  dailyReview,
}

class AppShell extends StatefulWidget {
  const AppShell({required this.user, required this.onLogout, super.key});
  final SignedInUser user;
  final Future<void> Function() onLogout;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _page = _ShellPage.today;
  FocusSession? _session;
  final _activities = <ActivityDraft>[
    const ActivityDraft(
      name: 'Study',
      icon: Icons.menu_book_outlined,
      plannedMinutes: 45,
      iconKey: 'study',
      category: 'Study',
    ),
    const ActivityDraft(
      name: 'Coding',
      icon: Icons.code,
      plannedMinutes: 60,
      iconKey: 'coding',
      category: 'Coding',
    ),
    const ActivityDraft(
      name: 'Exercise',
      icon: Icons.directions_run_outlined,
      plannedMinutes: 30,
      iconKey: 'exercise',
      category: 'Exercise',
    ),
    const ActivityDraft(
      name: 'Reading',
      icon: Icons.auto_stories_outlined,
      plannedMinutes: 30,
      iconKey: 'reading',
      category: 'Reading',
    ),
  ];
  String _reviewDate = '';
  _ShellPage _reviewReturnPage = _ShellPage.today;
  var _planRefresh = 0;
  FocusSession? _mediaSession;
  int? _mediaPhaseIndex;
  String? _mediaPhaseName;
  SessionStatus? _mediaStatus;
  var _transportBusy = false;
  var _notificationOfferStarted = false;

  @override
  void initState() {
    super.initState();
    SessionMedia.setTransportHandler(_onSessionTransport);
    unawaited(_restoreCurrentSession());
    unawaited(_loadActivities());
  }

  Future<void> _restoreCurrentSession() async {
    try {
      final response = await const DreamForceAuthApi().request(
        'GET',
        '/v1/sessions/current',
      );
      final value = jsonDecode(response.body);
      if (value is! Map<String, dynamic> || !mounted || _session != null) {
        return;
      }
      final plannedMinutes = (value['plannedMinutes'] as num?)?.toInt() ?? 25;
      final remoteStatus = switch (value['status']) {
        'paused' => SessionStatus.paused,
        'completed' => SessionStatus.completed,
        'cancelled' => SessionStatus.cancelled,
        _ => SessionStatus.running,
      };
      setState(() {
        _session = FocusSession(
          ActivityDraft(
            name: value['name'] as String? ?? 'Focus session',
            icon: Icons.timer_outlined,
            iconKey: value['iconKey'] as String? ?? 'focus',
            plannedMinutes: plannedMinutes,
          ),
          remoteId: value['id'] as String?,
          version: value['version'] as int? ?? 1,
          phaseIndex: value['currentPhaseIndex'] as int? ?? 0,
          status: remoteStatus,
          pausedAt: DateTime.tryParse(value['pausedAt'] as String? ?? '')
              ?.toLocal(),
          phaseTargetEndAt: DateTime.tryParse(
            value['phaseTargetEndAt'] as String? ?? '',
          )?.toLocal(),
        );
      });
      _attachSessionMedia(_session);
    } catch (_) {
      // Keep the dashboard usable if session recovery is temporarily offline.
    }
  }

  int get _selectedIndex => switch (_page) {
    _ShellPage.today ||
    _ShellPage.chooseActivity ||
    _ShellPage.createActivity => 0,
    _ShellPage.plan => 1,
    _ShellPage.dailyReview => _reviewReturnPage == _ShellPage.plan ? 1 : 0,
    _ShellPage.insights => 2,
    _ShellPage.profile => 3,
  };

  void _selectNavigation(int index) => setState(() {
    _page = switch (index) {
      0 => _ShellPage.today,
      1 => _ShellPage.plan,
      2 => _ShellPage.insights,
      _ => _ShellPage.profile,
    };
  });

  Future<void> _saveActivity(ActivityDraft activity) async {
    final response = await const DreamForceAuthApi().request(
      'POST',
      '/v1/activity-templates',
      body: {
        'name': activity.name,
        'iconKey': activity.iconKey,
        'category': activity.category,
        'plannedMinutes': activity.plannedMinutes.clamp(1, 480),
      },
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    setState(() {
      _activities.add(
        ActivityDraft.seconds(
          name: activity.name,
          icon: activity.icon,
          iconKey: activity.iconKey,
          category: activity.category,
          plannedSeconds: activity.plannedSeconds,
          templateId: body['id'] as String?,
        ),
      );
      _page = _ShellPage.chooseActivity;
    });
  }

  Future<void> _loadActivities() async {
    try {
      var response = await const DreamForceAuthApi().request(
        'GET',
        '/v1/activity-templates',
      );
      var rows = jsonDecode(response.body) as List<dynamic>;
      if (rows.isEmpty) {
        for (final activity in _activities) {
          await const DreamForceAuthApi().request(
            'POST',
            '/v1/activity-templates',
            body: {
              'name': activity.name,
              'iconKey': activity.iconKey,
              'category': activity.category,
              'plannedMinutes': activity.plannedMinutes.clamp(1, 480),
            },
          );
        }
        response = await const DreamForceAuthApi().request(
          'GET',
          '/v1/activity-templates',
        );
        rows = jsonDecode(response.body) as List<dynamic>;
      }
      final loaded = rows.whereType<Map<String, dynamic>>().map((item) {
        final iconKey = item['iconKey'] as String? ?? 'focus';
        return ActivityDraft.seconds(
          name: item['name'] as String? ?? 'Activity',
          icon: _activityIcon(iconKey),
          iconKey: iconKey,
          category: item['category'] as String?,
          templateId: item['id'] as String?,
          plannedSeconds:
              ((item['plannedMinutes'] as num?)?.toInt() ?? 25) * 60,
        );
      }).toList();
      if (mounted && loaded.isNotEmpty) {
        setState(() {
          _activities
            ..clear()
            ..addAll(loaded);
        });
      }
    } catch (_) {
      // Keep the built-in local choices available if template sync is offline.
    }
  }

  IconData _activityIcon(String key) => switch (key) {
    'study' => Icons.menu_book_outlined,
    'coding' => Icons.code,
    'exercise' => Icons.directions_run_outlined,
    'reading' => Icons.auto_stories_outlined,
    'focus' => Icons.bolt_outlined,
    _ => Icons.task_alt_outlined,
  };

  Future<void> _startSession(
    ActivityDraft activity, {
    String? planOccurrenceId,
  }) async {
    final response = await const DreamForceAuthApi().request(
      'POST',
      '/v1/sessions',
      idempotencyKey: DreamForceAuthApi.newRequestId(),
      body: {
        'templateId': activity.templateId,
        'name': activity.name,
        'planOccurrenceId': planOccurrenceId,
        'iconKey': activity.iconKey,
        'category': activity.category,
        'plannedMinutes': activity.plannedMinutes.clamp(1, 480),
        'timezone': 'Asia/Dhaka',
      },
    );
    final remote = jsonDecode(response.body) as Map<String, dynamic>;
    final previous = _session;
    setState(() {
      _session = FocusSession(
        activity,
        remoteId: remote['id'] as String?,
        version: remote['version'] as int? ?? 1,
        phaseTargetEndAt: DateTime.tryParse(
          remote['phaseTargetEndAt'] as String? ?? '',
        )?.toLocal(),
      );
      _planRefresh += 1;
      _page = _ShellPage.today;
    });
    _attachSessionMedia(_session);
    previous?.dispose();
  }

  void _openReview(String localDate, {_ShellPage? returnPage}) => setState(() {
    _reviewDate = localDate;
    _reviewReturnPage = returnPage ?? _page;
    _page = _ShellPage.dailyReview;
  });

  void _deleteSession() {
    final session = _session;
    _attachSessionMedia(null);
    setState(() {
      if (session?.status != SessionStatus.completed) session?.cancel();
      session?.dispose();
      _session = null;
      _planRefresh += 1;
    });
  }

  void _attachSessionMedia(FocusSession? session) {
    if (identical(_mediaSession, session)) return;
    _mediaSession?.removeListener(_onMediaSession);
    _mediaSession = session;
    _mediaPhaseIndex = session?.phaseIndex;
    _mediaPhaseName = session?.phaseName;
    _mediaStatus = session?.status;
    if (session == null) {
      unawaited(SessionMedia.hide());
      return;
    }
    session.addListener(_onMediaSession);
    unawaited(_syncMedia(session));
    unawaited(_offerNotificationPermission());
  }

  void _onMediaSession() {
    final session = _mediaSession;
    final previousPhase = _mediaPhaseName;
    final previousIndex = _mediaPhaseIndex;
    final previousStatus = _mediaStatus;
    if (session == null ||
        previousPhase == null ||
        previousIndex == null ||
        previousStatus == null) {
      return;
    }
    final notice = SessionNotice.forTransition(
      previousPhase: previousPhase,
      previousPhaseIndex: previousIndex,
      previousStatus: _statusName(previousStatus),
      phaseIndex: session.phaseIndex,
      status: _statusName(session.status),
    );
    _mediaPhaseIndex = session.phaseIndex;
    _mediaPhaseName = session.phaseName;
    _mediaStatus = session.status;
    unawaited(_syncMedia(session, notice: notice));
  }

  Future<void> _syncMedia(FocusSession session, {SessionNotice? notice}) async {
    if (notice != null) await SessionMedia.alert(notice);
    if (session.status == SessionStatus.completed ||
        session.status == SessionStatus.cancelled) {
      await SessionMedia.hide();
      return;
    }
    final durationMs = session.phaseSeconds * 1000;
    await SessionMedia.update(
      title: session.activity.name,
      subtitle: session.status == SessionStatus.paused
          ? 'Paused · ${session.phaseName}'
          : session.phaseName,
      positionMs: session.elapsedSeconds * 1000,
      durationMs: durationMs,
      playing: session.status == SessionStatus.running,
    );
  }

  Future<void> _onSessionTransport(String action) async {
    final session = _mediaSession;
    if (session == null || _transportBusy) return;
    final pause = action == 'pause' && session.status == SessionStatus.running;
    final resume = action == 'resume' && session.status == SessionStatus.paused;
    if (!pause && !resume) return;
    _transportBusy = true;
    try {
      await session.togglePause();
    } catch (_) {
      // The session puts itself back and the card follows that state.
    } finally {
      _transportBusy = false;
    }
  }

  Future<void> _offerNotificationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    if (_notificationOfferStarted || !mounted) return;
    try {
      await _askForSessionNotification();
    } catch (_) {
      // The in-app timer still runs if the permission prompt cannot be shown.
    }
  }

  Future<void> _askForSessionNotification() async {
    if (await SessionMedia.hasNotificationPermission() || !mounted) return;
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool('session_notification_asked') == true || !mounted) {
      return;
    }
    _notificationOfferStarted = true;
    final enable = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Show the running session?'),
        content: const Text(
          'Dream Force can keep this session in the notification shade, with the time left and pause, and play a sound when a block finishes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    await preferences.setBool('session_notification_asked', true);
    if (enable != true || !mounted) return;
    final granted = await SessionMedia.requestNotificationPermission();
    final session = _mediaSession;
    if (granted && session != null) await _syncMedia(session);
  }

  String _statusName(SessionStatus status) => switch (status) {
    SessionStatus.running => 'running',
    SessionStatus.paused => 'paused',
    SessionStatus.completed => 'completed',
    SessionStatus.cancelled => 'cancelled',
  };

  @override
  void dispose() {
    SessionMedia.setTransportHandler(null);
    _attachSessionMedia(null);
    _session?.dispose();
    super.dispose();
  }

  Widget? _overlayPage() => switch (_page) {
    _ShellPage.chooseActivity => ChooseActivityScreen(
      activities: _activities,
      onBack: () => setState(() => _page = _ShellPage.today),
      onCreateActivity: () => setState(() => _page = _ShellPage.createActivity),
      onStart: (activity) => _startSession(activity),
    ),
    _ShellPage.createActivity => CreateActivityScreen(
      onBack: () => setState(() => _page = _ShellPage.chooseActivity),
      onSave: _saveActivity,
    ),
    _ShellPage.dailyReview => DailyReviewScreen(
      localDate: _reviewDate,
      onDone: () => setState(() => _page = _reviewReturnPage),
    ),
    _ => null,
  };

  String _todayLocalDate() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final overlay = _overlayPage();
    return Scaffold(
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            IndexedStack(
              index: _selectedIndex,
              sizing: StackFit.expand,
              children: [
                TodayScreen(
                  active: _page == _ShellPage.today,
                  refreshToken: _planRefresh,
                  onChooseActivity: () =>
                      setState(() => _page = _ShellPage.chooseActivity),
                  onStartActivity: (activity, occurrenceId) =>
                      _startSession(activity, planOccurrenceId: occurrenceId),
                  session: _session,
                  onDeleteSession: _deleteSession,
                  onReviewToday: () => _openReview(
                    _todayLocalDate(),
                    returnPage: _ShellPage.today,
                  ),
                ),
                PlanScreen(
                  active: _page == _ShellPage.plan,
                  refreshToken: _planRefresh,
                  onReview: (date) =>
                      _openReview(date, returnPage: _ShellPage.plan),
                  onStartActivity: (activity, occurrenceId) =>
                      _startSession(activity, planOccurrenceId: occurrenceId),
                ),
                InsightsScreen(active: _page == _ShellPage.insights),
                ProfileScreen(
                  active: _page == _ShellPage.profile,
                  user: widget.user,
                  onLogout: widget.onLogout,
                ),
              ],
            ),
            if (overlay != null)
              Positioned.fill(
                child: ColoredBox(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: overlay,
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _page == _ShellPage.today
          ? FloatingActionButton(
              onPressed: () =>
                  setState(() => _page = _ShellPage.chooseActivity),
              tooltip: 'Choose activity',
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectNavigation,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
