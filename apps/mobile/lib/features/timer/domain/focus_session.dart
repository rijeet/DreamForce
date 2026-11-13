import 'dart:async';

import 'package:dream_force/features/activities/domain/activity_draft.dart';
import 'package:material_ui/material_ui.dart';
import 'package:dream_force/features/auth/data/dream_force_auth_api.dart';

import 'dart:convert';

enum SessionStatus { running, paused, completed, cancelled }

class SessionPhase {
  const SessionPhase(this.name, this.seconds);
  final String name;
  final int seconds;
}

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
  List<SessionPhase> get _phases {
    if (activity.plannedSeconds == 90 * 60) {
      return const [
        SessionPhase('Focus', 2400),
        SessionPhase('Rest', 300),
        SessionPhase('Focus', 2400),
        SessionPhase('Rest', 300),
      ];
    }
    final total = activity.plannedSeconds;
    final focus = (total * 5 / 6).round();
    return [SessionPhase('Focus', focus), SessionPhase('Rest', total - focus)];
  }

  String get phaseName =>
      status == SessionStatus.completed || status == SessionStatus.cancelled
      ? 'Finished'
      : _phases[phaseIndex].name;
  int get phaseCount => _phases.length;
  int get currentCycle => _phases
      .take(phaseIndex + 1)
      .where((phase) => phase.name == 'Focus')
      .length;
  int get cycleCount => _phases.where((phase) => phase.name == 'Focus').length;
  SessionPhase? get nextPhase =>
      phaseIndex + 1 < _phases.length ? _phases[phaseIndex + 1] : null;
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
    if (status != SessionStatus.running) {
      return;
    }
    if (DateTime.now().isBefore(_phaseEndsAt)) {
      notifyListeners();
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
    final wasRunning = status == SessionStatus.running;
    final previousEnd = _phaseEndsAt;
    final previousPausedAt = pausedAt;
    if (status == SessionStatus.running) {
      status = SessionStatus.paused;
      pausedAt = DateTime.now();
    } else if (status == SessionStatus.paused) {
      _phaseEndsAt = _phaseEndsAt.add(DateTime.now().difference(pausedAt!));
      pausedAt = null;
      status = SessionStatus.running;
    }
    notifyListeners();
    if (remoteId == null) return;
    try {
      final response = await const DreamForceAuthApi().request(
        'POST',
        '/v1/sessions/$remoteId/events',
        body: {
          'clientEventId': DreamForceAuthApi.newRequestId(),
          'eventType': wasRunning ? 'pause' : 'resume',
          'expectedVersion': _remoteVersion,
        },
      );
      _remoteVersion =
          (jsonDecode(response.body) as Map<String, dynamic>)['version']
              as int? ??
          _remoteVersion + 1;
    } catch (_) {
      if (wasRunning) {
        status = SessionStatus.running;
        pausedAt = null;
      } else {
        status = SessionStatus.paused;
        pausedAt = DateTime.now();
        _phaseEndsAt = previousEnd;
      }
      if (previousPausedAt != null && !wasRunning) pausedAt = previousPausedAt;
      notifyListeners();
      rethrow;
    }
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
