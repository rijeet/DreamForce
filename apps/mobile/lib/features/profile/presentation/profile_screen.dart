import 'package:dream_force/features/auth/presentation/auth_gate.dart';
import 'package:material_ui/material_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({required this.user, super.key});
  final SignedInUser user;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  var _editing = false;
  final _displayName = TextEditingController();
  final _gender = TextEditingController();
  final _birthDate = TextEditingController();
  final _country = TextEditingController();
  final _city = TextEditingController();
  final _profession = TextEditingController();
  final _timezone = TextEditingController(text: 'Asia/Dhaka');
  @override
  void initState() {
    super.initState();
    _displayName.text = widget.user.name ?? '';
  }

  @override
  void dispose() {
    for (final controller in [
      _displayName,
      _gender,
      _birthDate,
      _country,
      _city,
      _profession,
      _timezone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 4),
      const Text('Your private account details.'),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _editing
              ? Column(
                  children: [
                    _field(_displayName, 'Display name'),
                    _field(_gender, 'Gender (optional)'),
                    _field(
                      _birthDate,
                      'Date of birth (optional)',
                      hint: 'YYYY-MM-DD',
                    ),
                    _field(_country, 'Country'),
                    _field(_city, 'City'),
                    _field(_profession, 'Profession'),
                    _field(_timezone, 'Time zone'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => setState(() => _editing = false),
                      child: const Text('Save profile'),
                    ),
                  ],
                )
              : Column(
                  children: [
                    ListTile(
                      leading: CircleAvatar(
                        backgroundImage: widget.user.photoUrl == null
                            ? null
                            : NetworkImage(widget.user.photoUrl!),
                        child: widget.user.photoUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(
                        _displayName.text.isEmpty
                            ? widget.user.email
                            : _displayName.text,
                      ),
                      subtitle: Text(widget.user.email),
                      trailing: TextButton(
                        onPressed: () => setState(() => _editing = true),
                        child: const Text('Edit profile'),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Location'),
                      subtitle: Text(
                        [_city.text, _country.text]
                                .where((value) => value.isNotEmpty)
                                .join(', ')
                                .isEmpty
                            ? 'Not set'
                            : [
                                _city.text,
                                _country.text,
                              ].where((value) => value.isNotEmpty).join(', '),
                      ),
                    ),
                    ListTile(
                      title: const Text('Profession'),
                      subtitle: Text(
                        _profession.text.isEmpty ? 'Not set' : _profession.text,
                      ),
                    ),
                    ListTile(
                      title: const Text('Time zone'),
                      subtitle: Text(_timezone.text),
                    ),
                  ],
                ),
        ),
      ),
      const SizedBox(height: 12),
      const Card(
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text('Appearance'),
              subtitle: Text('System theme'),
            ),
            Divider(height: 1),
            ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Privacy'),
              subtitle: Text('Export data and delete account'),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}
