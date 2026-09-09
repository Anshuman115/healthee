/// The calculation behind the biological-age hero: the ladder and its two terms.
///
/// `design/mobile-preview/screens-fitness.js::H.screens.body`:
///
/// ```js
/// H.panel('From your age to this estimate','fitness', ageWaterfall + note,'','activity')
/// H.panel('Fitness contribution','fitness',
///         value + vo2 rail + two stats + note + link,'fitness')
/// H.panel('Sleep contribution','sleep',
///         value + comparison bars + note + link,'sleep','moon')
/// ```
///
/// ## Every term is the payload's, including how many there are
///
/// `contributions[]` decides the ladder's columns, the equation under it and
/// which of the two panels below is drawn. A model that stops sending a term
/// stops showing it, and a model that adds one draws it without this file
/// changing — the same rule `today_hero.dart` keeps for the hero's two stats.
///
/// ## The sleep term is compared at a value that is not the one you slept
///
/// `compared_as` is *"the value the hazard curve was actually read at"*: the
/// strap's hours translated to their questionnaire equivalent, because the curve
/// was measured on what people reported. The two bars are the whole point of the
/// panel — a single figure would hide the translation, and the translation is
/// the thing the server's own caveat spends a paragraph disclosing.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/tone.dart';
import 'package:healthee/data/models/biological_age.dart';
import 'package:healthee/data/models/vo2max.dart';
import 'package:healthee/shared/format/metric_names.dart';
import 'package:healthee/shared/metric_info/metric_detail.dart';
import 'package:healthee/shared/reveal_once.dart';
import 'package:healthee/shared/v02/buttons.dart';
import 'package:healthee/shared/v02/comparison_bars.dart';
import 'package:healthee/shared/v02/instruments/age_waterfall.dart';
import 'package:healthee/shared/v02/instruments/vo2max_rail.dart';
import 'package:healthee/shared/v02/panel.dart';
import 'package:healthee/shared/v02/panel_head.dart';
import 'package:healthee/shared/v02/panel_parts.dart';
import 'package:solar_icons/solar_icons.dart';

/// The prototype's line under the fitness rail.
const String kFitnessTermNote =
    'The model compares fitness against its own reference and converts the '
    'result into a year contribution.';

/// The prototype's line under the sleep bars.
const String kSleepTermNote =
    'This age term uses a documented self-report translation. It is separate '
    'from the 8h sleep-need reference.';

/// `fitness` → [Tone.fitness]; anything naming sleep → [Tone.sleep].
///
/// An unrecognised term takes the fitness family — the `:root` default — rather
/// than a hue picked to look distinct, exactly as `recoveryFactorTone` does.
Tone ageTermTone(String term) =>
    term.toLowerCase().contains('sleep') ? Tone.sleep : Tone.fitness;

/// `fitness` → `Fitness`; `sleep duration` → `Sleep duration`.
String ageTermName(String term) {
  final words = term.replaceAll('_', ' ').trim();
  return words.isEmpty ? term : words[0].toUpperCase() + words.substring(1);
}

/// `−1.7 years`, `+0.4 years`, `0.0 years` — a real minus sign either way.
String ageYears(double delta) => delta == 0
    ? '0.0 years'
    : '${delta < 0 ? '−' : '+'}${delta.abs().toStringAsFixed(1)} years';

/// `From your age to this estimate` — the ladder, and the arithmetic in words.
class AgeLadderPanel extends StatelessWidget {
  /// [chronologicalAge] is non-null by construction; the screen gates on it.
  const AgeLadderPanel({
    required this.age,
    required this.chronologicalAge,
    required this.reveals,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'From your age to this estimate';

  /// The estimate and its terms.
  final BiologicalAge age;

  /// The owner's actual age, which the ladder starts from.
  final double chronologicalAge;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// `36 chronological years − 1.7 fitness + 0.0 sleep = 34.3 modelled years.`
  ///
  /// Built from the same numbers the ladder is drawn from, so the sentence and
  /// the picture cannot disagree.
  static String equation(BiologicalAge age, double chronologicalAge) {
    final parts = StringBuffer('${_plain(chronologicalAge)} chronological years');
    for (final term in age.contributions) {
      if (term.deltaYears case final double delta) {
        parts.write(
          ' ${delta < 0 ? '−' : '+'} ${delta.abs().toStringAsFixed(1)} '
          '${term.term.toLowerCase()}',
        );
      }
    }
    parts.write(' = ${_plain(age.biologicalAge)} modelled years.');
    return parts.toString();
  }

  /// `36`, and `34.3` when there is a tenth to show. Never `36.0`.
  static String _plain(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) => Panel(
    tone: Tone.fitness,
    label: 'Biological age · calculation',
    head: const PanelHead(
      title: title,
      icon: SolarIconsOutline.heartPulse,
      infoKey: 'biological_age',
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RevealOnce(
          id: 'body.age-waterfall',
          registry: reveals,
          builder: (context, t) => AgeWaterfall(
            chronologicalAge: chronologicalAge,
            estimate: age.biologicalAge,
            terms: <AgeTerm>[
              for (final term in age.contributions)
                if (term.deltaYears case final double delta)
                  AgeTerm.measured(
                    ageTermName(term.term),
                    delta,
                    tone: ageTermTone(term.term),
                  ),
            ],
            progress: t,
          ),
        ),
        PanelNote(equation(age, chronologicalAge)),
      ],
    ),
  );
}

/// `Fitness contribution` — the years, the rail the years came off, and the
/// reference the model scored them against.
class FitnessTermPanel extends StatelessWidget {
  /// [vo2max] supplies the rail's own reference and error magnitude; null draws
  /// the rail against the age model's target alone.
  const FitnessTermPanel({
    required this.term,
    required this.reveals,
    this.vo2max,
    this.onOpenFitness,
    super.key,
  });

  /// The prototype's title.
  static const String title = 'Fitness contribution';

  /// The fitness entry of `contributions[]`.
  final AgeContribution term;

  /// Where "already revealed" is remembered.
  final RevealRegistry reveals;

  /// `/api/today.vo2max`, when the payload carried it.
  final Vo2max? vo2max;

  /// Opens the fitness screen.
  final VoidCallback? onOpenFitness;

  /// `Read by a graded session` over `VO₂max estimate 43.0`.
  ///
  /// The instrument is named rather than printed as its tier id — `gps_graded`
  /// on a health screen is a log line where an instrument's name belongs.
  static String? instrument(AgeContribution term) {
    final lines = <String>[
      if (term.method case final String method) 'Read by ${methodLabel(method)}',
      if (term.value case final double value)
        'VO₂max estimate ${value.toStringAsFixed(1)}',
    ];
    return lines.isEmpty ? null : lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final delta = term.deltaYears;
    return Panel(
      tone: Tone.fitness,
      label: 'Biological age · fitness term',
      head: PanelHead(
        title: title,
        icon: SolarIconsOutline.graphUp,
        infoKey: 'vo2max',
        detail: MetricDetail(notes: vo2max?.researchNotes ?? const <String>[]),
        actionLabel: onOpenFitness == null ? null : 'Details',
        onAction: onOpenFitness,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PanelValue(
            delta == null ? '—' : ageYears(delta).replaceAll(' years', ''),
            unit: 'years',
            context_: instrument(term),
          ),
          if (term.value case final double estimate)
            RevealOnce(
              id: 'body.fitness-rail',
              registry: reveals,
              builder: (context, t) => Vo2maxRail(
                estimate: estimate,
                medianForAge: vo2max?.medianForAge,
                errorMagnitude: vo2max?.standardErrorMlKgMin,
                progress: t,
              ),
            ),
          StatRow(<Stat>[
            if (term.value case final double estimate)
              Stat('Current estimate', estimate.toStringAsFixed(1)),
            if (term.target case final double target)
              Stat('Age-model target', target.toStringAsFixed(1)),
          ]),
          const PanelNote(kFitnessTermNote),
          if (onOpenFitness case final VoidCallback open)
            _TermLink(label: 'Open the fitness detail', onPressed: open),
        ],
      ),
    );
  }
}

/// `Sleep contribution` — the years, and the two hours behind them.
class SleepTermPanel extends StatelessWidget {
  /// [term] is the sleep entry of `contributions[]`.
  const SleepTermPanel({required this.term, this.onOpenSleep, super.key});

  /// The prototype's title.
  static const String title = 'Sleep contribution';

  /// The sleep entry of `contributions[]`.
  final AgeContribution term;

  /// Opens the sleep screen.
  final VoidCallback? onOpenSleep;

  /// `6.3h wearable average` over `Compared as 7.0h`.
  static String? measured(AgeContribution term) {
    final lines = <String>[
      if (term.value case final double value)
        '${_hours(value)} wearable average',
      if (term.comparedAs case final double compared)
        'Compared as ${_hours(compared)}',
    ];
    return lines.isEmpty ? null : lines.join('\n');
  }

  /// The two bars, on the scale `ComparisonBars` derives from them.
  static List<ComparisonBar> bars(AgeContribution term) => <ComparisonBar>[
    if (term.value case final double value)
      ComparisonBar('Wearable', value, _hours(value)),
    if (term.comparedAs case final double compared)
      ComparisonBar('Compared as', compared, _hours(compared)),
  ];

  static String _hours(double value) => '${value.toStringAsFixed(1)}h';

  @override
  Widget build(BuildContext context) {
    final delta = term.deltaYears;
    return Panel(
      tone: Tone.sleep,
      label: 'Biological age · sleep term',
      head: PanelHead(
        title: title,
        icon: SolarIconsOutline.moonSleep,
        infoKey: 'sleep',
        actionLabel: onOpenSleep == null ? null : 'Details',
        onAction: onOpenSleep,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          PanelValue(
            delta == null ? '—' : ageYears(delta).replaceAll(' years', ''),
            unit: 'years',
            context_: measured(term),
          ),
          ComparisonBars(bars(term)),
          const PanelNote(kSleepTermNote),
          if (onOpenSleep case final VoidCallback open)
            _TermLink(label: 'See your complete sleep picture', onPressed: open),
        ],
      ),
    );
  }
}

/// `H.link(...)` inside a panel — the prototype's own trailing text button.
class _TermLink extends StatelessWidget {
  const _TermLink({required this.label, required this.onPressed});

  /// The gap the prototype leaves above it.
  static const double topGap = 10;

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: topGap),
    child: Align(
      alignment: Alignment.centerLeft,
      child: HLinkButton(label: label, onPressed: onPressed),
    ),
  );
}
