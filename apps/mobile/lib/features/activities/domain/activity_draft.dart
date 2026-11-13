import 'package:material_ui/material_ui.dart';

class ActivityDraft {
  const ActivityDraft({
    required this.name,
    required this.icon,
    required int plannedMinutes,
    this.templateId,
  }) : plannedSeconds = plannedMinutes * 60;
  const ActivityDraft.seconds({
    required this.name,
    required this.icon,
    required this.plannedSeconds,
    this.templateId,
  });
  final String? templateId;
  final String name;
  final IconData icon;
  final int plannedSeconds;
  int get plannedMinutes => (plannedSeconds / 60).ceil();
}
