/// The collapsible AI sleep analysis.
///
/// **Legacy** `ai_insight.dart`'s `HAiInsight`, as the Sleep tab calls it
/// (`sleep_screen.dart:268`). A 36 px magic-stick badge in `cReady`, the title at
/// `serif(ink, 16)`, a subtitle that reports the load state, a spinner or a
/// quarter-turn chevron, and an `AnimatedSize` body. Collapsed by default,
/// because the call is slow on the first view of a day and a card that blocks
/// the screen on an LLM is a card that makes the screen feel broken.
///
/// ## Two honesty changes
///
/// **The chips are source names, not ids with the underscores taken out.**
/// Legacy drew `ct.replaceAll('_', ' ')`, so `sleep_regularity_index` reached the
/// owner as "sleep regularity index" — an internal identifier presented as a
/// citation. The body renders through [GroundedMarkdown], which resolves each id
/// against the corpus's own names and says plainly when it cannot.
///
/// **A locked card says it is locked.** `/api/sleep/insight` is premium and
/// answers 402 to a free owner; legacy's `error: (_, __) => 'unavailable right
/// now'` reported that as a fault and invited a retry that can never succeed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:healthee/core/theme/instrument_hues.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/motion.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/data/models/sleep_insight.dart';
import 'package:healthee/data/sleep_repository.dart';
import 'package:healthee/shared/instrument/h_icon_badge.dart';
import 'package:healthee/shared/instrument_module.dart';
import 'package:healthee/shared/states/grounded_markdown.dart';
import 'package:solar_icons/solar_icons.dart';

/// Legacy's collapsible AI-analysis card, for sleep.
class SleepInsightCard extends ConsumerStatefulWidget {
  /// Watches `sleepInsightProvider` on its own, so a slow LLM never holds the
  /// measured half of the screen.
  const SleepInsightCard({super.key});

  @override
  ConsumerState<SleepInsightCard> createState() => _SleepInsightCardState();
}

class _SleepInsightCardState extends ConsumerState<SleepInsightCard> {
  bool _open = false;

  /// Legacy's `loadingLabel`.
  static const String _loading = 'analysing your recent sleep…';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hues = context.hues;
    final insight = ref.watch(sleepInsightProvider);
    return InstrumentModule(
      tag: null,
      minHeight: 0,
      onOpen: () => setState(() => _open = !_open),
      children: <Widget>[
        Row(
          children: <Widget>[
            HIconBadge(
              SolarIconsBold.magicStick,
              color: hues.readiness,
              size: 36,
              radius: 11,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('AI sleep analysis', style: HType.serif(colors.ink, size: 16)),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(insight),
                    style: HType.sans(colors.ink3, size: 11.5),
                  ),
                ],
              ),
            ),
            if (insight.isLoading)
              SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: hues.readiness,
                ),
              )
            else
              AnimatedRotation(
                turns: _open ? 0.25 : 0,
                duration: HMotion.fast,
                child: Icon(
                  SolarIconsOutline.altArrowRight,
                  size: 18,
                  color: colors.ink3,
                ),
              ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: HMotion.curve,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _body(context, insight),
                ),
        ),
      ],
    );
  }

  /// The collapsed line. Says which of the five states the card is in.
  String _subtitle(AsyncValue<SleepInsight> insight) => insight.when(
    loading: () => _loading,
    error: (_, _) => 'we could not reach your server for this',
    data: (analysis) => analysis.locked
        ? 'not included in your plan'
        : analysis.refused
        ? 'declined — tap to read why'
        : analysis.hasText
        ? 'tap to read'
        : 'no analysis yet',
  );

  Widget _body(BuildContext context, AsyncValue<SleepInsight> insight) {
    final colors = context.colors;
    final hues = context.hues;
    final quiet = HType.sans(colors.ink3, size: 13);
    return insight.when(
      loading: () => Text(_loading, style: quiet),
      // A transport failure and a refusal are opposite messages and keep
      // opposite sentences (`README.md`, "AsyncView is its sibling").
      error: (_, _) => Text(
        'We could not reach your server for the analysis. Your measurements '
        'above are unaffected — pull down to try again.',
        style: quiet,
      ),
      data: (analysis) {
        if (analysis.locked) {
          return Text(
            'AI analysis is part of the paid plan. Everything else on this '
            'screen is measured from your own strap and stays free.',
            style: quiet,
          );
        }
        if (analysis.refused) {
          return Text(
            'The analysis was declined rather than guessed — there was not '
            'enough grounded evidence to say anything about these nights.',
            style: quiet,
          );
        }
        if (!analysis.hasText) {
          return Text(
            'No analysis yet — check back once more data is recorded.',
            style: quiet,
          );
        }
        return GroundedMarkdown(
          text: analysis.text,
          accent: hues.readiness,
          grade: analysis.gradeFloor,
          alsoCites: analysis.citations,
        );
      },
    );
  }
}
