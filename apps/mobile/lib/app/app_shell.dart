import 'dart:async';
import 'dart:convert';

import 'package:dream_force/features/activities/domain/activity_draft.dart';
import 'package:dream_force/features/auth/presentation/auth_gate.dart';
import 'package:dream_force/features/activities/presentation/choose_activity_screen.dart';
import 'package:dream_force/features/activities/presentation/create_activity_screen.dart';
import 'package:dream_force/features/insights/presentation/insights_screen.dart';
import 'package:dream_force/features/plan/presentation/plan_screen.dart';
import 'package:dream_force/features/profile/presentation/profile_screen.dart';
import 'package:dream_force/features/today/presentation/today_screen.dart';
import 'package:dream_force/features/timer/domain/focus_session.dart';
import 'package:dream_force/features/auth/data/dream_force_auth_api.dart';

import 'package:material_ui/material_ui.dart';

enum _ShellPage {
  today,
  plan,
  insights,
  profile,
  chooseActivity,
  createActivity,
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
    ),
    const ActivityDraft(name: 'Coding', icon: Icons.code, plannedMinutes: 60),
    const ActivityDraft(
      name: 'Exercise',
      icon: Icons.directions_run_outlined,
      plannedMinutes: 30,
    ),
    const ActivityDraft(
      name: 'Reading',
      icon: Icons.auto_stories_outlined,
      plannedMinutes: 30,
    ),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(_restoreCurrentSession());
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
    } catch (_) {
      // Keep the dashboard usable if session recovery is temporarily offline.
    }
  }

  int get _selectedIndex => switch (_page) {
    _ShellPage.today ||
    _ShellPage.chooseActivity ||
    _ShellPage.createActivity => 0,
    _ShellPage.plan => 1,
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
        'iconKey': 'focus',
        'plannedMinutes': activity.plannedMinutes.clamp(1, 480),
      },
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    setState(() {
      _activities.add(
        ActivityDraft.seconds(
          name: activity.name,
          icon: activity.icon,
          plannedSeconds: activity.plannedSeconds,
          templateId: body['id'] as String?,
        ),
      );
      _page = _ShellPage.chooseActivity;
    });
  }

  Future<void> _startSession(ActivityDraft activity) async {
    final response = await const DreamForceAuthApi().request(
      'POST',
      '/v1/sessions',
      idempotencyKey: DreamForceAuthApi.newRequestId(),
      body: {
        'templateId': activity.templateId,
        'name': activity.name,
        'iconKey': 'focus',
        'plannedMinutes': activity.plannedMinutes.clamp(1, 480),
        'timezone': 'Asia/Dhaka',
      },
    );
    final remote = jsonDecode(response.body) as Map<String, dynamic>;
    setState(() {
      _session?.dispose();
      _session = FocusSession(
        activity,
        remoteId: remote['id'] as String?,
        version: remote['version'] as int? ?? 1,
        phaseTargetEndAt: DateTime.tryParse(
          remote['phaseTargetEndAt'] as String? ?? '',
        )?.toLocal(),
      );
      _page = _ShellPage.today;
    });
  }

  void _deleteSession() => setState(() {
    if (_session?.status != SessionStatus.completed) _session?.cancel();
    _session?.dispose();
    _session = null;
  });

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  Widget _currentPage() => switch (_page) {
    _ShellPage.today => TodayScreen(
      onChooseActivity: () => setState(() => _page = _ShellPage.chooseActivity),
      session: _session,
      onDeleteSession: _deleteSession,
    ),
    _ShellPage.plan => const PlanScreen(),
    _ShellPage.insights => const InsightsScreen(),
    _ShellPage.profile => ProfileScreen(
      user: widget.user,
      onLogout: widget.onLogout,
    ),
    _ShellPage.chooseActivity => ChooseActivityScreen(
      activities: _activities,
      onBack: () => setState(() => _page = _ShellPage.today),
      onCreateActivity: () => setState(() => _page = _ShellPage.createActivity),
      onStart: _startSession,
    ),
    _ShellPage.createActivity => CreateActivityScreen(
      onBack: () => setState(() => _page = _ShellPage.chooseActivity),
      onSave: _saveActivity,
    ),
  };

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: _currentPage()),
    floatingActionButton: _page == _ShellPage.today
        ? FloatingActionButton(
            onPressed: () => setState(() => _page = _ShellPage.chooseActivity),
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
