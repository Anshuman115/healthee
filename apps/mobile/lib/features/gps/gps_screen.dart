/// `#record` — the outdoor recorder, on the v02 detail frame.
///
/// `screens-explore.js::H.screens.record`, in order: the detail header, the
/// schematic map, `.record-reading` (a line, the `#record-timer` hero number, a
/// second line), a `.three` of Distance · Pace · GPS fixes, the full-width
/// start/stop control, a centred `.form-note`, and `View saved route`.
///
/// It was the last legacy `Scaffold`/`AppBar` screen in the app along with the
/// other two in this directory; `shared/v02/detail_page.dart` is the frame every
/// other pushed screen already used.
///
/// ## What the prototype's note says, and what this one has to say instead
///
/// `.form-note` there reads *"This HTML preview never requests location or
/// records a real workout"* — a preview telling a reviewer its numbers are
/// fixtures. Printing that over a recorder that does open the phone's GPS would
/// be the opposite claim, so this screen says what IS true of it: the accuracy
/// floor, that recording survives leaving the screen, and that force-closing
/// interrupts it. Same slot, same voice, and it is the one line on this screen
/// that is not the prototype's words.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/data/gps/gps_recorder.dart';
import 'package:healthee/data/gps/gps_recording_state.dart';
import 'package:healthee/data/gps/route_repository.dart';
import 'package:healthee/features/gps/gps_live_summary.dart';
import 'package:healthee/features/gps/local_routes.dart';
import 'package:healthee/shared/server_action_button.dart';
import 'package:healthee/shared/states/account_async_view.dart';
import 'package:healthee/shared/v02/detail_page.dart';
import 'package:healthee/shared/v02/full_button.dart';
import 'package:healthee/shared/v02/section_head.dart';
import 'package:healthee/shared/v02/settings_page.dart';
import 'package:healthee/shared/v02/surface_cards.dart';

/// `H.header('Out for a little movement.','Outdoor workout',true)`.
const String kRecordTitle = 'Out for a little movement.';

/// Its eyebrow.
const String kRecordEyebrow = 'Outdoor workout';

/// `.form-note` — see the library docstring on why this is not the prototype's.
const String kRecordNote =
    'Fixes with accuracy worse than 50 m are skipped. Recording continues when '
    'you leave this screen; force-closing the app interrupts it. Anything saved '
    'and not yet uploaded stays on this phone and is listed below.';

/// The recorder.
class GpsScreen extends ConsumerWidget {
  /// Builds the screen.
  const GpsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // `panels.js:3` derives tone from the ROUTE, and files `record` under
    // movement with the rest of the workout group.
    return ToneScope(
      tone: Tone.movement,
      child: DetailPage(
        title: kRecordTitle,
        eyebrow: kRecordEyebrow,
        children: <Widget>[
          AccountAsyncView<GpsRecordingState>(
            value: ref.watch(gpsRecorderProvider),
            onRetry: () => ref.invalidate(gpsRecorderProvider),
            builder: (context, recording) =>
                _Recorder(recording: recording, ref: ref),
          ),
          const SizedBox(height: Insets.lg),
          const FormNote(kRecordNote, centred: true),
          const SizedBox(height: Insets.lg),
          V02FullButton(
            label: 'View saved route',
            onPressed: () => unawaited(context.push(Routes.routes)),
          ),
          const SectionGap(),
          const SectionHead(title: 'Saved on this phone'),
          const LocalRoutes(),
        ],
      ),
    );
  }
}

/// `.record-reading`, the `.three`, and the one control that starts or stops.
class _Recorder extends StatelessWidget {
  const _Recorder({required this.recording, required this.ref});

  final GpsRecordingState recording;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final GpsRecorder recorder = ref.read(gpsRecorderProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GpsLiveSummary(recording: recording),
        if (recording.error case final String failure) ...<Widget>[
          const SizedBox(height: Insets.md),
          // `liveRegion`, because this appears without the owner moving: a
          // recorder that stopped taking fixes has to say so out loud.
          Semantics(liveRegion: true, child: SmallProse(failure)),
        ],
        const SizedBox(height: Insets.lg),
        if (recording.busy)
          const LinearProgressIndicator()
        else
          ServerActionButton(
            label: recording.recording
                ? 'Stop, save and upload'
                : 'Start recording',
            action: recording.recording ? recorder.stopAndUpload : recorder.start,
            onSaved: () => ref.invalidate(recordedRoutesProvider),
          ),
      ],
    );
  }
}
