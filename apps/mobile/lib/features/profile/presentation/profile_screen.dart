import 'dart:async';
import 'dart:convert';

import 'package:dream_force/features/auth/data/dream_force_auth_api.dart';
import 'package:dream_force/features/auth/presentation/auth_gate.dart';
import 'package:dream_force/features/profile/domain/deletion_countdown.dart';
import 'package:dream_force/features/profile/domain/profile_options.dart';
import 'package:material_ui/material_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.user,
    required this.onLogout,
    this.active = true,
    super.key,
  });
  final SignedInUser user;
  final Future<void> Function() onLogout;
  final bool active;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  var _editing = false;
  var _saving = false;
  var _loading = true;
  var _loaded = false;
  String? _error;
  final _displayName = TextEditingController();
  String? _gender;
  DateTime? _birthDate;
  String? _city;
  String? _profession;
  DateTime? _deletionDueAt;
  Timer? _deletionClock;
  var _deleting = false;
  var _finishingDeletion = false;

  @override
  void initState() {
    super.initState();
    _displayName.text = widget.user.name ?? '';
    if (widget.active) unawaited(_load());
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.active || oldWidget.active || _loaded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_loaded) unawaited(_load());
    });
  }

  @override
  void dispose() {
    _deletionClock?.cancel();
    _displayName.dispose();
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
          child: _loading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _editing
              ? _editForm()
              : _summary(),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Column(
          children: [
            const ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text('Appearance'),
              subtitle: Text('System theme'),
            ),
            if (_loaded) ...[
              const Divider(height: 1),
              if (_deletionDueAt == null)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Delete account'),
                  subtitle: const Text(
                    'Confirm to start a 30-day timer. The account is deleted when it ends.',
                  ),
                  enabled: !_deleting,
                  onTap: _confirmDelete,
                )
              else
                _deletionTimer(),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Log out'),
          subtitle: const Text('Sign out of Dream Force on this device.'),
          onTap: _confirmLogout,
        ),
      ),
    ],
  );

  Widget _summary() => Column(
    children: [
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundImage: widget.user.photoUrl == null
              ? null
              : NetworkImage(widget.user.photoUrl!),
          child: widget.user.photoUrl == null ? const Icon(Icons.person) : null,
        ),
        title: Text(
          _displayName.text.isEmpty ? widget.user.email : _displayName.text,
        ),
        subtitle: Text(widget.user.email),
        trailing: TextButton(
          onPressed: _loaded ? () => setState(() => _editing = true) : null,
          child: const Text('Edit profile'),
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(onPressed: _load, child: const Text('Retry')),
        ),
      ],
      const Divider(),
      _detail('Gender', _gender),
      _detail(
        'Date of birth',
        _birthDate == null ? null : _formatDate(_birthDate!),
      ),
      _detail('Country', profileCountry),
      _detail('City', _city == null ? null : districtLabel(_city!)),
      _detail('Profession', _profession),
      _detail('Time zone', profileTimezone),
    ],
  );

  Widget _detail(String title, String? value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(value == null || value.isEmpty ? 'Not set' : value),
  );

  Widget _editForm() => Column(
    children: [
      TextField(
        controller: _displayName,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Display name',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 12),
      _choiceField(
        label: 'Gender (optional)',
        value: _gender,
        onTap: () => _pickChoice(
          title: 'Gender',
          choices: profileGenders,
          selected: _gender,
          onSelected: (value) => setState(() => _gender = value),
        ),
      ),
      _dateField(),
      _readonlyField('Country', profileCountry),
      _choiceField(
        label: 'City (optional)',
        value: _city == null ? null : districtLabel(_city!),
        onTap: _pickDistrict,
      ),
      _choiceField(
        label: 'Profession (optional)',
        value: _profession,
        onTap: () => _pickChoice(
          title: 'Profession',
          choices: profileProfessions,
          selected: _profession,
          onSelected: (value) => setState(() => _profession = value),
        ),
      ),
      _readonlyField('Time zone', profileTimezone),
      if (_error != null) ...[
        const SizedBox(height: 4),
        Text(_error!),
        const SizedBox(height: 8),
      ],
      Row(
        children: [
          TextButton(
            onPressed: _saving ? null : _cancelEdit,
            child: const Text('Cancel'),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _saving || !_loaded ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save profile'),
          ),
        ],
      ),
    ],
  );

  Widget _readonlyField(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      child: Text(value),
    ),
  );

  Widget _choiceField({
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: _saving ? null : onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(value == null || value.isEmpty ? 'Not set' : value),
      ),
    ),
  );

  Widget _dateField() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: _saving ? null : _pickBirthDate,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Date of birth (optional)',
          border: const OutlineInputBorder(),
          suffixIcon: _birthDate == null
              ? const Icon(Icons.calendar_today_outlined)
              : IconButton(
                  tooltip: 'Clear date of birth',
                  onPressed: _saving
                      ? null
                      : () => setState(() => _birthDate = null),
                  icon: const Icon(Icons.close),
                ),
        ),
        child: Text(_birthDate == null ? 'Not set' : _formatDate(_birthDate!)),
      ),
    ),
  );

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await const DreamForceAuthApi().request('GET', '/v1/me');
      final profile = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _applyProfile(profile);
        _loaded = true;
        _loading = false;
      });
      _syncDeletionClock();
    } catch (error) {
      if (!mounted) return;
      if (await _leaveIfDeleted(error)) return;
      setState(() {
        _loading = false;
        _error = error is AuthApiException
            ? error.message
            : 'Could not load profile.';
      });
    }
  }

  void _applyProfile(Map<String, dynamic> profile) {
    final displayName = profile['displayName'];
    if (displayName is String && displayName.trim().isNotEmpty) {
      _displayName.text = displayName.trim();
    }
    _gender = knownChoice(profileGenders, profile['gender']);
    _birthDate = _parseDate(profile['dateOfBirth']);
    _city = knownDistrict(profile['city']);
    _profession = knownChoice(profileProfessions, profile['profession']);
    final due = profile['deletionDueAt'];
    _deletionDueAt = profile['accountStatus'] == 'deletion_pending' && due != null
        ? DateTime.tryParse(due.toString())?.toLocal()
        : null;
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _error = null;
    });
    unawaited(_load());
  }

  Future<void> _pickChoice({
    required String title,
    required List<String> choices,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(title: Text(title)),
            ListTile(
              title: const Text('Not set'),
              trailing: selected == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final choice in choices)
              ListTile(
                title: Text(choice),
                trailing: selected == choice ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, choice),
              ),
          ],
        ),
      ),
    );
    if (!mounted || picked == null) return;
    onSelected(picked.isEmpty ? null : picked);
  }

  Future<void> _pickDistrict() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: ListView(
          children: [
            const ListTile(title: Text('City')),
            ListTile(
              title: const Text('Not set'),
              trailing: _city == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(context, ''),
            ),
            for (final division in bangladeshDivisions) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  division.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              for (final district in division.districts)
                ListTile(
                  title: Text(district.label),
                  trailing: _city == district.value
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, district.value),
                ),
            ],
          ],
        ),
      ),
    );
    if (!mounted || picked == null) return;
    setState(() => _city = picked.isEmpty ? null : picked);
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _birthDate ?? DateTime(2000);
    final picked = await showDatePicker(
      context: context,
      helpText: 'Date of birth',
      initialDate: initial.isAfter(today) ? today : initial,
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (!mounted || picked == null) return;
    setState(
      () => _birthDate = DateTime(picked.year, picked.month, picked.day),
    );
  }

  Widget _deletionTimer() {
    final due = _deletionDueAt!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account deletion',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text('Your account and its data are deleted when this reaches zero.'),
          const SizedBox(height: 12),
          Text(
            deletionCountdown(due, DateTime.now()),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text('Deletes on ${_formatDate(due)}'),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _deleting ? null : _keepAccount,
              child: const Text('Keep account'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'Confirming starts a 30-day timer. Dream Force deletes this account and its data when the timer ends. Your Google account is not deleted. You can keep the account from Profile before the timer ends.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start 30-day timer'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final response = await const DreamForceAuthApi().request('DELETE', '/v1/me');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final due = DateTime.tryParse('${body['deletionDueAt']}')?.toLocal();
      if (!mounted) return;
      if (due == null) {
        setState(() => _error = 'Could not start account deletion.');
        return;
      }
      setState(() => _deletionDueAt = due);
      _syncDeletionClock();
    } catch (error) {
      if (!mounted) return;
      if (await _leaveIfDeleted(error)) return;
      setState(() {
        _error = error is AuthApiException
            ? error.message
            : 'Could not start account deletion.';
      });
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _keepAccount() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await const DreamForceAuthApi().request(
        'POST',
        '/v1/me/deletion/cancel',
        body: const {},
      );
      if (!mounted) return;
      _deletionClock?.cancel();
      setState(() => _deletionDueAt = null);
    } catch (error) {
      if (!mounted) return;
      if (await _leaveIfDeleted(error)) return;
      setState(() {
        _error = error is AuthApiException
            ? error.message
            : 'Could not keep this account.';
      });
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _syncDeletionClock() {
    _deletionClock?.cancel();
    final due = _deletionDueAt;
    if (due == null) return;
    if (!due.isAfter(DateTime.now())) {
      unawaited(_finishIfDue());
      return;
    }
    _deletionClock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final current = _deletionDueAt;
      if (current == null || !current.isAfter(DateTime.now())) {
        _deletionClock?.cancel();
        unawaited(_finishIfDue());
        return;
      }
      setState(() {});
    });
  }

  Future<void> _finishIfDue() async {
    if (_finishingDeletion) return;
    _finishingDeletion = true;
    try {
      await _load();
    } finally {
      _finishingDeletion = false;
    }
  }

  Future<bool> _leaveIfDeleted(Object error) async {
    if (error is! AuthApiException || !error.message.contains('ACCOUNT_DELETED')) {
      return false;
    }
    await widget.onLogout();
    return true;
  }

  Future<void> _confirmLogout() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can sign in again with your Google account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (accepted ?? false) await widget.onLogout();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response = await const DreamForceAuthApi().request(
        'PATCH',
        '/v1/me',
        body: {
          'profile': {
            'displayName': _displayName.text.trim().isEmpty
                ? null
                : _displayName.text.trim(),
            'gender': _gender,
            'dateOfBirth': _birthDate == null ? null : _isoDate(_birthDate!),
            'country': profileCountry,
            'city': _city,
            'profession': _profession,
            'timezone': profileTimezone,
          },
        },
      );
      final profile = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _applyProfile(profile);
        _editing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is AuthApiException
            ? error.message
            : 'Could not save profile.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})')
        .firstMatch(value.toString());
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  String _isoDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
