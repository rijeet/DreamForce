import 'package:dream_force/core/platform/session_notice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notifies when a focus block finishes and the rest block starts', () {
    final notice = SessionNotice.forTransition(
      previousPhase: 'Focus',
      previousPhaseIndex: 0,
      previousStatus: 'running',
      phaseIndex: 1,
      status: 'running',
    );

    expect(notice?.title, 'Focus block finished');
    expect(notice?.body, 'Great job! You have completed a focus period.');
  });

  test('notifies when the session finishes', () {
    final notice = SessionNotice.forTransition(
      previousPhase: 'Rest',
      previousPhaseIndex: 1,
      previousStatus: 'running',
      phaseIndex: 1,
      status: 'completed',
    );

    expect(notice?.title, 'Session finished');
    expect(notice?.body, 'Your session is complete.');
  });

  test('stays quiet while the timer is still running or paused', () {
    expect(
      SessionNotice.forTransition(
        previousPhase: 'Focus',
        previousPhaseIndex: 0,
        previousStatus: 'running',
        phaseIndex: 0,
        status: 'running',
      ),
      isNull,
    );
    expect(
      SessionNotice.forTransition(
        previousPhase: 'Focus',
        previousPhaseIndex: 0,
        previousStatus: 'running',
        phaseIndex: 0,
        status: 'paused',
      ),
      isNull,
    );
    expect(
      SessionNotice.forTransition(
        previousPhase: 'Focus',
        previousPhaseIndex: 0,
        previousStatus: 'running',
        phaseIndex: 0,
        status: 'cancelled',
      ),
      isNull,
    );
  });
}
