/// Activity — what the owner did today, what it cost, and what it adds up to.
///
/// Composition only. The frame, the two data sources, the failure rules and the
/// reveal registry live in `shared/instrument_screen.dart`, and
/// `activity_sections.dart` decides what this screen shows and in what order.
/// This file is the wiring between them: the five destinations the screen can
/// reach, and nothing else.
///
/// Today's screen has the same shape for the same reason (Standards §3: a screen
/// is composition, not a God-widget).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:healthee/core/router.dart';
import 'package:healthee/features/activity/activity_sections.dart';
import 'package:healthee/shared/history_link.dart';
import 'package:healthee/shared/instrument_screen.dart';

/// The Activity tab.
class ActivityScreen extends StatelessWidget {
  /// [now] is injected by tests so the freshness labels are deterministic.
  const ActivityScreen({this.now, super.key});

  /// The instant every "x min ago" is measured against.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return InstrumentScreen(
      now: now,
      sections: (ScreenData data) => activitySections(
        data,
        ActivityExtras(
          // Pushed, never `go`: `go` REPLACES the location, which leaves the
          // destination with nothing beneath it and the next Back leaves the
          // app. `back_navigation_test.dart` owns that rule.
          onOpenProfile: () => unawaited(context.push(Routes.settings)),
          onOpenWorkouts: () => unawaited(context.push(Routes.workouts)),
          onOpenWorkout: (workout) => unawaited(
            context.push(
              '${Routes.workout}?start='
              '${Uri.encodeComponent(workout.start.toUtc().toIso8601String())}',
            ),
          ),
          onOpenRoutes: () => unawaited(context.push(Routes.routes)),
          onRecord: () => unawaited(context.push(Routes.gps)),
          onOpenMetric: (metric) => openMetricHistory(context, metric),
          onOpenRecovery: () => unawaited(context.push(Routes.recovery)),
          onOpenFitness: () => unawaited(context.push(Routes.fitness)),
          onOpenBody: () => unawaited(context.push(Routes.body)),
        ),
      ),
    );
  }
}
