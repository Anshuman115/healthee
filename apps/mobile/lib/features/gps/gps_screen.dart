import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/core/theme/dimensions.dart';
import 'package:healthee/data/gps/gps_recorder.dart';
import 'package:healthee/data/gps/gps_recording_state.dart';
import 'package:healthee/data/gps/route_repository.dart';
import 'package:healthee/features/gps/gps_live_summary.dart';
import 'package:healthee/features/gps/local_routes.dart';
import 'package:healthee/shared/server_action_button.dart';
import 'package:healthee/shared/states/account_async_view.dart';

class GpsScreen extends ConsumerWidget {
  const GpsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Record outdoor workout'),
      actions: [
        IconButton(
          tooltip: 'Saved routes',
          icon: const Icon(Icons.map_outlined),
          onPressed: () => unawaited(context.push(Routes.routes)),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(Insets.lg),
      children: [
        const Text(
          'Your phone records the route; your strap records heart rate. Sync the strap after finishing so the server can align both.',
        ),
        const SizedBox(height: Insets.lg),
        AccountAsyncView<GpsRecordingState>(
          value: ref.watch(gpsRecorderProvider),
          onRetry: () => ref.invalidate(gpsRecorderProvider),
          builder: (context, recording) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recording.recording
                    ? 'Recording · ${recording.points} GPS fixes'
                    : 'Ready to record',
              ),
              GpsLiveSummary(recording: recording),
              if (recording.start != null)
                Text('Started ${recording.start!.toLocal()}'),
              if (recording.error != null)
                Semantics(liveRegion: true, child: Text(recording.error!)),
              if (recording.busy)
                const LinearProgressIndicator()
              else
                ServerActionButton(
                  label: recording.recording
                      ? 'Stop, save and upload'
                      : 'Start recording',
                  action: recording.recording
                      ? ref.read(gpsRecorderProvider.notifier).stopAndUpload
                      : ref.read(gpsRecorderProvider.notifier).start,
                  onSaved: () => ref.invalidate(recordedRoutesProvider),
                ),
            ],
          ),
        ),
        const SizedBox(height: Insets.lg),
        const Text(
          'Fixes with accuracy worse than 50 m are skipped. Recording continues when you leave this screen; force-closing the app interrupts it. Saved fixes can be recovered here.',
        ),
        const SizedBox(height: Insets.lg),
        const LocalRoutes(),
      ],
    ),
  );
}
