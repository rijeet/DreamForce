class SessionNotice {
  const SessionNotice({required this.title, required this.body});

  final String title;
  final String body;

  /// Notice for a phase that just ended. Pause and resume return null.
  static SessionNotice? forTransition({
    required String previousPhase,
    required int previousPhaseIndex,
    required String previousStatus,
    required int phaseIndex,
    required String status,
  }) {
    if (status == 'cancelled' || previousStatus == 'cancelled') return null;
    final phaseEnded =
        phaseIndex != previousPhaseIndex || status == 'completed';
    if (!phaseEnded || previousStatus == 'completed') return null;
    if (previousPhase == 'Focus') {
      return const SessionNotice(
        title: 'Focus block finished',
        body: 'Great job! You have completed a focus period.',
      );
    }
    if (status == 'completed') {
      return const SessionNotice(
        title: 'Session finished',
        body: 'Your session is complete.',
      );
    }
    return const SessionNotice(
      title: 'Rest finished',
      body: 'Rest is over. The next focus block is starting.',
    );
  }
}
