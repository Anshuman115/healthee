/// `Today · logged` — the sessions, meditation and open fast nothing drew.
///
/// **Not a legacy card.** `read/routine.py` has been computing this block and
/// **no legacy file reads it at all**. It wears legacy's language — the same
/// `HModule`, the same eyebrow, the same icon badges the recovery card and the
/// actions block use — so it sits in the Activity section without reading as a
/// foreign object.
///
/// ```text
///   TODAY · LOGGED                                      ●
///   🏃  Outdoor run                              30 min · strap
///   🧘  Meditation                             10 min · 1 session
///   ⏳  Fasting, still open                              5h 00m
/// ```
///
/// ## It is a log, so nothing here is a judgement
///
/// There is no target, no percentage and no verdict colour. A workout is a thing
/// that happened; calling it good or bad needs a plan this app does not hold, and
/// the two cards above it are where the week's targets live.
///
/// Every session **names its source**, because a strap-recorded run and a
/// hand-typed one are different instruments and the difference belongs beside
/// the number rather than in a settings screen.
///
/// ## An empty day draws nothing
///
/// `Routine.isEmpty` gates the whole card in `today_sections.dart`. No heading,
/// no empty list, no "nothing logged yet" — the coordinator's rule and the
/// `anomalies` cautionary case: a heading that can never have content under it
/// is dead code, and one that merely has none today is noise.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/routine.dart';
import 'package:healthee/features/today/today_labels.dart';
import 'package:healthee/shared/instrument/h_icon_badge.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:solar_icons/solar_icons.dart';

/// Today's logged sessions, meditation, and any fast still running.
class RoutineCard extends StatelessWidget {
  /// [routine] is the whole `routine` block. Callers draw this only when it is
  /// not [Routine.isEmpty].
  const RoutineCard({required this.routine, super.key});

  /// What was logged or recorded today.
  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final hues = context.hues;
    return InstrumentModule(
      label: 'Today · logged',
      tag: hues.steps,
      minHeight: 0,
      children: [
        for (final session in routine.workouts)
          _Row(
            icon: SolarIconsBold.running,
            tint: hues.heart,
            title: session.type ?? 'Session',
            detail: _sessionDetail(session),
          ),
        if (routine.meditationCount > 0)
          _Row(
            icon: SolarIconsBold.meditation,
            tint: hues.sleep,
            title: 'Meditation',
            detail:
                '${routine.meditationMinutes} min · '
                '${routine.meditationCount} '
                '${routine.meditationCount == 1 ? 'session' : 'sessions'}',
          ),
        if (routine.openFast case final OpenFast fast)
          _Row(
            icon: SolarIconsBold.hourglass,
            tint: hues.calories,
            title: 'Fasting, still open',
            detail: hoursMinutes(fast.elapsedMin),
          ),
      ],
    );
  }

  /// `30 min · strap`, dropping either half the server did not send.
  static String _sessionDetail(RoutineEvent session) {
    final parts = <String>[
      if (session.durationMin case final int minutes) '$minutes min',
      if (session.source case final String source) source,
    ];
    return parts.join(' · ');
  }
}

/// One logged thing: a badge, what it was, and how much of it.
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.tint,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          HIconBadge(icon, color: tint, size: 30, radius: 10),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              title,
              style: HType.sans(
                colors.ink,
                size: 13.5,
                weight: FontWeight.w600,
              ),
            ),
          ),
          if (detail.isNotEmpty)
            Text(
              detail,
              style: HType.number(
                colors.ink3,
                size: 11,
                weight: FontWeight.w400,
              ),
            ),
        ],
      ),
    );
  }
}
