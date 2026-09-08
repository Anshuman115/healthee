/// `.record-reading` and the `.three` under it — what a recording reads right
/// now.
///
/// ```css
/// .record-reading { text-align:center; margin-block:24px }
/// .hero-number    { line-height:1; font-weight:600; letter-spacing:-5px }
/// .three.center   { text-align:center }
/// ```
///
/// `screens-explore.js::H.screens.record` draws a line, the `#record-timer` hero
/// number, a second line, then Distance · Pace · GPS fixes.
///
/// ## The prototype's three stats are three dashes; these are measurements
///
/// It prints `—km`, `—/km` and `0` because nothing is recording. Here the fix
/// count and the phone's own distance are real from the first fix, so they are
/// printed. **Pace is drawn only once it exists** — it is distance over time and
/// there is no such thing at zero distance, so the slot is absent rather than
/// carrying a dash that looks like a reading that failed. Two stats where the
/// prototype has three is the data half of *"except charts and data"*.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/gps/gps_clock.dart';
import 'package:healthee/data/gps/gps_recording_state.dart';
import 'package:healthee/shared/v02/panel_parts.dart';

/// What the line over the timer says in each state.
String recordingHeadline({required bool recording}) =>
    recording ? 'Recording' : 'Ready when you are';

/// And the line under it. Both are about this app, not about the owner.
String recordingFootnote({required bool recording}) => recording
    ? 'Phone GPS · distance is approximate until the track is uploaded'
    : 'Your phone records the track; your strap records heart rate';

/// `mm:ss` up to an hour, `h:mm:ss` past it.
String elapsedLabel(Duration elapsed) {
  String two(int value) => value.toString().padLeft(2, '0');
  final String tail =
      '${two(elapsed.inMinutes % 60)}:${two(elapsed.inSeconds % 60)}';
  return elapsed.inHours == 0 ? tail : '${elapsed.inHours}:$tail';
}

/// The timer, and the two or three figures beside it.
class GpsLiveSummary extends ConsumerWidget {
  /// [recording] is the recorder's current state.
  const GpsLiveSummary({required this.recording, super.key});

  /// `.record-reading { margin-block: 24px }`.
  static const double blockGap = Insets.xl;

  /// The recorder's state.
  final GpsRecordingState recording;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    // The ticking clock is only watched while something is running: watching it
    // on an idle screen would rebuild this subtree once a second for a timer
    // that reads 00:00.
    final DateTime now = recording.recording
        ? ref.watch(gpsClockProvider).value ?? DateTime.now()
        : DateTime.now();
    final Duration elapsed = recording.elapsedAt(now);
    final double? pace = recording.paceAt(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const SizedBox(height: blockGap),
        Text(
          recordingHeadline(recording: recording.recording),
          textAlign: TextAlign.center,
          style: TypeScale.small.copyWith(color: colors.ink2),
        ),
        Text(
          elapsedLabel(elapsed),
          textAlign: TextAlign.center,
          style: TypeScale.heroNumber.copyWith(color: colors.ink),
        ),
        Text(
          recordingFootnote(recording: recording.recording),
          textAlign: TextAlign.center,
          style: TypeScale.small.copyWith(color: colors.ink2),
        ),
        const SizedBox(height: blockGap),
        StatRow(<Stat>[
          Stat(
            'Distance',
            (recording.distanceM / 1000).toStringAsFixed(2),
            unit: 'km',
          ),
          // Absent until there is one. See the library docstring.
          if (pace != null)
            Stat('Pace', pace.toStringAsFixed(2), unit: '/km'),
          Stat('GPS fixes', recording.points.toString()),
        ]),
      ],
    );
  }
}
