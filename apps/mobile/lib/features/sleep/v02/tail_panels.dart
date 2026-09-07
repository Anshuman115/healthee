/// The two surfaces the prototype has no box for, rebuilt as v02 panels.
///
/// The prototype's Sleep screen ends at `Naps & your day` and a link to the
/// recommendations. This app's Sleep screen also reaches two server surfaces
/// that the browser mock-up never had to invent:
///
/// - **`/api/sleep/consistency`'s `tonight`** — one lever, a target clock, how
///   often it was hit, and a nap note.
/// - **`/api/sleep/insight`** — a grounded, server-written reading of these
///   nights, citation-validated against `packages/knowledge`.
///
/// Both are kept, for the reason `activity_sections.dart` records for its own
/// `InsightCard`: deleting a reachable server surface because the design
/// mock-up has no box for it is a feature removal wearing a redesign's clothes.
/// They sit **after** every panel the prototype does draw, so the prototype's
/// own order is never interrupted by something it does not contain.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/models/sleep_consistency.dart';
import 'package:healthee/data/models/sleep_insight.dart';
import 'package:healthee/data/sleep_repository.dart';
import 'package:healthee/shared/states/grounded_markdown.dart';
import 'package:healthee/shared/states/grounded_text.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';

/// The lever for tonight, and how often it has been hit.
class TonightPanel extends StatelessWidget {
  /// [lever] is `/api/sleep/consistency`'s `tonight` block.
  const TonightPanel({required this.lever, super.key});

  /// The gap above the adherence track.
  static const double trackGap = 14;

  /// The gap between the track and its count.
  static const double countGap = 8;

  /// The server's lever.
  final TonightLever lever;

  /// `LIGHTS OUT` for a bedtime lever, `TARGET WAKE` otherwise.
  String get targetCaption =>
      lever.lever == 'bedtime' || lever.lever == 'duration'
      ? 'Lights out'
      : 'Target wake';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final target = lever.targetClock;
    return Panel(
      tone: Tone.sleep,
      label: 'Tonight',
      head: PanelHead(
        title: lever.title,
        icon: Icons.bedtime_outlined,
        infoKey: 'sleep_consistency',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (target != null)
            PanelValue(target, unit: targetCaption.toLowerCase()),
          GroundedProse(
            text: lever.prose,
            style: TypeScale.panelContext.copyWith(color: colors.ink),
          ),
          if (lever.hasAdherence) ...<Widget>[
            const SizedBox(height: trackGap),
            ProgressTrack(fraction: lever.hit! / lever.of!),
            const SizedBox(height: countGap),
            Text(
              'Hit on ${lever.hit} of the last ${lever.of} nights.',
              style: TypeScale.panelNote.copyWith(color: colors.ink2),
            ),
          ],
          if (lever.napNote case final String note) PanelNote(note),
        ],
      ),
    );
  }
}

/// `/api/sleep/insight` — the grounded reading, or the reason there is none.
///
/// The four states are the endpoint's own and none of them is a blank panel: a
/// declined analysis says it was declined rather than guessed, and a locked one
/// says which plan it belongs to and that the measurements above are not part
/// of it.
class SleepAnalysisPanel extends ConsumerWidget {
  /// Reads `sleepInsightProvider`.
  const SleepAnalysisPanel({super.key});

  /// The panel's title.
  static const String title = 'Sleep analysis';

  /// While the server is still writing it.
  static const String pending = 'Analysing your recent sleep…';

  /// When the read failed.
  static const String unreachable =
      'We could not reach your server for the analysis. The measurements above '
      'come from your own strap and are unaffected — pull down to try again.';

  /// When the plan does not include it.
  static const String locked =
      'AI analysis is part of the paid plan. Everything else on this screen is '
      'measured from your own strap and stays free.';

  /// When the model had nothing grounded to say.
  static const String refused =
      'The analysis was declined rather than guessed — there was not enough '
      'grounded evidence to say anything about these nights.';

  /// When there is simply no analysis yet.
  static const String empty =
      'No analysis yet — check back once more nights are recorded.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insight = ref.watch(sleepInsightProvider);
    return Panel(
      tone: Tone.fitness,
      label: title,
      head: const PanelHead(
        title: title,
        icon: Icons.auto_awesome,
        infoKey: 'sleep',
      ),
      child: insight.when(
        loading: () => const PanelNote(pending),
        error: (_, _) => const PanelNote(unreachable),
        data: (analysis) => _body(context, analysis),
      ),
    );
  }

  Widget _body(BuildContext context, SleepInsight analysis) {
    if (analysis.locked) {
      return const PanelNote(locked);
    }
    if (analysis.refused) {
      return const PanelNote(refused);
    }
    if (!analysis.hasText) {
      return const PanelNote(empty);
    }
    return GroundedMarkdown(
      text: analysis.text,
      accent: context.family,
      grade: analysis.gradeFloor,
      alsoCites: analysis.citations,
    );
  }
}
