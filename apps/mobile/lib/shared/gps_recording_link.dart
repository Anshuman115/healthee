import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/data/gps/gps_recorder.dart';
import 'package:healthee/shared/states/current_account_value.dart';

class GpsRecordingLink extends ConsumerWidget {
  const GpsRecordingLink({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = currentAccountValue(ref.watch(gpsRecorderProvider));
    final active =
        !state.isLoading && !state.hasError && state.value?.recording == true;
    return ListTile(
      title: Text(
        active ? 'GPS recording in progress' : 'Outdoor GPS workouts',
      ),
      subtitle: Text(
        active
            ? '${state.value!.points} fixes · tap to stop'
            : 'Record a route or upload a saved recording',
      ),
      leading: Icon(active ? Icons.gps_fixed : Icons.route),
      onTap: () => unawaited(context.push(Routes.gps)),
    );
  }
}
