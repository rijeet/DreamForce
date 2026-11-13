import 'package:material_ui/material_ui.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});
  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final _items = <String>[];
  Future<void> _addPlanItem() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add activity to plan'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Activity name',
            hintText: 'Study',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.isNotEmpty) setState(() => _items.add(name));
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Plan', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 4),
      const Text('Build a simple, reusable week.'),
      const SizedBox(height: 20),
      for (final item in _items)
        Card(
          child: ListTile(
            leading: const Icon(Icons.schedule),
            title: Text(item),
            subtitle: const Text('Any time · automatic focus and rest'),
          ),
        ),
      if (_items.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Text(
              'No activities planned. Add a focus block for this week.',
            ),
          ),
        ),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: _addPlanItem,
        icon: const Icon(Icons.add),
        label: const Text('Add activity'),
      ),
    ],
  );
}
