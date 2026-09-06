/// One phone fix with measurement uncertainty retained.
class GpsFix {
  const GpsFix({
    required this.at,
    required this.latitude,
    required this.longitude,
    required this.accuracyM,
    this.altitudeM,
  });
  final DateTime at;
  final double latitude;
  final double longitude;
  final double accuracyM;
  final double? altitudeM;
}
