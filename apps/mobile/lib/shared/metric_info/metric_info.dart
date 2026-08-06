/// The plain-language explainer behind a card's ⓘ — legacy's `kMetricInfo`,
/// **grounded**.
///
/// `healthee-legacy/app/lib/ui/metric_info.dart`. Every card that carries an
/// `infoKey` opens one of these. Legacy's map was ported verbatim, and the port
/// note said in as many words that its prose citations *"have not been
/// re-verified against `packages/knowledge` in this pass"*. They have now.
///
/// ## What the audit found, and why this file changed
///
/// Seventeen explainers, ~40 interpretive claims, **not one note id and not one
/// evidence grade**. That is a grade-free channel into the UI: the corpus's own
/// enforcement (`insights/validator.py::_grade_issue`) calibrates language per
/// sentence against the cited note's grade, and it cannot see a Dart string. So
/// these were the only interpretive claims in the product nothing checked — and
/// checking them found the predictable:
///
///   * **Three prose citations are refuted by the corpus outright.** Steps
///     "~7,500/day" (`steps_mortality` reports an age-banded plateau of
///     8,000–10,000 under 60 and 6,000–8,000 at 60+, and the number 7,500
///     appears nowhere in the corpus); resting HR "~16%" (Aune 2017 is 17%, and
///     Zhang 2016 is 9% — the note gives the range, not a fourth number);
///     biological age built from "sleep regularity" (that term was **deleted**
///     on 2026-08-01 with a build-failing test guarding the deletion).
///   * **Six sentences would have been blocked had a model written them** —
///     personal death-risk numbers on RHR and steps (`resting_heart_rate` D13 is
///     the declared source of a live output rule), "fight-or-flight" on a score
///     whose note forbids inferring valence, SpO₂ "95–100% is normal / below
///     90%" against a note whose threshold is ~92% and whose device error is
///     unquantified, and the `recovery` explainer denying that a composite ships
///     while the `recovery_score` explainer three entries above describes it.
///   * **`energy` printed `~1,760/day` as the owner's BMR.** `grep` found that
///     string in exactly one place in the repo: the explainer. BMR is per-owner
///     (Mifflin–St Jeor over the profile and the last logged weight) and already
///     ships as `basal_calories`. Every owner was shown a stranger's number.
///
/// ## What was done about it
///
/// Each explainer now carries [MetricInfo.notes] — real corpus ids — and the
/// sheet renders them as sources with the **weakest** cited grade, the same rule
/// `jobs/recs.py::_provable_grade` applies on the server. Claims the corpus
/// refutes are corrected to what it says; claims no note covers are **not
/// invented into citations and not quietly deleted** — they are stated as what
/// they are, and [MetricInfo.uncited] names them so the sheet can say so out
/// loud rather than letting the citation row imply cover it does not give.
///
/// The full per-claim audit — every quote checked, every note read — is in the
/// work-package report, not restated here. What is here is the outcome.
library;

import 'package:healthee/shared/metric_info/explainers_body.dart';
import 'package:healthee/shared/metric_info/explainers_recovery.dart';
import 'package:healthee/shared/metric_info/explainers_sleep.dart';
import 'package:meta/meta.dart';

/// What one metric is, what to aim for, why it matters — and what backs that.
@immutable
class MetricInfo {
  /// Builds one explainer.
  ///
  /// [notes] must be real ids from `packages/knowledge/manifest.json`.
  /// `test/shared/metric_info_grounding_test.dart` resolves every one of them
  /// against the generated tables and fails on an id the corpus does not have,
  /// which is what stops a plausible-looking id being typed here.
  const MetricInfo({
    required this.title,
    required this.what,
    required this.target,
    required this.why,
    required this.notes,
    this.uncited = '',
  });

  /// The layman name.
  final String title;

  /// What it is, in plain words.
  final String what;

  /// What to aim for — the optimal value or range.
  final String target;

  /// Why it matters, and the evidence behind it.
  final String why;

  /// The corpus notes backing the three blocks above, most relevant first.
  ///
  /// Ordered rather than a set: the sheet lists them in this order, and the
  /// first one is the note a reader should open to check the headline claim.
  final List<String> notes;

  /// What this explainer says that **[notes] does not cover**, in plain words.
  ///
  /// Empty for most. Non-empty is not a defect to be tidied away — it is the
  /// honest half of a citation row. A surface that lists four sources beside a
  /// paragraph implies the paragraph is sourced; where part of it is our own
  /// arithmetic, our own product decision, or a threshold we chose, saying so is
  /// the difference between a citation and a costume.
  final String uncited;
}

/// Keyed by the card identity legacy uses in `infoKey`.
///
/// Split across three files by domain — one map of seventeen entries with their
/// citations does not fit in 400 lines, and the split is by what a reader would
/// look for rather than by size.
const Map<String, MetricInfo> kMetricInfo = <String, MetricInfo>{
  ...kRecoveryExplainers,
  ...kBodyExplainers,
  ...kSleepExplainers,
};
