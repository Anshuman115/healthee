/// One program — `screens-actions.js::H.screens.program`, in Flutter.
///
/// ```text
///   header (detail)  "A program that can adapt" · the program's title
///   badge            Active · week 3 of 4
///   small            what the program is
///   section          Your path → card + timeline
///   notice           Your progress sets the pace
///   button full      Start / End program
///   text-button      the evidence
///   footer
/// ```
///
/// ## A step's state comes off the wire, never off its position in the list
///
/// The prototype's timeline hard-codes which two nodes carry a check. A rung's
/// `status` is what decides here — `settled` is done, `active` is the current
/// step, everything else is ahead — because a program can hold a recovery step
/// or be adapted mid-run, and a list that numbered its own progress would keep
/// saying week three after the server moved on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/challenges/challenge.dart';
import 'package:healthee/data/challenges/commitment_repository.dart';
import 'package:healthee/data/challenges/health_program.dart';
import 'package:healthee/data/challenges/program_feed.dart';
import 'package:healthee/data/honesty/citations.dart';
import 'package:healthee/features/actions/v02/evidence_sheet.dart';
import 'package:healthee/features/today/v02/today_header.dart';
import 'package:healthee/shared/challenge_outcome_card.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/page_section.dart';
import 'package:healthee/shared/server_action_button.dart';
import 'package:healthee/shared/states/account_async_view.dart';
import 'package:healthee/shared/states/cached_async_view.dart';
import 'package:healthee/shared/states/state_scaffold.dart';
import 'package:healthee/shared/v02/controls.dart';
import 'package:healthee/shared/v02/detail_page.dart';
import 'package:healthee/shared/v02/rows.dart';
import 'package:healthee/shared/v02/section_head.dart';
import 'package:healthee/shared/v02/surfaces.dart';
import 'package:solar_icons/solar_icons.dart';

/// The prototype's section heading over the timeline.
const String kPathHeading = 'Your path';

/// Its notice, verbatim.
const String kPaceTitle = 'Your progress sets the pace';

/// And its body.
const String kPaceBody =
    'If a target stops fitting, the program can adjust. A recovery step is part '
    'of the plan.';

/// One program, in full.
class ProgramDetailScreen extends ConsumerWidget {
  /// [id] is the server's row id.
  const ProgramDetailScreen({required this.id, super.key});

  /// Which program.
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AccountAsyncView<CommitmentRepository>(
      value: ref.watch(commitmentRepositoryProvider),
      onRetry: () => ref.invalidate(commitmentRepositoryProvider),
      builder: (context, repository) => CachedAsyncView<ProgramFeed>(
        value: ref.watch(programFeedProvider),
        onRetry: () => ref.invalidate(programFeedProvider),
        builder: (context, feed) => switch (feed.find(id)) {
          final HealthProgram program => _Body(
            program: program,
            repository: repository,
            onChanged: () => ref.invalidate(commitmentRepositoryProvider),
          ),
          null => const DetailPage(
            title: 'Program unavailable',
            children: <Widget>[
              EmptyState(
                message: 'Program unavailable',
                hint: 'Refresh the program feed.',
              ),
            ],
          ),
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.program,
    required this.repository,
    required this.onChanged,
  });

  final HealthProgram program;
  final CommitmentRepository repository;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final citations = <String>{
      for (final rung in program.rungs) ...rung.citations,
    }.toList();
    final settled = program.rungs.where(_isSettled).length;
    return ToneScope(
      tone: Tone.movement,
      child: DetailPage(
        eyebrow: 'A program that can adapt',
        title: program.title,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: StatusBadge(_badge(program, settled), accented: true),
          ),
          const SizedBox(height: 12),
          Text(program.why, style: TypeScale.small.copyWith(color: colors.ink2)),
          if (program.goal case final String goal) ...<Widget>[
            const SizedBox(height: 8),
            Text(goal, style: TypeScale.small.copyWith(color: colors.ink2)),
          ],
          if (program.holdReason case final String hold) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'On hold: $hold',
              style: TypeScale.small.copyWith(color: colors.ink2),
            ),
          ],
          if (program.endedReason case final String ended) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Ended: $ended',
              style: TypeScale.small.copyWith(color: colors.ink2),
            ),
          ],
          const SizedBox(height: SectionHead.sectionGap),
          if (program.rungs.isNotEmpty) ...<Widget>[
            const SectionHead(title: kPathHeading),
            SurfaceCard(child: Timeline(_steps(context, program))),
            const SizedBox(height: PageSpacing.block),
          ],
          const Notice(title: kPaceTitle, body: kPaceBody),
          const SizedBox(height: PageSpacing.block),
          if (_control(program) case final (String, String) control)
            ServerActionButton(
              label: control.$1,
              action: () => repository.programAction(program.id, control.$2),
              onSaved: onChanged,
            ),
          if (citations.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextLink(
                label: 'Why this program',
                icon: SolarIconsOutline.infoCircle,
                onPressed: () => showEvidenceSheet(
                  context,
                  title: 'Behind this program',
                  prose: program.why,
                  grounding: groundingOf(program.why, alsoCites: citations),
                ),
              ),
            ),
          const DataFooter(),
        ],
      ),
    );
  }

  /// `Active · week 3 of 4`, or the program's status alone when it has no
  /// weeks. Never a week number this screen counted for itself.
  static String _badge(HealthProgram program, int settled) {
    final head = program.status.isEmpty
        ? program.status
        : program.status[0].toUpperCase() + program.status.substring(1);
    final total = program.rungs.length;
    return total == 0 ? head : '$head · step ${settled + 1} of $total';
  }

  /// The one control this status offers, or none.
  static (String, String)? _control(HealthProgram program) =>
      switch (program.status) {
        'suggested' => ('Start this program', 'adopt'),
        'active' => ('End program', 'abandon'),
        _ => null,
      };

  static bool _isSettled(Challenge rung) =>
      rung.status == 'settled' || rung.outcome != null;

  static List<TimelineStep> _steps(
    BuildContext context,
    HealthProgram program,
  ) {
    final rungs = program.rungs;
    return <TimelineStep>[
      for (var i = 0; i < rungs.length; i++)
        TimelineStep(
          ordinal: '${i + 1}',
          title: rungs[i].title,
          body: _rungLine(rungs[i]),
          done: _isSettled(rungs[i]),
          // `.node.active` is every step the owner has reached — settled or
          // current — which is what the prototype's three filled nodes are.
          active: _isSettled(rungs[i]) || rungs[i].status == 'active',
          actionLabel: rungs[i].outcome == null ? null : 'Review outcome',
          onAction: rungs[i].outcome == null
              ? null
              : () => showOutcomeSheet(context, rungs[i].outcome!),
        ),
    ];
  }

  static String _rungLine(Challenge rung) {
    final target = rung.target == rung.target.roundToDouble()
        ? '${rung.target.round()}'
        : '${rung.target}';
    final metric = metricName(rung.metric);
    return rung.kind == 'deload'
        ? '$metric $target · recovery step'
        : '$metric $target · ${rung.status}';
  }
}
