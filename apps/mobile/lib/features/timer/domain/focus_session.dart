import 'dart:async';

import 'package:dream_force/features/activities/domain/activity_draft.dart';
import 'package:material_ui/material_ui.dart';

enum SessionStatus { running, paused, completed, cancelled }

class FocusSession extends ChangeNotifier {
  FocusSession(this.activity) : startedAt = DateTime.now() {
    _phaseEndsAt = DateTime.now().add(Duration(seconds: _phases.first.seconds));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _advance());
  }
  final ActivityDraft activity;
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

  void togglePause() {
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

  void cancel() {
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
