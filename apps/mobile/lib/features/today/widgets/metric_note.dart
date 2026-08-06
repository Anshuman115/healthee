/// The one-line research note under legacy's HRV and blood-oxygen modules.
///
/// **Ported from** `healthee-legacy/app/lib/ui/today_screen.dart` —
/// `_MetricInsight` (54), `_hrvNote` (22) and `_spo2Note` (35). The sentences
/// below are legacy's, word for word, including their thresholds.
///
/// ## What is NOT ported, and why the card still looks the same
///
/// Legacy's `_MetricInsight` watches `metricInsightProvider`, which calls
/// `GET /api/metric/insight` — a per-metric, per-day, LLM-written line — and
/// falls back to the static sentence *"while it loads or if unavailable — so
/// it's instant and never blank"*. The static sentence is therefore what the card
/// renders on every cold read, and it is what renders here.
///
/// The LLM half is not wired: this app has no client for that endpoint, and
/// adding one is a data-layer feature rather than a screen port. The widget is
/// shaped so that wiring it later is one optional argument. Reported.
///
/// ## The HRV threshold is legacy's, and it is a claim
///
/// ±12% against the 30-day median. It is not re-derived here and it is not
/// softened — a port that quietly moved a threshold would be a behaviour change
/// hiding inside a layout change.
///
/// ## The SpO₂ half is NOT legacy's any more (2026-08-06), and it had to change
///
/// Legacy's `_spo2Note` had two single-night branches, and both shipped here:
///
/// ```dart
/// if (lowest != null && lowest < 90)      // ONE night, anywhere in 14
/// if (lastMinimum != null && lastMinimum < 92)  // ONE night: last night
/// ```
///
/// `wearable_spo2_validity` is a graded note whose directives forbid exactly
/// that. **D1:** surface SpO₂ as *"a trend over multiple nights, never a
/// single-reading alarm"*. **D3:** *"never call out individual low-reading
/// minutes (most are sensor artefacts)"*. A single 91% night is the most likely
/// thing in this whole card to be a cold hand, a loose strap or motion — the
/// strap is not a cleared oximeter, no independent validation of it exists, and
/// #98 records that its true error is unquantified and at least ±3.5%.
///
/// So only a **sustained run** says anything, it names ~92% as the convention it
/// is, and it routes to a clinician (D2) instead of concluding. This is the
/// honesty-wording exception the port allows, and it is the only category of
/// change made here.
///
/// ## Where this threshold lives, and why not in `analytics/`
///
/// [spo2ConventionPercent] and [sustainedLowNights] sit beside the sentence that
/// uses them because they are a **display rule**, not a derived metric: nothing
/// on the server computes a "sustained low run", so there is no canonical
/// definition for this to disagree with and no parity fixture to test it
/// against. `analytics/` is for numbers the device re-derives that the server
/// also computes, and putting a UI reading threshold there would invite exactly
/// the second definition that directory's README exists to prevent.
library;

import 'package:flutter/material.dart';
import 'package:healthee/core/theme/instrument_type.dart';
import 'package:healthee/core/theme/tokens.dart';

/// The static note under a metric's trend chart.
class MetricNote extends StatelessWidget {
  /// [text] is already chosen by [hrvNote] or [spo2Note].
  const MetricNote(this.text, {super.key});

  /// The sentence.
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(
      text,
      style: HType.sans(colors.ink3, size: 11.5, height: 1.45),
    );
  }
}

/// Legacy's `_hrvNote` — how last night's HRV sits against the owner's median.
String hrvNote(double? current, double? median) {
  if (current == null || median == null || median == 0) {
    return 'Overnight HRV is your vagal-recovery signal — trends matter far '
        'more than any single night.';
  }
  final percent = (current - median) / median * 100;
  if (percent <= -12) {
    return 'Below your recent baseline. Evening alcohol, short or poor sleep, '
        'late caffeine, or a hard workout the day before can each drop '
        'overnight HRV — check what changed yesterday.';
  }
  if (percent >= 12) {
    return 'Above your recent baseline — good autonomic recovery.';
  }
  return 'In line with your recent baseline.';
}

/// The ~92% line: a **clinical convention**, not a validated wearable cutoff.
///
/// `wearable_spo2_validity`: the ~90% hypoxaemia line plus the usual caution
/// margin. *"We could source no wearable-specific threshold at all"* (#98). It
/// is drawn on the chart as [ChartReferenceKind.convention] and described as one
/// in every sentence below, because a displayed 92% on an unvalidated reflectance
/// sensor could correspond to a normal or a genuinely low arterial value.
const double spo2ConventionPercent = 92;

/// How many nights in a row make a run "sustained".
///
/// D2 says *"across several nights"* and stops there — the corpus sources no
/// number, so this one is a **display decision and not a finding**, and it is
/// written down rather than inlined for that reason. Three is the smallest run
/// that can be called several, and the direction of the error is the safe one:
/// a longer required run makes the app slower to raise something, never quicker
/// to alarm about a night that was probably a sensor artefact (D3).
const int sustainedLowNights = 3;

/// The longest run of CONSECUTIVE nights whose minimum sat below the convention.
///
/// Consecutive rather than scattered, deliberately: D3 puts scattered low nights
/// down to artefacts, and a run is the pattern D2 actually describes.
int longestLowNightRun(List<double> minima) {
  var longest = 0;
  var run = 0;
  for (final minimum in minima) {
    run = minimum < spo2ConventionPercent ? run + 1 : 0;
    if (run > longest) {
      longest = run;
    }
  }
  return longest;
}

/// What the fortnight of nightly minimums is allowed to say. See the library
/// docstring — one sustained run, or nothing.
String spo2Note(List<double> minima) {
  if (minima.isEmpty) {
    return 'Overnight blood-oxygen is normally 95–100%. The nightly LOW matters '
        'more than the average, and only a pattern across several nights means '
        'anything — a single low night is usually the sensor, not you.';
  }
  final run = longestLowNightRun(minima);
  if (run >= sustainedLowNights) {
    return 'Your nightly low has sat under ${spo2ConventionPercent.round()}% on '
        '$run nights in a row. That figure is a clinical convention rather than '
        'a measurement threshold for this strap, which is not a cleared '
        'oximeter — so this is a reason to have your sleep breathing looked at '
        'by a clinician, not a finding about your oxygen and not a diagnosis.';
  }
  return 'No sustained run of low nightly minimums. Single low nights are '
      'usually artefacts — a cold hand, a loose strap, movement — so they are '
      'not flagged here; only a run across several nights is.';
}
