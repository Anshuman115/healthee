class GpsRecordingState {
  const GpsRecordingState({
    this.id,
    this.start,
    this.end,
    this.recording = false,
    this.busy = false,
    this.points = 0,
    this.distanceM = 0,
    this.error,
  });
  final String? id;
  final DateTime? start;
  final DateTime? end;
  final bool recording;
  final bool busy;
  final int points;
  final double distanceM;
  final String? error;
  Duration elapsedAt(DateTime now) {
    if (start == null) return Duration.zero;
    final duration = (end ?? now).difference(start!);
    return duration.isNegative ? Duration.zero : duration;
  }
  double? paceAt(DateTime now) => distanceM <= 0 ? null :
    elapsedAt(now).inSeconds / 60 / (distanceM / 1000);
}
