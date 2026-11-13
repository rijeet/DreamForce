import 'package:dream_force/features/activities/presentation/choose_activity_screen.dart';
import 'package:dream_force/features/insights/presentation/insights_screen.dart';
import 'package:dream_force/features/plan/presentation/plan_screen.dart';
import 'package:dream_force/features/profile/presentation/profile_screen.dart';
import 'package:dream_force/features/today/presentation/today_screen.dart';
import 'package:material_ui/material_ui.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  var _selectedIndex = 0;

  static const _pages = <Widget>[
    TodayScreen(),
    PlanScreen(),
    InsightsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: _pages[_selectedIndex]),
    floatingActionButton: FloatingActionButton(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ChooseActivityScreen()),
      ),
      tooltip: 'Choose activity',
      child: const Icon(Icons.add),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    bottomNavigationBar: NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) => setState(() => _selectedIndex = index),
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
