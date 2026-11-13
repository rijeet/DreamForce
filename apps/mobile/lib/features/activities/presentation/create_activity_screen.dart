import 'package:dream_force/features/activities/domain/activity_draft.dart';
import 'package:material_ui/material_ui.dart';

class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({
    required this.onBack,
    required this.onSave,
    super.key,
  });

  final VoidCallback onBack;
  final ValueChanged<ActivityDraft> onSave;

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  var _seconds = 3600;
  var _unit = 'Minutes';
  var _icon = Icons.bolt_outlined;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      widget.onSave(
        ActivityDraft.seconds(
          name: _nameController.text.trim(),
          icon: _icon,
          plannedSeconds: _seconds,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
        child: Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              tooltip: 'Back to activities',
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 8),
            Text(
              'Create activity',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
      ),
      Expanded(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            children: [
              Text(
                'Set a reusable default.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Activity name',
                  hintText: 'Deep work',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter an activity name.'
                    : null,
              ),
              const SizedBox(height: 20),
              Text(
                'Planned duration',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: _seconds > _step
                        ? () => setState(() => _seconds -= _step)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _durationLabel,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _seconds < 28800
                        ? () => setState(() => _seconds += _step)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Seconds', label: Text('Sec')),
                  ButtonSegment(value: 'Minutes', label: Text('Min')),
                  ButtonSegment(value: 'Hours', label: Text('Hour')),
                ],
                selected: {_unit},
                onSelectionChanged: (value) =>
                    setState(() => _unit = value.first),
              ),
              const SizedBox(height: 8),
              Text(
                'Focus and rest are calculated automatically.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              Text('Icon', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children:
                    [
                          Icons.bolt_outlined,
                          Icons.menu_book_outlined,
                          Icons.code,
                          Icons.directions_run_outlined,
                          Icons.auto_stories_outlined,
                        ]
                        .map(
                          (icon) => ChoiceChip(
                            label: Icon(icon),
                            selected: _icon == icon,
                            onSelected: (_) => setState(() => _icon = icon),
                          ),
                        )
                        .toList(),
              ),
            ],
          ),
        ),
      ),
      SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _save,
            child: const Text('Save activity'),
          ),
        ),
      ),
    ],
  );

  int get _step => switch (_unit) {
    'Seconds' => 10,
    'Hours' => 3600,
    _ => 60,
  };
  String get _durationLabel => switch (_unit) {
    'Seconds' => '$_seconds sec',
    'Hours' =>
      '${(_seconds / 3600).toStringAsFixed(_seconds % 3600 == 0 ? 0 : 1)} hr',
    _ => '${(_seconds / 60).round()} min',
  };
}
