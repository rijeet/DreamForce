import 'package:material_ui/material_ui.dart';

class ActivityDraft {
  const ActivityDraft({
    required this.name,
    required this.icon,
    required int plannedMinutes,
    this.iconKey = 'focus',
    this.category,
    this.templateId,
  }) : plannedSeconds = plannedMinutes * 60;
  const ActivityDraft.seconds({
    required this.name,
    required this.icon,
    required this.plannedSeconds,
    this.iconKey = 'focus',
    this.category,
    this.templateId,
  });
  final String? templateId;
  final String iconKey;
  final String? category;
  final String name;
  final IconData icon;
  final int plannedSeconds;
  int get plannedMinutes => (plannedSeconds / 60).ceil();
}
