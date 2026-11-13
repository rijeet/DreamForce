import 'package:material_ui/material_ui.dart';

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(message, style: Theme.of(context).textTheme.bodyLarge),
      ],
    ),
  );
}
