import 'dart:async';

import 'package:dream_force/features/activities/domain/activity_draft.dart';
import 'package:material_ui/material_ui.dart';
import 'package:dream_force/features/auth/data/dream_force_auth_api.dart';

import 'dart:convert';

enum SessionStatus { running, paused, completed, cancelled }

class FocusSession extends ChangeNotifier {
  FocusSession(this.activity, {this.remoteId, int version = 1})
    : startedAt = DateTime.now(),
      _remoteVersion = version {
    _phaseEndsAt = DateTime.now().add(Duration(seconds: _phases.first.seconds));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _advance());
  }
  final ActivityDraft activity;
  final String? remoteId;
  int _remoteVersion;
  final DateTime startedAt;
  late DateTime _phaseEndsAt;
  late Timer _ticker;
  var phaseIndex = 0;
  var status = SessionStatus.running;
  DateTime? pausedAt;
  List<_Phase> get _phases {
    if (activity.plannedSeconds == 90 * 60) {
      return const [
        _Phase('Focus', 2400),
        _Phase('Rest', 300),
        _Phase('Focus', 2400),
        _Phase('Rest', 300),
      ];
    }
    final total = activity.plannedSeconds;
    final focus = (total * 5 / 6).round();
    return [_Phase('Focus', focus), _Phase('Rest', total - focus)];
  }

  String get phaseName =>
      status == SessionStatus.completed || status == SessionStatus.cancelled
      ? 'Finished'
      : _phases[phaseIndex].name;
  int get remainingSeconds =>
      (status == SessionStatus.paused && pausedAt != null
              ? _phaseEndsAt.difference(pausedAt!)
              : _phaseEndsAt.difference(DateTime.now()))
          .inSeconds
          .clamp(0, 999999);
  double get progress => status == SessionStatus.completed
      ? 1
      : 1 - remainingSeconds / _phases[phaseIndex].seconds;
  void _advance() {
    if (status != SessionStatus.running ||
        DateTime.now().isBefore(_phaseEndsAt)) {
      return;
    }
    if (phaseIndex == _phases.length - 1) {
      status = SessionStatus.completed;
      _ticker.cancel();
      notifyListeners();
      return;
    }
    phaseIndex++;
    _phaseEndsAt = DateTime.now().add(
      Duration(seconds: _phases[phaseIndex].seconds),
    );
    notifyListeners();
  }

  Future<void> togglePause() async {
    if (remoteId != null) {
      final event = status == SessionStatus.running ? 'pause' : 'resume';
      final response = await const DreamForceAuthApi().request(
        'POST',
        '/v1/sessions/$remoteId/events',
        body: {
          'clientEventId': DreamForceAuthApi.newRequestId(),
          'eventType': event,
          'expectedVersion': _remoteVersion,
        },
      );
      _remoteVersion =
          (jsonDecode(response.body) as Map<String, dynamic>)['version']
              as int? ??
          _remoteVersion + 1;
    }
    if (status == SessionStatus.running) {
      status = SessionStatus.paused;
      pausedAt = DateTime.now();
    } else if (status == SessionStatus.paused) {
      _phaseEndsAt = _phaseEndsAt.add(DateTime.now().difference(pausedAt!));
      pausedAt = null;
      status = SessionStatus.running;
    }
    notifyListeners();
  }

  Future<void> cancel() async {
    if (remoteId != null &&
        (status == SessionStatus.running || status == SessionStatus.paused)) {
      final response = await const DreamForceAuthApi().request(
        'POST',
        '/v1/sessions/$remoteId/events',
        body: {
          'clientEventId': DreamForceAuthApi.newRequestId(),
          'eventType': 'cancel',
          'expectedVersion': _remoteVersion,
        },
      );
      _remoteVersion =
          (jsonDecode(response.body) as Map<String, dynamic>)['version']
              as int? ??
          _remoteVersion + 1;
    }
    status = SessionStatus.cancelled;
    _ticker.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }
}

class _Phase {
  const _Phase(this.name, this.seconds);
  final String name;
  final int seconds;
}
