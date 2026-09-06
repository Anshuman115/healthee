/// The panels and entry cards Insights is built from.
///
/// `screens-overview.js::H.screens.insights`:
///
/// ```js
/// .relationship-grid          two cards: a personal pattern, and the age model
/// H.panel('Effort & stress, side by side','heart', dayTogether + note,'activity')
/// H.panel('A useful question comes next','fitness', h3 + note + link,'coach','coach')
/// ```
///
/// ## The two entry cards carry no coefficient, and that is not an omission
///
/// The prototype prints `ρ −0.42` on its first card. This app moved exactly that
/// string off its surfaces on purpose: `findings_section.dart` records how
/// `Spearman(hrv_sleep_avg, recovery_score) = +0.72 over 105 days (p=0.000)`
/// reached the owner's home screen verbatim, and
/// `test/features/tab_screens_test.dart` now asserts that no rank coefficient is
/// on the surface at all. So the card names the two things and how much of the
/// owner's history is behind them; the arithmetic stays one tap behind the
/// finding's own disclosure, where it already lives.
///
/// ## Neither card's colour can depend on the sign
///
/// Both tones are **fixed** — sleep and fitness, the prototype's own — and are
/// not derived from the finding. A family chosen from the sign of a coefficient
/// would be a verdict painted on a correlation, which is the one thing this
/// screen exists not to do.
///
/// ## Neither card has an action, and that is the rule rather than an oversight
///
/// The prototype's destinations are `#insight` and `#body`, two screens that are
/// not built. `entry_card.dart`: *"An entry point that leads nowhere is worse
/// than an absent entry point: it spends a tap to teach the reader that the
/// screen lies about what it can do."* So the cards render their content with no
/// action line until those screens exist.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tokens.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/core/theme/tone_scope.dart';
import 'package:healthee/core/theme/type_scale.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/data/models/finding.dart';
import 'package:healthee/data/models/today_series.dart';
import 'package:healthee/shared/charts/v02/v02_linked_chart.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/entry_card.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';

/// The prototype's own line under the linked chart.
const String kLinkedNote =
    'Shared time axis. Independent scales. Check the context before '
    'interpreting a relationship.';

/// `H.bridge('stress', …)` — what a sensor cannot see.
const String kJournalBridge =
    'A journal entry can explain a busy hour in ways a sensor cannot.';

/// `Effort & stress, side by side` — two signals, one hour cursor, two scales.
class EffortStressPanel extends StatelessWidget {
  /// [heartRate] and [stress] are the payload's hourly series.
  const EffortStressPanel({
    required this.heartRate,
    required this.stress,
    required this.reveals,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'Effort & stress, side by side';

  /// Today's heart rate, hour by hour.
  final List<HourPoint> heartRate;

  /// Today's stress, hour by hour.
  final List<HourPoint> stress;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// Whether either signal has enough to draw.
  ///
  /// **Both or neither.** A "side by side" chart with one live pane is a
  /// different chart under a title promising a comparison the reader cannot
  /// make, and two hours is not a day.
  static bool hasSomethingToDraw(
    List<HourPoint> heartRate,
    List<HourPoint> stress,
  ) => heartRate.length > 2 && stress.length > 2;

  @override
  Widget build(BuildContext context) {
    final hours = heartRate.length < stress.length
        ? heartRate.length
        : stress.length;
    return Panel(
      tone: Tone.heart,
      head: const PanelHead(
        title: title,
        icon: Icons.favorite_outline,
        infoKey: 'stress',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          RevealOnce(
            id: 'insights.effort-stress',
            registry: reveals,
            builder: (context, t) => V02LinkedChart(
              <LinkedPane>[
                LinkedPane(
                  tone: Tone.heart,
                  label: 'Heart rate',
                  unit: 'bpm',
                  values: <double?>[
                    for (var i = 0; i < hours; i++) heartRate[i].average,
                  ],
                ),
                LinkedPane(
                  tone: Tone.stress,
                  label: 'Stress',
                  values: <double?>[
                    for (var i = 0; i < hours; i++) stress[i].average,
                  ],
                ),
              ],
              progress: t,
              captions: hours < 2
                  ? const <String>[]
                  : <String>[
                      _clock(heartRate.first.hour),
                      _clock(heartRate[hours - 1].hour),
                    ],
              sampleLabels: <String>[
                for (var i = 0; i < hours; i++) _clock(heartRate[i].hour),
              ],
              semanticLabel:
                  'Heart rate and stress through today, on a shared hour axis',
            ),
          ),
          const PanelNote(kLinkedNote),
        ],
      ),
    );
  }

  static String _clock(int hour) =>
      '${hour.toString().padLeft(2, '0')}:00';
}

/// `A useful question comes next` — the way from a pattern to a question.
class CoachQuestionPanel extends StatelessWidget {
  /// [onOpenCoach] of null draws the panel without either action.
  const CoachQuestionPanel({this.onOpenCoach, super.key});

  /// The prototype's title.
  static const String title = 'A useful question comes next';

  /// The prototype's own question.
  static const String question = 'What would you like to understand?';

  /// The prototype's own line under it.
  static const String note =
      'Follow the evidence and your own data, with the uncertainty kept in '
      'view.';

  /// Opens the coach sheet.
  final VoidCallback? onOpenCoach;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Panel(
      tone: Tone.fitness,
      head: PanelHead(
        title: title,
        icon: Icons.forum_outlined,
        actionLabel: onOpenCoach == null ? null : 'Details',
        onAction: onOpenCoach,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            question,
            style: TypeScale.entryTitle.copyWith(color: colors.ink),
          ),
          const PanelNote(note),
          if (onOpenCoach case final VoidCallback open)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: open,
                style: TextButton.styleFrom(
                  foregroundColor: context.family,
                  textStyle: TypeScale.textButton,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, PanelHead.actionMinHeight),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Ask your coach'),
              ),
            ),
        ],
      ),
    );
  }
}

/// The first relationship card: one pattern found in the owner's own history.
///
/// The wording is the same non-causal wording `findings_section.dart` uses — the
/// two metrics joined by a symmetric glyph, and the window under them. Nothing
/// here says "helps", "improves" or "because".
class FindingEntryCard extends StatelessWidget {
  /// Builds the card for [finding].
  const FindingEntryCard({required this.finding, super.key});

  /// The pattern this card names.
  final Finding finding;

  /// Whether [finding] has two named metrics to put on a card at all.
  static bool canDraw(Finding finding) =>
      finding.metricA != null && finding.metricB != null;

  @override
  Widget build(BuildContext context) {
    final samples = finding.nSamples;
    return EntryCard(
      // Fixed, and not derived from the coefficient. See the library docstring.
      tone: Tone.sleep,
      icon: Icons.insights_outlined,
      title: _pair(finding),
      body: samples == null
          ? 'Found in your own history.'
          : 'Across $samples days of your own history',
    );
  }

  static String _pair(Finding finding) {
    final a = metricName(finding.metricA!);
    final b = metricName(finding.metricB!);
    return '${a[0].toUpperCase()}${a.substring(1)} ↔ $b';
  }
}

/// The second relationship card: the fitness term of the age model.
class AgeEntryCard extends StatelessWidget {
  /// Builds the card for [years], the fitness contribution in years.
  const AgeEntryCard({required this.years, super.key});

  /// The contribution, signed as the server sent it.
  final double years;

  @override
  Widget build(BuildContext context) => EntryCard(
    tone: Tone.fitness,
    icon: Icons.monitor_heart_outlined,
    title: 'Fitness → age',
    body: '${_signed(years)} years\nModel contribution',
  );

  /// The fitness term of the age model, or null when the payload has none.
  static double? contribution(BiologicalAge? age) {
    for (final term in age?.contributions ?? const <AgeContribution>[]) {
      if (term.term == 'fitness' && term.deltaYears != null) {
        return term.deltaYears;
      }
    }
    return null;
  }

  static String _signed(double years) => years < 0
      ? '−${(-years).toStringAsFixed(1)}'
      : '+${years.toStringAsFixed(1)}';
}
