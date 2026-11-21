String deletionCountdown(DateTime due, DateTime now) {
  final remaining = due.difference(now);
  final totalSeconds = remaining.inSeconds < 0 ? 0 : remaining.inSeconds;
  final days = totalSeconds ~/ 86400;
  final hours = (totalSeconds ~/ 3600) % 24;
  final minutes = (totalSeconds ~/ 60) % 60;
  final seconds = totalSeconds % 60;
  return '${days}d ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}
