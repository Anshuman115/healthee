import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/data/gps/gps_clock.dart';
import 'package:healthee/data/gps/gps_recording_state.dart';

class GpsLiveSummary extends ConsumerWidget {
  const GpsLiveSummary({required this.recording, super.key});
  final GpsRecordingState recording;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = recording.recording
      ? ref.watch(gpsClockProvider).value ?? DateTime.now() : DateTime.now();
    final elapsed = recording.elapsedAt(now);
    final pace = recording.paceAt(now);
    String two(int value) => value.toString().padLeft(2, '0');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${elapsed.inHours}:${two(elapsed.inMinutes % 60)}:${two(elapsed.inSeconds % 60)} elapsed'),
      Text('${(recording.distanceM / 1000).toStringAsFixed(2)} km · approximate phone distance'),
      if (pace != null) Text('${pace.toStringAsFixed(2)} min/km · average including stops'),
    ]);
  }
}
