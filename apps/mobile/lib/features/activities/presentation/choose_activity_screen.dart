import 'package:material_ui/material_ui.dart';

class ChooseActivityScreen extends StatelessWidget {
  const ChooseActivityScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose activity')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Start a focused session',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text('Your reusable activities will be available here.'),
          const Spacer(),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add),
            label: const Text('Create activity'),
          ),
        ],
      ),
    ),
  );
}
