import 'package:material_ui/material_ui.dart';

class InsightHeatmapDay {
  const InsightHeatmapDay({
    required this.localDate,
    this.activitySeconds = 0,
    this.screenTimeSeconds = 0,
  });

  final String localDate;
  final int activitySeconds;
  final int screenTimeSeconds;
}

class InsightHeatmap extends StatefulWidget {
  const InsightHeatmap({
    required this.days,
    required this.year,
    required this.earliestYear,
    required this.onYearChanged,
    required this.selectedDate,
    required this.onDaySelected,
    super.key,
  });

  final List<InsightHeatmapDay> days;
  final int year;
  final int earliestYear;
  final ValueChanged<int> onYearChanged;
  final String selectedDate;
  final ValueChanged<String> onDaySelected;

  @override
  State<InsightHeatmap> createState() => _InsightHeatmapState();
}

class _InsightHeatmapState extends State<InsightHeatmap> {
  late int _quarter;

  static const _quarterNames = ['Jan–Mar', 'Apr–Jun', 'Jul–Sep', 'Oct–Dec'];
  static const _months = [
    ['Jan', 'Feb', 'Mar'],
    ['Apr', 'May', 'Jun'],
    ['Jul', 'Aug', 'Sep'],
    ['Oct', 'Nov', 'Dec'],
  ];
  @override
  void initState() {
    super.initState();
    _quarter = (DateTime.now().month - 1) ~/ 3;
  }

  @override
  Widget build(BuildContext context) {
    final byDate = {for (final day in widget.days) day.localDate: day};
    final currentYear = DateTime.now().year;
    final earliestYear = widget.earliestYear.clamp(2000, currentYear);
    final quarterStartMonth = _quarter * 3 + 1;
    final start = DateTime(widget.year, quarterStartMonth);
    final end = DateTime(widget.year, quarterStartMonth + 3);
    final leadingDays = start.weekday - 1;
    final quarterDays = end.difference(start).inDays;
    final columns = ((leadingDays + quarterDays) / 7).ceil();
    final maxDelta = widget.days.fold<int>(0, (max, day) {
      final delta = (day.activitySeconds - day.screenTimeSeconds).abs();
      return delta > max ? delta : max;
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var year = currentYear; year >= earliestYear; year--)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('$year'),
                        selected: year == widget.year,
                        onSelected: (_) => widget.onYearChanged(year),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < _quarterNames.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(_quarterNames[index]),
                        selected: index == _quarter,
                        onSelected: (_) => setState(() => _quarter = index),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Activity · screen time',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text('Swipe →', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity < -100 && _quarter < 3) {
                  setState(() => _quarter++);
                } else if (velocity > 100 && _quarter > 0) {
                  setState(() => _quarter--);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      children: [
                        for (final month in _months[_quarter])
                          Expanded(child: Text(month)),
                      ],
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            for (var row = 0; row < 7; row++)
                              SizedBox(
                                height: 17,
                                child: Row(
                                  children: [
                                    for (
                                      var column = 0;
                                      column < columns;
                                      column++
                                    )
                                      Expanded(
                                        child: Center(
                                          child: _cell(
                                            context,
                                            date: _dateAt(
                                              start,
                                              leadingDays,
                                              column,
                                              row,
                                            ),
                                            byDate: byDate,
                                            maxDelta: maxDelta,
                                            selectedDate: widget.selectedDate,
                                            onDaySelected: widget.onDaySelected,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _legend(context, 'More screen time', Colors.red.shade600),
                _legend(context, 'Balanced', Colors.grey.shade200),
                _legend(context, 'More activity', Colors.green.shade600),
              ],
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _dateAt(DateTime start, int leading, int column, int row) {
    final dayOffset = column * 7 + row - leading;
    final date = DateTime(start.year, start.month, start.day + dayOffset);
    final quarterEnd = DateTime(start.year, start.month + 3);
    if (dayOffset < 0 || date.isBefore(start) || !date.isBefore(quarterEnd)) {
      return null;
    }
    return date;
  }

  Widget _cell(
    BuildContext context, {
    required DateTime? date,
    required Map<String, InsightHeatmapDay> byDate,
    required int maxDelta,
    required String selectedDate,
    required ValueChanged<String> onDaySelected,
  }) {
    if (date == null) return const SizedBox(width: 12, height: 12);
    final key =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final day = byDate[key];
    final activity = day?.activitySeconds ?? 0;
    final screenTime = day?.screenTimeSeconds ?? 0;
    final delta = activity - screenTime;
    final color = _cellColor(delta, maxDelta);
    return Tooltip(
      message:
          '${date.month}/${date.day}/${date.year}\nActivity: ${_duration(activity)}\nScreen time: ${_duration(screenTime)}',
      child: GestureDetector(
        onTap: () => onDaySelected(key),
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: selectedDate == key
                ? Border.all(color: Colors.black87, width: 1.5)
                : null,
          ),
        ),
      ),
    );
  }

  Color _cellColor(int delta, int maxDelta) {
    if (delta == 0 || maxDelta == 0) return Colors.grey.shade200;
    final level = _level(delta.abs(), maxDelta);
    if (delta > 0) {
      return [
        Colors.green.shade100,
        Colors.green.shade200,
        Colors.green.shade400,
        Colors.green.shade700,
      ][level - 1];
    }
    return [
      Colors.red.shade100,
      Colors.red.shade200,
      Colors.red.shade400,
      Colors.red.shade700,
    ][level - 1];
  }

  int _level(int value, int maximum) => maximum == 0 || value == 0
      ? 0
      : ((value / maximum) * 4).ceil().clamp(1, 4);

  Widget _legend(BuildContext context, String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 9, height: 9, color: color),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.labelSmall),
    ],
  );

  String _duration(int seconds) {
    if (seconds <= 0) return '0 min';
    final minutes = seconds ~/ 60;
    if (minutes >= 60) return '${minutes ~/ 60} h ${minutes % 60} min';
    return '$minutes min';
  }
}
