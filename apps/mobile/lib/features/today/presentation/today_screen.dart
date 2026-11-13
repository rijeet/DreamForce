import 'package:dream_force/core/presentation/placeholder_page.dart';
import 'package:flutter/widgets.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});
  @override
  Widget build(BuildContext context) => const PlaceholderPage(
    title: 'Today',
    message: 'Choose an activity to begin your focused day.',
  );
}
