import 'package:dream_force/features/activities/domain/activity_draft.dart';
import 'package:dream_force/features/auth/presentation/auth_gate.dart';
import 'package:dream_force/features/activities/presentation/choose_activity_screen.dart';
import 'package:dream_force/features/activities/presentation/create_activity_screen.dart';
import 'package:dream_force/features/insights/presentation/insights_screen.dart';
import 'package:dream_force/features/plan/presentation/plan_screen.dart';
import 'package:dream_force/features/profile/presentation/profile_screen.dart';
import 'package:dream_force/features/today/presentation/today_screen.dart';
import 'package:dream_force/features/timer/domain/focus_session.dart';
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
  const AppShell({required this.user, super.key});
  final SignedInUser user;

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

  void _saveActivity(ActivityDraft activity) => setState(() {
    _activities.add(activity);
    _page = _ShellPage.chooseActivity;
  });

  void _startSession(ActivityDraft activity) => setState(() {
    _session?.dispose();
    _session = FocusSession(activity);
    _page = _ShellPage.today;
  });

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
    _ShellPage.profile => ProfileScreen(user: widget.user),
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
