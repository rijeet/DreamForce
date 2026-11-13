import 'package:dream_force/app/app_shell.dart';
import 'package:dream_force/core/theme/dream_force_theme.dart';
import 'package:dream_force/features/auth/presentation/auth_gate.dart';
import 'package:material_ui/material_ui.dart';

class DreamForceApp extends StatelessWidget {
  const DreamForceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Dream Force',
    debugShowCheckedModeBanner: false,
    theme: DreamForceTheme.light(),
    darkTheme: DreamForceTheme.dark(),
    home: AuthGate(child: (user) => AppShell(user: user)),
  );
}
